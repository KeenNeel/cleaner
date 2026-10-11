"""ハード保護リスト (仕様 3.2)。ここで保護と判定されたものは、どの機能も触らない。"""

from __future__ import annotations

import os
import stat
from collections.abc import Iterable
from datetime import datetime
from pathlib import Path

from cleaner.appdirs import AppPaths
from cleaner.fsutil import is_link, is_system_hidden, is_under, longpath, norm, tree_stats
from cleaner.quarantine import QUARANTINE_DIR_NAME

# パスの途中にこの名前のフォルダがあれば保護 (大文字小文字は区別しない)
PROTECTED_DIR_NAMES = {
    QUARANTINE_DIR_NAME,
    "$recycle.bin",
    "system volume information",
    "$windows.~bt",
    "$windows.~ws",
    "windows.old",
    # ゲームライブラリ
    "steamapps",
    "epic games",
    "windowsapps",
    "xboxgames",
    # バックアップソフトの保存先
    "filehistory",
    "windowsimagebackup",
}

PROTECTED_EXTENSIONS = {
    # 仮想マシンディスク
    ".vhd", ".vhdx", ".avhd", ".avhdx", ".vmdk", ".vdi", ".qcow2", ".vmem", ".vmsn",
    # データベース
    ".db", ".sqlite", ".sqlite3", ".mdf", ".ldf", ".ndf", ".accdb", ".mdb",
    # バックアップイメージ
    ".tib", ".tibx", ".mrimg", ".vbk", ".vib",
}

ANY_EXTENSION = "*"


class Protector:
    def __init__(self, paths: AppPaths, cfg: dict, now: datetime):
        self.now = now
        self.recent_seconds = cfg["recent_hours"] * 3600
        self.user_protect = [paths.expand(p) for p in cfg["protect"]]
        self.restricted_roots = [*paths.system_roots, paths.appdata, paths.localappdata]
        self._git_cache: dict[str, bool] = {}

    def check(
        self,
        path: Path,
        *,
        allow_roots: Iterable[Path] = (),
        allow_exts: Iterable[str] = (),
        allow_git: bool = False,
        newest_mtime: float | None = None,
    ) -> str | None:
        """保護対象なら理由 (日本語) を、触ってよければ None を返す。

        allow_roots: このフォルダ配下はシステム/AppData 保護と保護フォルダ名の判定を免除する
            (F1 のキャッシュ等、明示的に指定した場所を掃除するため)。
        allow_exts: 保護拡張子のうち許可するもの。ANY_EXTENSION ですべて許可。
        newest_mtime: 呼び出し側で計算済みなら渡す (フォルダの場合は配下の最新更新日時)。
        """
        p = norm(path)
        if QUARANTINE_DIR_NAME.lower() in (part.lower() for part in Path(p).parts):
            return "隔離フォルダ内"

        for root in self.user_protect:
            if is_under(path, root):
                return f"保護フォルダ ({root})"

        allow_root = next((r for r in allow_roots if is_under(path, r)), None)
        if allow_root is None:
            for root in self.restricted_roots:
                if is_under(path, root):
                    return f"システム/アプリのフォルダ ({root})"
            checked_parts = Path(p).parts
        else:
            checked_parts = Path(os.path.relpath(p, norm(allow_root))).parts
        for part in checked_parts:
            if part.lower() in PROTECTED_DIR_NAMES:
                return f"保護対象のフォルダ ({part})"

        if not allow_git and self._in_git_repo(path):
            return "Git リポジトリ内"

        try:
            st = os.lstat(longpath(path))
        except OSError as e:
            return f"アクセスできない ({e.strerror})"
        if is_link(st):
            return "シンボリックリンク/ジャンクション"
        if is_system_hidden(st):
            return "システムファイル"

        allowed_exts = {e.lower() for e in allow_exts}
        ext = path.suffix.lower()
        if ANY_EXTENSION not in allowed_exts and ext in PROTECTED_EXTENSIONS and ext not in allowed_exts:
            return f"保護対象の種類のファイル ({ext})"

        if newest_mtime is None:
            newest_mtime = tree_stats(path).newest_mtime if stat.S_ISDIR(st.st_mode) else st.st_mtime
        if self.now.timestamp() - newest_mtime < self.recent_seconds:
            return "最近更新された (作業中の可能性)"
        return None

    def is_excluded_dir(self, path: Path) -> bool:
        """フォルダを走査するときに、中に入る必要がないフォルダか (軽量な判定のみ)。"""
        if path.name.lower() in PROTECTED_DIR_NAMES or path.name == ".git":
            return True
        if any(is_under(path, r) for r in self.user_protect):
            return True
        return any(is_under(path, r) for r in self.restricted_roots)

    def _in_git_repo(self, path: Path) -> bool:
        checked: list[str] = []
        current = Path(norm(path))
        result = False
        for directory in [current, *current.parents]:
            key = str(directory)
            if key in self._git_cache:
                result = self._git_cache[key]
                break
            checked.append(key)
            if os.path.isdir(longpath(directory / ".git")):
                result = True
                break
        for key in checked:
            self._git_cache[key] = result
        return result
