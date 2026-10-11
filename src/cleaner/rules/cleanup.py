"""F1: 不要ファイル削除 (仕様 5 章 F1)。

各カテゴリの関数は Candidate (整理候補) または Skipped (保護されたため対象外) を返す。
実際の隔離・削除は engine が行う。
"""

from __future__ import annotations

import logging
import os
import stat
import struct
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

from cleaner.appdirs import AppPaths
from cleaner.drives import Drive
from cleaner.fsutil import is_link, longpath, tree_stats, walk_files
from cleaner.models import Candidate, Skipped
from cleaner.protect import ANY_EXTENSION, Protector

log = logging.getLogger(__name__)

FEATURE = "F1"

CATEGORY_LABELS = {
    "temp": "一時ファイル",
    "recycle_bin": "ゴミ箱",
    "browser_cache": "ブラウザキャッシュ",
    "thumbnail_cache": "サムネイルキャッシュ",
    "crash_dumps": "クラッシュダンプ",
    "partial_downloads": "中断ダウンロード",
    "dev_caches": "開発系キャッシュ",
}

PARTIAL_DOWNLOAD_SUFFIXES = {".crdownload", ".part", ".partial", ".tmp"}
DEV_CACHE_NAMES = {"node_modules", "__pycache__", ".gradle"}

# (表示名, プロセス名, %LOCALAPPDATA% からのキャッシュフォルダの glob)
BROWSERS = [
    ("Chrome", "chrome.exe", [
        "Google/Chrome/User Data/*/Cache/Cache_Data",
        "Google/Chrome/User Data/*/Code Cache",
        "Google/Chrome/User Data/*/GPUCache",
    ]),
    ("Edge", "msedge.exe", [
        "Microsoft/Edge/User Data/*/Cache/Cache_Data",
        "Microsoft/Edge/User Data/*/Code Cache",
        "Microsoft/Edge/User Data/*/GPUCache",
    ]),
    ("Firefox", "firefox.exe", [
        "Mozilla/Firefox/Profiles/*/cache2",
    ]),
]

# Windows FILETIME (1601-01-01 からの 100ns 単位) と UNIX 時刻の差
_FILETIME_EPOCH_DIFF = 116444736000000000


@dataclass
class CleanupContext:
    paths: AppPaths
    cfg: dict
    drives: list[Drive]
    now: datetime
    protector: Protector
    running_processes: Callable[[], set[str]]


Result = Candidate | Skipped


def collect(ctx: CleanupContext) -> Iterator[Result]:
    c = ctx.cfg["cleanup"]
    categories: list[tuple[str, Callable[[CleanupContext], Iterator[Result]]]] = [
        ("temp", _temp),
        ("recycle_bin", _recycle_bin),
        ("browser_cache", _browser_cache),
        ("thumbnail_cache", _thumbnail_cache),
        ("crash_dumps", _crash_dumps),
        ("partial_downloads", _partial_downloads),
        ("dev_caches", _dev_caches),
    ]
    for name, func in categories:
        if not c.get(name):
            continue
        try:
            yield from func(ctx)
        except OSError as e:
            log.warning("%s の検出中にエラー: %s", CATEGORY_LABELS[name], e)


def _immediate(ctx: CleanupContext, category: str) -> bool:
    return category in ctx.cfg["cleanup"]["immediate"]


def _older_than(ctx: CleanupContext, mtime: float, days: int) -> bool:
    return ctx.now.timestamp() - mtime >= days * 86400


def _consider(
    ctx: CleanupContext,
    path: Path,
    category: str,
    reason: str,
    *,
    min_age_days: int = 0,
    allow_roots: tuple[Path, ...] = (),
    allow_exts: tuple[str, ...] = (),
    allow_git: bool = False,
    entries: list[Path] | None = None,
) -> Result | None:
    """1 つのパスを候補として評価する。条件に合わなければ None。"""
    try:
        st = os.lstat(longpath(path))
        stats = tree_stats(path)
    except OSError:
        return None
    if not _older_than(ctx, stats.newest_mtime, min_age_days):
        return None
    protected = ctx.protector.check(
        path, allow_roots=allow_roots, allow_exts=allow_exts, allow_git=allow_git,
        newest_mtime=stats.newest_mtime,
    )
    if protected:
        return Skipped(path, category, protected)
    return Candidate(
        path=path,
        feature=FEATURE,
        category=category,
        reason=reason,
        size=stats.size,
        is_dir=stat.S_ISDIR(st.st_mode) and not is_link(st),
        immediate=_immediate(ctx, category),
        entries=entries or [],
    )


def _scandir(path: Path) -> list[os.DirEntry]:
    try:
        return list(os.scandir(longpath(path)))
    except OSError:
        return []


# ---- 各カテゴリ ----


def _temp(ctx: CleanupContext) -> Iterator[Result]:
    days = ctx.cfg["cleanup"]["temp_days"]
    temp = ctx.paths.temp
    for entry in _scandir(temp):
        r = _consider(
            ctx, temp / entry.name, "temp", f"一時ファイル ({days}日以上未更新)",
            min_age_days=days, allow_roots=(temp,),
        )
        if r:
            yield r


