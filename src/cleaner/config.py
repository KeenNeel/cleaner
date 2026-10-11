"""設定ファイル (config.toml) の読み書き。

ユーザーが書いた値を既定値に上書きマージして使う。未記載の項目は既定値になる。
"""

from __future__ import annotations

import copy
import tomllib
from typing import Any

import tomli_w

from cleaner.appdirs import AppPaths

ALL_FEATURES = ["F1", "F2", "F3", "F4", "F5"]

# 即時削除を許可できるカテゴリ (元々使い捨てで、復元価値がないもの)
IMMEDIATE_ALLOWED = {"recycle_bin", "browser_cache", "thumbnail_cache"}

DEFAULTS: dict[str, Any] = {
    "enabled": False,  # 初回はドライランのみ。`cleaner enable` で有効化
    "quarantine_days": 30,
    "min_quarantine_days": 7,  # 空き容量不足時の前倒し削除でも守る最低保持日数
    "min_free_percent": 10,
    "recent_hours": 24,  # これより新しいファイルは作業中とみなして触らない
    "protect": [],
    "drives": {},  # ボリュームID -> {label, enabled, features}
    "cleanup": {
        "temp": True,
        "temp_days": 7,
        "recycle_bin": True,
        "recycle_bin_days": 30,
        "browser_cache": True,
        "thumbnail_cache": True,
        "crash_dumps": True,
        "crash_dump_days": 30,
        "partial_downloads": True,
        "partial_download_days": 7,
        "dev_caches": False,
        "dev_cache_days": 90,
        "dev_cache_roots": ["~"],
        "immediate": [],  # 即時削除するカテゴリ (IMMEDIATE_ALLOWED のみ有効)
    },
}


def _merge(base: dict, override: dict) -> dict:
    result = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _merge(result[key], value)
        else:
            result[key] = value
    return result


class ConfigError(Exception):
    pass


def load_user(paths: AppPaths) -> dict[str, Any]:
    """ユーザーが書いた設定のみ (既定値をマージしない)。"""
    if not paths.config_file.exists():
        return {}
    try:
        with open(paths.config_file, "rb") as f:
            return tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"設定ファイルの書式が正しくありません: {paths.config_file}: {e}") from e


def load(paths: AppPaths) -> dict[str, Any]:
    cfg = _merge(DEFAULTS, load_user(paths))
    validate(cfg)
    return cfg


def validate(cfg: dict[str, Any]) -> None:
    for key in ("quarantine_days", "min_quarantine_days", "recent_hours"):
        if not isinstance(cfg[key], int) or cfg[key] < 0:
            raise ConfigError(f"{key} は 0 以上の整数で指定してください")
    if cfg["min_quarantine_days"] > cfg["quarantine_days"]:
        raise ConfigError("min_quarantine_days は quarantine_days 以下にしてください")
    if not 0 <= cfg["min_free_percent"] < 100:
        raise ConfigError("min_free_percent は 0〜99 で指定してください")
    unknown = set(cfg["cleanup"]["immediate"]) - IMMEDIATE_ALLOWED
    if unknown:
        raise ConfigError(f"即時削除できないカテゴリが指定されています: {', '.join(sorted(unknown))}")


def save_user_value(paths: AppPaths, key: str, value: Any) -> None:
    """ユーザー設定の 1 項目を書き換えて保存する (他の項目はそのまま)。

    注意: TOML 中のコメントは保存時に失われる。
    """
    user = load_user(paths)
    user[key] = value
    paths.config_dir.mkdir(parents=True, exist_ok=True)
    tmp = paths.config_file.with_suffix(".toml.tmp")
    with open(tmp, "wb") as f:
        tomli_w.dump(user, f)
    tmp.replace(paths.config_file)


def drive_settings(cfg: dict[str, Any], volume_id: str) -> dict[str, Any]:
    entry = cfg["drives"].get(volume_id, {})
    return {
        "enabled": entry.get("enabled", True),
        "features": entry.get("features", ALL_FEATURES),
    }
