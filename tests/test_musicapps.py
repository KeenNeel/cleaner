import struct
from datetime import datetime
from pathlib import Path

from cleaner import cli, musicapps
from cleaner.musicapps import ScanRoots, Source


def make_lnk(path: Path, target: str, args: str = "") -> Path:
    """LinkInfo (LocalBasePath) と Arguments を持つ最小の .lnk を作る。"""
    base = target.encode("cp932") + b"\x00"
    header_size = 0x1C
    info = struct.pack("<7I", header_size + len(base) + 1, header_size, 0x1, 0, header_size, 0,
                       header_size + len(base)) + base + b"\x00"
    flags = 0x2 | 0x80 | (0x20 if args else 0)
    header = struct.pack("<II", 0x4C, 0) + b"\x00" * 12 + struct.pack("<I", flags) + b"\x00" * (0x4C - 0x18)
    data = header + info
    if args:
        data += struct.pack("<H", len(args)) + args.encode("utf-16-le")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def write(path: Path, size: int = 10) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x" * size)
    return path


def test_read_lnk(tmp_path):
    lnk = make_lnk(tmp_path / "a.lnk", r"C:\Program Files\REAPER\reaper.exe", args="-new")
    sc = musicapps.read_lnk(lnk)
    assert sc.target == r"C:\Program Files\REAPER\reaper.exe"
    assert sc.args == "-new"
    assert musicapps.read_lnk(write(tmp_path / "broken.lnk")) is None


def test_match_catalog():
    assert musicapps.match_catalog("FL Studio 2024").id == "flstudio"
    assert musicapps.match_catalog("FL Studio ASIO").id == "flasio"
    assert musicapps.match_catalog("Synthesizer V Studio 2 Pro").id == "synthv"
    assert musicapps.match_catalog("VOICEVOX.lnk").id == "voicevox"
    assert musicapps.match_catalog("ComfyUI_windows_portable").id == "comfyui"
    assert musicapps.match_catalog("Google Chrome") is None
    assert musicapps.looks_musical("Some Synth VST3")
    assert not musicapps.looks_musical("Realtek High Definition Audio Driver")


def build_tree(tmp_path: Path) -> tuple[ScanRoots, list[Source]]:
    pf = tmp_path / "Program Files"
    desktop = tmp_path / "Users" / "me" / "Desktop"
    start = tmp_path / "Start Menu" / "Programs"
    c_root = tmp_path / "C"

    fl = pf / "Image-Line" / "FL Studio 2024"
    write(fl / "FL64.exe", 5000)
    write(fl / "uninstall.exe", 100)
    write(fl / "Data" / "big.dat", 10000)
    make_lnk(desktop / "FL Studio 2024.lnk", str(fl / "FL64.exe"))
    make_lnk(start / "Image-Line" / "Uninstall FL Studio.lnk", str(fl / "uninstall.exe"))

    comfy = c_root / "ComfyUI_windows_portable"
    write(comfy / "run_nvidia_gpu.bat", 50)
    write(comfy / "ComfyUI" / "main.py", 50)

    vvox = tmp_path / "Users" / "me" / "AppData" / "Local" / "Programs" / "VOICEVOX"
    write(vvox / "VOICEVOX.exe", 3000)
    make_lnk(start / "VOICEVOX.lnk", str(vvox / "VOICEVOX.exe"))

    (desktop / "Suno.url").write_text("[InternetShortcut]\nURL=https://suno.com/create\n", encoding="utf-8")
    (desktop / "Google.url").write_text("[InternetShortcut]\nURL=https://google.com/\n", encoding="utf-8")

    vst3 = pf / "Common Files" / "VST3"
    write(vst3 / "Vital.vst3" / "Contents" / "x86_64-win" / "Vital.vst3", 700)
    write(vst3 / "Serum2.vst3", 300)

    registry = [
        Source("registry", "FL Studio 2024", location=None, target=fl / "FL64.exe", size=999 * 1024,
               publisher="Image-Line", version="24.1"),
        Source("registry", "Cool Synth VST3 Bundle", size=2048 * 1024, publisher="Someone",
               url="https://example.com/synth"),
        Source("registry", "Realtek High Definition Audio Driver", size=1024),
        Source("registry", "Microsoft Edge"),
    ]
    roots = ScanRoots(
        desktops=[desktop],
        start_menus=[start],
        program_dirs=[pf, vvox.parent],
        shallow_dirs=[c_root],
        plugin_dirs=[vst3],
    )
    return roots, registry


def test_scan_and_render(tmp_path):
    roots, registry = build_tree(tmp_path)
    result = musicapps.scan(roots, registry=lambda: registry, now=datetime(2026, 10, 31, 12, 0))
    apps = {a.key: a for a in result.apps}
    assert set(apps) == {"flstudio", "comfyui", "voicevox", "suno", "other:cool synth vst3 bundle"}

    fl = apps["flstudio"]
    assert fl.location.name == "FL Studio 2024"
    assert fl.launch_file.name == "FL64.exe"
    assert fl.size == 15100 and fl.size_note == "フォルダ実測"
    assert fl.version == "24.1"
    assert "デスクトップの「FL Studio 2024」をダブルクリック" in fl.launch_method
    assert all("Uninstall" not in s.name for s in fl.shortcuts)

    comfy = apps["comfyui"]
    assert comfy.launch_file.name == "run_nvidia_gpu.bat"
    assert "127.0.0.1:8188" in comfy.launch_method

    assert apps["voicevox"].launch_file.name == "VOICEVOX.exe"
    assert "スタートメニュー" in apps["voicevox"].launch_method
    assert "ダブルクリック" in apps["suno"].launch_method
    assert apps["suno"].launch_file.name == "Suno.url"
    assert "Web サービス" in apps["suno"].size_note

    other = apps["other:cool synth vst3 bundle"]
    assert other.category == musicapps.OTHER_CATEGORY
    assert other.size == 2048 * 1024 and other.size_note == "インストール情報の推定値"
    assert other.url == "https://example.com/synth"

    assert [(p.name, p.format) for p in result.plugins] == [("Serum2", "VST3"), ("Vital", "VST3")]
    assert result.plugins[1].size == 700

    page = musicapps.render_html(result)
    assert page.startswith("<!DOCTYPE html>")
    for text in ("FL Studio", "https://www.image-line.com/fl-studio/", "FL64.exe", "VOICEVOX", "Suno",
                 "Serum2", "簡単な利用方法", "起動方法", "2026-10-31 12:00"):
        assert text in page
    assert "Realtek" not in page and "google.com" not in page


def test_render_escapes_html(tmp_path):
    rec = musicapps.AppRecord("other:x", "<script>alert(1)</script>", musicapps.OTHER_CATEGORY, "p", "", "h")
    result = musicapps.ScanResult([rec], [], ScanRoots(), datetime(2026, 1, 1), "")
    page = musicapps.render_html(result)
    assert "<script>alert(1)</script>" not in page
    assert "&lt;script&gt;" in page


def test_cli_music_apps(tmp_path, monkeypatch, capsys):
    roots, registry = build_tree(tmp_path)
    monkeypatch.setattr(musicapps, "default_roots", lambda: roots)
    real_scan = musicapps.scan
    monkeypatch.setattr(musicapps, "scan", lambda **kw: real_scan(roots, registry=lambda: registry, **kw))
    out = tmp_path / "report.html"
    assert cli.main(["music-apps", "-o", str(out)]) == 0
    assert "FL Studio" in out.read_text(encoding="utf-8")
    assert "HTML を作成しました" in capsys.readouterr().out