def parse_recycle_info(data: bytes) -> tuple[datetime, str] | None:
    """ゴミ箱の $I ファイルから (削除日時, 元のパス) を取り出す。"""
    if len(data) < 24:
        return None
    version, _size, filetime = struct.unpack_from("<qqq", data, 0)
    if version == 1:  # Vista〜8.1: 固定長 260 文字
        raw = data[24:24 + 520]
    elif version == 2:  # Windows 10 以降: 文字数 (4 バイト) + 可変長
        if len(data) < 28:
            return None
        (length,) = struct.unpack_from("<i", data, 24)
        raw = data[28:28 + length * 2]
    else:
        return None
    original = raw.decode("utf-16-le", errors="replace").split("\x00", 1)[0]
    deleted_at = datetime.fromtimestamp((filetime - _FILETIME_EPOCH_DIFF) / 10_000_000)
    return deleted_at, original


def _recycle_bin(ctx: CleanupContext) -> Iterator[Result]:
    days = ctx.cfg["cleanup"]["recycle_bin_days"]
    for drive in ctx.drives:
        bin_dir = drive.root / "$Recycle.Bin"
        for sid_entry in _scandir(bin_dir):
            sid_dir = bin_dir / sid_entry.name
            for entry in _scandir(sid_dir):
                if not entry.name.upper().startswith("$I"):
                    continue
                info_path = sid_dir / entry.name
                try:
                    parsed = parse_recycle_info(Path(longpath(info_path)).read_bytes())
                except OSError:
                    continue
                if parsed is None:
                    continue
                deleted_at, original = parsed
                if ctx.now - deleted_at < timedelta(days=days):
                    continue
                body = sid_dir / ("$R" + entry.name[2:])
                if not os.path.lexists(longpath(body)):
                    continue
                r = _consider(
                    ctx, body, "recycle_bin",
                    f"ゴミ箱 ({deleted_at:%Y-%m-%d} に削除: {original})",
                    allow_roots=(bin_dir,), allow_exts=(ANY_EXTENSION,),
                    entries=[body, info_path],
                )
                if r:
                    yield r


def _browser_cache(ctx: CleanupContext) -> Iterator[Result]:
    running = ctx.running_processes()
    local = ctx.paths.localappdata
    for label, process, patterns in BROWSERS:
        cache_dirs = [p for pattern in patterns for p in local.glob(pattern) if p.is_dir()]
        if not cache_dirs:
            continue
        if process in running:
            yield Skipped(local / patterns[0].split("/")[0], "browser_cache", f"{label} が起動中")
            continue
        for cache_dir in cache_dirs:
            files, size = [], 0
            for path, st in walk_files(cache_dir):
                if ctx.protector.check(path, allow_roots=(cache_dir,), newest_mtime=st.st_mtime) is None:
                    files.append(path)
                    size += st.st_size
            if files:
                yield Candidate(
                    path=cache_dir,
                    feature=FEATURE,
                    category="browser_cache",
                    reason=f"{label} のキャッシュ ({len(files)} ファイル)",
                    size=size,
                    is_dir=True,
                    immediate=_immediate(ctx, "browser_cache"),
                    entries=files,
                )


def _thumbnail_cache(ctx: CleanupContext) -> Iterator[Result]:
    explorer = ctx.paths.localappdata / "Microsoft" / "Windows" / "Explorer"
    for path in explorer.glob("thumbcache_*.db"):
        r = _consider(
            ctx, path, "thumbnail_cache", "サムネイルキャッシュ (自動で再作成されます)",
            allow_roots=(explorer,), allow_exts=(".db",),
        )
        if r:
            yield r


def _crash_dumps(ctx: CleanupContext) -> Iterator[Result]:
    days = ctx.cfg["cleanup"]["crash_dump_days"]
    dumps = ctx.paths.localappdata / "CrashDumps"
    for entry in _scandir(dumps):
        r = _consider(
            ctx, dumps / entry.name, "crash_dumps", f"クラッシュダンプ ({days}日以上前)",
            min_age_days=days, allow_roots=(dumps,),
        )
        if r:
            yield r


def _partial_downloads(ctx: CleanupContext) -> Iterator[Result]:
    days = ctx.cfg["cleanup"]["partial_download_days"]
    downloads = ctx.paths.downloads
    for entry in _scandir(downloads):
        if not entry.is_file(follow_symlinks=False):
            continue
        if Path(entry.name).suffix.lower() not in PARTIAL_DOWNLOAD_SUFFIXES:
            continue
        r = _consider(
            ctx, downloads / entry.name, "partial_downloads", f"中断したダウンロード ({days}日以上前)",
            min_age_days=days,
        )
        if r:
            yield r


def _dev_caches(ctx: CleanupContext) -> Iterator[Result]:
    days = ctx.cfg["cleanup"]["dev_cache_days"]
    roots = [ctx.paths.expand(r) for r in ctx.cfg["cleanup"]["dev_cache_roots"]]
    seen: set[str] = set()
    for root in roots:
        for dirpath, dirnames, _files in os.walk(root):
            current = Path(dirpath)
            keep = []
            for name in dirnames:
                full = current / name
                if name in DEV_CACHE_NAMES:
                    key = os.path.normcase(str(full))
                    if key in seen:
                        continue
                    seen.add(key)
                    project = current
                    try:
                        project_mtime = tree_stats(project).newest_mtime
                    except OSError:
                        continue
                    if _older_than(ctx, project_mtime, days):
                        r = _consider(
                            ctx, full, "dev_caches",
                            f"{name} (プロジェクトが{days}日以上未更新: {project.name})",
                            allow_git=True,
                        )
                        if r:
                            yield r
                    continue  # キャッシュの中には入らない
                if name.startswith(".") or ctx.protector.is_excluded_dir(full):
                    continue
                try:
                    if is_link(os.lstat(full)):
                        continue
                except OSError:
                    continue
                keep.append(name)
            dirnames[:] = keep
