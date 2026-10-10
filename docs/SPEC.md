# cleaner 仕様書 (v0.1 ドラフト)

Windows PC のディスクを定期的・自動的に整理するツール。
「容量を空ける」「散らかったファイルを片付ける」「判断材料を出す」の 3 つを、**誤削除しない**ことを最優先に行う。

---

## 1. 前提・スコープ

| 項目 | 内容 |
|---|---|
| 対象 OS | Windows 10 / 11 (64bit) |
| 実行権限 | 通常ユーザー権限 (管理者権限は不要。システム領域は触らない) |
| 実装 | Python 3.12 + 単一 exe 化 (PyInstaller) |
| 起動方法 | Windows タスクスケジューラによる定期実行 + 手動 CLI |
| 設定 | `%APPDATA%\cleaner\config.toml` |

### やらないこと (非スコープ)
- `C:\Windows`、`Program Files`、レジストリ、ドライバ等のシステム領域の掃除
- アプリのアンインストール
- デフラグ・SSD 最適化 (Windows 標準機能に任せる)
- クラウドストレージ (OneDrive 等) の「クラウドのみ」ファイルの中身読み取り

---

## 2. 機能一覧

| # | 機能 | 概要 | 既定の動作 |
|---|---|---|---|
| F1 | 不要ファイル削除 | 一時ファイル・キャッシュ・ゴミ箱・古いログ等 | 自動で隔離 |
| F2 | 重複ファイル検出 | 同一内容のファイルを検出 | 対象フォルダ内のみ自動隔離、他はレポート |
| F3 | ファイル仕分け | ダウンロード・デスクトップを種類/年月で振り分け | 自動で移動 |
| F4 | 古い/大きいファイル報告 | 長期間未使用・巨大ファイルの一覧 | レポートのみ |
| F5 | AI 不要判定 | 古い iPhone バックアップ等、ルールで決めにくいものを AI が判定 | 高確信度のみ隔離、他は承認待ち |

共通基盤: スキャナ / 隔離 (Quarantine) / 復元 / レポート / スケジューラ / ログ

---

## 3. 安全設計 (全機能共通)

