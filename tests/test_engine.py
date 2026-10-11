from datetime import timedelta

import pytest

from cleaner.lock import AlreadyRunning, RunLock
from cleaner.state import State

from .conftest import Usage, make_file


def kinds(report):
    return sorted(a.kind for a in report.actions)


def test_disabled_config_is_dry_run(env):
    f = make_file(env.paths.temp / "old.tmp", age_days=30)
    report = env.engine().run(dry_run=False)
    assert report.dry_run
    assert kinds(report) == ["would_quarantine"]
    assert f.exists()
    state = State.load(env.paths.state_file)
    assert state.is_reviewed("VOL-C") and state.is_reviewed("VOL-D")


def test_new_drive_gets_dry_run_first(env):
    env.cfg["enabled"] = True
    f = make_file(env.paths.temp / "old.tmp", age_days=30)
    first = env.engine().run(dry_run=False)
    assert not first.dry_run
    assert {d.root: d.status for d in first.drives}[str(env.c.root)] == "review"
    assert kinds(first) == ["would_quarantine"]
    assert f.exists()

    second = env.engine().run(dry_run=False)
    assert kinds(second) == ["quarantined"]
    assert not f.exists()


def test_quarantine_then_purge_after_retention(enabled_env):
    env = enabled_env
    f = make_file(env.paths.temp / "old.tmp", size=500, age_days=30)
    report = env.engine().run(dry_run=False)
    assert kinds(report) == ["quarantined"]
    item_id = report.actions[0].item_id
    assert not f.exists()

    env.clock[0] = env.now + timedelta(days=29)
    assert kinds(env.engine().run(dry_run=False)) == []

    env.clock[0] = env.now + timedelta(days=2)
    report = env.engine().run(dry_run=False)
    assert kinds(report) == ["purged"]
    assert report.actions[0].item_id == item_id
    assert report.freed == 500


def test_low_space_purges_early_but_keeps_minimum(enabled_env):
    env = enabled_env
    a = make_file(env.paths.temp / "a.tmp", size=100, age_days=30)
    env.engine().run(dry_run=False)
    env.clock[0] = env.now + timedelta(days=5)
    make_file(env.paths.temp / "b.tmp", size=100, age_days=30)
    env.engine().run(dry_run=False)
    assert not a.exists()

    # 空き 5% (閾値 10%)。a は隔離から 8 日、b は 3 日
    env.clock[0] = env.now + timedelta(days=3)
    env.usage[str(env.c.root)] = Usage(1000, 950, 50)
    report = env.engine().run(dry_run=False)
    purged = report.by_kind("purged")
    assert [p.path for p in purged] == [str(a.relative_to(env.c.root))]
    assert "前倒し" in purged[0].reason


def test_immediate_delete(enabled_env):
    env = enabled_env
    cache = env.paths.localappdata / "Google/Chrome/User Data/Default/Cache/Cache_Data"
    f = make_file(cache / "f_1", age_days=5)
    env.cfg["cleanup"]["immediate"] = ["browser_cache"]
    report = env.engine().run(dry_run=False)
    assert kinds(report) == ["deleted"]
    assert not f.exists()
    assert report.freed == 100


def test_excluded_drive_and_feature(enabled_env):
    env = enabled_env
    f = make_file(env.paths.temp / "old.tmp", age_days=30)
    env.cfg["drives"] = {"VOL-C": {"enabled": False}}
    report = env.engine().run(dry_run=False)
    assert report.actions == []
    assert {d.root: d.status for d in report.drives}[str(env.c.root)] == "excluded"

    env.cfg["drives"] = {"VOL-C": {"features": ["F2"]}}
    assert env.engine().run(dry_run=False).actions == []
    assert f.exists()


def test_drive_filter(enabled_env):
    env = enabled_env
    make_file(env.paths.temp / "old.tmp", age_days=30)
    report = env.engine().run(dry_run=False, drive_filter="VOL-D")
    assert [d.volume_id for d in report.drives] == ["VOL-D"]
    assert report.actions == []


def test_ineligible_drive(env):
    small_usb = type(env.d)(env.d.root, "VOL-U", "USB", "removable", 32 * 1000**3, 1)
    report = env.engine(drives=[env.c, small_usb]).run(dry_run=True)
    status = {d.volume_id: d for d in report.drives}["VOL-U"]
    assert status.status == "ineligible"
    assert "64GB" in status.note


def test_items_from_disconnected_drive(enabled_env):
    env = enabled_env
    make_file(env.paths.temp / "old.tmp", age_days=30)
    env.engine().run(dry_run=False)
    refs = env.engine(drives=[env.d]).items()
    assert len(refs) == 1
    assert refs[0].store is None
    assert "未接続" in refs[0].drive_label
    results = env.engine(drives=[env.d]).restore(refs)
    assert results[0][2] == "ドライブが接続されていません"


def test_errors_are_reported_not_raised(enabled_env, monkeypatch):
    env = enabled_env
    make_file(env.paths.temp / "old.tmp", age_days=30)
    import cleaner.quarantine as q

    def fail(*_a):
        raise PermissionError("locked")

    monkeypatch.setattr(q.os, "rename", fail)
    report = env.engine().run(dry_run=False)
    assert kinds(report) == ["error"]
    assert "locked" in report.actions[0].message


def test_lock_prevents_concurrent_runs(env):
    with RunLock(env.paths.lock_file):
        with pytest.raises(AlreadyRunning):
            env.engine().run(dry_run=True)


def test_run_report_saved(env):
    env.engine().run(dry_run=True)
    assert len(list(env.paths.runs_dir.glob("*.json"))) == 1
