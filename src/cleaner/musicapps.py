"""デスクトップと C ドライブから音楽生成アプリ・関連ソフトを探し、1 つの HTML にまとめる。

調べる場所:
  - アンインストール情報 (レジストリ HKLM / HKCU の Uninstall キー)
  - デスクトップ (ユーザー / パブリック / OneDrive) とスタートメニューのショートカット (.lnk / .url)
  - Program Files、%LOCALAPPDATA%\\Programs、C:\\ 直下、ユーザーフォルダ直下、デスクトップ上のフォルダ
    (ポータブル版や Python 製の AI ツールを見つけるため)
  - VST / VST3 / CLAP / AAX プラグインフォルダ

このモジュールはファイルを読むだけで、何も変更・削除しない。
"""

from __future__ import annotations

import html
import json
import os
import re
import struct
import sys
from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from cleaner import winapi
from cleaner.fsutil import human_size
from cleaner.musicapps_catalog import (
    CATALOG,
    CATEGORY_ORDER,
    GENERIC_EXCLUDE,
    GENERIC_KEYWORDS,
    CatalogEntry,
)

OTHER_CATEGORY = CATEGORY_ORDER[-1]

# 起動ファイルとして選ばないもの
_EXE_SKIP = re.compile(
    r"(unins|uninstall|setup|install|update|crash|report|helper|service|vc_?redist|dotnet|python|pythonw"
    r"|conhost|elevate|register|activation|repair|diag|bugsplat|cefsharp|squirrel|7z|ffmpeg|ffprobe)",
    re.I,
)
_SKIP_DIRS = {
    "windows", "$recycle.bin", "system volume information", "recovery", "perflogs", "msocache",
    "$windows.~bt", "$windows.~ws", "$winreagent", "config.msi", "programdata", "users",
    "program files", "program files (x86)", "node_modules", ".git", "__pycache__", "site-packages",
    "appdata", ".cleaner_quarantine",
}
PLUGIN_EXTS = {".vst3": "VST3", ".dll": "VST2", ".clap": "CLAP", ".aaxplugin": "AAX"}


@dataclass
class Source:
    """アプリを見つけた手がかり 1 件。"""

    kind: str  # registry / shortcut / url / folder
    name: str
    location: Path | None = None  # インストール先フォルダ
    target: Path | None = None  # ショートカットのリンク先・DisplayIcon の exe
    shortcut: Path | None = None  # ショートカットファイル自体
    url: str | None = None
    size: int | None = None  # レジストリの EstimatedSize (バイト)
    publisher: str = ""
    version: str = ""
    args: str = ""


@dataclass
class AppRecord:
    key: str
    name: str
    category: str
    purpose: str
    url: str
    howto: str
    launch_note: str = ""
    exes: tuple[str, ...] = ()
    sources: list[Source] = field(default_factory=list)
    # 以下は resolve() で埋める
    location: Path | None = None
    size: int | None = None
    size_note: str = ""
    launch_file: Path | None = None
    launch_method: str = ""
    shortcuts: list[Path] = field(default_factory=list)
    version: str = ""
    publisher: str = ""
    detected_names: list[str] = field(default_factory=list)


@dataclass
class PluginRecord:
    name: str
    format: str
    path: Path
    size: int


@dataclass
class ScanRoots:
    desktops: list[Path] = field(default_factory=list)
    start_menus: list[Path] = field(default_factory=list)
    program_dirs: list[Path] = field(default_factory=list)  # 2 階層まで (メーカー\製品)
    shallow_dirs: list[Path] = field(default_factory=list)  # C:\ 直下・ユーザーフォルダ直下など
    plugin_dirs: list[Path] = field(default_factory=list)


@dataclass
class ScanResult:
    apps: list[AppRecord]
    plugins: list[PluginRecord]
    roots: ScanRoots
    scanned_at: datetime
    computer: str
    errors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# マッチング
# ---------------------------------------------------------------------------

_COMPILED = [(e, [re.compile(p, re.I) for p in e.match]) for e in CATALOG]
_GENERIC = [re.compile(p, re.I) for p in GENERIC_KEYWORDS]
_GENERIC_EX = [re.compile(p, re.I) for p in GENERIC_EXCLUDE]


def match_catalog(*names: str) -> CatalogEntry | None:
    """名前のどれかがカタログの項目に一致すればその項目を返す。より具体的な (先に書いた) 項目を優先。"""
    texts = [_normalize(n) for n in names if n]
    for entry, pats in _COMPILED:
        for t in texts:
            if any(p.search(t) for p in pats):
                return entry
    return None


def looks_musical(name: str) -> bool:
    t = _normalize(name)
    if any(p.search(t) for p in _GENERIC_EX):
        return False
    return any(p.search(t) for p in _GENERIC)


def _normalize(name: str) -> str:
    name = re.sub(r"\.(lnk|url|exe|bat)$", "", name.strip(), flags=re.I)
    return re.sub(r"[_]+", " ", name).lower()


# ---------------------------------------------------------------------------
# ショートカット (.lnk / .url) の読み取り
# ---------------------------------------------------------------------------


@dataclass
class Shortcut:
    target: str | None
    args: str = ""
    working_dir: str | None = None


