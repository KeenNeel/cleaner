# C ドライブの大きい重複ファイルを整理する手順

cleaner の F2 (重複ファイル検出) を使って、C ドライブにある **大きい重複ファイル** を整理する手順です。
重複したファイルはすぐには消さず、`C:\.cleaner_quarantine` に移します (隔離)。30 日間はいつでも元に戻せます。

## 手順 1. Python をインストールする

1. https://www.python.org/downloads/ から Python 3.12 以上をダウンロードします。
2. インストーラの最初の画面で **「Add python.exe to PATH」にチェックを入れて** から「Install Now」を押します。
3. PowerShell (スタートメニューで「PowerShell」と検索) を開いて、バージョンが表示されることを確認します。

```
python --version
```

## 手順 2. cleaner をダウンロードしてインストールする

Git がある場合:

```
cd $HOME
git clone https://github.com/KeenNeel/cleaner.git
cd cleaner
pip install -e .
```

Git がない場合は、GitHub のリポジトリページの「Code」→「Download ZIP」で取得して展開し、
展開したフォルダで `pip install -e .` を実行します。

インストールできたか確認します:

```
cleaner --version
```

## 手順 3. 重複ファイルを確認する (ドライラン: 何も変更しません)

C ドライブの 100MB 以上の重複ファイルだけを探します。

```
cleaner scan --drive C: --only F2 --min-size 100MB
```

- 初回はファイル数が多いため時間がかかります (数分〜数十分)。2 回目以降はハッシュのキャッシュで速くなります。
- すべての候補を見るには `-v` を付けます: `cleaner -v scan --drive C: --only F2 --min-size 100MB`
- サイズは `500MB`、`1GB` のように変えられます。

表示の見方:

| 表示 | 意味 |
|---|---|
| `[隔離予定] 重複ファイル (同一ドライブ内)` | 有効にすると自動で隔離されるもの。「○○ と同じ内容」の ○○ が残る方 |
| `[承認待ち] 重複ファイル (ドライブをまたぐ)` | C: と D: などに同じファイルがあるもの。バックアップの可能性があるので自動では動かしません |
| `[承認待ち] 重複フォルダ` | フォルダの中身がまるごと同じもの。自動では動かしません |
| `保護のため対象外` | 最近更新された等の理由で触らないもの |

**残す 1 つ** は ドキュメント > ピクチャ > ビデオ > ミュージック > その他 > デスクトップ > ダウンロード の順で選ばれます
(同じ順位ならパスが浅い方、さらに同じなら作成日時が古い方)。
Windows 本体・Program Files・AppData・Git リポジトリ・アプリのフォルダ・OneDrive のクラウドのみのファイルは対象外です。

## 手順 4. 自動整理を有効にする

手順 3 の内容に問題がなければ、有効にします。

```
cleaner enable
```

## 手順 5. 重複ファイルを隔離する

手順 3 と同じ条件で実行します。

```
cleaner run --drive C: --only F2 --min-size 100MB
```

`[隔離]` と表示されたファイルが `C:\.cleaner_quarantine` に移されます。
(同じドライブ内の移動なので一瞬で終わりますが、この時点ではまだ容量は空きません)

## 手順 6. 必要なファイルがなくなっていないか確認する

```
cleaner list
```

隔離したファイルの ID・元の場所・本削除予定日が表示されます。間違えて隔離されたものがあれば戻します:

```
cleaner restore <ID>           # 1 件戻す
cleaner restore --all          # すべて戻す
```

## 手順 7. 容量を空ける (本削除)

隔離してから 30 日経つと、次の実行時に自動で本削除されて容量が空きます。手動で本削除する場合:

```
cleaner purge                    # 30 日を過ぎたものを本削除
cleaner purge --older-than 0d    # 隔離中のものをすべて今すぐ本削除 (確認あり、元に戻せません)
```

## 承認待ちの項目について

ドライブをまたぐ重複と重複フォルダは、表示されたパスを見て、不要なら エクスプローラー で手動で削除してください。
ドライブをまたぐ重複も自動で隔離したい場合は、`%APPDATA%\cleaner\config.toml` に次のように書きます。

```toml
[dedupe]
cross_drive = "quarantine"
```

## 設定 (`%APPDATA%\cleaner\config.toml`)

```toml
protect = ['C:\Users\me\大事なフォルダ']   # 絶対に触らないフォルダ

[dedupe]
min_size_kb = 102400        # 毎回 --min-size を付ける代わりに、100MB (=102400KB) を既定にする
keep_priority = ['~\Documents', '~\Pictures', '~\Videos', '~\Music', '*', '~\Desktop', '~\Downloads']
```
