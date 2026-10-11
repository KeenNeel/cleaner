from __future__ import annotations

import os
import shutil
from collections import namedtuple
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

import pytest

from cleaner import config
from cleaner.appdirs import AppPaths
from cleaner.drives import Drive
from cleaner.engine import Engine

NOW = datetime(2026, 10, 11, 12, 0, 0)
Usage = namedtuple("Usage", "total used free")


def make_file(path: Path, size: int = 100, age_days: float = 0, now: datetime = NOW) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x" * size)
    set_age(path, age_days, now)
    return path


def set_age(path: Path, age_days: float, now: datetime = NOW) -> None:
    t = now.timestamp() - age_days * 86400
    os.utime(path, (t, t))


@dataclass
class Env:
    root: Path
    paths: AppPaths
    c: Drive
    d: Drive
    cfg: dict
    clock: list[datetime] = field(default_factory=lambda: [NOW])
    processes: set[str] = field(default_factory=set)
    usage: dict[str, Usage] = field(default_factory=dict)

    @property
    def now(self) -> datetime:
        return self.clock[0]

    def engine(self, drives: list[Drive] | None = None) -> Engine:
        return Engine(
            self.paths,
            self.cfg,
            drives=drives if drives is not None else [self.c, self.d],
            now=lambda: self.clock[0],
            running_processes=lambda: self.processes,
            disk_usage=lambda root: self.usage.get(str(root), Usage(1000, 0, 1000)),
        )


@pytest.fixture
def env(tmp_path: Path) -> Env:
    c_root = tmp_path / "C"
    d_root = tmp_path / "D"
    home = c_root / "Users" / "me"
    local = home / "AppData" / "Local"
    paths = AppPaths(
        home=home,
        appdata=home / "AppData" / "Roaming",
        localappdata=local,
        temp=local / "Temp",
        downloads=home / "Downloads",
        system_roots=[c_root / "Windows", c_root / "Program Files"],
    )
    for p in (paths.appdata, paths.temp, paths.downloads, d_root, *paths.system_roots):
        p.mkdir(parents=True, exist_ok=True)
    gb = 1000**3
    c = Drive(c_root, "VOL-C", "System", "fixed", 500 * gb, 200 * gb)
    d = Drive(d_root, "VOL-D", "Data", "fixed", 1000 * gb, 800 * gb)
    cfg = config.load(paths)
    return Env(tmp_path, paths, c, d, cfg)


@pytest.fixture
def enabled_env(env: Env) -> Env:
    """自動整理を有効にし、両ドライブともドライラン済みの状態。"""
    env.cfg["enabled"] = True
    env.engine().run(dry_run=True)
    return env


__all__ = ["NOW", "Env", "Usage", "make_file", "set_age", "shutil"]
