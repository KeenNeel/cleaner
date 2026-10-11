import struct
from datetime import datetime

import pytest

from cleaner.models import Candidate, Skipped
from cleaner.protect import Protector
from cleaner.rules import cleanup

from .conftest import make_file


def collect(env, **cleanup_cfg):
    env.cfg["cleanup"].update(cleanup_cfg)
    ctx = cleanup.CleanupContext(
        paths=env.paths, cfg=env.cfg, drives=[env.c, env.d], now=env.now,
        protector=Protector(env.paths, env.cfg, env.now),
        running_processes=lambda: env.processes,
    )
    results = list(cleanup.collect(ctx))
    cands = [r for r in results if isinstance(r, Candidate)]
    skipped = [r for r in results if isinstance(r, Skipped)]
    return cands, skipped


def by_category(cands, category):
    return [c for c in cands if c.category == category]


def test_temp_respects_age(env):
    old = make_file(env.paths.temp / "old.tmp", age_days=8)
    make_file(env.paths.temp / "new.tmp", age_days=2)
    old_dir = env.paths.temp / "olddir"
    make_file(old_dir / "a", age_days=10)
    mixed = env.paths.temp / "mixed"
    make_file(mixed / "a", age_days=10)
    make_file(mixed / "b", age_days=1)
    cands, _ = collect(env)
    paths = {c.path for c in by_category(cands, "temp")}
    assert paths == {old, old_dir}
    assert next(c for c in cands if c.path == old_dir).is_dir


def _recycle_info(deleted: datetime, original: str) -> bytes:
    filetime = int(deleted.timestamp() * 10_000_000) + 116444736000000000
    name = (original + "\x00").encode("utf-16-le")
    return struct.pack("<qqqi", 2, 123, filetime, len(original) + 1) + name


def test_parse_recycle_info_v1_and_v2():
    when = datetime(2026, 8, 1, 10, 0, 0)
    assert cleanup.parse_recycle_info(_recycle_info(when, r"C:\a\b.txt")) == (when, r"C:\a\b.txt")
    v1 = struct.pack("<qqq", 1, 5, int(when.timestamp() * 1e7) + 116444736000000000)
    v1 += r"D:\x.doc".encode("utf-16-le").ljust(520, b"\x00")
    assert cleanup.parse_recycle_info(v1) == (when, r"D:\x.doc")
    assert cleanup.parse_recycle_info(b"short") is None


def test_recycle_bin(env):
    sid = env.d.root / "$Recycle.Bin" / "S-1-5-21-1"
    sid.mkdir(parents=True)
    (sid / "$IABC.txt").write_bytes(_recycle_info(datetime(2026, 8, 1), r"D:\old.txt"))
    body = make_file(sid / "$RABC.txt", age_days=100)
    (sid / "$INEW.vhdx").write_bytes(_recycle_info(datetime(2026, 10, 1), r"D:\new.vhdx"))
    make_file(sid / "$RNEW.vhdx", age_days=100)
    cands, _ = collect(env)
    rb = by_category(cands, "recycle_bin")
    assert len(rb) == 1
    assert rb[0].path == body
    assert rb[0].entries == [body, sid / "$IABC.txt"]
    assert "2026-08-01" in rb[0].reason


def test_browser_cache_skipped_while_running(env):
    cache = env.paths.localappdata / "Google/Chrome/User Data/Default/Cache/Cache_Data"
    make_file(cache / "f_000001", age_days=5)
    env.processes = {"chrome.exe"}
    cands, skipped = collect(env)
    assert not by_category(cands, "browser_cache")
    assert any("Chrome が起動中" in s.reason for s in skipped)


def test_browser_cache_takes_only_old_files(env):
    cache = env.paths.localappdata / "Google/Chrome/User Data/Default/Cache/Cache_Data"
    old = make_file(cache / "f_000001", size=300, age_days=5)
    make_file(cache / "index", age_days=0.1)
    cands, _ = collect(env)
    bc = by_category(cands, "browser_cache")
    assert len(bc) == 1
    assert bc[0].entries == [old]
    assert bc[0].size == 300


def test_immediate_setting(env):
    cache = env.paths.localappdata / "Mozilla/Firefox/Profiles/abc.default/cache2"
    make_file(cache / "entries" / "X", age_days=5)
    cands, _ = collect(env, immediate=["browser_cache"])
    assert by_category(cands, "browser_cache")[0].immediate


def test_crash_dumps_and_thumbnails(env):
    dump = make_file(env.paths.localappdata / "CrashDumps" / "app.dmp", age_days=40)
    make_file(env.paths.localappdata / "CrashDumps" / "recent.dmp", age_days=5)
    thumb = make_file(env.paths.localappdata / "Microsoft/Windows/Explorer/thumbcache_256.db", age_days=3)
    cands, _ = collect(env)
    assert [c.path for c in by_category(cands, "crash_dumps")] == [dump]
    assert [c.path for c in by_category(cands, "thumbnail_cache")] == [thumb]


def test_partial_downloads(env):
    part = make_file(env.paths.downloads / "movie.mp4.crdownload", age_days=10)
    make_file(env.paths.downloads / "fresh.part", age_days=1)
    make_file(env.paths.downloads / "doc.pdf", age_days=100)
    cands, _ = collect(env)
    assert [c.path for c in by_category(cands, "partial_downloads")] == [part]


@pytest.mark.parametrize("enabled", [False, True])
def test_dev_caches(env, enabled):
    old_project = env.paths.home / "code" / "old"
    (old_project / ".git").mkdir(parents=True)
    make_file(old_project / "package.json", age_days=200)
    make_file(old_project / "node_modules" / "lib" / "index.js", age_days=200)
    make_file(old_project / "node_modules" / "inner" / "node_modules" / "x.js", age_days=200)
    active = env.paths.home / "code" / "active"
    make_file(active / "main.py", age_days=3)
    make_file(active / "__pycache__" / "main.pyc", age_days=100)
    cands, _ = collect(env, dev_caches=enabled)
    dev = by_category(cands, "dev_caches")
    if not enabled:
        assert dev == []
    else:
        assert [c.path for c in dev] == [old_project / "node_modules"]
