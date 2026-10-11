import json
import shutil
from datetime import timedelta

import pytest

from cleaner.drives import Drive
from cleaner.models import Candidate
from cleaner.quarantine import QuarantineError, QuarantineStore, read_manifest

from .conftest import NOW, make_file


def cand(path, **kw):
    return Candidate(path=path, feature="F1", category="temp", reason="test", size=100, **kw)


@pytest.fixture
def store(env):
    return QuarantineStore(env.d, env.paths.manifests_dir)


def test_quarantine_and_restore_roundtrip(env, store):
    f = make_file(env.d.root / "a" / "b" / "file.txt", age_days=10)
    item = store.quarantine(cand(f), NOW)
    assert not f.exists()
    assert (store.items_dir / item.id / "0_file.txt").exists()
    assert (store.root / "README.txt").exists()
    assert store.items()[item.id].state == "quarantined"
    assert store.items()[item.id].entries[0]["hash"]

    shutil.rmtree(env.d.root / "a")  # 親フォルダが消えていても戻せる
    restored = store.restore(item.id, NOW)
    assert restored == [f]
    assert f.read_bytes() == b"x" * 100
    assert store.items()[item.id].state == "restored"
    assert not (store.items_dir / item.id).exists()


def test_restore_does_not_overwrite_existing_file(env, store):
    f = make_file(env.d.root / "file.txt", age_days=10)
    item = store.quarantine(cand(f), NOW)
    make_file(f, size=5)  # 同名の新しいファイルができた
    restored = store.restore(item.id, NOW)
    assert restored == [env.d.root / "file (1).txt"]
    assert f.stat().st_size == 5


def test_restore_twice_fails(env, store):
    f = make_file(env.d.root / "file.txt")
    item = store.quarantine(cand(f), NOW)
    store.restore(item.id, NOW)
    with pytest.raises(QuarantineError):
        store.restore(item.id, NOW)


def test_multiple_entries_and_folders(env, store):
    folder = env.d.root / "cache"
    a = make_file(folder / "x" / "a.bin")
    b = make_file(folder / "b.bin")
    item = store.quarantine(cand(folder, entries=[a, b]), NOW)
    assert not a.exists() and not b.exists()
    store.restore(item.id, NOW)
    assert a.exists() and b.exists()


def test_purge(env, store):
    f = make_file(env.d.root / "dir" / "file.txt")
    item = store.quarantine(cand(env.d.root / "dir", is_dir=True), NOW)
    store.purge(item.id, NOW + timedelta(days=31))
    assert not (store.items_dir / item.id).exists()
    assert store.items()[item.id].state == "purged"
    assert not f.exists()


def test_failed_manifest_write_rolls_back(env, store, monkeypatch):
    f = make_file(env.d.root / "file.txt")

    def boom(_event):
        raise OSError("disk full")

    monkeypatch.setattr(store, "_append", boom)
    with pytest.raises(QuarantineError):
        store.quarantine(cand(f), NOW)
    assert f.exists()
    assert list(store.items_dir.iterdir()) == []


def test_restore_after_drive_letter_change(env, store, tmp_path):
    f = make_file(env.d.root / "docs" / "file.txt")
    item = store.quarantine(cand(f), NOW)
    moved_root = tmp_path / "E"
    shutil.move(env.d.root, moved_root)
    new_store = QuarantineStore(Drive(moved_root, "VOL-D", "Data", "fixed", 1, 1), env.paths.manifests_dir)
    restored = new_store.restore(item.id, NOW)
    assert restored == [moved_root / "docs" / "file.txt"]


def test_delete_immediately_records_history(env, store):
    f = make_file(env.d.root / "file.txt")
    item = store.delete_immediately(cand(f, immediate=True), NOW)
    assert not f.exists()
    assert store.items()[item.id].state == "deleted"


def test_mirror_and_corrupt_lines(env, store):
    f = make_file(env.d.root / "file.txt")
    item = store.quarantine(cand(f), NOW)
    assert read_manifest(store.mirror)[item.id].state == "quarantined"
    with open(store.manifest, "a", encoding="utf-8") as fh:
        fh.write("{broken\n")
        fh.write(json.dumps({"v": 1, "event": "purge", "id": "unknown", "at": NOW.isoformat()}) + "\n")
    assert list(store.items()) == [item.id]
