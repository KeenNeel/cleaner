"""ドライブの検出と識別。

ドライブ文字は外付けの差し替えで変わるため、ボリュームシリアルで識別する。
"""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass
from pathlib import Path

from cleaner import winapi
from cleaner.fsutil import is_under, norm

# これより小さいリムーバブルドライブ (USB メモリ等) は対象外
MIN_REMOVABLE_BYTES = 64 * 1000**3


@dataclass(frozen=True)
class Drive:
    root: Path
    volume_id: str
    label: str
    kind: str  # fixed / removable / network / cdrom / ramdisk / unknown
    total: int
    free: int

    @property
    def eligible(self) -> bool:
        """整理の対象になりうる種類のドライブか (設定で除外されているかは別)。"""
        if self.kind == "fixed":
            return True
        return self.kind == "removable" and self.total >= MIN_REMOVABLE_BYTES

    @property
    def ineligible_reason(self) -> str | None:
        if self.eligible:
            return None
        if self.kind == "removable":
            return "64GB 未満のリムーバブルドライブ"
        return {"network": "ネットワークドライブ", "cdrom": "光学ドライブ", "ramdisk": "RAM ディスク"}.get(
            self.kind, "対象外の種類のドライブ"
        )

    @property
    def display(self) -> str:
        return f"{self.root} {self.label}".strip()


def list_drives() -> list[Drive]:
    if winapi.IS_WINDOWS:  # pragma: no cover - Windows 専用
        drives = []
        for root, kind, label, serial, _fs in winapi.logical_drives():
            try:
                usage = shutil.disk_usage(root)
            except OSError:
                continue
            drives.append(Drive(Path(root), f"VOL-{serial}", label, kind, usage.total, usage.free))
        return drives

    # Windows 以外 (開発用): ルートファイルシステムだけを 1 ドライブとして扱う
    usage = shutil.disk_usage("/")
    return [Drive(Path("/"), f"DEV-{os.stat('/').st_dev:X}", "root", "fixed", usage.total, usage.free)]


def drive_for_path(path: Path, drives: list[Drive]) -> Drive | None:
    """path を含むドライブ (ルートが最も長く一致するもの)。"""
    matches = [d for d in drives if is_under(path, d.root)]
    return max(matches, key=lambda d: len(norm(d.root)), default=None)
