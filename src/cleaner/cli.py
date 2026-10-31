"""コマンドライン (仕様 8 章)。"""

from __future__ import annotations

import argparse
import logging
import logging.handlers
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta

from cleaner import __version__, config
from cleaner.appdirs import AppPaths, default_paths
from cleaner.engine import Engine, ItemRef, RunReport
from cleaner.fsutil import human_size
from cleaner.lock import AlreadyRunning
from cleaner.rules.cleanup import CATEGORY_LABELS
from cleaner.state import State

EXIT_OK, EXIT_ERROR, EXIT_USAGE, EXIT_BUSY = 0, 1, 2, 3

KIND_LABELS = {
    "quarantined": "隔離",
    "deleted": "即時削除",
    "purged": "本削除",
    "would_quarantine": "隔離予定",
    "would_delete": "即時削除予定",
    "would_purge": "本削除予定",
    "error": "エラー",
}

DRIVE_STATUS_LABELS = {
    "active": "対象",
    "review": "初回ドライラン",
    "excluded": "除外",
    "ineligible": "対象外",
}

STATE_LABELS = {"quarantined": "隔離中", "restored": "復元済み", "purged": "本削除済み", "deleted": "即時削除済み"}


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="cleaner", description="ディスクを安全に自動整理します。")
    p.add_argument("--version", action="version", version=f"cleaner {__version__}")
    p.add_argument("-v", "--verbose", action="store_true", help="詳細を表示する")
    sub = p.add_subparsers(dest="command", required=True, metavar="コマンド")

    sub.add_parser("scan", help="ドライラン (何も変更せず、整理候補を表示する)")

    run = sub.add_parser("run", help="整理を実行する")
    run.add_argument("--dry-run", action="store_true", help="何も変更しない")
    run.add_argument("--drive", help="このドライブだけを対象にする (例: D: またはボリュームID)")

    lst = sub.add_parser("list", help="隔離ボックスの中身を表示する")
    lst.add_argument("--all", action="store_true", help="復元済み・本削除済みの履歴も表示する")

    restore = sub.add_parser("restore", help="隔離した項目を元の場所に戻す")
    restore.add_argument("ids", nargs="*", metavar="ID")
    restore.add_argument("--all", action="store_true", help="隔離中のものをすべて戻す")
    restore.add_argument("--since", type=_date, help="この日 (YYYY-MM-DD) 以降に隔離したものを戻す")

    purge = sub.add_parser("purge", help="隔離した項目を本削除する (元に戻せません)")
    purge.add_argument("ids", nargs="*", metavar="ID")
    purge.add_argument("--older-than", type=_days, metavar="日数",
                       help="隔離から指定日数 (例: 30d) 以上経過したものを本削除する")
    purge.add_argument("--yes", "-y", action="store_true", help="確認せずに実行する")

    sub.add_parser("drives", help="検出したドライブと対象状況を表示する")
    sub.add_parser("enable", help="自動整理を有効にする (隔離・移動を実際に行う)")
    sub.add_parser("disable", help="自動整理を無効にする (ドライランのみになる)")
    return p


