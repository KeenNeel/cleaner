"""アプリが使う場所 (設定・データ・ユーザーフォルダ) の解決。

テストや開発時は環境変数 CLEANER_HOME を指定すると、その下にすべての場所をまとめる。
"""

from __future__ import annotations

import os
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from cleaner import winapi


@dataclass
class AppPaths:
    home: Path
    appdata: Path  # Roaming (%APPDATA%)
    localappdata: Path  # %LOCALAPPDATA%
    temp: Path
    downloads: Path
    # Windows 本体・アプリのフォルダ。ここ以下は原則触らない (protect.py)
    system_roots: list[Path] = field(default_factory=list)

    @property
    def config_dir(self) -> Path:
        return self.appdata / "cleaner"

    @property
    def data_dir(self) -> Path:
        return self.localappdata / "cleaner"

    @property
    def config_file(self) -> Path:
        return self.config_dir / "config.toml"

    @property
    def state_file(self) -> Path:
        return self.data_dir / "state.json"

    @property
    def logs_dir(self) -> Path:
        return self.data_dir / "logs"

    @property
    def manifests_dir(self) -> Path:
        return self.data_dir / "manifests"

    @property
    def runs_dir(self) -> Path:
        return self.data_dir / "runs"

    @property
    def hashcache_file(self) -> Path:
        return self.data_dir / "hashcache.db"

    @property
    def lock_file(self) -> Path:
        return self.data_dir / "cleaner.lock"

    def expand(self, value: str) -> Path:
        """設定ファイル中の `~` をホームフォルダに展開する。"""
        if value == "~" or value.startswith(("~/", "~\\")):
            return self.home / value[2:] if len(value) > 1 else self.home
        return Path(os.path.expandvars(value))


def default_paths() -> AppPaths:
    override = os.environ.get("CLEANER_HOME")
    if override:
        root = Path(override)
        return AppPaths(
            home=root / "home",
            appdata=root / "appdata",
            localappdata=root / "localappdata",
            temp=root / "temp",
            downloads=root / "home" / "Downloads",
        )

    home = Path.home()
    if winapi.IS_WINDOWS:  # pragma: no cover - Windows 専用
        env = os.environ
        downloads = winapi.known_folder(winapi.FOLDERID_DOWNLOADS)
        system_roots = [
            Path(env[name])
            for name in ("SystemRoot", "ProgramFiles", "ProgramFiles(x86)", "ProgramW6432", "ProgramData")
            if env.get(name)
        ]
        return AppPaths(
            home=home,
            appdata=Path(env.get("APPDATA", home / "AppData" / "Roaming")),
            localappdata=Path(env.get("LOCALAPPDATA", home / "AppData" / "Local")),
            temp=Path(tempfile.gettempdir()),
            downloads=Path(downloads) if downloads else home / "Downloads",
            system_roots=system_roots,
        )

    # Windows 以外 (開発用)
    return AppPaths(
        home=home,
        appdata=Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")),
        localappdata=Path(os.environ.get("XDG_DATA_HOME", home / ".local" / "share")),
        temp=Path(tempfile.gettempdir()),
        downloads=home / "Downloads",
        system_roots=[Path(p) for p in ("/bin", "/boot", "/etc", "/lib", "/proc", "/sbin", "/sys", "/usr", "/var")],
    )
