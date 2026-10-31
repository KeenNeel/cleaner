"""src/ の scan.ps1・catalog.json・report.html を 1 つの .bat にまとめる。

    python music-apps/build.py

できた「音楽アプリ一覧を作成.bat」はダブルクリックだけで動く (Windows 標準の PowerShell を使う)。
"""

from __future__ import annotations

import json
import runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / "src"
OUTPUT = HERE / "音楽アプリ一覧を作成.bat"

# 先頭はバッチと PowerShell の両方として正しい形にする。
# cmd は 1 行目をラベルとして読み飛ばして PowerShell を起動し、PowerShell は <# … #> をコメントとして読み飛ばす。
HEADER = """<# : batch portion
@echo off
setlocal
title Music apps scanner
echo Scanning music apps. This may take a few minutes...
set "MUSICAPPS_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:MUSICAPPS_SELF, [Text.Encoding]::UTF8))"
echo.
pause
goto :EOF
#>
"""


def load_catalog() -> dict:
    """catalog.json に、details_apps.py (機能・使い方) と details_web.py (Web サービス) を合わせる。"""
    catalog = json.loads((SRC / "catalog.json").read_text(encoding="utf-8"))
    apps = runpy.run_path(str(SRC / "details_apps.py"))["APP_DETAILS"]
    web = runpy.run_path(str(SRC / "details_web.py"))
    for e in catalog["entries"]:
        features, usage = apps.get(e["id"], ([], []))
        e["features"] = list(features)
        e["usage"] = list(usage)
    catalog["webServices"] = web["WEB_SERVICES"]
    catalog["webKeywords"] = web["WEB_MUSIC_KEYWORDS"]
    return catalog


def build() -> str:
    catalog = load_catalog()
    catalog_json = json.dumps(catalog, ensure_ascii=False, indent=1)
    template = (SRC / "report.html").read_text(encoding="utf-8")
    script = (SRC / "scan.ps1").read_text(encoding="utf-8")
    for name, text in (("catalog.json", catalog_json), ("report.html", template)):
        if any(line.startswith("'@") for line in text.splitlines()):
            raise SystemExit(f"{name} に \"'@\" で始まる行があり、PowerShell の here-string を壊します")
    body = script.replace("__CATALOG_JSON__", catalog_json, 1).replace("__HTML_TEMPLATE__", template.rstrip("\n"), 1)
    text = HEADER + body
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def main() -> None:
    OUTPUT.write_bytes(build().encode("utf-8"))  # BOM なし (BOM があると cmd が 1 行目を読めない)
    print(f"作成しました: {OUTPUT}")


if __name__ == "__main__":
    main()
