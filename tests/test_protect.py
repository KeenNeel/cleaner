import os

import pytest

from cleaner.protect import ANY_EXTENSION, Protector

from .conftest import make_file


@pytest.fixture
def prot(env):
    env.cfg["protect"] = [str(env.d.root / "Important")]
    return Protector(env.paths, env.cfg, env.now)


def test_ordinary_old_file_is_allowed(env, prot):
    f = make_file(env.d.root / "stuff" / "a.txt", age_days=10)
    assert prot.check(f) is None


def test_recent_file_is_protected(env, prot):
    f = make_file(env.d.root / "a.txt", age_days=0.5)
    assert "最近" in prot.check(f)


def test_folder_with_recent_file_inside_is_protected(env, prot):
    make_file(env.d.root / "dir" / "old.txt", age_days=30)
    make_file(env.d.root / "dir" / "sub" / "new.txt", age_days=0.1)
    assert "最近" in prot.check(env.d.root / "dir")


def test_system_and_appdata_are_protected_unless_allowed(env, prot):
    win = make_file(env.c.root / "Windows" / "x.dll", age_days=100)
    assert "システム" in prot.check(win)
    tmp = make_file(env.paths.temp / "t.tmp", age_days=100)
    assert "システム" in prot.check(tmp)
    assert prot.check(tmp, allow_roots=(env.paths.temp,)) is None


def test_user_protect_list(env, prot):
    f = make_file(env.d.root / "Important" / "a.txt", age_days=100)
    assert "保護フォルダ" in prot.check(f)


def test_protected_folder_names(env, prot):
    f = make_file(env.d.root / "SteamLibrary" / "steamapps" / "game.bin", age_days=100)
    assert "steamapps" in prot.check(f)


def test_quarantine_folder_is_always_protected(env, prot):
    f = make_file(env.d.root / ".cleaner_quarantine" / "items" / "x", age_days=100)
    assert prot.check(f, allow_roots=(env.d.root,)) == "隔離フォルダ内"


def test_git_repository(env, prot):
    (env.d.root / "repo" / ".git").mkdir(parents=True)
    f = make_file(env.d.root / "repo" / "src" / "a.py", age_days=100)
    assert "Git" in prot.check(f)
    assert prot.check(f, allow_git=True) is None


def test_protected_extensions(env, prot):
    f = make_file(env.d.root / "vm" / "disk.vhdx", age_days=100)
    assert ".vhdx" in prot.check(f)
    assert prot.check(f, allow_exts=(".vhdx",)) is None
    assert prot.check(f, allow_exts=(ANY_EXTENSION,)) is None


@pytest.mark.skipif(os.name == "nt", reason="シンボリックリンク作成に権限が必要")
def test_symlink_is_protected(env, prot):
    target = make_file(env.d.root / "real.txt", age_days=100)
    link = env.d.root / "link.txt"
    link.symlink_to(target)
    assert "リンク" in prot.check(link)
