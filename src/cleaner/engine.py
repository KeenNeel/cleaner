"""整理処理の全体の流れ (仕様 7 章の処理順) と、隔離項目の復元・本削除。

現在の実装範囲: 期限切れ隔離の本削除 → F1 不要ファイル削除 → F2 重複ファイル検出。
"""

from __future__ import annotations

import json
import logging
import shutil
from collections.abc import Callable, Iterable
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

from cleaner import winapi
from cleaner.appdirs import AppPaths
from cleaner.config import drive_settings
from cleaner.drives import Drive, drive_for_path, list_drives
from cleaner.lock import RunLock
from cleaner.models import Candidate, Skipped
from cleaner.protect import Protector
from cleaner.quarantine import QuarantineError, QuarantineItem, QuarantineStore, read_manifest
from cleaner.rules import cleanup, dedupe
from cleaner.state import State

log = logging.getLogger(__name__)

KEEP_RUN_REPORTS = 12


@dataclass
class Action:
    # quarantined / deleted / purged / would_quarantine / would_delete / would_purge / needs_approval / error
    kind: str
    path: str
    feature: str
    category: str
    reason: str
    size: int
    drive: str | None = None
    item_id: str | None = None
    message: str = ""


@dataclass
class DriveStatus:
    root: str
    volume_id: str
    label: str
    status: str  # active / review / excluded / ineligible
    note: str = ""