### 3.1 削除フロー
```
検出 → [隔離フォルダへ移動] → 保持期間 (既定 30 日) 経過 → 本削除
                     └── 期間中はいつでも `cleaner restore` で元の場所に戻せる
```
- **即時削除はしない**。例外は「ゴミ箱を空にする」「ブラウザ等のキャッシュ」のように、元々使い捨てで復元価値がないものに限り、設定で `immediate = true` を許可する。
- 隔離フォルダは **各ドライブ直下** `X:\.cleaner_quarantine\` に置く (同一ボリューム内の移動なら瞬時・追加容量不要)。
- 隔離時に `manifest.jsonl` へ「元パス・サイズ・更新日時・ハッシュ・理由・判定元(ルール/AI)・隔離日時」を記録する。
- 注意: 隔離中は容量が空かない。空き容量が閾値 (既定 10%) を切った場合は、保持期間が長いものから前倒し削除する (ただし最低保持 7 日は守る)。

### 3.2 絶対に触らないもの (ハード保護リスト)
- `C:\Windows`、`C:\Program Files*`、`C:\ProgramData` (キャッシュの明示指定を除く)
- 実行中プロセスが開いているファイル (ロック中はスキップ)
- システム属性・隠しシステムファイル、シンボリックリンク/ジャンクションの先 (リンクは辿らない)
- Git リポジトリ内 (`.git` を含むディレクトリ配下)、仮想マシンディスク、データベースファイル
- ユーザー設定 `protect` に列挙されたパス
- 更新日時が直近 24 時間以内のファイル (作業中の可能性)

### 3.3 初回実行
- 初回は必ず **ドライラン** (何も動かさずレポートのみ)。ユーザーが内容を確認し `cleaner enable` するまで自動実行は隔離・移動を行わない。

---

## 4. 機能詳細

### F1. 不要ファイル削除
対象カテゴリ (それぞれ設定で ON/OFF・日数変更可):

| カテゴリ | 場所の例 | 条件 |
|---|---|---|
| ユーザー一時ファイル | `%TEMP%` | 7 日以上未更新 |
| ゴミ箱 | 各ドライブの `$Recycle.Bin` | 30 日以上前に捨てたもの |
| ブラウザキャッシュ | Chrome / Edge / Firefox の Cache ディレクトリ | ブラウザ未起動時のみ |
| サムネイルキャッシュ | `%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*` | 常に |
| クラッシュダンプ | `%LOCALAPPDATA%\CrashDumps` | 30 日以上 |
| 中断ダウンロード | `*.crdownload` `*.part` `*.tmp` (Downloads 内) | 7 日以上 |
| 開発系キャッシュ | `node_modules`, `__pycache__`, `.gradle` 等 | **既定 OFF**。有効時も 90 日以上未更新のプロジェクトのみ |

### F2. 重複ファイル検出
- 手順: サイズで絞る → 先頭/末尾 64KB のハッシュ → 全体ハッシュ (BLAKE3) で確定。
- 1KB 未満、ハードリンク同士、保護パス内は対象外。
- **残す 1 つの選び方** (優先順): ① 設定 `keep_priority` に指定したフォルダ内 (例: `Pictures` > `Downloads`) → ② パスが浅い → ③ 作成日時が古い。
- 自動隔離は `auto_dedupe_dirs` (既定: `Downloads`, `Desktop`) に「残す側以外」がある場合のみ。それ以外はレポートに一覧表示。

### F3. ファイル仕分け
- 対象フォルダ: 既定 `Downloads`, `Desktop` (直下のファイルのみ。サブフォルダは触らない)。
- 条件: 最終更新から 3 日以上経過、ロックされていない、中断ダウンロードでない。
- 振り分けルール (既定、設定で変更可):

| 種類 | 拡張子例 | 移動先 |
|---|---|---|
| 画像 | jpg, png, heic, gif, webp | `Pictures\Sorted\{YYYY-MM}` |
| 動画 | mp4, mov, mkv | `Videos\Sorted\{YYYY-MM}` |
| 文書 | pdf, docx, xlsx, pptx, txt | `Documents\Sorted\{種類}\{YYYY}` |
| 圧縮 | zip, 7z, rar | `Downloads\Archives\{YYYY-MM}` |
| インストーラ | exe, msi | `Downloads\Installers` (90 日後に F1 対象として隔離) |
| その他 | — | 移動しない |

- 同名ファイルがある場合は ` (1)` 等の連番を付与。移動履歴も manifest に記録し、`restore` で元に戻せる。

### F4. 古い/大きいファイル報告
- 「大きい」: 既定 1GB 以上。「古い」: 最終アクセス 1 年以上 (NTFS の最終アクセス更新が無効な環境では最終更新日時で代替)。
- フォルダ別の容量ランキング (上位 20) も出す。
- **自動で動かさない**。レポート上から「隔離する」を選べる (手動承認)。

### F5. AI 不要判定
ルールだけでは決めにくいが「たぶん要らない」ものを、AI (Claude API) に判定させる。

**検出器 (ルールで候補を拾う → AI が判断する) の初期セット:**

| 検出器 | 内容 | 判定のヒント |
|---|---|---|
| iPhone/iPad バックアップ | `%APPDATA%\Apple Computer\MobileSync\Backup\*` と `%USERPROFILE%\Apple\MobileSync\Backup\*` | `Info.plist` からデバイス名・機種・最終バックアップ日を取得。同一デバイスの最新以外、または 1 年以上更新のないデバイスは不要候補 |
| 古いインストーラ | 既にインストール済みアプリのインストーラ | インストール済み一覧 (レジストリ読み取りのみ) と照合 |
| 古いドライバ/SDK 展開物 | `C:\NVIDIA`, `C:\AMD`, 展開済み SDK 等 | 作成日・サイズ |
| 放置プロジェクト/ビルド成果物 | `bin/obj/dist/build` 等 | 最終更新日 |
| 旧 Windows 更新残骸の案内 | `C:\Windows.old` | 管理者権限が要るので**案内のみ** (「ディスク クリーンアップ」を促す) |

**AI に渡すもの / 渡さないもの:**
- 渡す: パス、サイズ、作成/更新/アクセス日時、拡張子、検出器が抽出したメタ情報 (例: バックアップのデバイス名・日付)。
- **渡さない: ファイルの中身**。ユーザー名部分のパスはマスク (`C:\Users\<user>\...`)。
- AI 機能は既定 OFF。API キー設定と同意 (`ai.enabled = true`) で有効化。

**AI の出力と扱い:**
- 出力: `{判定: 不要/要確認/必要, 確信度: 0-1, 理由: 文章}`
- 自動隔離: 判定「不要」かつ確信度 ≥ 0.9 かつ検出器ごとの `auto_quarantine = true` のときのみ。
- それ以外はレポートの「承認待ち」欄に理由付きで表示。
- AI は削除を直接実行しない (常に隔離フロー経由)。

---

## 5. 定期実行

| 項目 | 既定 |
|---|---|
| 頻度 | 毎週日曜 3:00 (タスクスケジューラ) |
| 条件 | AC 電源接続時、PC アイドル 10 分以上 |
| 見逃し時 | 次回起動後に実行 |
| 処理順 | 期限切れ隔離の本削除 → F1 → F3 → F2 → F5 → F4 → レポート生成 |
| 実行時間上限 | 2 時間 (超えたら中断し次回継続) |
| 負荷 | 低優先度プロセス・I/O 優先度低で動作 |
| 通知 | 完了時に Windows トースト通知「◯GB 空きました / 承認待ち ◯件」 |

`cleaner schedule install` / `uninstall` で登録・解除。

---

## 6. CLI

```
cleaner scan                 # ドライラン (何も変更せずレポート生成)
cleaner run [--dry-run]      # 整理を実行
cleaner report               # 最新レポートをブラウザで開く
cleaner approve <id...>      # 承認待ち項目を隔離
cleaner restore <id|--all|--since DATE>   # 隔離/移動を元に戻す
cleaner purge [--older-than 30d]          # 隔離フォルダの本削除
cleaner enable / disable     # 自動実行の有効化/無効化
cleaner schedule install|uninstall
```

---

## 7. レポート
- HTML 1 ファイル (`%LOCALAPPDATA%\cleaner\reports\YYYY-MM-DD.html`)。
- 内容: 空いた容量 (カテゴリ別)、隔離した項目、仕分けした項目、重複一覧、古い/大きいファイル、AI 承認待ち (理由付き)、エラー/スキップ一覧。
- 各項目に「復元」「承認」用のコマンドを表示 (コピー可能)。

---

## 8. 設定ファイル例 (`config.toml`)

```toml
enabled = false            # 初回はドライランのみ
quarantine_days = 30
min_free_percent = 10

