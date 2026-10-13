"""ファイルシステム操作の共通処理。"""

from __future__ import annotations

import hashlib
import os
import shutil
import stat
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from cleaner import winapi

_FILE_ATTRIBUTE_HIDDEN = 0x2
_FILE_ATTRIBUTE_SYSTEM = 0x4
_FILE_ATTRIBUTE_REPARSE_POINT = 0x400
_FILE_ATTRIBUTE_OFFLINE = 0x1000
_FILE_ATTRIBUTE_RECALL_ON_OPEN = 0x40000
_FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000
_CLOUD_ONLY_ATTRIBUTES = (
    _FILE_ATTRIBUTE_OFFLINE | _FILE_ATTRIBUTE_RECALL_ON_OPEN | _FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS
)

# 隔離時にハッシュを取るファイルサイズの上限 (これより大きいファイルは時間がかかるので省略)
HASH_LIMIT = 512 * 1024 * 1024


def longpath(path: Path | str) -> str:
    """Windows で 260 文字を超えるパスを扱えるよう `\\\\?\\` 形式にする。"""
    s = os.fspath(path)
    if winapi.IS_WINDOWS and os.path.isabs(s) and not s.startswith("\\\\"):  # pragma: no cover
        return "\\\\?\\" + os.path.normpath(s)
    return s


def norm(path: Path | str) -> str:
    return os.path.normcase(os.path.abspath(os.fspath(path)))


def is_under(path: Path | str, root: Path | str) -> bool:
    """path が root 自身またはその配下なら True (Windows では大文字小文字を区別しない)。"""
    p, r = norm(path), norm(root)
    if p == r:
        return True
    return p.startswith(r if r.endswith(os.sep) else r + os.sep)


def is_link(st: os.stat_result) -> bool:
    """シンボリックリンク・ジャンクション等のリパースポイントなら True。"""
    attrs = getattr(st, "st_file_attributes", 0)
    return stat.S_ISLNK(st.st_mode) or bool(attrs & _FILE_ATTRIBUTE_REPARSE_POINT)


def is_system_hidden(st: os.stat_result) -> bool:
    attrs = getattr(st, "st_file_attributes", 0)
    return bool(attrs & _FILE_ATTRIBUTE_HIDDEN) and bool(attrs & _FILE_ATTRIBUTE_SYSTEM)


def is_cloud_only(st: os.stat_result) -> bool:
    """OneDrive 等の「クラウドのみ」ファイルなら True (中身を読むとダウンロードが始まる)。"""
    return bool(getattr(st, "st_file_attributes", 0) & _CLOUD_ONLY_ATTRIBUTES)


@dataclass
class TreeStats:
    size: int
    newest_mtime: float
    files: int


def tree_stats(path: Path) -> TreeStats:
    """ファイルまたはフォルダの合計サイズと最新の更新日時。リンクは辿らない。"""
    st = os.lstat(longpath(path))
    if not stat.S_ISDIR(st.st_mode) or is_link(st):
        return TreeStats(st.st_size, st.st_mtime, 1)
    # フォルダ自体の更新日時は中身の追加・削除で変わるだけなので、中のファイルで判断する
    size, newest, files = 0, 0.0, 0
    for _, fst in walk_files(path):
        size += fst.st_size
        newest = max(newest, fst.st_mtime)
        files += 1
    return TreeStats(size, newest if files else st.st_mtime, files)


def walk_files(root: Path) -> Iterator[tuple[Path, os.stat_result]]:
    """root 配下のファイルを列挙する。リンクは辿らず、アクセスできない場所は飛ばす。"""
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            entries = list(os.scandir(longpath(current)))
        except OSError:
            continue
        for entry in entries:
            path = current / entry.name
            try:
                st = entry.stat(follow_symlinks=False)
            except OSError:
                continue
            if is_link(st):
                continue
            if stat.S_ISDIR(st.st_mode):
                stack.append(path)
            else:
                yield path, st


def unique_path(path: Path) -> Path:
    """同名が存在する場合は `名前 (1).ext` のように連番を付ける。"""
    if not os.path.lexists(longpath(path)):
        return path
    n = 1
    while True:
        candidate = path.with_name(f"{path.stem} ({n}){path.suffix}")
        if not os.path.lexists(longpath(candidate)):
            return candidate
        n += 1


def remove_path(path: Path) -> None:
    """ファイルまたはフォルダを削除する。読み取り専用属性が付いていても消す。"""
    lp = longpath(path)

    def _on_error(func, p, _exc):
        os.chmod(p, stat.S_IWRITE)
        func(p)

    st = os.lstat(lp)
    if stat.S_ISDIR(st.st_mode) and not is_link(st):
        shutil.rmtree(lp, onexc=_on_error)
    else:
        try:
            os.unlink(lp)
        except PermissionError:
            os.chmod(lp, stat.S_IWRITE)
            os.unlink(lp)


def file_hash(path: Path, limit: int | None = HASH_LIMIT) -> str | None:
    """BLAKE2b ハッシュ (16進)。フォルダや limit より大きいファイルは None (limit=None なら上限なし)。"""
    try:
        st = os.lstat(longpath(path))
        if not stat.S_ISREG(st.st_mode) or (limit is not None and st.st_size > limit):
            return None
        h = hashlib.blake2b(digest_size=20)
        with open(longpath(path), "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def human_size(n: int) -> str:
    value = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024:
            return f"{value:.0f}{unit}" if unit == "B" else f"{value:.1f}{unit}"
        value /= 1024
    return f"{value:.1f}TB"
