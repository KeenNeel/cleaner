"""隔離フォルダと manifest (仕様 3.1)。

各ドライブ直下の `.cleaner_quarantine` に隔離する。同一ボリューム内の移動なので瞬時に終わり、
追加の空き容量も要らない。ドライブをまたぐ移動は行わない。

manifest.jsonl はイベントの追記ログで、replay すると各項目の現在の状態になる。
ドライブ側の manifest が正本で、%LOCALAPPDATA%\\cleaner\\manifests に写しを置く
(外付けドライブが未接続でも一覧を表示できるように)。
"""

from __future__ import annotations

import json
import logging
import os
import secrets
import shutil
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING, Any

from cleaner import winapi
from cleaner.fsutil import file_hash, longpath, remove_path, unique_path

if TYPE_CHECKING:
    from cleaner.drives import Drive
    from cleaner.models import Candidate

log = logging.getLogger(__name__)

QUARANTINE_DIR_NAME = ".cleaner_quarantine"
MANIFEST_VERSION = 1

_README = """このフォルダは cleaner の隔離フォルダです。
整理されたファイルは、本削除されるまでここに保管されます。
元に戻すには cleaner の「隔離ボックス」画面、または `cleaner restore <ID>` を使ってください。
このフォルダ内のファイルを手で移動・削除しないでください。
"""


class QuarantineError(Exception):
    pass


@dataclass
class QuarantineItem:
    id: str
    volume_id: str
    feature: str
    category: str
    source: str
    reason: str
    size: int
    is_dir: bool
    display_rel: str  # ドライブルートからの相対パス (ドライブ文字が変わっても戻せるように)
    entries: list[dict[str, Any]]  # {rel, stored, hash}
    quarantined_at: datetime
    state: str = "quarantined"  # quarantined / restored / purged / deleted
    state_at: datetime | None = None
    restored_to: list[str] = field(default_factory=list)

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "volume_id": self.volume_id,
            "feature": self.feature,
            "category": self.category,
            "source": self.source,
            "reason": self.reason,
            "size": self.size,
            "is_dir": self.is_dir,
            "display_rel": self.display_rel,
            "entries": self.entries,
            "quarantined_at": self.quarantined_at.isoformat(timespec="seconds"),
        }

    @classmethod
    def from_json(cls, d: dict[str, Any]) -> QuarantineItem:
        return cls(
            id=d["id"],
            volume_id=d["volume_id"],
            feature=d["feature"],
            category=d["category"],
            source=d.get("source", "rule"),
            reason=d["reason"],
            size=d["size"],
            is_dir=d["is_dir"],
            display_rel=d["display_rel"],
            entries=d["entries"],
            quarantined_at=datetime.fromisoformat(d["quarantined_at"]),
        )

    def age_days(self, now: datetime) -> float:
        return (now - self.quarantined_at).total_seconds() / 86400


def read_manifest(path: Path) -> dict[str, QuarantineItem]:
    """manifest を replay して ID -> 項目 の辞書を返す。壊れた行は飛ばす。"""
    items: dict[str, QuarantineItem] = {}
    try:
        f = open(path, encoding="utf-8")
    except FileNotFoundError:
        return items
    with f:
        for lineno, line in enumerate(f, 1):
            if not line.strip():
                continue
            try:
                ev = json.loads(line)
                kind = ev["event"]
                if kind in ("quarantine", "delete"):
                    item = QuarantineItem.from_json(ev["item"])
                    if kind == "delete":
                        item.state, item.state_at = "deleted", item.quarantined_at
                    items[item.id] = item
                elif kind in ("restore", "purge"):
                    item = items[ev["id"]]
                    item.state = "restored" if kind == "restore" else "purged"
                    item.state_at = datetime.fromisoformat(ev["at"])
                    item.restored_to = ev.get("restored_to", [])
            except (ValueError, KeyError, TypeError) as e:
                log.warning("manifest の %s 行目を読めません (%s): %s", lineno, path, e)
    return items


