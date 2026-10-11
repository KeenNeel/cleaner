"""機能間で受け渡すデータ。"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Candidate:
    """整理候補。entries が空なら path そのものが対象。

    ブラウザキャッシュのように「フォルダ内の古いファイルだけ」を 1 件として扱う場合や、
    ゴミ箱の本体 ($R) と情報ファイル ($I) をまとめて扱う場合は entries に列挙する。
    """

    path: Path
    feature: str  # "F1" など
    category: str  # "temp" など
    reason: str  # 人が読む説明
    size: int
    is_dir: bool = False
    immediate: bool = False  # True なら隔離せず即時削除
    source: str = "rule"  # "rule" / "ai"
    entries: list[Path] = field(default_factory=list)

    @property
    def targets(self) -> list[Path]:
        return self.entries or [self.path]


@dataclass
class Skipped:
    path: Path
    category: str
    reason: str