def _date(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError:
        raise argparse.ArgumentTypeError("日付は YYYY-MM-DD 形式で指定してください") from None


def _days(value: str) -> int:
    m = re.fullmatch(r"(\d+)d?", value.strip())
    if not m:
        raise argparse.ArgumentTypeError("日数は 30d のように指定してください")
    return int(m.group(1))


def setup_logging(paths: AppPaths, verbose: bool) -> None:
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    try:
        paths.logs_dir.mkdir(parents=True, exist_ok=True)
        fh = logging.handlers.TimedRotatingFileHandler(
            paths.logs_dir / "cleaner.log", when="midnight", backupCount=90, encoding="utf-8"
        )
        fh.setFormatter(fmt)
        root.addHandler(fh)
    except OSError as e:
        print(f"警告: ログファイルを開けません: {e}", file=sys.stderr)
    console = logging.StreamHandler(sys.stderr)
    console.setLevel(logging.INFO if verbose else logging.WARNING)
    console.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
    root.addHandler(console)


def main(argv: list[str] | None = None, *, paths: AppPaths | None = None, engine: Engine | None = None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    args = build_parser().parse_args(argv)
    paths = paths or default_paths()
    if engine is None:
        setup_logging(paths, args.verbose)

    try:
        if args.command in ("enable", "disable"):
            return cmd_toggle(paths, args.command == "enable")
        cfg = config.load(paths)
        engine = engine or Engine(paths, cfg)
        if args.command == "scan":
            return cmd_run(engine, dry_run=True, drive=None, verbose=args.verbose)
        if args.command == "run":
            return cmd_run(engine, dry_run=args.dry_run, drive=args.drive, verbose=args.verbose)
        if args.command == "list":
            return cmd_list(engine, show_all=args.all)
        if args.command == "restore":
            return cmd_restore(engine, args)
        if args.command == "purge":
            return cmd_purge(engine, args)
        if args.command == "drives":
            return cmd_drives(engine, paths)
    except config.ConfigError as e:
        print(f"エラー: {e}", file=sys.stderr)
        return EXIT_USAGE
    except AlreadyRunning as e:
        print(f"エラー: {e}", file=sys.stderr)
        return EXIT_BUSY
    return EXIT_USAGE  # pragma: no cover


# ---- 各コマンド ----


def cmd_toggle(paths: AppPaths, enabled: bool) -> int:
    config.save_user_value(paths, "enabled", enabled)
    if enabled:
        print("自動整理を有効にしました。次回の実行から隔離・移動を行います。")
        print("(初めて検出したドライブは、そのドライブについて 1 回ドライランしてから対象になります)")
    else:
        print("自動整理を無効にしました。以降の実行はドライラン (確認のみ) になります。")
    return EXIT_OK


def cmd_run(engine: Engine, *, dry_run: bool, drive: str | None, verbose: bool) -> int:
    report = engine.run(dry_run=dry_run, drive_filter=drive)
    print_report(report, verbose=verbose)
    return EXIT_ERROR if report.errors else EXIT_OK


def print_report(report: RunReport, *, verbose: bool) -> None:
    mode = "ドライラン (何も変更していません)" if report.dry_run else "整理を実行しました"
    print(f"== cleaner: {mode} ==")
    print("ドライブ:")
    for d in report.drives:
        note = f" - {d.note}" if d.note else ""
        print(f"  {d.root:<4} {d.label or '(ラベルなし)'}  [{DRIVE_STATUS_LABELS[d.status]}]{note}")

    groups: dict[tuple[str, str], list] = defaultdict(list)
    for a in report.actions:
        groups[(a.kind, a.category)].append(a)
    if not groups:
        print("\n整理する候補はありませんでした。")
    for (kind, category), actions in sorted(groups.items()):
        label = CATEGORY_LABELS.get(category, category)
        total = sum(a.size for a in actions)
        print(f"\n[{KIND_LABELS.get(kind, kind)}] {label}: {len(actions)} 件 / {human_size(total)}")
        shown = actions if verbose else actions[:10]
        for a in shown:
            suffix = f"  ({a.item_id})" if a.item_id else ""
            msg = f"  -> {a.message}" if a.message else ""
            print(f"  - {a.path}  {human_size(a.size)}  {a.reason}{suffix}{msg}")
        if len(shown) < len(actions):
            print(f"  … ほか {len(actions) - len(shown)} 件 (-v ですべて表示)")

    planned = sum(a.size for a in report.by_kind("would_quarantine", "would_delete"))
    moved = sum(a.size for a in report.by_kind("quarantined"))
    print("\n--- まとめ ---")
    if report.dry_run or planned:
        print(f"整理予定: {human_size(planned)}")
    if moved:
        print(f"隔離: {human_size(moved)} (保持期間が過ぎると本削除され、容量が空きます)")
    if report.freed:
        print(f"空いた容量: {human_size(report.freed)}")
    if report.protected:
        print(f"保護のため対象外: {len(report.protected)} 件")
        if verbose:
            for p in report.protected:
                print(f"  - {p['path']}: {p['reason']}")
    if report.errors:
        print(f"エラー: {len(report.errors)} 件 (詳細はログを参照)")
    if report.dry_run:
        print("\n自動整理を有効にするには `cleaner enable` を実行してください。")


def _item_line(ref: ItemRef, quarantine_days: int) -> str:
    item = ref.item
    expires = (item.quarantined_at + timedelta(days=quarantine_days)).strftime("%Y-%m-%d")
    state = STATE_LABELS.get(item.state, item.state)
    tail = f"本削除予定 {expires}" if item.state == "quarantined" else state
    return (f"{item.id}  {ref.drive_label}  {item.display_rel}  {human_size(item.size)}  "
            f"{CATEGORY_LABELS.get(item.category, item.category)}  隔離 {item.quarantined_at:%Y-%m-%d}  {tail}")


def cmd_list(engine: Engine, *, show_all: bool) -> int:
    refs = [r for r in engine.items() if show_all or r.item.state == "quarantined"]
    if not refs:
        print("隔離ボックスは空です。")
        return EXIT_OK
    for ref in refs:
        print(_item_line(ref, engine.cfg["quarantine_days"]))
    total = sum(r.item.size for r in refs if r.item.state == "quarantined")
    print(f"\n隔離中: {sum(r.item.state == 'quarantined' for r in refs)} 件 / {human_size(total)}")
    return EXIT_OK


def _select(engine: Engine, ids: list[str], *, all_items: bool = False, since: datetime | None = None,
            older_than: int | None = None) -> tuple[list[ItemRef], list[str]]:
    refs = [r for r in engine.items() if r.item.state == "quarantined"]
    if ids:
        by_id = {r.item.id: r for r in refs}
        return [by_id[i] for i in ids if i in by_id], [i for i in ids if i not in by_id]
    if since is not None:
        refs = [r for r in refs if r.item.quarantined_at >= since]
    if older_than is not None:
        now = engine.now()
        refs = [r for r in refs if r.item.age_days(now) >= older_than]
    if not (all_items or since is not None or older_than is not None):
        return [], []
    return refs, []


def cmd_restore(engine: Engine, args: argparse.Namespace) -> int:
    if not (args.ids or args.all or args.since):
        print("復元する ID、--all、--since のいずれかを指定してください。", file=sys.stderr)
        return EXIT_USAGE
    refs, missing = _select(engine, args.ids, all_items=args.all, since=args.since)
    for i in missing:
        print(f"エラー: 隔離中の項目に {i} はありません", file=sys.stderr)
    if not refs:
        print("復元する項目はありません。")
        return EXIT_ERROR if missing else EXIT_OK
    failed = bool(missing)
    for ref, restored, error in engine.restore(refs):
        if error:
            failed = True
            print(f"失敗: {ref.item.id}: {error}")
        else:
            for path in restored or []:
                print(f"復元: {ref.item.id} -> {path}")
    return EXIT_ERROR if failed else EXIT_OK


def cmd_purge(engine: Engine, args: argparse.Namespace) -> int:
    older_than = args.older_than
    if not args.ids and older_than is None:
        older_than = engine.cfg["quarantine_days"]
    refs, missing = _select(engine, args.ids, older_than=older_than)
    for i in missing:
        print(f"エラー: 隔離中の項目に {i} はありません", file=sys.stderr)
    if not refs:
        print("本削除する項目はありません。")
        return EXIT_ERROR if missing else EXIT_OK
    total = sum(r.item.size for r in refs)
    print(f"{len(refs)} 件 / {human_size(total)} を本削除します。本削除すると元に戻せません。")
    if not args.yes:
        if not sys.stdin.isatty():
            print("確認できないため中止しました (--yes で確認を省略できます)。", file=sys.stderr)
            return EXIT_USAGE
        if input("よろしいですか? [y/N]: ").strip().lower() not in ("y", "yes"):
            print("中止しました。")
            return EXIT_OK
    failed = bool(missing)
    for ref, error in engine.purge(refs):
        if error:
            failed = True
            print(f"失敗: {ref.item.id}: {error}")
        else:
            print(f"本削除: {ref.item.id}  {ref.item.display_rel}")
    return EXIT_ERROR if failed else EXIT_OK


def cmd_drives(engine: Engine, paths: AppPaths) -> int:
    state = State.load(paths.state_file)
    for d in engine.drives:
        settings = config.drive_settings(engine.cfg, d.volume_id)
        if not d.eligible:
            status = f"対象外 ({d.ineligible_reason})"
        elif not settings["enabled"]:
            status = "設定で除外"
        elif not state.is_reviewed(d.volume_id):
            status = "未確認 (次回はドライラン)"
        else:
            status = "対象 (" + ",".join(settings["features"]) + ")"
        print(f"{str(d.root):<4} {d.label or '(ラベルなし)':<16} {d.volume_id:<14} {d.kind:<9} "
              f"空き {human_size(d.free)} / {human_size(d.total)}  {status}")
    connected = {d.volume_id for d in engine.drives}
    for volume_id, info in state.known_drives().items():
        if volume_id not in connected:
            print(f"{info.get('last_root', '?'):<4} {info.get('label') or '(ラベルなし)':<16} {volume_id:<14} "
                  f"未接続 (最終接続 {info.get('last_seen', '?')})")
    print(f"\n自動整理: {'有効' if engine.cfg['enabled'] else '無効 (ドライランのみ)'}")
    return EXIT_OK