def read_lnk(path: Path) -> Shortcut | None:
    """Windows のショートカット (.lnk, MS-SHLLINK 形式) からリンク先を読む。"""
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if len(data) < 0x4C or struct.unpack_from("<I", data, 0)[0] != 0x4C:
        return None
    flags = struct.unpack_from("<I", data, 0x14)[0]
    pos = 0x4C
    try:
        if flags & 0x1:  # HasLinkTargetIDList
            pos += 2 + struct.unpack_from("<H", data, pos)[0]
        target = None
        if flags & 0x2:  # HasLinkInfo
            info_size, header_size, info_flags, _vol, base_off, _net, suffix_off = struct.unpack_from(
                "<7I", data, pos
            )
            if info_flags & 0x1:
                if header_size >= 0x24:
                    ubase_off = struct.unpack_from("<I", data, pos + 0x1C)[0]
                    target = _read_cstr_w(data, pos + ubase_off) if ubase_off else None
                if not target:
                    target = _read_cstr_a(data, pos + base_off)
                    suffix = _read_cstr_a(data, pos + suffix_off) if suffix_off else ""
                    target = target + suffix if target else None
            pos += info_size
        unicode = bool(flags & 0x80)
        strings: dict[int, str] = {}
        for bit in (0x4, 0x8, 0x10, 0x20, 0x40):  # Name, RelativePath, WorkingDir, Arguments, IconLocation
            if flags & bit:
                count = struct.unpack_from("<H", data, pos)[0]
                pos += 2
                nbytes = count * 2 if unicode else count
                raw = data[pos:pos + nbytes]
                strings[bit] = raw.decode("utf-16-le" if unicode else _ansi(), errors="replace")
                pos += nbytes
    except (struct.error, IndexError):
        return None
    if not target and 0x8 in strings:
        target = str((path.parent / strings[0x8]).resolve()) if not _is_win_abs(strings[0x8]) else strings[0x8]
    return Shortcut(target=target, args=strings.get(0x20, ""), working_dir=strings.get(0x10))


def read_url_file(path: Path) -> str | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    m = re.search(r"^\s*URL\s*=\s*(\S+)", text, re.M | re.I)
    return m.group(1) if m else None


def _ansi() -> str:
    return "mbcs" if winapi.IS_WINDOWS else "cp932"


def _read_cstr_a(data: bytes, off: int) -> str:
    end = data.find(b"\x00", off)
    return data[off:end if end >= 0 else None].decode(_ansi(), errors="replace")


def _read_cstr_w(data: bytes, off: int) -> str:
    end = off
    while end + 1 < len(data) and data[end:end + 2] != b"\x00\x00":
        end += 2
    return data[off:end].decode("utf-16-le", errors="replace")


def _is_win_abs(p: str) -> bool:
    return bool(re.match(r"^[A-Za-z]:[\\/]|^\\\\", p))


def _to_path(p: str | None) -> Path | None:
    if not p:
        return None
    p = os.path.expandvars(p.strip().strip('"'))
    return Path(p) if p else None


# ---------------------------------------------------------------------------
# 情報源ごとの収集
# ---------------------------------------------------------------------------


