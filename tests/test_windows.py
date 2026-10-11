"""Windows 実機 (CI の windows-latest) でのみ動かす、Windows API 呼び出しの確認。"""

import sys

import pytest

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows 専用")


def test_list_drives_finds_system_drive():
    from cleaner.drives import list_drives

    drives = list_drives()
    system = [d for d in drives if str(d.root).upper().startswith("C:")]
    assert system, drives
    assert system[0].kind == "fixed"
    assert system[0].volume_id.startswith("VOL-")
    assert system[0].total > 0


def test_default_paths():
    from cleaner.appdirs import default_paths

    paths = default_paths()
    assert paths.downloads.name
    assert any(p.name.lower() == "windows" for p in paths.system_roots)
    assert paths.localappdata.exists()


def test_process_names_include_python():
    from cleaner import winapi

    names = winapi.process_names()
    assert any(n.startswith("python") for n in names)


def test_set_hidden(tmp_path):
    import os
    import stat

    from cleaner import winapi

    d = tmp_path / "q"
    d.mkdir()
    winapi.set_hidden(str(d))
    assert os.stat(d).st_file_attributes & stat.FILE_ATTRIBUTE_HIDDEN


def test_long_path_quarantine(tmp_path):
    import os

    from cleaner.drives import Drive
    from cleaner.fsutil import longpath
    from cleaner.models import Candidate
    from cleaner.quarantine import QuarantineStore

    from .conftest import NOW

    deep = tmp_path
    for i in range(12):
        deep = deep / f"very_long_directory_name_{i:02d}"
    os.makedirs(longpath(deep))
    f = deep / "file.txt"
    with open(longpath(f), "wb") as fh:
        fh.write(b"x" * 100)
    assert len(str(f)) > 260
    store = QuarantineStore(Drive(tmp_path, "VOL-T", "", "fixed", 1, 1), tmp_path / "mirror")
    item = store.quarantine(Candidate(f, "F1", "temp", "t", 100), NOW)
    assert store.restore(item.id, NOW) == [f]
