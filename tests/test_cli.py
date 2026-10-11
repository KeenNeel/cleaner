import tomllib

import pytest

from cleaner import cli, config

from .conftest import make_file


def run_cli(env, capsys, *argv):
    # enable/disable 以外は engine を差し込む (設定はファイルから読み直したものを使う)
    env.cfg = config.load(env.paths)
    code = cli.main(list(argv), paths=env.paths, engine=env.engine())
    out = capsys.readouterr()
    return code, out.out + out.err


def test_scan_is_dry_run(env, capsys):
    f = make_file(env.paths.temp / "old.tmp", age_days=30)
    code, out = run_cli(env, capsys, "scan")
    assert code == 0
    assert "ドライラン" in out
    assert "一時ファイル: 1 件" in out
    assert "cleaner enable" in out
    assert f.exists()


def test_enable_run_list_restore(env, capsys):
    f = make_file(env.paths.temp / "old.tmp", age_days=30)
    run_cli(env, capsys, "scan")
    code, out = run_cli(env, capsys, "enable")
    assert code == 0
    with open(env.paths.config_file, "rb") as fh:
        assert tomllib.load(fh)["enabled"] is True

    code, out = run_cli(env, capsys, "run")
    assert code == 0
    assert "[隔離]" in out
    assert not f.exists()

    code, out = run_cli(env, capsys, "list")
    assert "old.tmp" in out
    item_id = out.split()[0]

    code, out = run_cli(env, capsys, "restore", item_id)
    assert code == 0
    assert f.exists()

    code, out = run_cli(env, capsys, "list", "--all")
    assert "復元済み" in out


def test_restore_requires_selection(env, capsys):
    code, out = run_cli(env, capsys, "restore")
    assert code == cli.EXIT_USAGE
    code, out = run_cli(env, capsys, "restore", "nope")
    assert code == cli.EXIT_ERROR
    assert "nope" in out


def test_purge(env, capsys, monkeypatch):
    make_file(env.paths.temp / "old.tmp", age_days=30)
    run_cli(env, capsys, "scan")
    run_cli(env, capsys, "enable")
    run_cli(env, capsys, "run")

    code, out = run_cli(env, capsys, "purge")
    assert "本削除する項目はありません" in out  # まだ保持期間内

    monkeypatch.setattr("sys.stdin.isatty", lambda: False)
    code, out = run_cli(env, capsys, "purge", "--older-than", "0d")
    assert code == cli.EXIT_USAGE
    assert "--yes" in out

    code, out = run_cli(env, capsys, "purge", "--older-than", "0d", "--yes")
    assert code == 0
    assert "本削除:" in out
    code, out = run_cli(env, capsys, "list")
    assert "空" in out


def test_drives_and_disable(env, capsys):
    code, out = run_cli(env, capsys, "drives")
    assert "VOL-C" in out and "未確認" in out
    run_cli(env, capsys, "scan")
    code, out = run_cli(env, capsys, "drives")
    assert "対象 (F1,F2,F3,F4,F5)" in out
    code, out = run_cli(env, capsys, "disable")
    assert "無効" in out


def test_invalid_config(env, capsys):
    env.paths.config_dir.mkdir(parents=True, exist_ok=True)
    env.paths.config_file.write_text("quarantine_days = -1\n", encoding="utf-8")
    code = cli.main(["scan"], paths=env.paths, engine=env.engine())
    assert code == cli.EXIT_USAGE
    assert "quarantine_days" in capsys.readouterr().err


@pytest.mark.parametrize("value,expected", [("30d", 30), ("7", 7)])
def test_days_parser(value, expected):
    assert cli._days(value) == expected
