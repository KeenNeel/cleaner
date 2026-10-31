"""music-apps/ (音楽アプリ一覧を作成.bat) の検査。"""

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "music-apps"


def load_build():
    spec = importlib.util.spec_from_file_location("music_apps_build", ROOT / "build.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_bat_is_up_to_date():
    build = load_build()
    data = build.OUTPUT.read_bytes()
    assert data == build.build().encode("utf-8"), "python music-apps/build.py を実行してください"
    assert not data.startswith(b"\xef\xbb\xbf")
    assert data.startswith(b"<# : batch portion\r\n")
    assert b"\n" not in data.replace(b"\r\n", b"")
    assert b"__CATALOG_JSON__" not in data and b"__HTML_TEMPLATE__" not in data


def test_catalog():
    catalog = json.loads((ROOT / "src" / "catalog.json").read_text(encoding="utf-8"))
    ids = [e["id"] for e in catalog["entries"]]
    assert len(ids) == len(set(ids))
    for e in catalog["entries"]:
        assert e["category"] in catalog["categories"]
        assert e["url"].startswith("https://")
        assert e["purpose"] and e["howto"] and e["match"]
        assert all(x == x.lower() for x in e["exes"])

    def find(name):
        t = re.sub(r"_+", " ", name).lower()
        for e in catalog["entries"]:
            if any(re.search(p, t, re.I) for p in e["match"]):
                return e["id"]
        return None

    assert find("FL Studio 2024") == "flstudio"
    assert find("FL Studio ASIO") == "flasio"
    assert find("Synthesizer V Studio 2 Pro") == "synthv"
    assert find("ComfyUI_windows_portable") == "comfyui"
    assert find("iZotope RX 11 Audio Editor") == "rx"
    assert find("VitalSource Bookshelf") is None
    assert find("Google Chrome") is None


def test_template_has_data_placeholder():
    html = (ROOT / "src" / "report.html").read_text(encoding="utf-8")
    assert html.count("__DATA_JSON__") == 1
