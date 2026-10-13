import os
from types import SimpleNamespace

from cleaner import cli, config
from cleaner.fsutil import is_cloud_only
from cleaner.models import Candidate, Skipped
from cleaner.protect import Protector
from cleaner.rules import dedupe

from .conftest import set_age


def write(path, content: bytes, age_days: float = 10):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    set_age(path, age_days)
    return path


def blob(seed: int, size: int = 4096) -> bytes:
    return bytes((seed + i) % 251 for i in range(size))


def collect(env, drives=None, **dedupe_cfg):
    env.cfg["dedupe"].update(dedupe_cfg)
    with dedupe.HashCache(None, env.now) as cache:
        ctx = dedupe.DedupeContext(
            paths=env.paths, cfg=env.cfg, drives=drives or [env.c, env.d], now=env.now,
            protector=Protector(env.paths, env.cfg, env.now), cache=cache,
        )
        results = list(dedupe.collect(ctx))
    cands = [r for r in results if isinstance(r, Candidate)]
    skipped = [r for r in results if isinstance(r, Skipped)]
    return cands, skipped


def test_same_drive_duplicate_keeps_documents_copy(env):
    home = env.paths.home
    keep = write(home / "Documents" / "report.pdf", blob(1))
    dup = write(home / "Desktop" / "report.pdf", blob(1))
    write(home / "Documents" / "other.pdf", blob(2))  # 同じサイズで中身が違う
    cands, _ = collect(env)
    assert [(c.path, c.category, c.approval) for c in cands] == [(dup, "duplicate", False)]
    assert str(keep) in cands[0].reason


