"""実行状態 (state.json)。ドライブを初めて見た日時やドライラン済みかを記録する。"""

from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

from cleaner.drives import Drive


class State:
    def __init__(self, path: Path, data: dict[str, Any] | None = None):
        self.path = path
        self.data: dict[str, Any] = data or {"drives": {}}
        self.data.setdefault("drives", {})

    @classmethod
    def load(cls, path: Path) -> State:
        try:
            with open(path, encoding="utf-8") as f:
                return cls(path, json.load(f))
        except (OSError, json.JSONDecodeError):
            return cls(path)

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, self.path)

    def see_drive(self, drive: Drive, now: datetime) -> bool:
        """ドライブの接続を記録する。初めて見たドライブなら True。"""
        entry = self.data["drives"].get(drive.volume_id)
        is_new = entry is None
        if is_new:
            entry = {"first_seen": now.isoformat(timespec="seconds"), "reviewed": False}
            self.data["drives"][drive.volume_id] = entry
        entry["label"] = drive.label
        entry["last_root"] = str(drive.root)
        entry["last_seen"] = now.isoformat(timespec="seconds")
        return is_new

    def is_reviewed(self, volume_id: str) -> bool:
        """このドライブについてドライラン (確認用レポート) を 1 回以上実施済みか。"""
        return bool(self.data["drives"].get(volume_id, {}).get("reviewed"))

    def mark_reviewed(self, volume_id: str) -> None:
        self.data["drives"].setdefault(volume_id, {})["reviewed"] = True

    def known_drives(self) -> dict[str, dict[str, Any]]:
        return self.data["drives"]