class QuarantineStore:
    """1 ドライブ分の隔離フォルダ。"""

    def __init__(self, drive: Drive, mirror_dir: Path):
        self.drive = drive
        self.root = drive.root / QUARANTINE_DIR_NAME
        self.items_dir = self.root / "items"
        self.manifest = self.root / "manifest.jsonl"
        self.mirror = mirror_dir / f"{drive.volume_id}.jsonl"

    # ---- 読み取り ----

    def items(self) -> dict[str, QuarantineItem]:
        return read_manifest(self.manifest)

    def sync_mirror(self) -> None:
        """ドライブ側の manifest を写しにコピーする。"""
        if self.manifest.exists():
            self.mirror.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.manifest, self.mirror)

    # ---- 書き込み ----

    def quarantine(self, cand: Candidate, now: datetime) -> QuarantineItem:
        """候補を隔離フォルダへ移動し manifest に記録する。失敗したら元に戻して例外を投げる。"""
        self._ensure_root()
        item_id = self._new_id(now)
        item_dir = self.items_dir / item_id
        os.makedirs(longpath(item_dir))
        moved: list[tuple[Path, Path]] = []
        try:
            entries = []
            for i, src in enumerate(cand.targets):
                stored = f"{i}_{src.name}"
                dest = item_dir / stored
                os.rename(longpath(src), longpath(dest))
                moved.append((src, dest))
                entries.append({"rel": self._rel(src), "stored": stored, "hash": file_hash(dest)})
            item = self._make_item(item_id, cand, entries, now)
            self._append({"event": "quarantine", "item": item.to_json()})
            return item
        except Exception as e:
            self._rollback(moved)
            try:
                os.rmdir(longpath(item_dir))
            except OSError:
                pass
            raise QuarantineError(f"隔離できませんでした: {cand.path}: {e}") from e

    def delete_immediately(self, cand: Candidate, now: datetime) -> QuarantineItem:
        """即時削除 (復元不可)。記録のため manifest には残す。"""
        entries = []
        try:
            for src in cand.targets:
                rel = self._rel(src)
                remove_path(src)
                entries.append({"rel": rel, "stored": None, "hash": None})
        finally:
            if entries:
                self._ensure_root()
                item = self._make_item(self._new_id(now), cand, entries, now)
                item.state = "deleted"
                self._append({"event": "delete", "item": item.to_json()})
        return item

    def restore(self, item_id: str, now: datetime) -> list[Path]:
        """隔離した項目を元の場所に戻す。同名がある場合は連番を付ける。"""
        item = self.items().get(item_id)
        if item is None:
            raise QuarantineError(f"ID が見つかりません: {item_id}")
        if item.state != "quarantined":
            raise QuarantineError(f"{item_id} は復元できません (状態: {item.state})")
        item_dir = self.items_dir / item_id
        restored: list[tuple[Path, Path]] = []
        try:
            for entry in item.entries:
                src = item_dir / entry["stored"]
                dest = unique_path(self.drive.root / entry["rel"])
                os.makedirs(longpath(dest.parent), exist_ok=True)
                os.rename(longpath(src), longpath(dest))
                restored.append((dest, src))
            self._append({
                "event": "restore",
                "id": item_id,
                "at": now.isoformat(timespec="seconds"),
                "restored_to": [str(d) for d, _ in restored],
            })
        except Exception as e:
            self._rollback(restored)
            raise QuarantineError(f"復元できませんでした: {item_id}: {e}") from e
        try:
            os.rmdir(longpath(item_dir))
        except OSError:
            pass
        return [d for d, _ in restored]

    def purge(self, item_id: str, now: datetime) -> QuarantineItem:
        """隔離した項目を本削除する。"""
        item = self.items().get(item_id)
        if item is None:
            raise QuarantineError(f"ID が見つかりません: {item_id}")
        if item.state != "quarantined":
            raise QuarantineError(f"{item_id} は本削除できません (状態: {item.state})")
        item_dir = self.items_dir / item_id
        if os.path.lexists(longpath(item_dir)):
            remove_path(item_dir)
        self._append({"event": "purge", "id": item_id, "at": now.isoformat(timespec="seconds")})
        item.state, item.state_at = "purged", now
        return item

    # ---- 内部処理 ----

    def _ensure_root(self) -> None:
        if self.root.exists():
            return
        self.items_dir.mkdir(parents=True, exist_ok=True)
        (self.root / "README.txt").write_text(_README, encoding="utf-8")
        if winapi.IS_WINDOWS:  # pragma: no cover
            winapi.set_hidden(str(self.root))

    def _new_id(self, now: datetime) -> str:
        return f"{now:%Y%m%d}-{secrets.token_hex(3)}"

    def _rel(self, path: Path) -> str:
        return os.path.relpath(os.path.abspath(path), os.path.abspath(self.drive.root))

    def _make_item(self, item_id: str, cand: Candidate, entries: list[dict], now: datetime) -> QuarantineItem:
        return QuarantineItem(
            id=item_id,
            volume_id=self.drive.volume_id,
            feature=cand.feature,
            category=cand.category,
            source=cand.source,
            reason=cand.reason,
            size=cand.size,
            is_dir=cand.is_dir,
            display_rel=self._rel(cand.path),
            entries=entries,
            quarantined_at=now,
        )

    def _append(self, event: dict[str, Any]) -> None:
        line = json.dumps({"v": MANIFEST_VERSION, **event}, ensure_ascii=False) + "\n"
        # 正本 (ドライブ側) への書き込みに失敗したら例外 → 呼び出し側で移動を元に戻す
        with open(self.manifest, "a", encoding="utf-8") as f:
            f.write(line)
            f.flush()
            os.fsync(f.fileno())
        try:
            self.mirror.parent.mkdir(parents=True, exist_ok=True)
            with open(self.mirror, "a", encoding="utf-8") as f:
                f.write(line)
        except OSError as e:
            log.warning("manifest の写しを書けませんでした: %s", e)

    @staticmethod
    def _rollback(moved: list[tuple[Path, Path]]) -> None:
        for original, current in reversed(moved):
            try:
                os.rename(longpath(current), longpath(original))
            except OSError as e:
                log.error("元に戻せませんでした: %s -> %s: %s", current, original, e)
