"""Windows 固有の API 呼び出し (ctypes)。

このモジュールの関数は Windows でのみ呼び出すこと。他の OS では IS_WINDOWS が False になり、
呼び出し側でフォールバックする。
"""

from __future__ import annotations

import csv
import io
import subprocess
import sys
import uuid

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:  # pragma: no cover - Windows 専用
    import ctypes
    from ctypes import wintypes

DRIVE_TYPES = {
    0: "unknown",
    1: "no_root",
    2: "removable",
    3: "fixed",
    4: "network",
    5: "cdrom",
    6: "ramdisk",
}

FOLDERID_DOWNLOADS = "374DE290-123F-4565-9164-39C4925E467B"

_SEM_FAILCRITICALERRORS = 0x0001
_FILE_ATTRIBUTE_HIDDEN = 0x2
_CREATE_NO_WINDOW = 0x08000000


def logical_drives() -> list[tuple[str, str, str, str, str]]:  # pragma: no cover
    """(ルート, 種類, ラベル, ボリュームシリアル, ファイルシステム) の一覧を返す。

    メディアの入っていないドライブ (空のカードリーダー等) は除外する。
    """
    k32 = ctypes.windll.kernel32
    # メディア未挿入ドライブで「ディスクを挿入してください」ダイアログを出さない
    old_mode = k32.SetErrorMode(_SEM_FAILCRITICALERRORS)
    try:
        mask = k32.GetLogicalDrives()
        result = []
        for i in range(26):
            if not mask & (1 << i):
                continue
            root = f"{chr(ord('A') + i)}:\\"
            kind = DRIVE_TYPES.get(k32.GetDriveTypeW(root), "unknown")
            label = ctypes.create_unicode_buffer(261)
            fs_name = ctypes.create_unicode_buffer(261)
            serial = wintypes.DWORD()
            max_len = wintypes.DWORD()
            flags = wintypes.DWORD()
            ok = k32.GetVolumeInformationW(
                root, label, 261, ctypes.byref(serial), ctypes.byref(max_len),
                ctypes.byref(flags), fs_name, 261,
            )
            if not ok:
                continue
            result.append((root, kind, label.value, f"{serial.value:08X}", fs_name.value))
        return result
    finally:
        k32.SetErrorMode(old_mode)


def known_folder(folder_id: str) -> str | None:  # pragma: no cover
    """SHGetKnownFolderPath でシェルフォルダ (ダウンロード等) の実際の場所を得る。"""

    class GUID(ctypes.Structure):
        _fields_ = [
            ("Data1", wintypes.DWORD),
            ("Data2", wintypes.WORD),
            ("Data3", wintypes.WORD),
            ("Data4", ctypes.c_ubyte * 8),
        ]

    u = uuid.UUID(folder_id)
    guid = GUID(u.fields[0], u.fields[1], u.fields[2], (ctypes.c_ubyte * 8).from_buffer_copy(u.bytes[8:]))
    out = ctypes.c_wchar_p()
    hr = ctypes.windll.shell32.SHGetKnownFolderPath(ctypes.byref(guid), 0, None, ctypes.byref(out))
    try:
        return out.value if hr == 0 else None
    finally:
        ctypes.windll.ole32.CoTaskMemFree(out)


def set_hidden(path: str) -> None:  # pragma: no cover
    k32 = ctypes.windll.kernel32
    attrs = k32.GetFileAttributesW(path)
    if attrs != 0xFFFFFFFF:
        k32.SetFileAttributesW(path, attrs | _FILE_ATTRIBUTE_HIDDEN)


def process_names() -> set[str]:  # pragma: no cover
    """実行中プロセスのイメージ名 (小文字) の集合。"""
    out = subprocess.run(
        ["tasklist", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, encoding="oem", errors="replace",
        creationflags=_CREATE_NO_WINDOW, check=False,
    ).stdout
    return {row[0].lower() for row in csv.reader(io.StringIO(out)) if row}
