# cleaner

Windows のディスク (内蔵ドライブ・外付け HDD) を、誤削除しないことを最優先に自動整理するツールです。
仕様は [docs/SPEC.md](docs/SPEC.md) を参照してください。

## 実装状況

| フェーズ | 内容 | 状況 |
|---|---|---|
| 1 | ドライブ管理・隔離/復元・manifest・CLI・F1 不要ファイル削除 | ✅ |
| 2 | F3 仕分け、F4 レポート (HTML) | 未着手 |
| 3 | F2 重複検出 | 未着手 |
| 4 | タスクスケジューラ登録・通知・タスクトレイ | 未着手 |
| 5 | 設定画面・承認待ち画面・隔離ボックス画面 | 未着手 |
| 6 | F5 AI 判定 | 未着手 |

## インストール (開発版)

Python 3.12 以上が必要です。

```
pip install -e .
```

## 使い方

```
cleaner scan                  # ドライラン: 何も変更せず、整理候補を表示する
cleaner enable                # 自動整理を有効にする (以降、実際に隔離する)
cleaner run                   # 整理を実行する
cleaner run --drive D:        # D: ドライブだけ整理する
cleaner list                  # 隔離ボックスの中身
cleaner restore <ID>          # 元の場所に戻す (--all / --since 2026-10-01 も可)
cleaner purge                 # 保持期間 (30日) を過ぎたものを本削除
cleaner purge --older-than 0d # 隔離中のものをすべて本削除 (確認あり)
cleaner drives                # ドライブの一覧と対象状況
cleaner disable               # 自動整理を無効にする
```

### 安全のしくみ
- 初回、および新しいドライブを初めて検出したときは必ずドライランになります。
- 整理したファイルはすぐに消さず、各ドライブ直下の `.cleaner_quarantine` に移します。
  30 日間はいつでも `cleaner restore` で元に戻せます。
- Windows 本体・Program Files・AppData・Git リポジトリ・仮想ディスク・データベース・
  ゲームライブラリ・バックアップ先・24 時間以内に更新したファイルには触りません。

### 設定・データの場所
- 設定: `%APPDATA%\cleaner\config.toml` (項目は仕様書 10 章)
- ログ・実行結果・manifest の写し: `%LOCALAPPDATA%\cleaner\`

## 開発

```
pip install -e ".[dev]" ruff
ruff check src tests
python -m pytest
```

テストは一時フォルダに偽のドライブ構成を作って実行するため、実際のファイルには触りません。
Windows API を使う部分は `tests/test_windows.py` で、GitHub Actions の Windows 環境で確認します。