def test_same_head_and_tail_but_different_middle(env):
    size = 3 * dedupe.PARTIAL_BYTES
    a = bytearray(blob(1, size))
    b = bytearray(a)
    b[size // 2] ^= 0xFF
    write(env.paths.home / "Videos" / "a.mp4", bytes(a))
    write(env.paths.home / "Videos" / "b.mp4", bytes(b))
    cands, _ = collect(env)
    assert cands == []


def test_shallower_path_kept_when_same_priority(env):
    write(env.c.root / "Data" / "big.iso", blob(3))
    deep = write(env.c.root / "Data" / "old" / "copy" / "big.iso", blob(3))
    cands, _ = collect(env)
    assert [c.path for c in cands] == [deep]


def test_min_size(env):
    write(env.c.root / "Data" / "a.bin", blob(4))
    write(env.c.root / "Data" / "b.bin", blob(4))
    assert collect(env, min_size_kb=5)[0] == []
    assert len(collect(env, min_size_kb=4)[0]) == 1


def test_cross_drive_is_approval_by_default(env):
    write(env.paths.home / "Pictures" / "photo.jpg", blob(5))
    backup = write(env.d.root / "Backup" / "photo.jpg", blob(5))
    cands, _ = collect(env)
    assert [(c.path, c.category, c.approval) for c in cands] == [(backup, "duplicate_cross_drive", True)]
    cands, _ = collect(env, cross_drive="quarantine")
    assert [c.approval for c in cands] == [False]


def test_cross_drive_with_local_duplicates(env):
    write(env.paths.home / "Pictures" / "photo.jpg", blob(6))
    c_dup = write(env.paths.home / "Downloads" / "photo.jpg", blob(6))
    d_keep = write(env.d.root / "Backup" / "photo.jpg", blob(6))
    d_dup = write(env.d.root / "Backup" / "old" / "photo.jpg", blob(6))
    cands, _ = collect(env)
    result = {c.path: (c.category, c.approval) for c in cands}
    assert result == {
        c_dup: ("duplicate", False),
        d_dup: ("duplicate", False),
        d_keep: ("duplicate_cross_drive", True),
    }


def test_whole_folder_duplicate_is_approval_only(env):
    home = env.paths.home
    for name, seed in (("1.jpg", 10), ("2.jpg", 11), ("sub/3.jpg", 12)):
        write(home / "Pictures" / "trip" / name, blob(seed))
        write(home / "Downloads" / "trip (copy)" / name, blob(seed))
    loose = write(home / "Downloads" / "1.jpg", blob(10))
    cands, _ = collect(env)
    folders = [c for c in cands if c.category == "duplicate_folder"]
    assert [(c.path, c.approval, c.is_dir, c.size) for c in folders] == [
        (home / "Downloads" / "trip (copy)", True, True, 3 * 4096)
    ]
    # フォルダ内のファイルは個別に隔離しない。フォルダ外の重複も、残す側がフォルダ内なら触らない
    assert [c for c in cands if c.category != "duplicate_folder"] == []
    assert loose.exists()


def test_partial_folder_match_is_handled_per_file(env):
    home = env.paths.home
    write(home / "Pictures" / "trip" / "1.jpg", blob(20))
    write(home / "Pictures" / "trip" / "2.jpg", blob(21))
    dup = write(home / "Downloads" / "trip" / "1.jpg", blob(20))
    cands, _ = collect(env)
    assert [(c.path, c.category) for c in cands] == [(dup, "duplicate")]


def test_protected_locations(env):
    home = env.paths.home
    write(home / "Documents" / "keep.bin", blob(30))
    write(env.paths.localappdata / "app" / "keep.bin", blob(30))  # AppData は走査しない
    write(home / "repo" / ".git" / "HEAD", b"ref")
    write(home / "repo" / "keep.bin", blob(30))  # Git リポジトリ内
    write(home / "Tools" / "app" / "tool.dll", b"MZ")
    write(home / "Tools" / "app" / "data" / "keep.bin", blob(30))  # アプリのフォルダ
    write(env.c.root / "Windows" / "keep.bin", blob(30))
    write(home / "Downloads" / "keep.bin.crdownload", blob(30))  # 中断ダウンロード
    recent = write(home / "Desktop" / "keep.bin", blob(30), age_days=0.1)  # 作業中かもしれない
    cands, skipped = collect(env)
    assert cands == []
    assert [(s.path, s.reason) for s in skipped] == [(recent, "最近更新された (作業中の可能性)")]


def test_installer_in_downloads_does_not_hide_folder(env):
    downloads = env.paths.downloads
    write(downloads / "setup.exe", b"MZ")
    write(env.paths.home / "Documents" / "movie.mp4", blob(40))
    dup = write(downloads / "movie.mp4", blob(40))
    cands, _ = collect(env)
    assert [c.path for c in cands] == [dup]


def test_user_protect_folder(env):
    write(env.d.root / "Work" / "a.bin", blob(41))
    write(env.d.root / "Work" / "b.bin", blob(41))
    env.cfg["protect"] = [str(env.d.root / "Work")]
    assert collect(env)[0] == []


def test_hardlinks_are_ignored(env):
    a = write(env.c.root / "Data" / "a.bin", blob(50))
    os.link(a, env.c.root / "Data" / "b.bin")
    assert collect(env)[0] == []


def test_changed_after_scan_is_skipped(env, monkeypatch):
    write(env.paths.home / "Documents" / "a.bin", blob(60))
    dup = write(env.paths.home / "Downloads" / "a.bin", blob(60))
    real = dedupe.find_groups

    def find_then_modify(ctx, files):
        groups = real(ctx, files)
        set_age(dup, 5)
        return groups

    monkeypatch.setattr(dedupe, "find_groups", find_then_modify)
    assert collect(env)[0] == []


def test_hash_cache_reuses_and_invalidates(env, tmp_path, monkeypatch):
    f = write(tmp_path / "a.bin", blob(70, 300 * 1024))
    calls = []
    real = dedupe.HashCache._COLUMNS["full"]
    monkeypatch.setitem(dedupe.HashCache._COLUMNS, "full", lambda p, s: calls.append(p) or real(p, s))
    db = tmp_path / "cache.db"
    st = f.stat()
    with dedupe.HashCache(db, env.now) as cache:
        first = cache.full(f, st.st_size, st.st_mtime_ns)
    with dedupe.HashCache(db, env.now) as cache:
        assert cache.full(f, st.st_size, st.st_mtime_ns) == first
        assert len(calls) == 1
        write(f, blob(71, 300 * 1024), age_days=3)
        st = f.stat()
        assert cache.full(f, st.st_size, st.st_mtime_ns) != first
        assert len(calls) == 2


def test_cloud_only_attribute():
    assert is_cloud_only(SimpleNamespace(st_file_attributes=0x400000))
    assert not is_cloud_only(SimpleNamespace(st_file_attributes=0x20))
    assert not is_cloud_only(SimpleNamespace())


# ---- engine / CLI ----


def test_engine_quarantines_and_restores(enabled_env):
    env = enabled_env
    keep = write(env.paths.home / "Documents" / "a.bin", blob(80))
    dup = write(env.paths.home / "Downloads" / "a.bin", blob(80))
    backup = write(env.d.root / "a.bin", blob(80))
    report = env.engine().run(dry_run=False)
    kinds = {a.path: a.kind for a in report.actions}
    assert kinds == {str(dup): "quarantined", str(backup): "needs_approval"}
    assert keep.exists() and backup.exists() and not dup.exists()
    ref = next(r for r in env.engine().items() if r.item.feature == "F2")
    env.engine().restore([ref])
    assert dup.read_bytes() == blob(80)


def test_engine_features_filter(env):
    write(env.paths.temp / "old.tmp", blob(1), age_days=30)
    write(env.paths.home / "Documents" / "a.bin", blob(81))
    write(env.paths.home / "Downloads" / "a.bin", blob(81))
    report = env.engine().run(dry_run=True, features=["F2"])
    assert [a.feature for a in report.actions] == ["F2"]
    assert (env.paths.data_dir / "hashcache.db").exists()


def test_cli_scan_large_duplicates_on_one_drive(env, capsys):
    write(env.paths.home / "Documents" / "big.mkv", blob(90, 2 * 1024 * 1024))
    write(env.paths.home / "Downloads" / "big.mkv", blob(90, 2 * 1024 * 1024))
    write(env.paths.home / "Documents" / "small.txt", blob(91))
    write(env.paths.home / "Downloads" / "small.txt", blob(91))
    env.cfg = config.load(env.paths)
    code = cli.main(["scan", "--drive", "VOL-C", "--only", "F2", "--min-size", "1MB"],
                    paths=env.paths, engine=env.engine())
    out = capsys.readouterr().out
    assert code == 0
    assert "[隔離予定] 重複ファイル (同一ドライブ内): 1 件 / 2.0MB" in out
    assert "big.mkv" in out and "small.txt" not in out


def test_cli_size_and_feature_parsers():
    assert cli._size("100MB") == 100 * 1024
    assert cli._size("1.5gb") == int(1.5 * 1024 * 1024)
    assert cli._features("f1, F2") == ["F1", "F2"]
    for bad in ("100", "0KB"):
        try:
            cli._size(bad)
        except Exception as e:  # argparse.ArgumentTypeError
            assert "サイズ" in str(e)
        else:
            raise AssertionError(bad)


def test_feature_only_review_allows_feature_only_run(env):
    env.cfg["enabled"] = True
    old_tmp = write(env.paths.temp / "old.tmp", blob(1), age_days=30)
    write(env.paths.home / "Documents" / "a.bin", blob(82))
    dup = write(env.paths.home / "Downloads" / "a.bin", blob(82))
    first = env.engine().run(dry_run=True, features=["F2"])
    assert [a.kind for a in first.actions] == ["would_quarantine"]
    second = env.engine().run(dry_run=False, features=["F2"])
    assert [a.kind for a in second.actions] == ["quarantined"]
    assert not dup.exists()
    # F1 はまだ確認していないので、全機能の実行ではドライランになる
    third = env.engine().run(dry_run=False)
    assert [a.kind for a in third.actions] == ["would_quarantine"]
    assert old_tmp.exists()


def test_exe_in_drive_root_or_users_does_not_hide_drive(env):
    write(env.c.root / "installer.exe", b"MZ")
    write(env.c.root / "Users" / "tool.exe", b"MZ")
    write(env.paths.home / "Documents" / "a.bin", blob(83))
    dup = write(env.paths.home / "Videos" / "old" / "a.bin", blob(83))
    cands, _ = collect(env)
    assert [c.path for c in cands] == [dup]


def test_skipped_folders_are_logged(env, caplog):
    write(env.c.root / "Tools" / "app.dll", b"MZ")
    with caplog.at_level("INFO", logger="cleaner.rules.dedupe"):
        collect(env)
    assert "Tools を飛ばしました: アプリのフォルダ (app.dll)" in caplog.text