protect = ['D:\Work', 'C:\Users\me\Important']

[cleanup]
temp_days = 7
recycle_bin_days = 30
browser_cache = true
dev_caches = false

[dedupe]
auto_dedupe_dirs = ['~\Downloads', '~\Desktop']
keep_priority = ['~\Pictures', '~\Documents', '~\Downloads']

[organize]
dirs = ['~\Downloads', '~\Desktop']
min_age_days = 3

[report]
large_file_gb = 1
old_file_days = 365

[ai]
enabled = false
model = "claude-opus-5-5"   # コスト重視なら claude-haiku-5-5
auto_quarantine_threshold = 0.9

[ai.detectors]
iphone_backup = { enabled = true, auto_quarantine = true, keep_latest_per_device = 1 }
old_installers = { enabled = true, auto_quarantine = false }
```

---

## 9. ログ・エラー処理
- ログ: `%LOCALAPPDATA%\cleaner\logs\` (日次ローテーション、90 日保持)。
- アクセス拒否・ロック中・パス長超過 (260 文字超は `\\?\` 形式で対応) はスキップしてレポートに記載。処理全体は止めない。
- 隔離移動中にエラーが起きた場合は manifest に書く前に元に戻す (中途半端な状態を残さない)。

---

## 10. 開発フェーズ案

| フェーズ | 内容 |
|---|---|
| 1 | スキャナ・隔離/復元・manifest・CLI (`scan`/`run`/`restore`/`purge`)・F1 |
| 2 | F3 仕分け、F4 レポート (HTML) |
| 3 | F2 重複検出 |
| 4 | タスクスケジューラ登録・通知 |
| 5 | F5 AI 判定 (iPhone バックアップから) |

---

## 11. 未決事項 (要確認)
1. 対象ドライブ: C: のみか、D: 等のデータドライブ・外付け HDD も含めるか。
2. 仕分けの移動先構成 (上記の既定でよいか、例えば全部 `D:\Sorted` に集めたいか)。
3. 重複ファイルの自動隔離範囲 (Downloads/Desktop 限定でよいか)。
4. AI 判定に使う API キーの用意 (Claude API の従量課金が発生。1 回の実行で数円〜数十円程度の想定)。
5. iPhone バックアップは「デバイスごとに最新 1 件だけ残す」でよいか。
6. GUI (トレイアイコン/設定画面) は必要か。現状は CLI + HTML レポートのみ。