@dataclass
class RunReport:
    started_at: str
    finished_at: str = ""
    dry_run: bool = True
    actions: list[Action] = field(default_factory=list)
    protected: list[dict[str, str]] = field(default_factory=list)
    drives: list[DriveStatus] = field(default_factory=list)

    def by_kind(self, *kinds: str) -> list[Action]:
        return [a for a in self.actions if a.kind in kinds]

    @property
    def freed(self) -> int:
        return sum(a.size for a in self.by_kind("deleted", "purged"))

    @property
    def errors(self) -> list[Action]:
        return self.by_kind("error")

    def to_json(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ItemRef:
    """隔離項目と、それが置かれているドライブ (未接続なら store は None)。"""

    item: QuarantineItem
    store: QuarantineStore | None
    drive_label: str


def _default_processes() -> set[str]:
    if winapi.IS_WINDOWS:  # pragma: no cover
        return winapi.process_names()
    return set()


class Engine:
    def __init__(
        self,
        paths: AppPaths,
        cfg: dict[str, Any],
        *,
        drives: list[Drive] | None = None,
        now: Callable[[], datetime] = datetime.now,
        running_processes: Callable[[], set[str]] = _default_processes,
        disk_usage: Callable[[Path], Any] = shutil.disk_usage,
    ):
        self.paths = paths
        self.cfg = cfg
        self.drives = drives if drives is not None else list_drives()
        self.now = now
        self.running_processes = running_processes
        self.disk_usage = disk_usage

    # ---- 整理の実行 ----

    def run(self, *, dry_run: bool, drive_filter: str | None = None,
            features: list[str] | None = None) -> RunReport:
        """features を指定すると、その機能だけを実行する (例: ["F2"])。"""
        with RunLock(self.paths.lock_file):
            return self._run(dry_run=dry_run, drive_filter=drive_filter, features=features)

    def _run(self, *, dry_run: bool, drive_filter: str | None, features: list[str] | None) -> RunReport:
        now = self.now()
        global_dry = dry_run or not self.cfg["enabled"]
        report = RunReport(started_at=now.isoformat(timespec="seconds"), dry_run=global_dry)
        state = State.load(self.paths.state_file)

        active: list[Drive] = []
        acting: set[str] = set()
        for drive in self.drives:
            if drive_filter and not _matches_drive(drive, drive_filter):
                continue
            state.see_drive(drive, now)
            settings = drive_settings(self.cfg, drive.volume_id)
            if not drive.eligible:
                status = DriveStatus(str(drive.root), drive.volume_id, drive.label, "ineligible",
                                     drive.ineligible_reason or "")
            elif not settings["enabled"]:
                status = DriveStatus(str(drive.root), drive.volume_id, drive.label, "excluded", "設定で除外")
            else:
                active.append(drive)
                if global_dry or state.is_reviewed(drive.volume_id, features):
                    status = DriveStatus(str(drive.root), drive.volume_id, drive.label, "active")
                    if not global_dry:
                        acting.add(drive.volume_id)
                else:
                    status = DriveStatus(str(drive.root), drive.volume_id, drive.label, "review",
                                         "初めて検出したドライブのため今回はドライラン")
            report.drives.append(status)

        log.info("整理を開始 (ドライラン=%s, 対象ドライブ=%s)", global_dry, [str(d.root) for d in active])

        # 1. 期限切れ隔離の本削除
        for drive in active:
            store = QuarantineStore(drive, self.paths.manifests_dir)
            try:
                store.sync_mirror()
                self._purge_due(store, drive.volume_id in acting, report)
            except OSError as e:
                report.actions.append(Action("error", str(store.root), "-", "purge", "隔離フォルダの整理",
                                             0, str(drive.root), message=str(e)))

        protector = Protector(self.paths, self.cfg, now)

        def wanted(feature: str) -> list[Drive]:
            if features is not None and feature not in features:
                return []
            return [d for d in active if feature in drive_settings(self.cfg, d.volume_id)["features"]]

        # 2. F1 不要ファイル削除
        if wanted("F1"):
            ctx = cleanup.CleanupContext(
                paths=self.paths, cfg=self.cfg, drives=active, now=now,
                protector=protector, running_processes=self.running_processes,
            )
            self._handle(cleanup.collect(ctx), active, acting, report, now)

        # 3. F2 重複ファイル検出 (F1 で隔離した後のファイルを対象にする)
        f2_drives = wanted("F2")
        if f2_drives:
            with dedupe.HashCache(self.paths.hashcache_file, now) as cache:
                dctx = dedupe.DedupeContext(
                    paths=self.paths, cfg=self.cfg, drives=f2_drives, now=now,
                    protector=protector, cache=cache,
                )
                self._handle(dedupe.collect(dctx), active, acting, report, now)

        for drive in active:
            state.mark_reviewed(drive.volume_id, features)
        state.save()
        report.finished_at = self.now().isoformat(timespec="seconds")
        self._save_report(report)
        log.info("整理を終了 (処理 %d 件, エラー %d 件)", len(report.actions), len(report.errors))
        return report

    def _handle(
        self,
        results: Iterable[Candidate | Skipped],
        active: list[Drive],
        acting: set[str],
        report: RunReport,
        now: datetime,
    ) -> None:
        for result in results:
            if isinstance(result, Skipped):
                report.protected.append(
                    {"path": str(result.path), "category": result.category, "reason": result.reason}
                )
                continue
            cand = result
            drive = drive_for_path(cand.path, active)
            if drive is None:
                continue  # 対象外ドライブ上のもの
            if cand.feature not in drive_settings(self.cfg, drive.volume_id)["features"]:
                continue
            action = Action(
                kind="", path=str(cand.path), feature=cand.feature, category=cand.category,
                reason=cand.reason, size=cand.size, drive=str(drive.root),
            )
            if cand.approval:
                action.kind = "needs_approval"
            elif drive.volume_id not in acting:
                action.kind = "would_delete" if cand.immediate else "would_quarantine"
            else:
                store = QuarantineStore(drive, self.paths.manifests_dir)
                try:
                    if cand.immediate:
                        item = store.delete_immediately(cand, now)
                        action.kind = "deleted"
                    else:
                        item = store.quarantine(cand, now)
                        action.kind = "quarantined"
                    action.item_id = item.id
                    log.info("%s: %s (%s)", action.kind, cand.path, cand.reason)
                except (QuarantineError, OSError) as e:
                    action.kind = "error"
                    action.message = str(e)
                    log.warning("処理できませんでした: %s: %s", cand.path, e)
            report.actions.append(action)

    def _purge_due(self, store: QuarantineStore, act: bool, report: RunReport) -> None:
        now = self.now()
        days = self.cfg["quarantine_days"]
        min_days = self.cfg["min_quarantine_days"]
        items = sorted(
            (i for i in store.items().values() if i.state == "quarantined"),
            key=lambda i: i.quarantined_at,
        )

        def purge(item: QuarantineItem, reason: str) -> None:
            action = Action("purged" if act else "would_purge", item.display_rel, item.feature, item.category,
                            reason, item.size, str(store.drive.root), item.id)
            if act:
                try:
                    store.purge(item.id, now)
                except (QuarantineError, OSError) as e:
                    action.kind, action.message = "error", str(e)
            report.actions.append(action)

        remaining = []
        for item in items:
            if item.age_days(now) >= days:
                purge(item, f"保持期間 ({days}日) を経過")
            else:
                remaining.append(item)

        # 空き容量が閾値を切っていたら、最低保持日数を守りつつ古いものから前倒しで本削除
        usage = self.disk_usage(store.drive.root)
        free, total = usage.free, usage.total
        threshold = self.cfg["min_free_percent"]
        for item in remaining:
            if total == 0 or free / total * 100 >= threshold:
                break
            if item.age_days(now) < min_days:
                break
            purge(item, f"空き容量が {threshold}% 未満のため前倒しで本削除")
            free += item.size

    def _save_report(self, report: RunReport) -> None:
        try:
            self.paths.runs_dir.mkdir(parents=True, exist_ok=True)
            name = report.started_at.replace(":", "").replace("-", "")
            with open(self.paths.runs_dir / f"{name}.json", "w", encoding="utf-8") as f:
                json.dump(report.to_json(), f, ensure_ascii=False, indent=2)
            for old in sorted(self.paths.runs_dir.glob("*.json"))[:-KEEP_RUN_REPORTS]:
                old.unlink()
        except OSError as e:
            log.warning("実行結果を保存できませんでした: %s", e)

    # ---- 隔離ボックスの操作 ----

    def items(self) -> list[ItemRef]:
        """全ドライブの隔離項目。未接続ドライブの項目は写しの manifest から読む。"""
        refs: list[ItemRef] = []
        connected: set[str] = set()
        for drive in self.drives:
            store = QuarantineStore(drive, self.paths.manifests_dir)
            if not store.root.exists():
                continue
            connected.add(drive.volume_id)
            store.sync_mirror()
            refs.extend(ItemRef(item, store, drive.display) for item in store.items().values())
        if self.paths.manifests_dir.exists():
            for mirror in sorted(self.paths.manifests_dir.glob("*.jsonl")):
                volume_id = mirror.stem
                if volume_id in connected:
                    continue
                label = f"{volume_id} (未接続)"
                refs.extend(ItemRef(item, None, label) for item in read_manifest(mirror).values())
        refs.sort(key=lambda r: r.item.quarantined_at)
        return refs

    def restore(self, refs: list[ItemRef]) -> list[tuple[ItemRef, list[Path] | None, str]]:
        """(項目, 戻した先, エラーメッセージ) の一覧を返す。"""
        with RunLock(self.paths.lock_file):
            results = []
            now = self.now()
            for ref in refs:
                if ref.store is None:
                    results.append((ref, None, "ドライブが接続されていません"))
                    continue
                try:
                    results.append((ref, ref.store.restore(ref.item.id, now), ""))
                except QuarantineError as e:
                    results.append((ref, None, str(e)))
            return results

    def purge(self, refs: list[ItemRef]) -> list[tuple[ItemRef, str]]:
        """(項目, エラーメッセージ) の一覧を返す。"""
        with RunLock(self.paths.lock_file):
            results = []
            now = self.now()
            for ref in refs:
                if ref.store is None:
                    results.append((ref, "ドライブが接続されていません"))
                    continue
                try:
                    ref.store.purge(ref.item.id, now)
                    results.append((ref, ""))
                except (QuarantineError, OSError) as e:
                    results.append((ref, str(e)))
            return results


def _matches_drive(drive: Drive, spec: str) -> bool:
    spec = spec.strip().rstrip("\\/").upper()
    root = str(drive.root).rstrip("\\/").upper()
    return spec in (root, root.rstrip(":"), drive.volume_id.upper())