def registry_entries() -> list[Source]:  # pragma: no cover - Windows 専用
    """Uninstall キーからインストール済みソフトを列挙する。"""
    if not winapi.IS_WINDOWS:
        return []
    import winreg

    keys = [
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_64KEY),
        (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", winreg.KEY_WOW64_32KEY),
        (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", 0),
    ]
    result: list[Source] = []
    seen: set[tuple[str, str]] = set()
    for hive, path, view in keys:
        try:
            root = winreg.OpenKey(hive, path, 0, winreg.KEY_READ | view)
        except OSError:
            continue
        with root:
            i = 0
            while True:
                try:
                    sub = winreg.EnumKey(root, i)
                except OSError:
                    break
                i += 1
                try:
                    with winreg.OpenKey(root, sub) as k:
                        vals = _reg_values(winreg, k)
                except OSError:
                    continue
                name = str(vals.get("DisplayName") or "").strip()
                if not name or vals.get("SystemComponent") == 1 or vals.get("ParentKeyName"):
                    continue
                dedup = (name.lower(), str(vals.get("DisplayVersion") or ""))
                if dedup in seen:
                    continue
                seen.add(dedup)
                icon = str(vals.get("DisplayIcon") or "").split(",")[0]
                est = vals.get("EstimatedSize")
                result.append(Source(
                    kind="registry",
                    name=name,
                    location=_to_path(str(vals.get("InstallLocation") or "")),
                    target=_to_path(icon) if icon.lower().strip('"').endswith(".exe") else None,
                    size=int(est) * 1024 if isinstance(est, int) and est > 0 else None,
                    publisher=str(vals.get("Publisher") or ""),
                    version=str(vals.get("DisplayVersion") or ""),
                    url=str(vals.get("URLInfoAbout") or vals.get("HelpLink") or "") or None,
                ))
    return result


def _reg_values(winreg, key) -> dict:  # pragma: no cover - Windows 専用
    vals = {}
    j = 0
    while True:
        try:
            n, v, _t = winreg.EnumValue(key, j)
        except OSError:
            return vals
        vals[n] = v
        j += 1


def shortcut_entries(dirs: Iterable[Path], *, recursive: bool) -> list[Source]:
    result: list[Source] = []
    for d in dirs:
        if not d.is_dir():
            continue
        files = d.rglob("*") if recursive else d.iterdir()
        for f in _safe_iter(files):
            suffix = f.suffix.lower()
            try:
                if not f.is_file():
                    continue
            except OSError:
                continue
            if suffix == ".lnk":
                sc = read_lnk(f)
                target = _to_path(sc.target) if sc else None
                result.append(Source("shortcut", f.stem, target=target, shortcut=f, args=sc.args if sc else "",
                                     location=_to_path(sc.working_dir) if sc else None))
            elif suffix == ".url":
                url = read_url_file(f)
                if url and url.lower().startswith("file:"):
                    result.append(Source("shortcut", f.stem, target=_to_path(url[5:].lstrip("/")), shortcut=f))
                elif url:
                    result.append(Source("url", f.stem, shortcut=f, url=url))
            elif suffix in (".exe", ".bat", ".cmd"):
                result.append(Source("shortcut", f.stem, target=f, shortcut=f, location=f.parent))
    return result


def _safe_iter(it: Iterable[Path]) -> Iterator[Path]:
    it = iter(it)
    while True:
        try:
            yield next(it)
        except StopIteration:
            return
        except OSError:
            continue


def folder_entries(dirs: Iterable[Path], depth: int) -> list[Source]:
    """フォルダ名がカタログに一致するものを探す。一致したフォルダの中へは降りない。"""
    result: list[Source] = []

    def walk(d: Path, level: int) -> None:
        try:
            children = sorted(os.scandir(d), key=lambda e: e.name.lower())
        except OSError:
            return
        for e in children:
            try:
                if not e.is_dir(follow_symlinks=False) or _is_junction(e):
                    continue
            except OSError:
                continue
            low = e.name.lower()
            if low in _SKIP_DIRS or low.startswith("."):
                continue
            if match_catalog(e.name):
                result.append(Source("folder", e.name, location=Path(e.path)))
            elif level < depth:
                walk(Path(e.path), level + 1)

    for d in dirs:
        if d.is_dir():
            walk(d, 1)
    return result


def _is_junction(e: os.DirEntry) -> bool:
    fn = getattr(e, "is_junction", None)
    return bool(fn and fn())


def plugin_entries(dirs: Iterable[Path], size_of: Callable[[Path], int]) -> list[PluginRecord]:
    result: list[PluginRecord] = []
    seen: set[str] = set()
    for d in dirs:
        if not d.is_dir():
            continue
        for p in _iter_plugins(d, 3):
            key = str(p).lower()
            if key in seen:
                continue
            seen.add(key)
            fmt = PLUGIN_EXTS[p.suffix.lower()]
            result.append(PluginRecord(p.stem if p.suffix else p.name, fmt, p, size_of(p)))
    result.sort(key=lambda r: (r.format, r.name.lower()))
    return result


def _iter_plugins(d: Path, depth: int) -> Iterator[Path]:
    try:
        children = sorted(d.iterdir(), key=lambda p: p.name.lower())
    except OSError:
        return
    for p in children:
        ext = p.suffix.lower()
        if ext in PLUGIN_EXTS:
            yield p
        elif depth > 1:
            try:
                is_dir = p.is_dir() and not p.is_symlink()
            except OSError:
                continue
            if is_dir:
                yield from _iter_plugins(p, depth - 1)


# ---------------------------------------------------------------------------
# 容量・起動ファイル
# ---------------------------------------------------------------------------


def dir_size(path: Path, limit_files: int = 400_000) -> int:
    """フォルダの合計サイズ。シンボリックリンク・ジャンクションはたどらない。"""
    try:
        if path.is_file():
            return path.stat().st_size
    except OSError:
        return 0
    total = 0
    count = 0
    stack = [str(path)]
    while stack:
        cur = stack.pop()
        try:
            with os.scandir(cur) as it:
                for e in it:
                    try:
                        if e.is_symlink() or _is_junction(e):
                            continue
                        if e.is_dir(follow_symlinks=False):
                            stack.append(e.path)
                        else:
                            total += e.stat(follow_symlinks=False).st_size
                            count += 1
                    except OSError:
                        continue
                    if count >= limit_files:
                        return total
        except OSError:
            continue
    return total


def find_launch_file(folder: Path, exes: tuple[str, ...], depth: int = 3) -> Path | None:
    """カタログの起動ファイル名を優先して探し、なければフォルダ直下の主な exe を選ぶ。"""
    wanted = {n.lower(): i for i, n in enumerate(exes)}
    best: tuple[int, int, Path] | None = None  # (優先順位, 深さ, パス)
    fallback: list[tuple[int, int, Path]] = []  # (深さ, -サイズ, パス)

    def walk(d: Path, level: int) -> None:
        nonlocal best
        try:
            children = list(os.scandir(d))
        except OSError:
            return
        for e in children:
            try:
                if e.is_dir(follow_symlinks=False):
                    low = e.name.lower()
                    if level < depth and low not in _SKIP_DIRS and not low.startswith((".", "_")) \
                            and low not in ("models", "venv", "env", "runtime", "python_embeded", "lib", "libs"):
                        walk(Path(e.path), level + 1)
                    continue
                low = e.name.lower()
                if low in wanted:
                    cand = (wanted[low], level, Path(e.path))
                    if best is None or cand[:2] < best[:2]:
                        best = cand
                elif low.endswith(".exe") and not _EXE_SKIP.search(low) and level <= 2:
                    fallback.append((level, -e.stat().st_size, Path(e.path)))
            except OSError:
                continue

    if folder.is_dir():
        walk(folder, 1)
    if best:
        return best[2]
    if fallback:
        return sorted(fallback)[0][2]
    return None


# ---------------------------------------------------------------------------
# 集約
# ---------------------------------------------------------------------------


def collect(sources: Iterable[Source]) -> list[AppRecord]:
    apps: dict[str, AppRecord] = {}
    for s in sources:
        entry = match_catalog(s.name, s.target.stem if s.target else "", s.location.name if s.location else "")
        if s.kind == "url" and entry is None:
            continue
        if entry:
            rec = apps.get(entry.id)
            if rec is None:
                rec = apps[entry.id] = AppRecord(
                    key=entry.id, name=entry.name, category=entry.category, purpose=entry.purpose,
                    url=entry.url, howto=entry.howto, launch_note=entry.launch_note, exes=entry.exes,
                )
        elif s.kind == "registry" and looks_musical(s.name):
            key = "other:" + s.name.lower()
            rec = apps.get(key)
            if rec is None:
                rec = apps[key] = AppRecord(
                    key=key, name=s.name, category=OTHER_CATEGORY,
                    purpose="カタログ未登録のため自動判定。名前から音楽関連ソフトの可能性があります。",
                    url=s.url or "", howto="公式ページのマニュアルを参照してください。",
                )
        else:
            continue
        rec.sources.append(s)
    return list(apps.values())


def resolve(rec: AppRecord, size_of: Callable[[Path], int]) -> None:
    """集めた手がかりから、場所・容量・起動ファイル・起動方法を決める。"""
    names: list[str] = []
    for s in rec.sources:
        if s.name not in names:
            names.append(s.name)
        if s.version and not rec.version:
            rec.version = s.version
        if s.publisher and not rec.publisher:
            rec.publisher = s.publisher
        if s.shortcut and s.shortcut not in rec.shortcuts and not _SHORTCUT_SKIP.search(s.shortcut.stem):
            rec.shortcuts.append(s.shortcut)
    rec.detected_names = names

    # インストール先: レジストリの InstallLocation > レジストリの DisplayIcon の場所 > 一致したフォルダ
    # > ショートカットのリンク先の場所
    reg_targets = [s.target for s in rec.sources if s.kind == "registry" and s.target and _usable_target(s.target)]
    sc_targets = [s.target for s in rec.sources if s.kind == "shortcut" and s.target and _usable_target(s.target)]
    locs = [s.location for s in rec.sources if s.kind == "registry" and s.location and s.location.is_dir()]
    locs += [t.parent for t in reg_targets]
    locs += [s.location for s in rec.sources if s.kind == "folder" and s.location]
    locs += [t.parent for t in sc_targets if not _is_desktop_like(t.parent)]
    locs = [p for p in locs if p.is_dir() and len(p.parts) > 2]
    rec.location = locs[0] if locs else None

    # 起動ファイル: カタログの起動ファイル名 > ショートカットのリンク先 > DisplayIcon > フォルダ内の主な exe
    launch = find_launch_file(rec.location, rec.exes) if rec.location and rec.exes else None
    launch = launch or next((t for t in sc_targets + reg_targets if t.suffix.lower() in _LAUNCH_EXTS), None)
    if launch is None and rec.location:
        launch = find_launch_file(rec.location, ())
    if launch is None:  # Web サービスはブラウザ用ショートカット (.url) を起動ファイルとする
        launch = next((s.shortcut for s in rec.sources if s.kind == "url" and s.shortcut), None)
    rec.launch_file = launch

    # 容量
    reg_sizes = [s.size for s in rec.sources if s.size]
    if rec.location:
        rec.size = size_of(rec.location)
        rec.size_note = "フォルダ実測"
    if not rec.size and reg_sizes:
        rec.size = max(reg_sizes)
        rec.size_note = "インストール情報の推定値"
    if not rec.size and all(s.kind == "url" for s in rec.sources):
        rec.size_note = "Web サービスのため PC の容量は使いません"

    rec.launch_method = _launch_method(rec)


_LAUNCH_EXTS = (".exe", ".bat", ".cmd", ".py")
_SHORTCUT_SKIP = re.compile(
    r"(unins|uninstall|アンインストール|削除|readme|manual|マニュアル|help|ヘルプ|website|web site|homepage"
    r"|license|ライセンス|changelog|release notes|documentation|ドキュメント)",
    re.I,
)


def _usable_target(p: Path) -> bool:
    low = str(p).lower().replace("/", "\\")
    return p.exists() and "\\windows\\installer" not in low and not _EXE_SKIP.search(p.name)


def _is_desktop_like(p: Path) -> bool:
    return p.name.lower() in ("desktop", "デスクトップ", "downloads", "ダウンロード")


def _launch_method(rec: AppRecord) -> str:
    steps: list[str] = []
    desktop = [s for s in rec.shortcuts if _is_on_desktop(s)]
    start = [s for s in rec.shortcuts if "start menu" in str(s).lower() or "スタート メニュー" in str(s)]
    urls = [s for s in rec.sources if s.kind == "url" and s.url]
    if desktop:
        steps.append(f"デスクトップの「{desktop[0].stem}」をダブルクリック")
    if start:
        steps.append(f"スタートメニューで「{start[0].stem}」を検索して起動")
    if rec.launch_file and not desktop:
        kind = "バッチファイル" if rec.launch_file.suffix.lower() in (".bat", ".cmd") else "起動ファイル"
        if rec.launch_file.suffix.lower() == ".py":
            steps.append(f"コマンドプロンプトでフォルダに移動し python {rec.launch_file.name} を実行")
        else:
            steps.append(f"{kind}「{rec.launch_file.name}」をダブルクリック")
    if urls and not steps:
        steps.append(f"ブラウザで {urls[0].url} を開く")
    if not steps:
        if rec.category.startswith("音源・プラグイン"):
            steps.append("DAW を起動し、プラグインとして読み込む")
        else:
            steps.append("スタートメニューからアプリ名で検索して起動")
    text = " / ".join(steps)
    if rec.launch_note:
        text += "。" + rec.launch_note
    return text


def _is_on_desktop(p: Path) -> bool:
    return any(part.lower() in ("desktop", "デスクトップ") for part in p.parts)


# ---------------------------------------------------------------------------
# 既定の調査範囲
# ---------------------------------------------------------------------------


def default_roots() -> ScanRoots:
    env = os.environ
    home = Path.home()
    desktops: list[Path] = []
    if winapi.IS_WINDOWS:  # pragma: no cover - Windows 専用
        d = winapi.known_folder(winapi.FOLDERID_DESKTOP)
        if d:
            desktops.append(Path(d))
    desktops += [home / "Desktop", home / "OneDrive" / "Desktop", home / "OneDrive" / "デスクトップ"]
    if env.get("PUBLIC"):
        desktops.append(Path(env["PUBLIC"]) / "Desktop")
    for name, value in env.items():
        if name.upper().startswith("ONEDRIVE") and value:
            desktops += [Path(value) / "Desktop", Path(value) / "デスクトップ"]

    system_drive = Path((env.get("SystemDrive") or "C:") + "\\") if winapi.IS_WINDOWS else Path("/")
    pf = [Path(env[k]) for k in ("ProgramW6432", "ProgramFiles", "ProgramFiles(x86)") if env.get(k)]
    local = Path(env.get("LOCALAPPDATA", home / "AppData" / "Local"))
    appdata = Path(env.get("APPDATA", home / "AppData" / "Roaming"))
    program_data = Path(env.get("ProgramData", system_drive / "ProgramData"))

    plugin_dirs: list[Path] = []
    for base in pf:
        plugin_dirs += [base / "Common Files" / "VST3", base / "Common Files" / "VST2", base / "Common Files" / "CLAP",
                        base / "Common Files" / "Avid" / "Audio" / "Plug-Ins", base / "VSTPlugins",
                        base / "Steinberg" / "VSTPlugins", base / "Steinberg" / "VstPlugins", base / "Vstplugins",
                        base / "Image-Line" / "Shared" / "Plugins"]
    plugin_dirs += [local / "Programs" / "Common" / "VST3", local / "Programs" / "Common" / "CLAP"]

    return ScanRoots(
        desktops=_unique(desktops),
        start_menus=_unique([appdata / "Microsoft" / "Windows" / "Start Menu" / "Programs",
                             program_data / "Microsoft" / "Windows" / "Start Menu" / "Programs"]),
        program_dirs=_unique(pf + [local / "Programs"]),
        shallow_dirs=_unique([system_drive, home, home / "Documents", home / "Downloads"]),
        plugin_dirs=_unique(plugin_dirs),
    )


def _unique(paths: Iterable[Path]) -> list[Path]:
    seen: set[str] = set()
    out = []
    for p in paths:
        k = os.path.normcase(str(p))
        if k not in seen:
            seen.add(k)
            out.append(p)
    return out


# ---------------------------------------------------------------------------
# 実行
# ---------------------------------------------------------------------------


def scan(
    roots: ScanRoots | None = None,
    *,
    registry: Callable[[], list[Source]] = registry_entries,
    size_of: Callable[[Path], int] = dir_size,
    progress: Callable[[str], None] = lambda msg: None,
    now: datetime | None = None,
) -> ScanResult:
    roots = roots or default_roots()
    errors: list[str] = []
    sources: list[Source] = []

    progress("インストール情報 (レジストリ) を確認しています…")
    try:
        sources += registry()
    except OSError as e:  # pragma: no cover
        errors.append(f"レジストリを読めませんでした: {e}")
    progress("デスクトップとスタートメニューのショートカットを確認しています…")
    sources += shortcut_entries(roots.desktops, recursive=False)
    sources += shortcut_entries(roots.start_menus, recursive=True)
    progress("Program Files などのフォルダを確認しています…")
    sources += folder_entries(roots.program_dirs, depth=2)
    sources += folder_entries(roots.shallow_dirs, depth=2)
    sources += folder_entries(roots.desktops, depth=2)

    cache: dict[str, int] = {}

    def cached_size(p: Path) -> int:
        k = os.path.normcase(str(p))
        if k not in cache:
            cache[k] = size_of(p)
        return cache[k]

    apps = collect(sources)
    progress(f"{len(apps)} 件のアプリの容量と起動ファイルを調べています…")
    for rec in apps:
        resolve(rec, cached_size)
    order = {c: i for i, c in enumerate(CATEGORY_ORDER)}
    apps.sort(key=lambda r: (order.get(r.category, 99), r.name.lower()))

    progress("VST / VST3 / CLAP / AAX プラグインを確認しています…")
    plugins = plugin_entries(roots.plugin_dirs, cached_size)
    return ScanResult(apps, plugins, roots, now or datetime.now(), os.environ.get("COMPUTERNAME", ""), errors)


# ---------------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------------


def _e(v: object) -> str:
    return html.escape(str(v), quote=True)


def _file_link(p: Path | None, label: str | None = None) -> str:
    if not p:
        return '<span class="muted">不明</span>'
    uri = p.as_uri() if p.is_absolute() else str(p)
    return f'<a href="{_e(uri)}" title="{_e(p)}">{_e(label or p)}</a>'


def render_html(result: ScanResult) -> str:
    apps = result.apps
    total = sum(a.size or 0 for a in apps)
    plugin_total = sum(p.size for p in result.plugins)
    cats = [c for c in CATEGORY_ORDER if any(a.category == c for a in apps)]

    cards = []
    for a in apps:
        open_folder = _file_link(a.location) if a.location else '<span class="muted">不明</span>'
        url = (f'<a href="{_e(a.url)}" target="_blank" rel="noopener">{_e(a.url)}</a>'
               if a.url else '<span class="muted">不明</span>')
        size = (f"{human_size(a.size)} <span class='muted'>({_e(a.size_note)})</span>" if a.size
                else f'<span class="muted">{_e(a.size_note or "不明")}</span>')
        shortcuts = "".join(f"<li>{_file_link(s, s.name)}</li>" for s in a.shortcuts[:5])
        meta = " / ".join(x for x in (a.version and f"バージョン {a.version}", a.publisher) if x)
        found = "、".join(sorted({_SOURCE_LABELS[s.kind] for s in a.sources}))
        search = " ".join([a.name, a.category, a.purpose, *a.detected_names]).lower()
        cards.append(f"""
<article class="app" data-cat="{_e(a.category)}" data-search="{_e(search)}" data-size="{a.size or 0}">
  <header><h3>{_e(a.name)}</h3><span class="tag">{_e(a.category)}</span><span class="size">{size}</span></header>
  {f'<p class="meta">{_e(meta)}</p>' if meta else ''}
  <dl>
    <dt>用途</dt><dd>{_e(a.purpose)}</dd>
    <dt>公式ページ</dt><dd>{url}</dd>
    <dt>容量</dt><dd>{size}</dd>
    <dt>起動方法</dt><dd>{_e(a.launch_method)}</dd>
    <dt>起動ファイル</dt><dd><code>{_e(a.launch_file) if a.launch_file else '不明'}</code></dd>
    <dt>インストール先</dt><dd>{open_folder}</dd>
    <dt>簡単な利用方法</dt><dd>{_e(a.howto)}</dd>
    {f'<dt>ショートカット</dt><dd><ul>{shortcuts}</ul></dd>' if shortcuts else ''}
    <dt>検出元</dt><dd class="muted">{_e(found)} ({_e(" / ".join(a.detected_names[:4]))})</dd>
  </dl>
</article>""")

    rows = "".join(
        f"<tr data-search=\"{_e((a.name + ' ' + a.category).lower())}\" data-cat=\"{_e(a.category)}\">"
        f"<td><a href='#app-{i}'>{_e(a.name)}</a></td><td>{_e(a.category)}</td>"
        f"<td class='num' data-v='{a.size or 0}'>{human_size(a.size) if a.size else '-'}</td>"
        f"<td><code>{_e(a.launch_file.name) if a.launch_file else '-'}</code></td></tr>"
        for i, a in enumerate(apps)
    )
    cards = [c.replace('<article class="app"', f'<article id="app-{i}" class="app"', 1) for i, c in enumerate(cards)]

    plugin_rows = "".join(
        f"<tr><td>{_e(p.name)}</td><td>{_e(p.format)}</td><td class='num' data-v='{p.size}'>{human_size(p.size)}</td>"
        f"<td>{_file_link(p.path.parent)}</td></tr>"
        for p in result.plugins
    )
    options = "".join(f'<option value="{_e(c)}">{_e(c)}</option>' for c in cats)
    roots_list = "".join(
        f"<li><b>{_e(label)}</b>: {_e(', '.join(str(p) for p in paths if p.exists()) or '(なし)')}</li>"
        for label, paths in (
            ("デスクトップ", result.roots.desktops),
            ("スタートメニュー", result.roots.start_menus),
            ("プログラムフォルダ", result.roots.program_dirs),
            ("C ドライブ直下ほか", result.roots.shallow_dirs),
            ("プラグインフォルダ", result.roots.plugin_dirs),
        )
    )
    errors = "".join(f"<li>{_e(e)}</li>" for e in result.errors)
    data = json.dumps([
        {"name": a.name, "category": a.category, "size": a.size,
         "launch_file": str(a.launch_file) if a.launch_file else None,
         "location": str(a.location) if a.location else None, "url": a.url}
        for a in apps
    ], ensure_ascii=False).replace("</", "<\\/")

    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>音楽生成アプリ・関連ソフト一覧</title>
<style>
:root {{ --bg:#f6f7fb; --card:#fff; --fg:#1d2330; --muted:#6b7280; --line:#e3e6ee; --accent:#5b5bd6; --tag:#eef0ff; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --bg:#14161c; --card:#1d2029; --fg:#e7e9ee; --muted:#9aa1ad; --line:#2c303b; --accent:#9b9bff; --tag:#2a2d48; }}
}}
* {{ box-sizing: border-box; }}
body {{ margin:0; font-family: "Segoe UI", "Yu Gothic UI", "Meiryo", sans-serif; background:var(--bg); color:var(--fg);
       line-height:1.6; }}
main {{ max-width: 1100px; margin: 0 auto; padding: 24px 16px 64px; }}
h1 {{ font-size: 1.6rem; margin: 0 0 4px; }}
h2 {{ font-size: 1.2rem; margin: 36px 0 12px; border-bottom: 2px solid var(--line); padding-bottom: 4px; }}
h3 {{ font-size: 1.1rem; margin: 0; }}
a {{ color: var(--accent); word-break: break-all; }}
.muted {{ color: var(--muted); }}
.summary {{ display:flex; gap:12px; flex-wrap:wrap; margin: 16px 0; }}
.stat {{ background:var(--card); border:1px solid var(--line); border-radius:10px; padding:10px 16px; min-width:160px; }}
.stat b {{ display:block; font-size:1.4rem; }}
.toolbar {{ position: sticky; top:0; background:var(--bg); padding:10px 0; display:flex; gap:8px; flex-wrap:wrap; z-index:1; }}
.toolbar input, .toolbar select {{ padding:8px 10px; border:1px solid var(--line); border-radius:8px; background:var(--card);
  color:var(--fg); font-size:0.95rem; }}
.toolbar input {{ flex: 1; min-width: 220px; }}
table {{ width:100%; border-collapse: collapse; background:var(--card); border:1px solid var(--line); border-radius:10px;
  overflow:hidden; font-size:0.92rem; }}
th, td {{ padding:7px 10px; border-bottom:1px solid var(--line); text-align:left; vertical-align: top; }}
th {{ cursor:pointer; user-select:none; background:var(--tag); }}
td.num {{ text-align:right; white-space:nowrap; }}
.app {{ background:var(--card); border:1px solid var(--line); border-radius:12px; padding:16px 18px; margin:12px 0; }}
.app header {{ display:flex; align-items:center; gap:10px; flex-wrap:wrap; }}
.app .size {{ margin-left:auto; font-weight:600; }}
.tag {{ background:var(--tag); border-radius:999px; padding:1px 10px; font-size:0.8rem; }}
.meta {{ margin: 2px 0 0; color: var(--muted); font-size: 0.85rem; }}
dl {{ display:grid; grid-template-columns: 8.5em 1fr; gap: 4px 12px; margin: 12px 0 0; }}
dt {{ color:var(--muted); font-size:0.88rem; }}
dd {{ margin:0; }}
dd ul {{ margin:0; padding-left:1.2em; }}
code {{ font-family: Consolas, "BIZ UDGothic", monospace; font-size:0.85rem; word-break: break-all; }}
details {{ margin-top: 12px; }}
.note {{ font-size: 0.88rem; color: var(--muted); }}
@media (max-width: 640px) {{ dl {{ grid-template-columns: 1fr; }} dt {{ margin-top:6px; }} }}
@media print {{ .toolbar {{ display:none; }} .app {{ break-inside: avoid; }} }}
</style>
</head>
<body>
<main>
<h1>🎵 音楽生成アプリ・関連ソフト一覧</h1>
<p class="muted">スキャン日時: {result.scanned_at:%Y-%m-%d %H:%M}{f' / PC: {_e(result.computer)}' if result.computer else ''}</p>

<div class="summary">
  <div class="stat">アプリ<b>{len(apps)} 件</b></div>
  <div class="stat">アプリ合計容量<b>{human_size(total)}</b></div>
  <div class="stat">プラグイン<b>{len(result.plugins)} 件</b></div>
  <div class="stat">プラグイン合計容量<b>{human_size(plugin_total)}</b></div>
</div>

<div class="toolbar">
  <input id="q" type="search" placeholder="アプリ名・用途で絞り込み (例: 歌声, DAW, VOICEVOX)">
  <select id="cat"><option value="">すべてのカテゴリ</option>{options}</select>
  <select id="sort"><option value="cat">カテゴリ順</option><option value="size">容量の大きい順</option>
    <option value="name">名前順</option></select>
</div>

<h2>一覧</h2>
{'<p>音楽関連のアプリは見つかりませんでした。</p>' if not apps else f'''
<table id="summary-table"><thead><tr><th>アプリ</th><th>カテゴリ</th><th>容量</th><th>起動ファイル</th></tr></thead>
<tbody>{rows}</tbody></table>'''}

<h2>詳細</h2>
<div id="cards">{''.join(cards)}</div>

<h2>VST / VST3 / CLAP / AAX プラグイン</h2>
{'<p class="muted">プラグインフォルダに項目はありませんでした。</p>' if not result.plugins else f'''
<p class="note">DAW から読み込んで使う音源・エフェクトです。単体では起動しません (DAW のプラグイン一覧から選びます)。</p>
<table id="plugin-table"><thead><tr><th>名前</th><th>形式</th><th>容量</th><th>場所</th></tr></thead>
<tbody>{plugin_rows}</tbody></table>'''}

<h2>このレポートについて</h2>
<ul class="note">
  <li>このファイルは <code>cleaner music-apps</code> が自動生成しました。スキャンはファイルを読むだけで、何も変更・削除していません。</li>
  <li>容量は「フォルダ実測」がインストール先フォルダの実際の合計サイズ、「推定値」はインストール情報に記録された値です。
      AI ツールはモデルファイルを別フォルダに置くことがあり、その分は含まれない場合があります。</li>
  <li>用途・公式ページ・利用方法は既知アプリのカタログから表示しています。「その他」はアプリ名から自動判定したもので、
      音楽と関係ないソフトが含まれることがあります。</li>
  <li>Microsoft Store アプリ、および下記以外の場所に置いたポータブル版は検出されないことがあります。</li>
</ul>
<details><summary class="note">スキャンした場所</summary><ul class="note">{roots_list}</ul></details>
{f'<details open><summary class="note">エラー</summary><ul class="note">{errors}</ul></details>' if errors else ''}
<script type="application/json" id="data">{data}</script>
</main>
<script>
(function () {{
  const q = document.getElementById('q'), cat = document.getElementById('cat'), sort = document.getElementById('sort');
  const cards = document.getElementById('cards');
  const original = Array.from(cards.children);
  function apply() {{
    const text = q.value.trim().toLowerCase(), c = cat.value;
    const show = el => (!c || el.dataset.cat === c) && (!text || el.dataset.search.includes(text));
    document.querySelectorAll('#cards .app, #summary-table tbody tr').forEach(el => {{
      el.style.display = show(el) ? '' : 'none';
    }});
  }}
  function reorder() {{
    let items = original.slice();
    if (sort.value === 'size') items.sort((a, b) => b.dataset.size - a.dataset.size);
    if (sort.value === 'name') items.sort((a, b) => a.querySelector('h3').textContent.localeCompare(
      b.querySelector('h3').textContent, 'ja'));
    items.forEach(el => cards.appendChild(el));
  }}
  q.addEventListener('input', apply); cat.addEventListener('change', apply);
  sort.addEventListener('change', reorder);
  document.querySelectorAll('table').forEach(table => {{
    table.querySelectorAll('th').forEach((th, i) => th.addEventListener('click', () => {{
      const body = table.tBodies[0], rows = Array.from(body.rows);
      const dir = th.dataset.dir === 'asc' ? -1 : 1; th.dataset.dir = dir === 1 ? 'asc' : 'desc';
      rows.sort((a, b) => {{
        const x = a.cells[i], y = b.cells[i];
        if (x.dataset.v !== undefined) return (x.dataset.v - y.dataset.v) * dir;
        return x.textContent.localeCompare(y.textContent, 'ja') * dir;
      }});
      rows.forEach(r => body.appendChild(r));
    }}));
  }});
}})();
</script>
</body>
</html>
"""


_SOURCE_LABELS = {"registry": "インストール情報", "shortcut": "ショートカット", "url": "Web ショートカット",
                  "folder": "フォルダ"}


def default_output() -> Path:
    roots = default_roots()
    desktop = next((d for d in roots.desktops if d.is_dir()), Path.cwd())
    return desktop / "音楽アプリ一覧.html"


def main(argv: list[str] | None = None) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="cleaner music-apps", description=__doc__.splitlines()[0])
    add_arguments(p)
    return run(p.parse_args(argv))


def add_arguments(p) -> None:
    p.add_argument("-o", "--output", type=Path, help="出力する HTML ファイル (既定: デスクトップの 音楽アプリ一覧.html)")
    p.add_argument("--open", action="store_true", help="作成後に HTML をブラウザで開く")
    p.add_argument("--no-size", action="store_true", help="フォルダ容量の実測を省略する (速くなる)")


def run(args) -> int:
    out: Path = args.output or default_output()
    result = scan(
        size_of=(lambda p: 0) if args.no_size else dir_size,
        progress=lambda m: print(m, file=sys.stderr),
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_html(result), encoding="utf-8")
    print(f"{len(result.apps)} 件のアプリ、{len(result.plugins)} 件のプラグインを見つけました。")
    print(f"HTML を作成しました: {out}")
    if args.open:  # pragma: no cover
        import webbrowser

        webbrowser.open(out.resolve().as_uri())
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
