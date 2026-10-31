<# : batch portion
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
# 音楽生成アプリ・関連ソフトを探し、デスクトップに「音楽アプリ一覧.html」を作る。
# ファイルやレジストリを読むだけで、何も変更・削除しない。Windows PowerShell 5.1 以降で動く。
#
# このファイルは build.py が catalog.json と report.html を埋め込んで .bat にまとめる。

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$CatalogJson = @'
{
 "categories": [
  "AI作曲・音楽生成",
  "AI歌声・音声合成",
  "AI音源分離・声質変換",
  "AI音楽解析・歌詞",
  "DAW (作曲・録音・編集)",
  "楽譜作成・MIDI",
  "波形編集・録音・変換",
  "音源・プラグイン・管理ツール",
  "オーディオ設定・ドライバ",
  "その他 (音楽関連の可能性)"
 ],
 "entries": [
  {
   "id": "chordmini",
   "name": "ChordMini",
   "category": "AI音楽解析・歌詞",
   "purpose": "曲のコード進行・ビート・歌詞を AI で解析し、ギター/ピアノのコード表示や歌詞の同期表示をするオープンソースアプリ。YouTube のリンクや音声ファイルに対応。",
   "url": "https://github.com/ptnghia-j/ChordMiniApp",
   "match": [
    "chord[\\s_-]?mini"
   ],
   "exes": [
    "start.bat",
    "run.bat",
    "start-dev.bat",
    "start.ps1"
   ],
   "howto": "Python バックエンドとフロントエンド (npm run dev) を起動 → ブラウザで http://localhost:3000 を開く → YouTube の URL か音声ファイルを指定して解析 → コード譜・ビート・歌詞を確認。",
   "launch_note": "起動後に http://localhost:3000 をブラウザで開きます (Docker 版は docker compose up)。",
   "features": [
    "音声を解析してコード進行を自動で書き出す (301 種類のコード表記に対応)",
    "ビート (拍) を検出し、メトロノームと一緒に再生できる",
    "ギターのコードダイアグラム・ピアノの鍵盤表示でコードを確認できる",
    "歌詞を取得して曲に同期表示 (カラオケのように流れる)",
    "メロディの自動採譜 (実験的機能)",
    "YouTube のリンク、または手元の音声ファイルを入力にできる"
   ],
   "usage": [
    "初回のみ: Python バックエンドのライブラリと、フロントエンドの npm パッケージを入れる (README の手順どおり)",
    "Python バックエンドを起動する",
    "フロントエンドを npm run dev で起動する (Docker 版は docker compose up だけで両方起動)",
    "ブラウザで http://localhost:3000 を開く",
    "YouTube の URL を貼るか音声ファイルを選び、解析を開始",
    "コード譜・ビート・歌詞の表示を見ながら再生。ギター/ピアノ表示に切り替えて練習に使う"
   ]
  },
  {
   "id": "suno",
   "name": "Suno",
   "category": "AI作曲・音楽生成",
   "purpose": "歌詞やスタイルの指示文から、ボーカル入りの楽曲を丸ごと AI 生成する Web サービス。",
   "url": "https://suno.com/",
   "match": [
    "\\bsuno\\b"
   ],
   "exes": [],
   "howto": "ブラウザで suno.com を開いてログイン → Create で曲のスタイル (例: J-POP, 女性ボーカル) と歌詞を入力 → Create を押すと 2 曲生成される。",
   "launch_note": "Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。",
   "features": [
    "歌詞とスタイル (ジャンル・雰囲気・声質) の指示から、ボーカル入りの曲を丸ごと生成",
    "歌詞を自分で書く「Custom」モードと、テーマだけ入力する簡単モードがある",
    "曲の続きを作る Extend、カバー・リミックス、ステム (パート) 分割",
    "生成した曲は MP3 / WAV でダウンロード可能 (プランにより商用利用可否が異なる)"
   ],
   "usage": [
    "suno.com にアクセスしてログイン",
    "Create を開き、Custom をオンにして Lyrics (歌詞) と Style of Music (例: J-POP, female vocal, emotional) を入力",
    "Create を押すと 2 曲生成される",
    "気に入った曲は Extend で続きを作り、最後に Get Whole Song で 1 曲にまとめる",
    "… メニューからダウンロード"
   ]
  },
  {
   "id": "udio",
   "name": "Udio",
   "category": "AI作曲・音楽生成",
   "purpose": "テキストの指示から歌入りの楽曲を生成・延長 (Extend) できる AI 作曲 Web サービス。",
   "url": "https://www.udio.com/",
   "match": [
    "\\budio\\b"
   ],
   "exes": [],
   "howto": "udio.com にログイン → プロンプトに曲の雰囲気を書いて Create → 気に入った曲を Extend で伸ばして 1 曲に仕上げる。",
   "launch_note": "Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。",
   "features": [
    "テキストの指示から歌入りの楽曲を生成 (32 秒〜の断片を順に伸ばして 1 曲にする)",
    "前後への Extend、イントロ / アウトロの追加、Inpaint (一部だけ作り直し)",
    "歌詞の自動生成または自分で入力した歌詞で歌わせる",
    "Remix で既存の曲の雰囲気を変える"
   ],
   "usage": [
    "udio.com にログイン",
    "プロンプトに曲の雰囲気・ジャンル・楽器を書いて Create",
    "良い断片を選んで Extend で前後を伸ばす",
    "Add Outro で曲を終わらせ、Publish またはダウンロード"
   ]
  },
  {
   "id": "stableaudio",
   "name": "Stable Audio",
   "category": "AI作曲・音楽生成",
   "purpose": "Stability AI のテキストから音楽・効果音を生成する AI (Web 版 / ローカルモデル版)。",
   "url": "https://stableaudio.com/",
   "match": [
    "stable[\\s_-]?audio"
   ],
   "exes": [],
   "howto": "Web 版はプロンプトと長さを指定して Generate。ローカル版 (stable-audio-tools / ComfyUI) はモデルを読み込んでプロンプトを入力する。",
   "launch_note": "",
   "features": [
    "テキストから音楽・効果音・ループ素材を生成",
    "曲の長さや BPM を指定できる",
    "Audio-to-Audio で手持ちの音を元に変化させる",
    "オープン版 (Stable Audio Open) は ComfyUI などでローカル実行可能"
   ],
   "usage": [
    "Web 版: stableaudio.com でプロンプト (例: lo-fi hip hop, piano, 90 BPM) と長さを指定して Generate",
    "ローカル版: ComfyUI に Stable Audio Open のモデルを入れ、用意されたワークフローを読み込む",
    "プロンプトを入力して実行し、生成された WAV を保存"
   ]
  },
  {
   "id": "musicgen",
   "name": "MusicGen / AudioCraft (Meta)",
   "category": "AI作曲・音楽生成",
   "purpose": "Meta のオープンソース音楽生成 AI。テキストやメロディから BGM を生成する (Python / Gradio)。",
   "url": "https://github.com/facebookresearch/audiocraft",
   "match": [
    "audiocraft",
    "musicgen"
   ],
   "exes": [
    "run.bat",
    "start.bat",
    "webui.bat",
    "app.py"
   ],
   "howto": "付属の起動バッチ (または python app.py) で Web 画面を起動 → ブラウザで表示された URL を開き、説明文を入力して Generate。",
   "launch_note": "起動後に表示される http://127.0.0.1:xxxx をブラウザで開きます。",
   "features": [
    "Meta のオープンソース音楽生成 AI (AudioCraft に含まれる)",
    "テキストの説明から BGM (歌なし) を生成",
    "メロディ版モデルは、手持ちの曲のメロディに沿って別アレンジを生成",
    "モデルの大きさ (small / medium / large) で品質と速度を選べる",
    "AudioGen (効果音生成) も同梱"
   ],
   "usage": [
    "起動バッチ (または python -m demos.musicgen_app) で Gradio の画面を起動",
    "表示された http://127.0.0.1:7860 などをブラウザで開く",
    "Model を選び、Input Text に曲の説明を英語で入力 (例: upbeat EDM with heavy bass)",
    "Duration で長さを指定して Submit",
    "生成された音声を再生・ダウンロード"
   ]
  },
  {
   "id": "acestep",
   "name": "ACE-Step",
   "category": "AI作曲・音楽生成",
   "purpose": "歌詞とタグから歌入り楽曲を生成するオープンソースの音楽生成モデル。",
   "url": "https://github.com/ace-step/ACE-Step",
   "match": [
    "ace[\\s_.-]?step"
   ],
   "exes": [
    "acestep.exe",
    "start.bat",
    "run.bat",
    "acestep-gui.bat",
    "app.py"
   ],
   "howto": "起動バッチで Gradio 画面を開き、Tags (ジャンル等) と Lyrics を入力して Generate。",
   "launch_note": "起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。",
   "features": [
    "歌詞とタグ (ジャンル・楽器・声質) から、ボーカル入りの楽曲を生成するオープンソースモデル",
    "数分の曲を短時間で生成できる (GPU 推奨)",
    "Retake / Repaint (一部の作り直し)、Edit (歌詞の差し替え)、Extend (延長) に対応",
    "多言語の歌詞に対応 (日本語も可)",
    "LoRA による歌声・スタイルの追加学習が可能"
   ],
   "usage": [
    "初回のみ: README の手順で Python 環境とモデルを用意 (Pinokio からワンクリックで入れることも可)",
    "起動バッチ (または acestep コマンド) で Gradio 画面を起動",
    "ブラウザで表示された http://127.0.0.1:7865 などを開く",
    "Tags 欄にジャンル等 (例: j-pop, female vocal, piano, upbeat)、Lyrics 欄に [verse] [chorus] などの区切り付きで歌詞を入力",
    "Audio Duration (長さ) を決めて Generate",
    "結果を聴き、気になる部分は Repaint / Retake で作り直す"
   ]
  },
  {
   "id": "yue",
   "name": "YuE",
   "category": "AI作曲・音楽生成",
   "purpose": "歌詞から長尺のボーカル入り楽曲を生成するオープンソースモデル。",
   "url": "https://github.com/multimodal-art-projection/YuE",
   "match": [
    "^yue\\b",
    "yue[\\s_-]?(gp|ui|exllamav2)"
   ],
   "exes": [
    "run.bat",
    "start.bat"
   ],
   "howto": "ジャンル指定 (genre.txt) と歌詞 (lyrics.txt) を用意して推論スクリプト/Web UI から生成する。",
   "launch_note": "",
   "features": [
    "歌詞から最大数分の長尺のボーカル入り楽曲を生成するオープンソースモデル",
    "ジャンル・楽器・声質をタグで指定",
    "英語・中国語・日本語・韓国語などに対応",
    "参照音声のスタイルをまねる In-Context Learning が可能"
   ],
   "usage": [
    "Python 環境とモデルを用意 (GPU のメモリが多く必要)",
    "genre.txt にタグ、lyrics.txt に [verse] [chorus] 区切りの歌詞を書く",
    "推論スクリプト (または YuE 用の Web UI) を実行",
    "出力フォルダの音声を確認"
   ]
  },
  {
   "id": "riffusion",
   "name": "Riffusion",
   "category": "AI作曲・音楽生成",
   "purpose": "スペクトログラム画像生成を応用した AI 作曲ツール / Web サービス。",
   "url": "https://www.riffusion.com/",
   "match": [
    "riffusion"
   ],
   "exes": [],
   "howto": "Web 版はプロンプトを入力して生成。ローカル版は付属の起動手順に従ってサーバーを立ち上げる。",
   "launch_note": "",
   "features": [
    "プロンプトから曲を生成する AI 作曲サービス (初期版は画像生成 AI を応用したオープンソース)",
    "歌詞付きの曲生成、曲の続きや別バージョンの生成",
    "ジャンルやムードを組み合わせて作れる"
   ],
   "usage": [
    "Web 版: riffusion.com でプロンプトや歌詞を入力して生成",
    "ローカル版: README の手順でサーバーを起動し、ブラウザで開く"
   ]
  },
  {
   "id": "comfyui",
   "name": "ComfyUI",
   "category": "AI作曲・音楽生成",
   "purpose": "ノードをつなぐ方式の生成 AI 実行環境。Stable Audio / ACE-Step 等の音楽生成モデルも動かせる。",
   "url": "https://www.comfy.org/",
   "match": [
    "comfyui",
    "comfy[\\s_-]?ui"
   ],
   "exes": [
    "comfyui.exe",
    "run_nvidia_gpu.bat",
    "run_cpu.bat",
    "main.py"
   ],
   "howto": "run_nvidia_gpu.bat (GPU なしは run_cpu.bat) を実行 → ブラウザで http://127.0.0.1:8188 → 音楽用ワークフローを読み込んで Queue Prompt。",
   "launch_note": "起動後に http://127.0.0.1:8188 をブラウザで開きます (デスクトップ版はアプリが直接開きます)。",
   "features": [
    "処理の部品 (ノード) を線でつないで生成 AI を動かす実行環境",
    "画像だけでなく Stable Audio Open・ACE-Step などの音楽生成モデルも動かせる",
    "作った手順 (ワークフロー) を JSON / 画像として保存・共有できる",
    "Custom Nodes (拡張機能) で機能を追加できる (ComfyUI-Manager から導入)",
    "ポータブル版は Python 同梱で、フォルダごと持ち運べる"
   ],
   "usage": [
    "run_nvidia_gpu.bat (GPU なしは run_cpu.bat) をダブルクリック",
    "ブラウザで http://127.0.0.1:8188 が開く",
    "音楽用のワークフロー (.json) を画面にドラッグして読み込む",
    "モデルを models フォルダに置き、ノードで選択",
    "プロンプトを入力して Queue (実行)。結果は output フォルダに保存される"
   ]
  },
  {
   "id": "magenta",
   "name": "Magenta Studio",
   "category": "AI作曲・音楽生成",
   "purpose": "Google Magenta の AI による MIDI フレーズ生成・続き生成・ドラム生成ツール (単体版 / Ableton 用)。",
   "url": "https://magenta.tensorflow.org/studio",
   "match": [
    "magenta"
   ],
   "exes": [
    "magenta studio.exe",
    "continue.exe",
    "generate.exe"
   ],
   "howto": "Generate / Continue / Drumify などのツールを開き、MIDI ファイルを入力して生成 → 結果の MIDI を DAW に読み込む。",
   "launch_note": "",
   "features": [
    "Google Magenta の AI による MIDI 生成ツール集",
    "Generate: 何もないところからメロディ・ドラムを生成",
    "Continue: 入力した MIDI の続きを生成",
    "Interpolate: 2 つのフレーズの中間を作る",
    "Groove / Drumify: ドラムに人間らしいノリを付ける・リズムからドラムパターンを作る"
   ],
   "usage": [
    "使いたいツール (Generate / Continue など) を起動",
    "入力用の MIDI ファイルを選ぶ (Continue などの場合)",
    "Temperature (ランダムさ) や長さを設定して Generate",
    "出力フォルダの MIDI を DAW に読み込んで使う"
   ]
  },
  {
   "id": "aiva",
   "name": "AIVA",
   "category": "AI作曲・音楽生成",
   "purpose": "スタイルやコード進行を指定して BGM を AI 作曲するサービス (デスクトップ版あり)。",
   "url": "https://www.aiva.ai/",
   "match": [
    "\\baiva\\b"
   ],
   "exes": [
    "aiva.exe"
   ],
   "howto": "ログイン → Create track でスタイル・キー・長さを選んで生成 → MIDI / WAV で書き出し。",
   "launch_note": "",
   "features": [
    "スタイル (映画音楽・ポップ・アンビエントなど) を選ぶだけで AI が作曲",
    "キー・テンポ・長さ・楽器編成を指定可能",
    "生成後にピアノロールでメロディや和音を編集できる",
    "MIDI / WAV / MP3 で書き出し (プランにより著作権の扱いが異なる)"
   ],
   "usage": [
    "アプリまたは aiva.ai でログイン",
    "Create Track → From a Style でスタイルを選ぶ",
    "キー・長さ・曲数を設定して Create",
    "気に入った曲を開いて編集し、Download で書き出す"
   ]
  },
  {
   "id": "orbplugins",
   "name": "Orb Producer Suite",
   "category": "AI作曲・音楽生成",
   "purpose": "コード・メロディ・ベース・アルペジオを AI 生成する DAW 用プラグイン。",
   "url": "https://www.orbplugins.com/",
   "match": [
    "orb\\s?producer",
    "orb\\s?(chords|melody|bass|arpeggio)"
   ],
   "exes": [],
   "howto": "DAW のインストゥルメント/MIDI トラックに挿してスタイルを選び、生成された MIDI をドラッグ&ドロップ。",
   "launch_note": "",
   "features": [
    "DAW 上で AI がコード・メロディ・ベース・アルペジオのフレーズを生成するプラグイン",
    "キー・スケール・複雑さを指定して何度でも作り直せる",
    "生成した MIDI をドラッグ&ドロップで DAW のトラックへ"
   ],
   "usage": [
    "DAW の MIDI / インストゥルメントトラックに Orb を挿す",
    "キーとスタイルを選んで生成",
    "気に入ったフレーズを DAW のトラックへドラッグ"
   ]
  },
  {
   "id": "scaler",
   "name": "Scaler 2/3",
   "category": "AI作曲・音楽生成",
   "purpose": "コード進行の提案・生成を行う作曲支援プラグイン/スタンドアロン。",
   "url": "https://www.pluginboutique.com/product/2-Effects/58-Chord-Generator/14431-Scaler-3",
   "match": [
    "^scaler\\s?\\d?\\b"
   ],
   "exes": [
    "scaler 3.exe",
    "scaler 2.exe",
    "scaler.exe"
   ],
   "howto": "キーやジャンルを選ぶとコード候補が表示される → 並べて進行を作り MIDI として DAW へドラッグ。",
   "launch_note": "",
   "features": [
    "キーやジャンルから使えるコードを提案する作曲支援ツール",
    "有名曲・ジャンル別のコード進行プリセット",
    "ボイシング・リズムパターン・ベースラインの自動生成",
    "弾いた和音からキーを判定する機能"
   ],
   "usage": [
    "DAW のインストゥルメントトラックに挿す (単体起動も可)",
    "キーやコードセットを選んでコードを並べる",
    "パターン (演奏の仕方) を選んで試聴",
    "完成した進行を MIDI としてトラックへドラッグ"
   ]
  },
  {
   "id": "synthv",
   "name": "Synthesizer V Studio",
   "category": "AI歌声・音声合成",
   "purpose": "AI 歌声合成ソフト。MIDI と歌詞を入力するだけで人間らしい歌声を生成する。",
   "url": "https://dreamtonics.com/synthesizerv/",
   "match": [
    "synthesizer\\s?v",
    "synthv",
    "dreamtonics"
   ],
   "exes": [
    "synthv studio pro.exe",
    "synthv studio basic.exe",
    "synthesizer v studio pro.exe",
    "synthesizer v studio 2 pro.exe",
    "synthv studio.exe"
   ],
   "howto": "ボイスデータベースを選択 → ピアノロールにノートを描いて歌詞を入力 → 再生して確認 → WAV で書き出し。",
   "launch_note": "",
   "features": [
    "AI による人間に近い歌声合成 (日本語・英語・中国語など)",
    "ノート (音符) と歌詞を入力するだけで自然な抑揚を自動で付ける",
    "AI リテイクで歌い方の候補を何通りも出せる",
    "声質・ブレス・力み・ピッチなどを細かく調整できる",
    "DAW 用プラグイン (VSTi) としても使える"
   ],
   "usage": [
    "Synthesizer V Studio を起動し、使う歌声データベース (ボイス) を選ぶ",
    "ピアノロールにノートを描く (または MIDI を読み込む)",
    "ノートを選択して歌詞を流し込む",
    "再生して確認し、必要なら AI リテイクやパラメータで調整",
    "ファイル → レンダリングで WAV に書き出す"
   ]
  },
  {
   "id": "vocaloid",
   "name": "VOCALOID",
   "category": "AI歌声・音声合成",
   "purpose": "ヤマハの歌声合成ソフト。メロディと歌詞から歌声を作る。",
   "url": "https://www.vocaloid.com/",
   "match": [
    "vocaloid"
   ],
   "exes": [
    "vocaloid6.exe",
    "vocaloid5.exe",
    "vocaloid editor.exe"
   ],
   "howto": "Voice Bank を選んでトラックを作成 → ノートと歌詞を入力 → 表情パラメータを調整 → オーディオ書き出し。",
   "launch_note": "",
   "features": [
    "ヤマハの歌声合成ソフト。Voice Bank (歌声ライブラリ) を選んで歌わせる",
    "VOCALOID6 は AI 技術で自然な歌声、VOCALO CHANGER で自分の声から歌わせることも可能",
    "ビブラート・ダイナミクスなどの表情を細かく編集",
    "DAW 用プラグインとしても動作"
   ],
   "usage": [
    "VOCALOID エディターを起動し、トラックに Voice Bank を設定",
    "ノートと歌詞を入力 (MIDI 読み込みも可)",
    "表情パラメータを調整",
    "オーディオとして書き出す"
   ]
  },
  {
   "id": "piapro",
   "name": "Piapro Studio (初音ミク NT 等)",
   "category": "AI歌声・音声合成",
   "purpose": "クリプトン社の歌声合成エディタ (VSTi / スタンドアロン)。",
   "url": "https://ec.crypton.co.jp/",
   "match": [
    "piapro"
   ],
   "exes": [
    "piapro studio nt.exe",
    "piapro studio.exe"
   ],
   "howto": "DAW にプラグインとして挿す (または単体起動) → ノートと歌詞を入力して歌わせる。",
   "launch_note": "",
   "features": [
    "初音ミク NT などクリプトン社の歌声ライブラリ用エディタ",
    "VSTi / AU プラグインとして DAW 上で使うのが基本 (単体起動も可)",
    "歌い方のスタイル・表情パラメータを細かく調整"
   ],
   "usage": [
    "DAW にインストゥルメントとして Piapro Studio を挿す",
    "ノートと歌詞を入力",
    "DAW の再生に合わせて歌わせ、ミックスダウンで書き出す"
   ]
  },
  {
   "id": "cevio",
   "name": "CeVIO AI",
   "category": "AI歌声・音声合成",
   "purpose": "AI による歌声・トーク音声の合成ソフト。",
   "url": "https://cevio.jp/",
   "match": [
    "cevio"
   ],
   "exes": [
    "cevio ai.exe",
    "cevio creative studio.exe"
   ],
   "howto": "ソングトラックを追加 → 楽譜にノートと歌詞を入力 → 調声して書き出し。トークは文章を入力して再生。",
   "launch_note": "",
   "features": [
    "AI による歌声 (ソング) とトーク音声の合成ソフト",
    "楽譜入力から人間らしい歌い方を自動生成",
    "感情パラメータ (元気・普通・怒り など) でトークの表情を変更",
    "キャラクターごとにボイスを追加購入"
   ],
   "usage": [
    "CeVIO AI を起動し、ソングトラックを追加",
    "楽譜にノートと歌詞を入力 (MusicXML・MIDI の読み込みも可)",
    "調声して再生確認",
    "ファイル → 書き出しで WAV 保存"
   ]
  },
  {
   "id": "voisona",
   "name": "VoiSona",
   "category": "AI歌声・音声合成",
   "purpose": "AI 歌声合成ソフト (CeVIO 系技術、基本無料)。",
   "url": "https://voisona.com/",
   "match": [
    "voisona"
   ],
   "exes": [
    "voisona.exe"
   ],
   "howto": "ボイスライブラリを有効化 → ノートと歌詞を入力 → 再生・WAV 書き出し。",
   "launch_note": "",
   "features": [
    "AI 歌声合成ソフト (CeVIO 系の技術を使用、エディタは基本無料)",
    "MIDI 入力から自然な歌声を生成",
    "DAW 用プラグイン版あり"
   ],
   "usage": [
    "VoiSona を起動してボイスライブラリを有効化",
    "ノートと歌詞を入力",
    "再生して確認し、WAV に書き出す"
   ]
  },
  {
   "id": "neutrino",
   "name": "NEUTRINO",
   "category": "AI歌声・音声合成",
   "purpose": "MusicXML の楽譜から AI が歌声を合成する無料ソフト。",
   "url": "https://studio-neutrino.com/",
   "match": [
    "neutrino"
   ],
   "exes": [
    "neutrino.exe",
    "run.bat",
    "run_musicxml.bat"
   ],
   "howto": "楽譜ソフトで歌詞付き MusicXML を作成 → score\\musicxml に置く → Run.bat を編集して実行 → output に WAV が出力される。",
   "launch_note": "",
   "features": [
    "楽譜 (MusicXML) から AI が歌声を合成する無料ソフト",
    "複数の歌声モデルを切り替えて使える",
    "ピッチや音色の後から編集できるツールも同梱"
   ],
   "usage": [
    "楽譜ソフト (MuseScore など) で歌詞付きの楽譜を作り MusicXML で保存",
    "NEUTRINO フォルダの score\\musicxml に置く",
    "Run.bat の BASENAME などを編集して実行",
    "output フォルダに WAV が出力される"
   ]
  },
  {
   "id": "utau",
   "name": "UTAU / OpenUtau",
   "category": "AI歌声・音声合成",
   "purpose": "音声ライブラリを使って歌わせる歌声合成ソフト (OpenUtau は後継のオープンソース版)。",
   "url": "https://www.openutau.com/",
   "match": [
    "\\butau\\b",
    "openutau"
   ],
   "exes": [
    "openutau.exe",
    "utau.exe"
   ],
   "howto": "音源 (歌声ライブラリ) を導入 → ピアノロールにノートと歌詞を入力 → レンダリングして WAV 書き出し。",
   "launch_note": "",
   "features": [
    "音声ライブラリ (UTAU 音源) を使って歌わせる歌声合成ソフト",
    "OpenUtau は無料・オープンソースの後継エディタで、多言語・AI 系レンダラーにも対応",
    "大量の無料音源が公開されている"
   ],
   "usage": [
    "OpenUtau を起動し、歌声ライブラリをドラッグしてインストール",
    "トラックに歌手を設定し、ピアノロールでノートと歌詞を入力",
    "再生して確認し、ファイル → 書き出しで WAV 保存"
   ]
  },
  {
   "id": "acestudio",
   "name": "ACE Studio",
   "category": "AI歌声・音声合成",
   "purpose": "AI 歌声合成・AI 楽器演奏ソフト。MIDI から歌声やバイオリン等を生成する。",
   "url": "https://acestudio.ai/",
   "match": [
    "ace\\s?studio"
   ],
   "exes": [
    "ace studio.exe",
    "acestudio.exe"
   ],
   "howto": "ボイス (歌手) を選んでトラック作成 → MIDI を読み込むかノートを入力 → 歌詞を流し込み → 書き出し。",
   "launch_note": "",
   "features": [
    "AI 歌声合成と AI 楽器演奏 (バイオリン・サックスなど) を 1 つのソフトで",
    "MIDI を読み込んで歌詞を流し込むだけで歌わせられる",
    "声の混ぜ合わせ (ボイスミックス) や歌い方の調整",
    "DAW との同期プラグインあり"
   ],
   "usage": [
    "ACE Studio を起動してログイン",
    "トラックに歌手 (または楽器) を選ぶ",
    "MIDI を読み込むかノートを入力し、歌詞を入力",
    "再生して調整し、書き出す"
   ]
  },
  {
   "id": "voicevox",
   "name": "VOICEVOX",
   "category": "AI歌声・音声合成",
   "purpose": "無料の AI 音声合成 (読み上げ) ソフト。ソング機能で簡単な歌唱も可能。",
   "url": "https://voicevox.hiroshiba.jp/",
   "match": [
    "voicevox"
   ],
   "exes": [
    "voicevox.exe"
   ],
   "howto": "キャラクターを選んで文章を入力 → 再生 → 音声書き出し。ソングタブでは MIDI を読み込み歌わせられる。",
   "launch_note": "",
   "features": [
    "無料の AI 音声合成 (読み上げ) ソフト。多数のキャラクターボイス",
    "イントネーション (アクセント・高さ) を細かく編集",
    "ソング機能で MIDI を読み込んで歌わせることも可能",
    "ローカルで API サーバーとして動き、他のアプリから呼び出せる"
   ],
   "usage": [
    "VOICEVOX を起動し、キャラクターを選ぶ",
    "文章を入力して再生",
    "アクセントや速さを調整",
    "ファイル → 音声書き出し"
   ]
  },
  {
   "id": "aivoice",
   "name": "A.I.VOICE",
   "category": "AI歌声・音声合成",
   "purpose": "AI 音声合成 (トーク) ソフト。",
   "url": "https://aivoice.jp/",
   "match": [
    "a\\.?i\\.?voice"
   ],
   "exes": [
    "aivoiceeditor.exe",
    "a.i.voice editor.exe"
   ],
   "howto": "ボイスを選び文章を入力 → 抑揚や話速を調整 → 音声保存。",
   "launch_note": "",
   "features": [
    "AI 音声合成 (トーク) ソフト",
    "抑揚・話速・感情の調整",
    "辞書登録で読み方を修正"
   ],
   "usage": [
    "ボイスを選んで文章を入力",
    "再生して抑揚を調整",
    "音声ファイルとして保存"
   ]
  },
  {
   "id": "uvr",
   "name": "Ultimate Vocal Remover (UVR5)",
   "category": "AI音源分離・声質変換",
   "purpose": "AI で楽曲をボーカルと伴奏 (ドラム・ベース等) に分離する無料ソフト。",
   "url": "https://ultimatevocalremover.com/",
   "match": [
    "ultimate\\s?vocal\\s?remover",
    "^uvr\\d?\\b"
   ],
   "exes": [
    "ultimate vocal remover.exe",
    "uvr.exe",
    "uvr.py"
   ],
   "howto": "入力ファイルと出力先を選択 → 処理方法 (MDX-Net / Demucs 等) とモデルを選ぶ → Start Processing。",
   "launch_note": "",
   "features": [
    "AI で楽曲をボーカルと伴奏 (インスト) に分離する無料ソフト",
    "ドラム・ベース・その他など 4 パート以上への分離も可能 (Demucs モデル)",
    "MDX-Net / VR / Demucs など多数のモデルから選べる",
    "複数ファイルの一括処理"
   ],
   "usage": [
    "Ultimate Vocal Remover を起動",
    "Select Input で曲、Select Output で保存先を選ぶ",
    "CHOOSE PROCESS METHOD で方式、CHOOSE MODEL でモデルを選ぶ (初回はダウンロード)",
    "GPU Conversion をオン (NVIDIA GPU がある場合) にして Start Processing"
   ]
  },
  {
   "id": "demucs",
   "name": "Demucs",
   "category": "AI音源分離・声質変換",
   "purpose": "Meta のオープンソース音源分離 AI。ボーカル・ドラム・ベース・その他に分ける。",
   "url": "https://github.com/facebookresearch/demucs",
   "match": [
    "demucs"
   ],
   "exes": [
    "demucs.exe",
    "demucs-gui.exe",
    "run.bat"
   ],
   "howto": "コマンド `demucs 曲.mp3` (または GUI 版) で実行 → separated フォルダにパートごとの WAV が出力される。",
   "launch_note": "",
   "features": [
    "Meta のオープンソース音源分離 AI",
    "ボーカル・ドラム・ベース・その他の 4 パート (6 パートモデルもあり) に分離",
    "高品質なモデル (htdemucs_ft など) を選べる"
   ],
   "usage": [
    "コマンドプロンプトで demucs 曲.mp3 を実行 (GUI 版はファイルをドラッグ)",
    "--two-stems=vocals でボーカルと伴奏の 2 つに分離",
    "separated フォルダにパートごとの WAV が出力される"
   ]
  },
  {
   "id": "spleeter",
   "name": "Spleeter",
   "category": "AI音源分離・声質変換",
   "purpose": "Deezer のオープンソース音源分離ツール。",
   "url": "https://github.com/deezer/spleeter",
   "match": [
    "spleeter"
   ],
   "exes": [
    "spleeter.exe",
    "spleetergui.exe"
   ],
   "howto": "コマンド `spleeter separate -p spleeter:2stems -o 出力先 曲.mp3` で 2/4/5 パートに分離。",
   "launch_note": "",
   "features": [
    "Deezer のオープンソース音源分離ツール",
    "2 / 4 / 5 パートに分離 (ボーカル・ドラム・ベース・ピアノ・その他)",
    "処理が速い"
   ],
   "usage": [
    "spleeter separate -p spleeter:2stems -o 出力先 曲.mp3 を実行",
    "出力先にパートごとの WAV ができる"
   ]
  },
  {
   "id": "rvc",
   "name": "RVC (Retrieval-based Voice Conversion)",
   "category": "AI音源分離・声質変換",
   "purpose": "歌声・話し声を別の人の声質に変換する AI ボイスチェンジャー / 学習ツール。",
   "url": "https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI",
   "match": [
    "\\brvc\\b",
    "retrieval[\\s_-]?based",
    "rvc[\\s_-]?webui",
    "applio"
   ],
   "exes": [
    "go-web.bat",
    "go-web-dml.bat",
    "applio.exe",
    "run-applio.bat",
    "infer-web.py"
   ],
   "howto": "go-web.bat を実行 → ブラウザの WebUI で声モデル (.pth) を選択 → 変換したい音声を指定して Convert。",
   "launch_note": "起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。",
   "features": [
    "声を別の人の声質に変換する AI (歌声・話し声どちらも)",
    "10 分程度の音声から声モデル (.pth) を学習できる",
    "WebUI で学習・変換・モデルの合成を行う",
    "Applio などの派生版はより使いやすい画面"
   ],
   "usage": [
    "go-web.bat (Applio は run-applio.bat) をダブルクリック",
    "ブラウザで WebUI (http://127.0.0.1:7865 など) が開く",
    "推論タブで声モデル (.pth) と index ファイルを選択",
    "変換したい音声 (UVR でボーカルだけにしたもの推奨) を指定し、ピッチを調整して変換",
    "出力された音声を伴奏と合わせる"
   ]
  },
  {
   "id": "sovits",
   "name": "so-vits-svc",
   "category": "AI音源分離・声質変換",
   "purpose": "歌声を別の声質に変換する歌声変換 (SVC) AI。",
   "url": "https://github.com/svc-develop-team/so-vits-svc",
   "match": [
    "so[\\s_-]?vits",
    "sovits"
   ],
   "exes": [
    "webui.bat",
    "run.bat",
    "webui.py"
   ],
   "howto": "起動バッチで WebUI を開き、モデルと設定ファイルを読み込み → 変換する音声をアップロードして変換。",
   "launch_note": "",
   "features": [
    "歌声を別の声質に変換する歌声変換 (SVC) AI",
    "音程を保ったまま声質だけを変える",
    "学習用のスクリプトと WebUI を同梱"
   ],
   "usage": [
    "起動バッチで WebUI を開く",
    "モデル (.pth) と設定ファイル (config.json) を読み込む",
    "変換する歌声をアップロードして変換",
    "結果をダウンロード"
   ]
  },
  {
   "id": "wokada",
   "name": "VC Client (w-okada)",
   "category": "AI音源分離・声質変換",
   "purpose": "RVC モデルなどを使ってリアルタイムに声を変換するボイスチェンジャー。",
   "url": "https://github.com/w-okada/voice-changer",
   "match": [
    "mmvcserversio",
    "voice[\\s_-]?changer",
    "vcclient"
   ],
   "exes": [
    "start_http.bat",
    "mmvcserversio.exe",
    "vcclient.exe"
   ],
   "howto": "start_http.bat を実行 → ブラウザ画面でモデルを選び、入力マイク・出力デバイスを設定して start。",
   "launch_note": "",
   "features": [
    "RVC などのモデルでリアルタイムに声を変換するボイスチェンジャー",
    "配信・通話での使用を想定",
    "GPU で低遅延"
   ],
   "usage": [
    "start_http.bat を実行してブラウザ画面を開く",
    "モデルを選び、入力 (マイク) と出力 (スピーカー / 仮想デバイス) を設定",
    "start を押して話す"
   ]
  },
  {
   "id": "lalal",
   "name": "LALAL.AI",
   "category": "AI音源分離・声質変換",
   "purpose": "AI による音源分離 (ステム分割) サービス / デスクトップアプリ。",
   "url": "https://www.lalal.ai/",
   "match": [
    "lalal"
   ],
   "exes": [
    "lalal.ai.exe",
    "lalal.exe"
   ],
   "howto": "分離したいパート (Vocal, Drum 等) を選び、ファイルをドラッグ&ドロップ → 分離結果をダウンロード。",
   "launch_note": "",
   "features": [
    "AI による音源分離サービス (ボーカル・ドラム・ベース・ピアノ・ギターなど)",
    "ノイズや声の除去 (Voice Cleaner) にも対応",
    "デスクトップアプリ版あり"
   ],
   "usage": [
    "分離したいパートを選ぶ",
    "ファイルをドラッグ&ドロップ",
    "プレビューを確認して結果をダウンロード"
   ]
  },
  {
   "id": "flstudio",
   "name": "FL Studio",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "ループ・パターン中心の作曲がしやすい人気 DAW。ビートメイク・EDM 制作に強い。",
   "url": "https://www.image-line.com/fl-studio/",
   "match": [
    "fl\\s?studio(?!\\s?asio)"
   ],
   "exes": [
    "fl64.exe",
    "fl.exe",
    "fl studio.exe"
   ],
   "howto": "チャンネルラックで音色を選び、ステップ/ピアノロールでパターンを作る → プレイリストに並べて曲にする → File > Export で WAV/MP3 書き出し。",
   "launch_note": "",
   "features": [
    "パターンを作ってプレイリストに並べる方式の DAW",
    "ステップシーケンサーとピアノロールが使いやすく、ビートメイク・EDM に強い",
    "多数の内蔵シンセ・エフェクト、VST プラグイン対応",
    "一度買えば将来のバージョンも無料 (生涯アップデート)"
   ],
   "usage": [
    "FL Studio を起動し、チャンネルラックに音色を追加",
    "ステップシーケンサーでリズム、ピアノロールでメロディを作る",
    "プレイリストにパターンを並べて曲の構成を作る",
    "ミキサーで音量・エフェクトを調整",
    "File → Export → WAV / MP3 で書き出し"
   ]
  },
  {
   "id": "ableton",
   "name": "Ableton Live",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "ループを組み合わせる「セッションビュー」が特徴の DAW。ライブ演奏・電子音楽向け。",
   "url": "https://www.ableton.com/",
   "match": [
    "ableton"
   ],
   "exes": [
    "ableton live 12 suite.exe",
    "ableton live 12 standard.exe",
    "ableton live 12 intro.exe",
    "ableton live 12 lite.exe",
    "ableton live 11 suite.exe",
    "ableton live 11 standard.exe",
    "ableton live 11 lite.exe",
    "ableton live 11 intro.exe"
   ],
   "howto": "ブラウザから音源やループをトラックへドラッグ → クリップを録音/打ち込み → アレンジメントビューで曲にまとめ → ファイル > 書き出し。",
   "launch_note": "",
   "features": [
    "クリップを自由に組み合わせるセッションビューと、時間軸のアレンジメントビューを持つ DAW",
    "ライブ演奏・電子音楽制作向け",
    "オーディオのテンポ・ピッチを自在に変えるワープ機能",
    "Max for Live で機能を拡張 (Suite)"
   ],
   "usage": [
    "ブラウザから音源やループをトラックへドラッグ",
    "セッションビューでクリップを録音・打ち込みして組み合わせを試す",
    "アレンジメントビューで曲の流れにまとめる",
    "ファイル → オーディオ/ビデオを書き出し"
   ]
  },
  {
   "id": "cubase",
   "name": "Cubase",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "Steinberg の定番 DAW。打ち込み・録音・ミックスまで幅広く対応。",
   "url": "https://www.steinberg.net/ja/cubase/",
   "match": [
    "cubase"
   ],
   "exes": [
    "cubase14.exe",
    "cubase13.exe",
    "cubase12.exe",
    "cubase11.exe",
    "cubase10.5.exe",
    "cubase.exe"
   ],
   "howto": "プロジェクトを新規作成 → インストゥルメントトラックを追加して打ち込み/録音 → ミックス → ファイル > 書き出し > オーディオミックスダウン。",
   "launch_note": "",
   "features": [
    "Steinberg の定番 DAW。打ち込み・録音・ミックスまで対応",
    "高機能な MIDI 編集とスコア表示",
    "VariAudio でボーカルの音程補正",
    "付属音源 (HALion Sonic など) とエフェクトが豊富"
   ],
   "usage": [
    "新規プロジェクトを作成",
    "インストゥルメントトラックを追加して打ち込み、オーディオトラックで録音",
    "ミックスコンソールで調整",
    "ファイル → 書き出し → オーディオミックスダウン"
   ]
  },
  {
   "id": "studioone",
   "name": "Studio One",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "ドラッグ&ドロップ操作中心で使いやすい DAW (PreSonus / Fender)。",
   "url": "https://www.presonus.com/studioone",
   "match": [
    "studio\\s?one"
   ],
   "exes": [
    "studio one.exe"
   ],
   "howto": "新規ソング作成 → 右側ブラウザから音源をドラッグしてトラック作成 → 打ち込み/録音 → ソング > ミックスダウンをエクスポート。",
   "launch_note": "",
   "features": [
    "ドラッグ&ドロップ中心で直感的に使える DAW",
    "作曲・録音・ミックス・マスタリング (プロジェクトページ) まで 1 本で",
    "コードトラックでコードに沿った編集が可能"
   ],
   "usage": [
    "新規ソングを作成",
    "右のブラウザから音源をドラッグしてトラックを作成",
    "打ち込み・録音",
    "ソング → ミックスダウンをエクスポート"
   ]
  },
  {
   "id": "reaper",
   "name": "REAPER",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "軽量・高機能で低価格な DAW。カスタマイズ性が高い。",
   "url": "https://www.reaper.fm/",
   "match": [
    "\\breaper\\b"
   ],
   "exes": [
    "reaper.exe"
   ],
   "howto": "トラックを追加 (Ctrl+T) → FX から音源を挿して MIDI を打ち込む/録音 → File > Render で書き出し。",
   "launch_note": "",
   "features": [
    "軽量・高機能で低価格な DAW (試用期間が長い)",
    "動作が軽く、古い PC でも使いやすい",
    "スクリプトやテーマで自由にカスタマイズ",
    "VST / VST3 / CLAP に対応"
   ],
   "usage": [
    "Ctrl+T でトラックを追加",
    "FX ボタンから音源を挿して MIDI を打ち込む、または録音",
    "File → Render で書き出し"
   ]
  },
  {
   "id": "bitwig",
   "name": "Bitwig Studio",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "モジュレーション機能が強力な DAW。電子音楽・サウンドデザイン向け。",
   "url": "https://www.bitwig.com/",
   "match": [
    "bitwig"
   ],
   "exes": [
    "bitwig studio.exe"
   ],
   "howto": "トラックにデバイスをドラッグ → クリップを作って打ち込み → アレンジャーで並べる → File > Export Audio。",
   "launch_note": "",
   "features": [
    "モジュレーション機能が強力な DAW",
    "The Grid で自分だけのシンセ・エフェクトを組める",
    "クリップランチャーでライブ的な制作",
    "Linux にも対応"
   ],
   "usage": [
    "トラックにデバイス (音源) をドラッグ",
    "クリップを作って打ち込み",
    "アレンジャーに並べる",
    "File → Export Audio"
   ]
  },
  {
   "id": "cakewalk",
   "name": "Cakewalk / Sonar",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "BandLab 提供の DAW (Cakewalk by BandLab / Sonar)。",
   "url": "https://www.cakewalk.com/",
   "match": [
    "cakewalk",
    "\\bsonar\\b"
   ],
   "exes": [
    "cakewalk.exe",
    "sonar.exe"
   ],
   "howto": "新規プロジェクト → インストゥルメントトラックを挿入して打ち込み/録音 → ファイル > エクスポート > オーディオ。",
   "launch_note": "",
   "features": [
    "BandLab が提供する DAW (Cakewalk by BandLab / Sonar)",
    "打ち込み・録音・ミックスに対応",
    "ProChannel (コンソール風のエフェクト)"
   ],
   "usage": [
    "新規プロジェクトを作成",
    "インストゥルメントトラックを挿入して打ち込み/録音",
    "ファイル → エクスポート → オーディオ"
   ]
  },
  {
   "id": "lmms",
   "name": "LMMS",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "無料・オープンソースの作曲ソフト。シンセやビートメイク機能を内蔵。",
   "url": "https://lmms.io/",
   "match": [
    "\\blmms\\b"
   ],
   "exes": [
    "lmms.exe"
   ],
   "howto": "Song Editor にインストゥルメントを追加 → Piano Roll で打ち込み → Beat+Bassline でリズム → File > Export。",
   "launch_note": "",
   "features": [
    "無料・オープンソースの作曲ソフト",
    "内蔵シンセ・サンプラー・ドラムマシン",
    "VST プラグイン対応 (Windows)"
   ],
   "usage": [
    "Song Editor にインストゥルメントを追加",
    "Piano Roll で打ち込み",
    "Beat+Bassline Editor でリズムを作る",
    "File → Export で書き出し"
   ]
  },
  {
   "id": "protools",
   "name": "Pro Tools",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "Avid のプロ向け録音・ミックス DAW。スタジオ標準。",
   "url": "https://www.avid.com/pro-tools",
   "match": [
    "pro\\s?tools"
   ],
   "exes": [
    "protools.exe"
   ],
   "howto": "新規セッション作成 → トラック作成 → 録音/編集 → File > Bounce Mix で書き出し。",
   "launch_note": "",
   "features": [
    "Avid のプロ向け録音・ミックス DAW。レコーディングスタジオの標準",
    "高度なオーディオ編集と自動化",
    "AAX プラグイン形式"
   ],
   "usage": [
    "新規セッションを作成",
    "トラックを作成して録音・編集",
    "File → Bounce Mix で書き出し"
   ]
  },
  {
   "id": "reason",
   "name": "Reason",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "ラック型の仮想機材で音作りする DAW / プラグイン (Reason Studios)。",
   "url": "https://www.reasonstudios.com/",
   "match": [
    "^reason\\b",
    "reason\\s?(studios|\\d+|rack)"
   ],
   "exes": [
    "reason.exe",
    "reason 13.exe",
    "reason 12.exe"
   ],
   "howto": "ラックに音源やエフェクトを追加 → シーケンサーで打ち込み → File > Export Song as Audio File。",
   "launch_note": "",
   "features": [
    "ラック型の仮想機材 (シンセ・ドラムマシン・エフェクト) で音作りする DAW",
    "Reason Rack Plugin で他の DAW 上でもラックを使える"
   ],
   "usage": [
    "ラックに音源やエフェクトを追加",
    "シーケンサーで打ち込み",
    "File → Export Song as Audio File"
   ]
  },
  {
   "id": "mixcraft",
   "name": "Mixcraft",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "Acoustica の初心者向け DAW。ループ素材が豊富。",
   "url": "https://acoustica.com/mixcraft",
   "match": [
    "mixcraft"
   ],
   "exes": [
    "mixcraft10.exe",
    "mixcraft9.exe",
    "mixcraft.exe"
   ],
   "howto": "ループライブラリから素材をドラッグ → 打ち込み/録音 → ミックスダウン。",
   "launch_note": "",
   "features": [
    "Acoustica の初心者向け DAW",
    "ループ素材が豊富で、並べるだけで曲が作れる"
   ],
   "usage": [
    "ループライブラリから素材をトラックへドラッグ",
    "打ち込み・録音",
    "ミックスダウンして書き出し"
   ]
  },
  {
   "id": "musicmaker",
   "name": "MAGIX Music Maker",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "ループを並べるだけで曲を作れる初心者向け作曲ソフト。",
   "url": "https://www.magix.com/music-maker/",
   "match": [
    "music\\s?maker"
   ],
   "exes": [
    "musicmaker.exe",
    "music maker.exe"
   ],
   "howto": "サウンドプールからループをトラックへドラッグ → 並べて曲にする → ファイル > 書き出し。",
   "launch_note": "",
   "features": [
    "ループ素材を並べるだけで曲が作れる初心者向けソフト",
    "サウンドプールにジャンル別素材"
   ],
   "usage": [
    "サウンドプールからループをトラックへドラッグ",
    "並べて曲にする",
    "ファイル → 書き出し"
   ]
  },
  {
   "id": "soundit",
   "name": "Sound it!",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "インターネット社の国産 DAW / 波形編集ソフト。",
   "url": "https://www.ssw.co.jp/",
   "match": [
    "sound\\s?it!?"
   ],
   "exes": [
    "soundit.exe"
   ],
   "howto": "新規作成 → オーディオ/MIDI トラックを追加 → 録音・編集 → ミックスダウンして書き出し。",
   "launch_note": "",
   "features": [
    "インターネット社の国産 DAW / 波形編集ソフト",
    "日本語マニュアル・サポート"
   ],
   "usage": [
    "新規作成でトラックを追加",
    "録音・編集",
    "ミックスダウンして書き出し"
   ]
  },
  {
   "id": "abilitypro",
   "name": "ABILITY",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "インターネット社の国産 DAW。日本語環境で使いやすい。",
   "url": "https://www.ssw.co.jp/products/ability/",
   "match": [
    "^ability\\b"
   ],
   "exes": [
    "ability.exe"
   ],
   "howto": "新規ソング → トラック追加 → スコア/ピアノロールで打ち込み → ミックスダウン。",
   "launch_note": "",
   "features": [
    "インターネット社の国産 DAW",
    "スコア (楽譜) 表示で打ち込みやすい"
   ],
   "usage": [
    "新規ソングを作成",
    "トラックを追加してスコア/ピアノロールで打ち込み",
    "ミックスダウン"
   ]
  },
  {
   "id": "bandlab",
   "name": "BandLab",
   "category": "DAW (作曲・録音・編集)",
   "purpose": "無料のオンライン DAW / コラボレーション作曲サービス。",
   "url": "https://www.bandlab.com/",
   "match": [
    "bandlab(?!\\s?assistant)"
   ],
   "exes": [
    "bandlab.exe"
   ],
   "howto": "Create → Studio でトラックを追加 → 録音やループで曲を作る → 保存して公開または書き出し。",
   "launch_note": "",
   "features": [
    "無料のオンライン DAW とコラボレーションサービス",
    "ブラウザやスマホで作曲・録音",
    "他のユーザーと共同制作・公開"
   ],
   "usage": [
    "Create → Studio を開く",
    "トラックを追加して録音、またはループを配置",
    "保存して公開、または書き出し"
   ]
  },
  {
   "id": "musescore",
   "name": "MuseScore",
   "category": "楽譜作成・MIDI",
   "purpose": "無料の楽譜作成ソフト。入力した楽譜を再生・MIDI/MusicXML 書き出しできる。",
   "url": "https://musescore.org/",
   "match": [
    "musescore",
    "muse\\s?hub"
   ],
   "exes": [
    "musescore4.exe",
    "musescore3.exe",
    "musescore.exe",
    "musehub.exe"
   ],
   "howto": "新しいスコアで楽器と拍子を選ぶ → N キーで音符入力 → 再生で確認 → ファイル > エクスポート (PDF / MIDI / MusicXML / MP3)。",
   "launch_note": "",
   "features": [
    "無料の楽譜作成ソフト",
    "入力した楽譜を MuseSounds の高品質な音で再生",
    "PDF / MIDI / MusicXML / MP3 で書き出し (NEUTRINO 用の MusicXML 作成にも便利)",
    "MuseHub から音源をインストール"
   ],
   "usage": [
    "新しいスコアで楽器・拍子・調を選ぶ",
    "N キーで音符入力モード、数字キーで音価、A〜G で音名",
    "再生で確認",
    "ファイル → エクスポートで書き出し"
   ]
  },
  {
   "id": "domino",
   "name": "Domino",
   "category": "楽譜作成・MIDI",
   "purpose": "無料の国産 MIDI シーケンサ。ピアノロールで細かく打ち込める。",
   "url": "https://takabosoft.com/domino",
   "match": [
    "^domino\\b"
   ],
   "exes": [
    "domino.exe"
   ],
   "howto": "音源 (MIDI 出力) を設定 → ピアノロールで打ち込み → 保存 (SMF/MIDI 形式で DAW に持っていける)。",
   "launch_note": "",
   "features": [
    "無料の国産 MIDI シーケンサ",
    "ピアノロールで細かい打ち込みが可能",
    "音源定義ファイルで各種 MIDI 音源に対応"
   ],
   "usage": [
    "MIDI 出力 (音源) を設定",
    "ピアノロールで打ち込み",
    "SMF (MIDI) 形式で保存して DAW に持っていく"
   ]
  },
  {
   "id": "dorico",
   "name": "Dorico",
   "category": "楽譜作成・MIDI",
   "purpose": "Steinberg のプロ向け楽譜作成ソフト。",
   "url": "https://www.steinberg.net/ja/dorico/",
   "match": [
    "dorico"
   ],
   "exes": [
    "dorico5.exe",
    "dorico4.exe",
    "dorico.exe"
   ],
   "howto": "新規プロジェクトで楽器を追加 → 記譜モードで音符入力 → 再生モードで確認 → PDF/オーディオ書き出し。",
   "launch_note": "",
   "features": [
    "Steinberg のプロ向け楽譜作成ソフト",
    "美しい浄書を自動でレイアウト",
    "再生モードで DAW のような編集"
   ],
   "usage": [
    "新規プロジェクトで楽器を追加",
    "記譜モードで音符入力",
    "再生モードで確認",
    "PDF / オーディオに書き出し"
   ]
  },
  {
   "id": "sibelius",
   "name": "Sibelius",
   "category": "楽譜作成・MIDI",
   "purpose": "Avid の楽譜作成ソフト。",
   "url": "https://www.avid.com/sibelius",
   "match": [
    "sibelius"
   ],
   "exes": [
    "sibelius.exe"
   ],
   "howto": "新規スコアで編成を選ぶ → 音符入力 → 再生 → PDF / MIDI / オーディオで書き出し。",
   "launch_note": "",
   "features": [
    "Avid の楽譜作成ソフト",
    "ポップ〜オーケストラまで対応"
   ],
   "usage": [
    "新規スコアで編成を選ぶ",
    "音符を入力",
    "PDF / MIDI / オーディオで書き出し"
   ]
  },
  {
   "id": "finale",
   "name": "Finale",
   "category": "楽譜作成・MIDI",
   "purpose": "MakeMusic の楽譜作成ソフト (2024 年に開発終了)。",
   "url": "https://www.finalemusic.com/",
   "match": [
    "^finale\\b",
    "makemusic"
   ],
   "exes": [
    "finale.exe"
   ],
   "howto": "セットアップウィザードで編成を選ぶ → 高速入力/ステップ入力で音符入力 → 印刷・書き出し。",
   "launch_note": "",
   "features": [
    "MakeMusic の楽譜作成ソフト (2024 年に開発・販売終了)",
    "既存の楽譜データは Dorico などへ移行が推奨"
   ],
   "usage": [
    "セットアップウィザードで編成を選ぶ",
    "音符を入力",
    "印刷・MusicXML で書き出し (他ソフトへの移行用)"
   ]
  },
  {
   "id": "guitarpro",
   "name": "Guitar Pro",
   "category": "楽譜作成・MIDI",
   "purpose": "ギター TAB 譜・楽譜の作成と再生ソフト。",
   "url": "https://www.guitar-pro.com/",
   "match": [
    "guitar\\s?pro"
   ],
   "exes": [
    "guitarpro.exe",
    "guitarpro8.exe",
    "guitarpro7.exe"
   ],
   "howto": "トラックに楽器を選ぶ → TAB 譜または五線譜で入力 → 再生で確認 → MIDI / オーディオ書き出し。",
   "launch_note": "",
   "features": [
    "ギター TAB 譜・五線譜の作成と再生",
    "練習用のテンポ変更・ループ再生",
    "多数のギター / ベース / ドラム音色"
   ],
   "usage": [
    "トラックに楽器を選ぶ",
    "TAB 譜または五線譜で入力",
    "再生して練習・MIDI やオーディオで書き出し"
   ]
  },
  {
   "id": "melodyne",
   "name": "Melodyne",
   "category": "波形編集・録音・変換",
   "purpose": "録音した歌や楽器の音程・タイミングを 1 音ずつ修正できるピッチ編集ソフト。",
   "url": "https://www.celemony.com/",
   "match": [
    "melodyne",
    "celemony"
   ],
   "exes": [
    "melodyne.exe",
    "melodyne 5.exe"
   ],
   "howto": "DAW のトラックに ARA プラグインとして挿す (または単体でファイルを開く) → 音の塊 (blob) をドラッグして音程・長さを修正。",
   "launch_note": "",
   "features": [
    "録音した歌や楽器の音程・タイミング・長さを 1 音ずつ修正",
    "和音の中の 1 音だけを修正 (DNA 技術、上位版)",
    "ARA 対応の DAW ではトラック上で直接編集"
   ],
   "usage": [
    "DAW のトラックに ARA プラグインとして挿す (または単体で音声ファイルを開く)",
    "音の塊 (blob) を上下に動かして音程、左右でタイミングを修正",
    "修正後の音を DAW 側で書き出す"
   ]
  },
  {
   "id": "audacity",
   "name": "Audacity",
   "category": "波形編集・録音・変換",
   "purpose": "無料の録音・波形編集ソフト。カット・ノイズ除去・形式変換などに便利。",
   "url": "https://www.audacityteam.org/",
   "match": [
    "audacity"
   ],
   "exes": [
    "audacity.exe"
   ],
   "howto": "ファイルを開くか録音 → 範囲を選択してカット/エフェクト (ノイズ除去等) → ファイル > 書き出し で MP3/WAV に保存。",
   "launch_note": "",
   "features": [
    "無料の録音・波形編集ソフト",
    "カット・コピー・フェード・音量調整",
    "ノイズ除去・ノーマライズ・テンポ変更",
    "MP3 / WAV / FLAC などに変換して保存"
   ],
   "usage": [
    "ファイルを開くか、録音ボタンで録音",
    "範囲を選んで編集やエフェクトを適用",
    "ファイル → 書き出し で保存"
   ]
  },
  {
   "id": "ocenaudio",
   "name": "ocenaudio",
   "category": "波形編集・録音・変換",
   "purpose": "軽量で使いやすい無料の波形編集ソフト。",
   "url": "https://www.ocenaudio.com/",
   "match": [
    "ocenaudio"
   ],
   "exes": [
    "ocenaudio.exe"
   ],
   "howto": "ファイルを開く → 範囲選択して編集/エフェクト → 名前を付けて保存。",
   "launch_note": "",
   "features": [
    "軽量で使いやすい無料の波形編集ソフト",
    "エフェクトのリアルタイムプレビュー"
   ],
   "usage": [
    "ファイルを開く",
    "範囲を選んで編集・エフェクト",
    "名前を付けて保存"
   ]
  },
  {
   "id": "wavelab",
   "name": "WaveLab",
   "category": "波形編集・録音・変換",
   "purpose": "Steinberg のマスタリング・波形編集ソフト。",
   "url": "https://www.steinberg.net/ja/wavelab/",
   "match": [
    "wavelab"
   ],
   "exes": [
    "wavelab pro 12.exe",
    "wavelab elements 12.exe",
    "wavelab pro 11.exe",
    "wavelab.exe"
   ],
   "howto": "オーディオファイルを開く → マスターセクションでエフェクト → レンダリングして書き出し。",
   "launch_note": "",
   "features": [
    "Steinberg のマスタリング・波形編集ソフト",
    "アルバム (モンタージュ) 作成とラウドネス管理"
   ],
   "usage": [
    "オーディオファイルを開く",
    "マスターセクションでエフェクト",
    "レンダリングして書き出し"
   ]
  },
  {
   "id": "soundforge",
   "name": "SOUND FORGE",
   "category": "波形編集・録音・変換",
   "purpose": "MAGIX の波形編集・マスタリングソフト。",
   "url": "https://www.magix.com/sound-forge/",
   "match": [
    "sound\\s?forge"
   ],
   "exes": [
    "soundforge.exe",
    "sound forge pro.exe"
   ],
   "howto": "ファイルを開いて編集 → エフェクト/マスタリング → 名前を付けて保存。",
   "launch_note": "",
   "features": [
    "MAGIX の波形編集・マスタリングソフト"
   ],
   "usage": [
    "ファイルを開いて編集",
    "エフェクト・マスタリング",
    "名前を付けて保存"
   ]
  },
  {
   "id": "rx",
   "name": "iZotope RX",
   "category": "波形編集・録音・変換",
   "purpose": "ノイズ・クリック・リップノイズ除去などの音声修復ソフト。",
   "url": "https://www.izotope.com/en/products/rx.html",
   "match": [
    "izotope\\s?rx",
    "^rx\\s?\\d+"
   ],
   "exes": [
    "izotope rx 11 audio editor.exe",
    "izotope rx 10 audio editor.exe",
    "izotope rx audio editor.exe"
   ],
   "howto": "ファイルを開く → スペクトログラムで問題箇所を選択 → De-noise 等のモジュールを適用 → 書き出し。",
   "launch_note": "",
   "features": [
    "ノイズ・クリック・リップノイズ・ハム音などの除去",
    "スペクトログラム表示で目に見える形で修復",
    "セリフと背景音の分離 (Dialogue Isolate)、Music Rebalance (パート音量の調整)"
   ],
   "usage": [
    "ファイルを開く",
    "スペクトログラムで問題の箇所を選択",
    "De-noise などのモジュールを適用",
    "書き出し"
   ]
  },
  {
   "id": "audiotools",
   "name": "fre:ac / foobar2000 (変換)",
   "category": "波形編集・録音・変換",
   "purpose": "音声ファイルの形式変換・タグ編集に使える無料ツール。",
   "url": "https://www.freac.org/",
   "match": [
    "fre[:\\s]?ac",
    "foobar2000"
   ],
   "exes": [
    "freac.exe",
    "foobar2000.exe"
   ],
   "howto": "ファイルを追加 → 出力形式 (MP3/FLAC 等) を選んで変換開始。",
   "launch_note": "",
   "features": [
    "音声ファイルの形式変換・タグ編集",
    "複数ファイルの一括変換"
   ],
   "usage": [
    "ファイルを追加",
    "出力形式 (MP3 / FLAC など) を選ぶ",
    "変換開始"
   ]
  },
  {
   "id": "nativeaccess",
   "name": "Native Access / Kontakt (Native Instruments)",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "Native Instruments 製品 (Kontakt, Komplete 等) のインストール・アクティベーション管理と、サンプラー音源。",
   "url": "https://www.native-instruments.com/",
   "match": [
    "native\\s?access",
    "native\\s?instruments",
    "kontakt",
    "komplete",
    "maschine",
    "massive"
   ],
   "exes": [
    "native access.exe",
    "kontakt 8.exe",
    "kontakt 7.exe",
    "kontakt.exe",
    "komplete kontrol.exe"
   ],
   "howto": "Native Access でログインして製品をインストール/更新 → DAW から Kontakt 等をプラグインとして読み込む。",
   "launch_note": "",
   "features": [
    "Native Instruments 製品 (Kontakt・Komplete・Massive など) のインストール・更新・認証",
    "Kontakt は多数のメーカー音源を読み込むサンプラー"
   ],
   "usage": [
    "Native Access を起動してログイン",
    "製品をインストール / 更新",
    "DAW で Kontakt などをプラグインとして読み込む"
   ]
  },
  {
   "id": "arturia",
   "name": "Arturia Software Center / V Collection",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "Arturia のシンセ音源 (Analog Lab, Pigments 等) と、その管理ツール。",
   "url": "https://www.arturia.com/",
   "match": [
    "arturia",
    "analog\\s?lab",
    "pigments"
   ],
   "exes": [
    "arturia software center.exe",
    "analog lab v.exe",
    "pigments.exe"
   ],
   "howto": "Software Center でログインして製品をインストール → DAW でプラグインとして使う (単体起動も可)。",
   "launch_note": "",
   "features": [
    "Arturia の名機再現シンセ (V Collection・Analog Lab・Pigments) と管理ツール"
   ],
   "usage": [
    "Software Center でログインしてインストール",
    "DAW でプラグインとして使う (単体起動も可)"
   ]
  },
  {
   "id": "spitfire",
   "name": "Spitfire Audio",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "オーケストラ・映画音楽向け音源 (BBC Symphony Orchestra, LABS 等) と管理アプリ。",
   "url": "https://www.spitfireaudio.com/",
   "match": [
    "spitfire"
   ],
   "exes": [
    "spitfire audio.exe"
   ],
   "howto": "Spitfire Audio アプリで音源をダウンロード → DAW でプラグインとして読み込む。LABS は無料。",
   "launch_note": "",
   "features": [
    "映画音楽・オーケストラ向けの高品質音源",
    "無料の LABS シリーズあり"
   ],
   "usage": [
    "Spitfire Audio アプリでログインして音源をダウンロード",
    "DAW でプラグインとして読み込む"
   ]
  },
  {
   "id": "splice",
   "name": "Splice",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "サンプル素材 (ループ・ワンショット) のサブスク配信とプラグイン管理アプリ。",
   "url": "https://splice.com/",
   "match": [
    "\\bsplice\\b"
   ],
   "exes": [
    "splice.exe"
   ],
   "howto": "Web/アプリでサンプルを検索して取得 → Splice フォルダの素材を DAW にドラッグ。",
   "launch_note": "",
   "features": [
    "サンプル素材 (ループ・ワンショット) のサブスク配信",
    "Create 機能で素材の組み合わせを提案"
   ],
   "usage": [
    "アプリでサンプルを検索してダウンロード",
    "Splice フォルダの素材を DAW にドラッグ"
   ]
  },
  {
   "id": "serum",
   "name": "Serum (Xfer Records)",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "EDM で定番のウェーブテーブルシンセ プラグイン。",
   "url": "https://xferrecords.com/products/serum-2",
   "match": [
    "\\bserum\\b",
    "xfer"
   ],
   "exes": [],
   "howto": "DAW のインストゥルメントトラックにプラグインとして挿す → プリセットを選んで演奏/打ち込み。",
   "launch_note": "",
   "features": [
    "EDM で定番のウェーブテーブルシンセ",
    "波形を目で見ながら音作りできる"
   ],
   "usage": [
    "DAW のインストゥルメントトラックに挿す",
    "プリセットを選んで演奏・打ち込み"
   ]
  },
  {
   "id": "vital",
   "name": "Vital",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "無料から使えるウェーブテーブルシンセ プラグイン。",
   "url": "https://vital.audio/",
   "match": [
    "^vital\\b(?!source)"
   ],
   "exes": [
    "vital.exe"
   ],
   "howto": "DAW にプラグインとして挿す → プリセットを選ぶ / 波形を描いて音作り。",
   "launch_note": "",
   "features": [
    "無料から使えるウェーブテーブルシンセ",
    "テキストや音声から波形を作る機能"
   ],
   "usage": [
    "DAW にプラグインとして挿す",
    "プリセットを選ぶ / 波形を編集して音作り"
   ]
  },
  {
   "id": "izotope",
   "name": "iZotope Product Portal / Ozone / Neutron",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "AI アシスタント付きのマスタリング (Ozone)・ミックス (Neutron) プラグインと管理ツール。",
   "url": "https://www.izotope.com/",
   "match": [
    "izotope",
    "\\bozone\\b",
    "neutron",
    "native\\s?instruments\\s?product\\s?portal"
   ],
   "exes": [
    "izotope product portal.exe",
    "izotope ozone 11.exe",
    "izotope ozone 10.exe"
   ],
   "howto": "マスタートラックに Ozone を挿す → Master Assistant で自動調整 → 好みで微調整。",
   "launch_note": "",
   "features": [
    "Ozone: AI アシスタントによる自動マスタリング",
    "Neutron: AI アシスタントによるミックス支援",
    "Product Portal で製品の管理"
   ],
   "usage": [
    "マスタートラックに Ozone を挿す",
    "Master Assistant を実行して自動調整",
    "好みで微調整して書き出し"
   ]
  },
  {
   "id": "waves",
   "name": "Waves Central",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "Waves プラグインのインストール・ライセンス管理ツール。",
   "url": "https://www.waves.com/",
   "match": [
    "waves\\s?central",
    "^waves\\b"
   ],
   "exes": [
    "waves central.exe"
   ],
   "howto": "Waves Central でログイン → 製品をインストール/ライセンスを有効化 → DAW でプラグインを使う。",
   "launch_note": "",
   "features": [
    "Waves プラグインのインストール・ライセンス管理"
   ],
   "usage": [
    "Waves Central でログイン",
    "製品をインストールしてライセンスを有効化",
    "DAW でプラグインを使う"
   ]
  },
  {
   "id": "autotune",
   "name": "Antares Auto-Tune",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "ボーカルの音程補正・ケロケロボイス効果の定番プラグイン。",
   "url": "https://www.antarestech.com/",
   "match": [
    "auto[\\s-]?tune",
    "antares"
   ],
   "exes": [
    "antares central.exe"
   ],
   "howto": "ボーカルトラックにプラグインとして挿す → Key と Scale を曲に合わせ、Retune Speed で補正の強さを調整。",
   "launch_note": "",
   "features": [
    "ボーカルの音程を自動で補正",
    "Retune Speed を速くするとケロケロボイス効果"
   ],
   "usage": [
    "ボーカルトラックに挿す",
    "曲の Key と Scale を設定",
    "Retune Speed で補正の強さを調整"
   ]
  },
  {
   "id": "steinbergtools",
   "name": "Steinberg Download Assistant / Activation Manager",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "Cubase など Steinberg 製品のダウンロードとライセンス管理ツール。",
   "url": "https://www.steinberg.net/",
   "match": [
    "steinberg\\s?(download|activation|library)",
    "elicenser"
   ],
   "exes": [
    "steinberg download assistant.exe",
    "steinberg activation manager.exe"
   ],
   "howto": "アプリを起動して Steinberg ID でログイン → 製品・音源をダウンロード / ライセンスを有効化。",
   "launch_note": "",
   "features": [
    "Steinberg 製品のダウンロード・ライセンス管理"
   ],
   "usage": [
    "アプリを起動して Steinberg ID でログイン",
    "製品・音源をダウンロード / ライセンスを有効化"
   ]
  },
  {
   "id": "ilok",
   "name": "iLok License Manager",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "多くのプラグイン (Pro Tools, UAD, Softube 等) のライセンス管理ツール。",
   "url": "https://www.ilok.com/",
   "match": [
    "\\bilok\\b",
    "pace\\s?license"
   ],
   "exes": [
    "license support.exe",
    "ilok license manager.exe"
   ],
   "howto": "iLok アカウントでサインイン → 購入したライセンスをこの PC (または iLok USB) に割り当てる。",
   "launch_note": "",
   "features": [
    "多くのプラグインで使われるライセンス管理"
   ],
   "usage": [
    "iLok アカウントでサインイン",
    "ライセンスを PC または iLok USB に割り当てる"
   ]
  },
  {
   "id": "plugin_alliance",
   "name": "Plugin Alliance / Plugin Boutique / UAD",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "プラグイン販売サイトの製品管理アプリ (Installation Manager / UA Connect 等)。",
   "url": "https://www.plugin-alliance.com/",
   "match": [
    "plugin\\s?alliance",
    "plugin\\s?boutique",
    "ua\\s?connect",
    "universal\\s?audio"
   ],
   "exes": [
    "installation manager.exe",
    "ua connect.exe"
   ],
   "howto": "管理アプリでログイン → 購入済みプラグインをインストール → DAW を起動してプラグインを再スキャン。",
   "launch_note": "",
   "features": [
    "プラグイン販売サイトの製品管理アプリ"
   ],
   "usage": [
    "ログインして購入済みプラグインをインストール",
    "DAW でプラグインを再スキャン"
   ]
  },
  {
   "id": "ezdrummer",
   "name": "Toontrack EZdrummer / Superior Drummer",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "生ドラム音源と MIDI グルーブを提供するドラム音源。",
   "url": "https://www.toontrack.com/",
   "match": [
    "toontrack",
    "ez\\s?(drummer|keys|bass)",
    "superior\\s?drummer"
   ],
   "exes": [
    "ezdrummer 3.exe",
    "superior drummer 3.exe",
    "toontrack product manager.exe"
   ],
   "howto": "DAW にプラグインとして挿す → Grooves から好みのリズムパターンを曲にドラッグ。",
   "launch_note": "",
   "features": [
    "生ドラムの音源と、ジャンル別のドラムパターン (グルーブ) 集",
    "曲に合うパターンの提案機能"
   ],
   "usage": [
    "DAW にプラグインとして挿す",
    "Grooves から好みのパターンを選んで曲へドラッグ"
   ]
  },
  {
   "id": "asio4all",
   "name": "ASIO4ALL",
   "category": "オーディオ設定・ドライバ",
   "purpose": "専用ドライバのないオーディオ機器でも DAW を低遅延で使えるようにする汎用 ASIO ドライバ。",
   "url": "https://asio4all.org/",
   "match": [
    "asio4all"
   ],
   "exes": [],
   "howto": "DAW のオーディオ設定でドライバに ASIO4ALL を選択 → 使う入出力デバイスを有効化し、バッファサイズを調整。",
   "launch_note": "単体では起動しません。DAW のオーディオ設定から選択して使います。",
   "features": [
    "専用ドライバのない機器 (内蔵サウンドなど) でも DAW を低遅延で使える汎用 ASIO ドライバ"
   ],
   "usage": [
    "DAW のオーディオ設定でドライバに ASIO4ALL を選ぶ",
    "使う入出力デバイスを有効化",
    "バッファサイズで遅延と安定性を調整"
   ]
  },
  {
   "id": "flasio",
   "name": "FL Studio ASIO",
   "category": "オーディオ設定・ドライバ",
   "purpose": "FL Studio に付属する汎用 ASIO ドライバ (他の DAW でも使用可)。",
   "url": "https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/envsettings_audio.htm",
   "match": [
    "fl\\s?studio\\s?asio"
   ],
   "exes": [],
   "howto": "DAW のオーディオ設定でデバイスに「FL Studio ASIO」を選ぶ。",
   "launch_note": "単体では起動しません。DAW のオーディオ設定から選択して使います。",
   "features": [
    "FL Studio 付属の汎用 ASIO ドライバ (他の DAW でも使える)"
   ],
   "usage": [
    "DAW のオーディオ設定で FL Studio ASIO を選ぶ"
   ]
  },
  {
   "id": "voicemeeter",
   "name": "VoiceMeeter",
   "category": "オーディオ設定・ドライバ",
   "purpose": "PC 内の音声を自由にミックス・ルーティングできる仮想ミキサー。配信・録音で便利。",
   "url": "https://vb-audio.com/Voicemeeter/",
   "match": [
    "voicemeeter",
    "vb-?audio",
    "vb-?cable"
   ],
   "exes": [
    "voicemeeter8x64.exe",
    "voicemeeterpro_x64.exe",
    "voicemeeter_x64.exe",
    "voicemeeter.exe"
   ],
   "howto": "起動して HARDWARE INPUT にマイク、A1 に出力デバイスを割り当て → 各アプリの出力を VoiceMeeter に向ける。",
   "launch_note": "",
   "features": [
    "PC 内の音を自由にミックス・振り分けできる仮想ミキサー",
    "配信・録音・通話で、マイクと PC の音をまとめるのに便利"
   ],
   "usage": [
    "VoiceMeeter を起動",
    "HARDWARE INPUT にマイク、A1 に出力デバイスを割り当て",
    "各アプリの出力先を VoiceMeeter Input にする"
   ]
  },
  {
   "id": "audiointerface",
   "name": "オーディオインターフェース設定ツール",
   "category": "オーディオ設定・ドライバ",
   "purpose": "Steinberg / Yamaha / Focusrite / Roland / Behringer 等のオーディオインターフェース用ドライバと設定アプリ。",
   "url": "https://focusrite.com/downloads",
   "match": [
    "yamaha\\s?steinberg\\s?usb",
    "focusrite",
    "scarlett",
    "roland\\s?(rubix|quad|duo|octa)",
    "behringer",
    "motu",
    "presonus\\s?universal",
    "audient",
    "zoom\\s?(uac|livetrak|l-)"
   ],
   "exes": [
    "focusrite control 2.exe",
    "focusrite control.exe",
    "dspmixfx_ur-c.exe"
   ],
   "howto": "機器を USB 接続 → 設定アプリで入出力・サンプルレートを確認 → DAW のオーディオ設定でその機器の ASIO ドライバを選ぶ。",
   "launch_note": "",
   "features": [
    "オーディオインターフェースのドライバと設定アプリ",
    "入出力の切り替え・サンプルレート・ループバック設定"
   ],
   "usage": [
    "機器を USB で接続",
    "設定アプリで入出力とサンプルレートを確認",
    "DAW のオーディオ設定でその機器の ASIO ドライバを選ぶ"
   ]
  },
  {
   "id": "taip",
   "name": "TAIP (Baby Audio)",
   "category": "音源・プラグイン・管理ツール",
   "purpose": "AI でアナログテープの質感 (サチュレーション) を再現するテープ系エフェクト プラグイン。",
   "url": "https://babyaud.io/taip-plugin",
   "match": [
    "\\btaip\\b",
    "baby\\s?audio"
   ],
   "howto": "DAW のトラックやマスターにエフェクトとして挿す → Drive で歪み具合、Character でテープらしさを調整。",
   "exes": [],
   "launch_note": "",
   "features": [
    "AI でアナログテープの質感 (温かみ・歪み) を再現するエフェクト",
    "ドラム・ボーカル・マスターなどに使える"
   ],
   "usage": [
    "DAW のトラックやマスターにエフェクトとして挿す",
    "Drive で歪み具合、Character でテープらしさを調整"
   ]
  },
  {
   "id": "pinokio",
   "name": "Pinokio",
   "category": "AI作曲・音楽生成",
   "purpose": "AI アプリ (ACE-Step・RVC・音声合成など) をワンクリックでインストール・起動できるランチャー。",
   "url": "https://github.com/pinokiocomputer/pinokio",
   "match": [
    "^pinokio\\b"
   ],
   "exes": [
    "pinokio.exe"
   ],
   "howto": "Pinokio を起動 → Discover からアプリを探して Install → 一覧から Start を押すと、そのアプリの画面が開く。",
   "launch_note": "個々の AI アプリは Pinokio の画面から起動します。",
   "features": [
    "AI アプリをワンクリックでインストール・起動できるランチャー",
    "Python・Git などの必要なものを自動で準備",
    "各アプリは pinokio\\api フォルダに保存される",
    "ACE-Step・RVC・音声合成など音楽系 AI も多数登録"
   ],
   "usage": [
    "Pinokio を起動",
    "Discover からアプリを探して Install",
    "インストール後、一覧から Start を押すとアプリの画面が開く",
    "使い終わったら Stop で停止"
   ]
  },
  {
   "id": "stabilitymatrix",
   "name": "Stability Matrix",
   "category": "AI作曲・音楽生成",
   "purpose": "ComfyUI などの生成 AI ツールをまとめてインストール・管理・起動できるランチャー。",
   "url": "https://github.com/LykosAI/StabilityMatrix",
   "match": [
    "stability\\s?matrix"
   ],
   "exes": [
    "stabilitymatrix.exe"
   ],
   "howto": "StabilityMatrix.exe を起動 → Packages からツールを追加 → Launch で起動。モデルは共有フォルダで一括管理される。",
   "launch_note": "",
   "features": [
    "ComfyUI などの生成 AI ツールをまとめてインストール・管理・起動",
    "モデルを共有フォルダで一括管理"
   ],
   "usage": [
    "StabilityMatrix.exe を起動",
    "Packages からツールを追加",
    "Launch で起動"
   ]
  }
 ],
 "generic": [
  "\\bvst[i3]?\\b",
  "\\bclap\\b",
  "\\baax\\b",
  "\\bdaw\\b",
  "synth",
  "sampler",
  "\\bmidi\\b",
  "vocal",
  "music",
  "\\bbeat",
  "drum",
  "\\bpiano\\b",
  "orchestra",
  "音楽",
  "音源",
  "作曲",
  "歌声",
  "楽譜",
  "\\bsong\\b",
  "\\bmixer\\b",
  "mastering",
  "reverb",
  "\\bcompressor\\b",
  "\\beq\\b"
 ],
 "genericExclude": [
  "realtek",
  "nvidia",
  "\\bamd\\b",
  "intel",
  "microsoft",
  "windows",
  "high definition audio",
  "\\bhd audio\\b",
  "conexant",
  "dolby",
  "dts",
  "itunes",
  "apple",
  "spotify",
  "amazon music",
  "youtube",
  "steam",
  "epic games",
  "xbox",
  "discord"
 ],
 "folderKeywords": {
  "lyric|歌詞": "歌詞関連のツール (フォルダ名からの推定)",
  "chord|コード進行": "コード解析・作曲支援のツール (フォルダ名からの推定)",
  "\\btape(?!str)|テープ": "テープ・録音関連のツール (フォルダ名からの推定)",
  "melod|メロディ": "メロディ生成・解析のツール (フォルダ名からの推定)",
  "vocal|voice|singing|\\bsing\\b|svc|tts|ボーカル|歌声|音声": "歌声・音声関連のツール (フォルダ名からの推定)",
  "\\bstems?\\b|separat|分離": "音源分離のツール (フォルダ名からの推定)",
  "music|song|beat|midi|audio|sound|karaoke|作曲|音楽|カラオケ": "音楽関連のツール (フォルダ名からの推定)"
 },
 "webServices": [
  {
   "id": "suno",
   "name": "Suno",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "suno.com",
    "suno.ai"
   ],
   "overview": "歌詞とスタイルの指示から、ボーカル入りの楽曲を丸ごと生成する AI 作曲サービス。",
   "features": [
    "歌詞を自分で書く Custom モードと、テーマだけ入力する簡単モード",
    "ジャンル・雰囲気・声質 (例: J-POP, female vocal) をスタイル欄で指定",
    "Extend で曲の続きを生成、Cover / Remix / ステム分割",
    "MP3 / WAV でダウンロード (無料プランは商用利用不可)"
   ],
   "usage": [
    "suno.com にログイン",
    "Create → Custom をオンにして歌詞とスタイルを入力",
    "Create で 2 曲生成",
    "Extend で伸ばして Get Whole Song で 1 曲にまとめる",
    "… メニューからダウンロード"
   ]
  },
  {
   "id": "udio",
   "name": "Udio",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "udio.com"
   ],
   "overview": "テキストの指示から歌入りの楽曲を生成し、少しずつ伸ばして 1 曲にする AI 作曲サービス。",
   "features": [
    "32 秒〜の断片を生成し、前後に Extend",
    "Inpaint で一部だけ作り直し",
    "歌詞の自動生成または自作歌詞",
    "Remix で既存曲の雰囲気を変える"
   ],
   "usage": [
    "udio.com にログイン",
    "プロンプトに曲の雰囲気を書いて Create",
    "良い断片を Extend で伸ばす",
    "Add Outro で終わらせて公開またはダウンロード"
   ]
  },
  {
   "id": "stableaudio",
   "name": "Stable Audio",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "stableaudio.com"
   ],
   "overview": "Stability AI のテキストから音楽・効果音を生成するサービス。",
   "features": [
    "曲の長さ・BPM を指定して生成",
    "Audio-to-Audio で手持ちの音を変化させる",
    "ループ素材・効果音づくり"
   ],
   "usage": [
    "stableaudio.com にログイン",
    "プロンプト (例: lo-fi, piano, 90 BPM) と長さを指定",
    "Generate して試聴・ダウンロード"
   ]
  },
  {
   "id": "aiva",
   "name": "AIVA",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "aiva.ai"
   ],
   "overview": "スタイルを選ぶだけで BGM を AI 作曲するサービス。",
   "features": [
    "映画音楽・ポップ・アンビエントなどのスタイル",
    "キー・テンポ・長さ・楽器編成の指定",
    "ピアノロールで編集",
    "MIDI / WAV / MP3 書き出し"
   ],
   "usage": [
    "aiva.ai にログイン",
    "Create Track → From a Style",
    "設定して Create",
    "編集して Download"
   ]
  },
  {
   "id": "soundraw",
   "name": "SOUNDRAW",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "soundraw.io"
   ],
   "overview": "ジャンル・ムード・長さを選ぶと、著作権を気にせず使える BGM を AI が生成するサービス (日本発)。",
   "features": [
    "ジャンル・ムード・テーマ・長さ・テンポを選んで生成",
    "曲の構成 (盛り上がり) をブロック単位で編集",
    "楽器ごとの音量調整",
    "有料プランで商用利用・ダウンロード"
   ],
   "usage": [
    "soundraw.io を開く",
    "ムードやジャンルを選んで生成",
    "気に入った曲を開いて長さや構成を編集",
    "ダウンロード"
   ]
  },
  {
   "id": "mubert",
   "name": "Mubert",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "mubert.com"
   ],
   "overview": "テキストや雰囲気の指定から、ループ型の BGM をリアルタイム生成するサービス。",
   "features": [
    "テキスト・画像からの BGM 生成",
    "長さを指定してトラックを生成",
    "配信・動画向けのライセンス",
    "API 提供"
   ],
   "usage": [
    "mubert.com の Render を開く",
    "プロンプトまたはジャンルを選ぶ",
    "長さを指定して生成・ダウンロード"
   ]
  },
  {
   "id": "beatoven",
   "name": "Beatoven.ai",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "beatoven.ai"
   ],
   "overview": "動画やポッドキャスト向けの BGM を、ムードの変化を指定して生成するサービス。",
   "features": [
    "区間ごとにムード (楽しい・緊張 など) を指定",
    "楽器の差し替え",
    "著作権フリーで使えるライセンス"
   ],
   "usage": [
    "プロジェクトを作成して長さを指定",
    "区間ごとにジャンルとムードを設定",
    "生成・調整してダウンロード"
   ]
  },
  {
   "id": "soundful",
   "name": "Soundful",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "soundful.com"
   ],
   "overview": "テンプレートから著作権フリーの楽曲を生成するサービス。",
   "features": [
    "ジャンル別テンプレート",
    "テンポ・キーの調整",
    "ステム (パート別) のダウンロード"
   ],
   "usage": [
    "テンプレートを選ぶ",
    "テンポやキーを設定して生成",
    "ダウンロード"
   ]
  },
  {
   "id": "boomy",
   "name": "Boomy",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "boomy.com"
   ],
   "overview": "数クリックで曲を作り、そのまま配信サービスへ公開できる AI 作曲サービス。",
   "features": [
    "スタイルを選ぶだけで曲を生成",
    "ボーカル録音の追加",
    "Spotify などへの配信"
   ],
   "usage": [
    "Create Song でスタイルを選ぶ",
    "生成された曲を編集",
    "保存・配信"
   ]
  },
  {
   "id": "loudly",
   "name": "Loudly",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "loudly.com"
   ],
   "overview": "ジャンル・長さ・テンポを指定して BGM を生成するサービス。",
   "features": [
    "テキストからの生成",
    "長さ・テンポ指定",
    "ロイヤリティフリーのライセンス"
   ],
   "usage": [
    "ジャンルやプロンプトを入力",
    "生成してダウンロード"
   ]
  },
  {
   "id": "riffusion",
   "name": "Riffusion",
   "kind": "AI 作曲・音楽生成",
   "domains": [
    "riffusion.com"
   ],
   "overview": "プロンプトや歌詞から曲を生成する AI 作曲サービス。",
   "features": [
    "歌詞付きの曲生成",
    "曲の別バージョン・続きの生成",
    "スタイルの組み合わせ"
   ],
   "usage": [
    "riffusion.com にログイン",
    "プロンプト・歌詞を入力して生成",
    "試聴してダウンロード"
   ]
  },
  {
   "id": "musicfy",
   "name": "Musicfy",
   "kind": "AI 歌声・音声",
   "domains": [
    "musicfy.lol"
   ],
   "overview": "AI ボイスで歌声を別の声に変換したり、テキストから曲を作ったりするサービス。",
   "features": [
    "歌声の声質変換 (RVC 系)",
    "自分の声モデルの作成",
    "テキストからの楽曲生成"
   ],
   "usage": [
    "音声をアップロード",
    "使う声を選んで変換",
    "ダウンロード"
   ]
  },
  {
   "id": "kits",
   "name": "Kits.ai",
   "kind": "AI 歌声・音声",
   "domains": [
    "kits.ai"
   ],
   "overview": "AI ボイス変換・声モデル作成・音源分離などができる音楽制作者向けサービス。",
   "features": [
    "ライセンス済みのアーティスト声で歌声変換",
    "自分の声モデルの学習",
    "ボーカル分離・マスタリング"
   ],
   "usage": [
    "Voice Conversion を開く",
    "声を選び、歌声ファイルをアップロード",
    "変換して保存"
   ]
  },
  {
   "id": "elevenlabs",
   "name": "ElevenLabs",
   "kind": "AI 歌声・音声",
   "domains": [
    "elevenlabs.io"
   ],
   "overview": "高品質な AI 音声合成サービス。テキスト読み上げに加え、効果音・音楽の生成機能もある。",
   "features": [
    "多言語のテキスト読み上げ",
    "声のクローン",
    "効果音生成 (Sound Effects)",
    "楽曲生成 (Music)"
   ],
   "usage": [
    "ログインして機能を選ぶ",
    "テキストや指示を入力して生成",
    "ダウンロード"
   ]
  },
  {
   "id": "voicevox_web",
   "name": "VOICEVOX (公式サイト)",
   "kind": "AI 歌声・音声",
   "domains": [
    "voicevox.hiroshiba.jp"
   ],
   "overview": "無料の AI 音声合成ソフト VOICEVOX の公式サイト (ダウンロード・キャラクター紹介・利用規約)。",
   "features": [
    "ソフトのダウンロード",
    "キャラクターごとの利用規約",
    "ソング機能の説明"
   ],
   "usage": [
    "ダウンロードページから Windows 版を入手",
    "キャラクターの規約を確認して利用"
   ]
  },
  {
   "id": "dreamtonics",
   "name": "Dreamtonics (Synthesizer V)",
   "kind": "AI 歌声・音声",
   "domains": [
    "dreamtonics.com"
   ],
   "overview": "AI 歌声合成ソフト Synthesizer V の公式サイト。",
   "features": [
    "ソフト・ボイスの購入とダウンロード",
    "マニュアル・更新情報"
   ],
   "usage": [
    "マイページから製品をダウンロード",
    "ライセンスを入力して有効化"
   ]
  },
  {
   "id": "lalal",
   "name": "LALAL.AI",
   "kind": "AI 音源分離・加工",
   "domains": [
    "lalal.ai"
   ],
   "overview": "AI で曲をボーカル・ドラム・ベース・ギターなどに分離するサービス。",
   "features": [
    "ボーカル / 伴奏の分離",
    "ドラム・ベース・ピアノ・ギター・シンセなどのパート分離",
    "Voice Cleaner (声のノイズ除去)",
    "デスクトップアプリ版"
   ],
   "usage": [
    "分離したいパートを選ぶ",
    "ファイルをアップロード",
    "プレビューを確認して購入・ダウンロード"
   ]
  },
  {
   "id": "moises",
   "name": "Moises",
   "kind": "AI 音源分離・加工",
   "domains": [
    "moises.ai"
   ],
   "overview": "AI でパート分離し、練習用にテンポ・キー変更やコード表示ができるミュージシャン向けアプリ。",
   "features": [
    "ボーカル・ドラム・ベースなどの分離",
    "テンポ・キー (移調) の変更",
    "コード検出・メトロノーム",
    "歌詞の書き起こし"
   ],
   "usage": [
    "曲をアップロード",
    "分離方法を選ぶ",
    "練習したいパートだけを鳴らしたり消したりして再生"
   ]
  },
  {
   "id": "vocalremover",
   "name": "Vocal Remover (vocalremover.org)",
   "kind": "AI 音源分離・加工",
   "domains": [
    "vocalremover.org"
   ],
   "overview": "ブラウザで使える無料のボーカル除去・音源分離ツール集。",
   "features": [
    "ボーカル除去",
    "キー / テンポ変更",
    "BPM 検出・カッター・ジョイナー"
   ],
   "usage": [
    "ツールを選ぶ",
    "ファイルをアップロード",
    "結果をダウンロード"
   ]
  },
  {
   "id": "audioshake",
   "name": "AudioShake",
   "kind": "AI 音源分離・加工",
   "domains": [
    "audioshake.ai"
   ],
   "overview": "高品質な AI 音源分離サービス (業務向け、歌詞の書き起こし・同期機能もある)。",
   "features": [
    "ステム分離",
    "歌詞の書き起こしとタイミング合わせ",
    "API 提供"
   ],
   "usage": [
    "ファイルをアップロード",
    "分離するパートを選ぶ",
    "結果をダウンロード"
   ]
  },
  {
   "id": "landr",
   "name": "LANDR",
   "kind": "オンライン DAW・制作ツール",
   "domains": [
    "landr.com"
   ],
   "overview": "AI 自動マスタリング・配信・サンプル素材・プラグインをまとめたミュージシャン向けサービス。",
   "features": [
    "AI 自動マスタリング",
    "Spotify などへの配信",
    "サンプル素材",
    "コラボレーション"
   ],
   "usage": [
    "曲をアップロード",
    "マスタリングのスタイルを選んで試聴",
    "ダウンロードまたは配信"
   ]
  },
  {
   "id": "bandlab",
   "name": "BandLab",
   "kind": "オンライン DAW・制作ツール",
   "domains": [
    "bandlab.com"
   ],
   "overview": "無料のオンライン DAW とコラボレーション・公開サービス。",
   "features": [
    "ブラウザ / スマホで作曲・録音",
    "ループ素材",
    "AI マスタリング",
    "共同制作・公開"
   ],
   "usage": [
    "Create → Studio を開く",
    "録音やループで曲を作る",
    "保存・公開・書き出し"
   ]
  },
  {
   "id": "soundtrap",
   "name": "Soundtrap",
   "kind": "オンライン DAW・制作ツール",
   "domains": [
    "soundtrap.com"
   ],
   "overview": "ブラウザで使えるオンライン DAW (共同編集に対応)。",
   "features": [
    "ブラウザで録音・打ち込み",
    "ループ素材",
    "共同編集"
   ],
   "usage": [
    "ログインして新規プロジェクト",
    "トラックを追加して制作",
    "書き出し"
   ]
  },
  {
   "id": "splice",
   "name": "Splice",
   "kind": "素材・音源・プラグイン",
   "domains": [
    "splice.com"
   ],
   "overview": "サンプル素材 (ループ・ワンショット) のサブスク配信サービス。",
   "features": [
    "ジャンル・楽器・キー・BPM で素材を検索",
    "Create で素材の組み合わせを提案",
    "プラグインのレンタル"
   ],
   "usage": [
    "サンプルを検索して試聴",
    "ダウンロード (クレジット消費)",
    "DAW にドラッグして使う"
   ]
  },
  {
   "id": "tunebat",
   "name": "Tunebat",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "tunebat.com"
   ],
   "overview": "曲の BPM・キー・雰囲気を調べられるデータベースと解析ツール。",
   "features": [
    "曲名から BPM・キーを検索",
    "音声ファイルの BPM / キー解析",
    "ボーカル除去などのツール"
   ],
   "usage": [
    "曲名で検索",
    "またはファイルをアップロードして解析"
   ]
  },
  {
   "id": "chordify",
   "name": "Chordify",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "chordify.net"
   ],
   "overview": "YouTube などの曲から自動でコード譜を作るサービス。",
   "features": [
    "コード進行の自動解析",
    "ギター / ピアノ / ウクレレのコード図",
    "テンポ変更・移調"
   ],
   "usage": [
    "曲を検索するか URL を貼る",
    "表示されたコードに合わせて再生・練習"
   ]
  },
  {
   "id": "ultimateguitar",
   "name": "Ultimate Guitar",
   "kind": "楽譜・学習",
   "domains": [
    "ultimate-guitar.com"
   ],
   "overview": "ギターのコード譜・TAB 譜の投稿サイト。",
   "features": [
    "コード譜・TAB 譜の検索",
    "移調・自動スクロール"
   ],
   "usage": [
    "曲名で検索",
    "譜面を開いて練習"
   ]
  },
  {
   "id": "ufret",
   "name": "U-フレット",
   "kind": "楽譜・学習",
   "domains": [
    "ufret.jp"
   ],
   "overview": "日本の曲のギターコード譜サイト。",
   "features": [
    "コード譜の検索",
    "移調・簡単コード表示・自動スクロール"
   ],
   "usage": [
    "曲名・歌手名で検索",
    "コード譜を表示して練習"
   ]
  },
  {
   "id": "musescore_com",
   "name": "MuseScore.com",
   "kind": "楽譜・学習",
   "domains": [
    "musescore.com"
   ],
   "overview": "楽譜の共有サイト (MuseScore で作った楽譜の公開・ダウンロード)。",
   "features": [
    "楽譜の検索・閲覧",
    "再生・練習",
    "MuseScore 形式でダウンロード"
   ],
   "usage": [
    "曲名で検索",
    "楽譜を開いて再生・ダウンロード"
   ]
  },
  {
   "id": "lrclib",
   "name": "LRCLIB",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "lrclib.net"
   ],
   "overview": "タイミング付き歌詞 (LRC 形式) を無料で検索・取得できるデータベースと API。",
   "features": [
    "曲名・歌手名・アルバム・長さから同期歌詞を検索",
    "API で他のアプリ (歌詞表示・カラオケ) から利用",
    "誰でも歌詞を投稿できる",
    "サーバーのソースコードも公開 (自分で立てられる)"
   ],
   "usage": [
    "サイトで曲を検索して歌詞を確認",
    "アプリから API (https://lrclib.net/api/get?...) で取得"
   ]
  },
  {
   "id": "musixmatch",
   "name": "Musixmatch",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "musixmatch.com"
   ],
   "overview": "世界最大級の歌詞データベース。Spotify などに歌詞を提供。",
   "features": [
    "歌詞の検索・同期歌詞",
    "翻訳",
    "歌詞の投稿・修正"
   ],
   "usage": [
    "曲名で検索",
    "歌詞を表示"
   ]
  },
  {
   "id": "genius",
   "name": "Genius",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "genius.com"
   ],
   "overview": "歌詞と、その意味の解説が読める歌詞サイト。",
   "features": [
    "歌詞の検索",
    "歌詞の解説 (アノテーション)"
   ],
   "usage": [
    "曲名で検索",
    "歌詞と解説を読む"
   ]
  },
  {
   "id": "utanet",
   "name": "歌ネット",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "uta-net.com"
   ],
   "overview": "日本の曲の歌詞検索サイト。",
   "features": [
    "曲名・歌手名・歌詞の一部で検索",
    "ランキング"
   ],
   "usage": [
    "検索して歌詞を表示"
   ]
  },
  {
   "id": "utaten",
   "name": "UtaTen",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "utaten.com"
   ],
   "overview": "ふりがな付きの歌詞検索サイト。",
   "features": [
    "ふりがな付き歌詞",
    "歌詞の意味の解説記事"
   ],
   "usage": [
    "検索して歌詞を表示"
   ]
  },
  {
   "id": "jlyric",
   "name": "J-Lyric.net",
   "kind": "音楽解析・コード・歌詞",
   "domains": [
    "j-lyric.net"
   ],
   "overview": "日本の曲の歌詞検索サイト。",
   "features": [
    "曲名・歌手名・歌詞の一部で検索"
   ],
   "usage": [
    "検索して歌詞を表示"
   ]
  },
  {
   "id": "piapro_jp",
   "name": "ピアプロ",
   "kind": "素材・音源・プラグイン",
   "domains": [
    "piapro.jp"
   ],
   "overview": "クリプトン社が運営する、初音ミクなどの創作物 (歌詞・音楽・イラスト) を投稿・共有するサイト。",
   "features": [
    "歌詞・楽曲・イラストの投稿と利用",
    "コラボ (他人の作品を使った創作)"
   ],
   "usage": [
    "ログインして作品を検索",
    "ライセンスを確認して利用"
   ]
  },
  {
   "id": "soundcloud",
   "name": "SoundCloud",
   "kind": "配信・公開・視聴",
   "domains": [
    "soundcloud.com"
   ],
   "overview": "自作曲を公開・共有できる音楽ストリーミングサービス。",
   "features": [
    "曲のアップロードと公開",
    "コメント・フォロー",
    "他の人の曲を聴く"
   ],
   "usage": [
    "ログインして Upload",
    "公開範囲を決めて投稿"
   ]
  },
  {
   "id": "ytmusic",
   "name": "YouTube Music",
   "kind": "配信・公開・視聴",
   "domains": [
    "music.youtube.com"
   ],
   "overview": "YouTube の音楽ストリーミングサービス。",
   "features": [
    "曲・アルバム・プレイリストの再生"
   ],
   "usage": [
    "検索して再生"
   ]
  },
  {
   "id": "spotify",
   "name": "Spotify",
   "kind": "配信・公開・視聴",
   "domains": [
    "spotify.com"
   ],
   "overview": "音楽ストリーミングサービス。",
   "features": [
    "曲の再生・プレイリスト"
   ],
   "usage": [
    "検索して再生"
   ]
  },
  {
   "id": "tunecore",
   "name": "TuneCore Japan",
   "kind": "配信・公開・視聴",
   "domains": [
    "tunecore.co.jp",
    "tunecore.com"
   ],
   "overview": "自作曲を Spotify・Apple Music などの配信サービスに届ける配信代行サービス。",
   "features": [
    "主要ストリーミングへの配信",
    "収益の受け取り",
    "YouTube の権利管理"
   ],
   "usage": [
    "アカウント作成",
    "曲とジャケットを登録",
    "配信先を選んで申請"
   ]
  },
  {
   "id": "distrokid",
   "name": "DistroKid",
   "kind": "配信・公開・視聴",
   "domains": [
    "distrokid.com"
   ],
   "overview": "定額制の音楽配信代行サービス。",
   "features": [
    "曲数無制限の配信",
    "収益の分配設定"
   ],
   "usage": [
    "登録して曲をアップロード",
    "配信先を選ぶ"
   ]
  },
  {
   "id": "nana",
   "name": "nana",
   "kind": "配信・公開・視聴",
   "domains": [
    "nana-music.com"
   ],
   "overview": "スマホで歌や演奏を録音して投稿・コラボできる音楽 SNS。",
   "features": [
    "歌・演奏の投稿",
    "他の人の伴奏に重ねてコラボ"
   ],
   "usage": [
    "伴奏を選んで録音",
    "投稿"
   ]
  },
  {
   "id": "hf_spaces",
   "name": "Hugging Face",
   "kind": "AI モデル・コード公開サイト",
   "domains": [
    "huggingface.co",
    "hf.co"
   ],
   "overview": "AI モデルとデモ (Spaces) の公開サイト。音楽生成・音声合成・音源分離のモデルやブラウザで試せるデモが多数ある。",
   "features": [
    "モデル (重みファイル) のダウンロード",
    "Spaces: ブラウザで動くデモ",
    "データセット"
   ],
   "usage": [
    "リンク先のページを開く",
    "Spaces ならその場で入力して試せる",
    "モデルは Files タブからダウンロード"
   ]
  },
  {
   "id": "replicate",
   "name": "Replicate",
   "kind": "AI モデル・コード公開サイト",
   "domains": [
    "replicate.com"
   ],
   "overview": "AI モデルをクラウドで実行できるサービス (音楽生成モデルも多数)。",
   "features": [
    "ブラウザでモデルを実行",
    "API で呼び出し (従量課金)"
   ],
   "usage": [
    "モデルのページで入力して Run",
    "結果をダウンロード"
   ]
  },
  {
   "id": "github",
   "name": "GitHub",
   "kind": "AI モデル・コード公開サイト",
   "domains": [
    "github.com"
   ],
   "overview": "プログラムのソースコード公開サイト。音楽 AI ツールの多くがここで公開されている。",
   "features": [
    "README に機能と使い方が書かれている",
    "Releases からアプリをダウンロードできる場合がある",
    "Issues で不具合の報告・質問"
   ],
   "usage": [
    "リンク先の README を読む",
    "Releases か README の手順でインストール"
   ]
  },
  {
   "id": "google_colab",
   "name": "Google Colab",
   "kind": "AI モデル・コード公開サイト",
   "domains": [
    "colab.research.google.com"
   ],
   "overview": "ブラウザ上で Python を動かせる Google のサービス。音楽 AI を GPU で試すノートブックとしてよく使われる。",
   "features": [
    "無料枠で GPU を使える",
    "共有されたノートブックを開いてそのまま実行"
   ],
   "usage": [
    "ノートブックを開く",
    "上のセルから順に実行 (▶)",
    "生成されたファイルをダウンロード"
   ]
  }
 ],
 "webKeywords": [
  "music",
  "\\bsong",
  "lyric",
  "\\bchord",
  "melod",
  "\\bbeat",
  "\\bmidi\\b",
  "vocal",
  "singing",
  "\\bsing\\b",
  "\\baudio\\b",
  "\\bsound",
  "\\bdaw\\b",
  "\\bvst",
  "\\bsynth",
  "karaoke",
  "\\bstems?\\b",
  "\\btts\\b",
  "\\bsvc\\b",
  "\\brvc\\b",
  "音楽",
  "楽曲",
  "作曲",
  "作詞",
  "歌詞",
  "歌声",
  "ボーカル",
  "音声合成",
  "コード進行",
  "カラオケ",
  "音源",
  "サウンド",
  "\\bbgm\\b",
  "\\btape\\b",
  "\\bmastering",
  "\\bmixing"
 ]
}
'@

$Template = @'
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>音楽生成アプリ・関連ソフト一覧</title>
<style>
:root { --bg:#f6f7fb; --card:#fff; --fg:#1d2330; --muted:#6b7280; --line:#e3e6ee; --accent:#5b5bd6; --tag:#eef0ff; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#14161c; --card:#1d2029; --fg:#e7e9ee; --muted:#9aa1ad; --line:#2c303b; --accent:#9b9bff; --tag:#2a2d48; }
}
* { box-sizing: border-box; }
body { margin:0; font-family: "Segoe UI", "Yu Gothic UI", "Meiryo", sans-serif; background:var(--bg); color:var(--fg); line-height:1.6; }
main { max-width: 1100px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 1.6rem; margin: 0 0 4px; }
h2 { font-size: 1.2rem; margin: 36px 0 12px; border-bottom: 2px solid var(--line); padding-bottom: 4px; }
h3 { font-size: 1.1rem; margin: 0; }
a { color: var(--accent); word-break: break-all; }
.muted { color: var(--muted); }
.summary { display:flex; gap:12px; flex-wrap:wrap; margin: 16px 0; }
.stat { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:10px 16px; min-width:160px; }
.stat b { display:block; font-size:1.4rem; }
.toolbar { position: sticky; top:0; background:var(--bg); padding:10px 0; display:flex; gap:8px; flex-wrap:wrap; z-index:1; }
.toolbar input, .toolbar select { padding:8px 10px; border:1px solid var(--line); border-radius:8px; background:var(--card); color:var(--fg); font-size:0.95rem; }
.toolbar input { flex: 1; min-width: 220px; }
table { width:100%; border-collapse: collapse; background:var(--card); border:1px solid var(--line); font-size:0.92rem; }
th, td { padding:7px 10px; border-bottom:1px solid var(--line); text-align:left; vertical-align: top; }
th { cursor:pointer; user-select:none; background:var(--tag); white-space:nowrap; }
td.num { text-align:right; white-space:nowrap; }
.app { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:16px 18px; margin:12px 0; }
.app header { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }
.app .size { margin-left:auto; font-weight:600; }
.tag { background:var(--tag); border-radius:999px; padding:1px 10px; font-size:0.8rem; }
.meta { margin: 2px 0 0; color: var(--muted); font-size: 0.85rem; }
dl { display:grid; grid-template-columns: 8.5em 1fr; gap: 4px 12px; margin: 12px 0 0; }
dt { color:var(--muted); font-size:0.88rem; }
dd { margin:0; }
dd ul { margin:0; padding-left:1.2em; }
code { font-family: Consolas, "BIZ UDGothic", monospace; font-size:0.85rem; word-break: break-all; }
details { margin-top: 12px; }
.note { font-size: 0.88rem; color: var(--muted); }
ul.bl, ol.bl { margin: 0; padding-left: 1.4em; }
ul.bl li, ol.bl li { margin: 2px 0; }
.link { border-left: 4px solid var(--accent); }
button { padding: 6px 14px; border-radius: 8px; border: 1px solid var(--line); background: var(--card); color: var(--fg); cursor: pointer; }
.mv { font-weight: 700; white-space: nowrap; }
td.mv { text-align: center; }
.mv-ok { color: #1a7f37; } .mv-warn { color: #b26b00; } .mv-ng { color: #c62828; } .mv-na, .mv-q { color: var(--muted); }
@media (max-width: 640px) { dl { grid-template-columns: 1fr; } dt { margin-top:6px; } }
@media print { .toolbar { display:none; } .app { break-inside: avoid; } }
</style>
</head>
<body>
<main>
<h1>🎵 音楽生成アプリ・関連ソフト一覧</h1>
<p class="muted" id="when"></p>
<div class="summary" id="summary"></div>
<div class="toolbar">
  <input id="q" type="search" placeholder="アプリ名・用途で絞り込み (例: 歌声, DAW, VOICEVOX)">
  <select id="cat"><option value="">すべてのカテゴリ</option></select>
  <select id="sort"><option value="cat">カテゴリ順</option><option value="size">容量の大きい順</option><option value="name">名前順</option></select>
</div>
<h2>一覧</h2>
<div id="list"></div>
<h2>詳細</h2>
<div id="cards"></div>
<h2>インターネットショートカット (音楽系のリンク)</h2>
<div id="links"></div>
<h2>VST / VST3 / CLAP / AAX プラグイン</h2>
<div id="plugins"></div>
<h2>このレポートについて</h2>
<ul class="note">
  <li>「音楽アプリ一覧を作成.bat」が自動生成しました。スキャンはファイルを読むだけで、何も変更・削除していません。</li>
  <li>容量の「フォルダ実測」はインストール先フォルダの実際の合計サイズ、「推定値」はインストール情報に記録された値です。AI ツールはモデルファイルを別フォルダに置くことがあり、その分は含まれない場合があります。</li>
  <li>用途・公式ページ・利用方法は既知アプリのカタログから表示しています。「その他」はアプリ名から自動判定したもので、音楽と関係ないソフトが含まれることがあります。</li>
  <li>Microsoft Store アプリ、および下記以外の場所に置いたポータブル版は検出されないことがあります。</li>
</ul>
<details><summary class="note">スキャンした場所</summary><ul class="note" id="roots"></ul></details>
<h2>調査の依頼</h2>
<p class="note">「その他」や、内容が分からないリンクについて詳しく調べたいときは、下のボタンで一覧をコピーして開発者 (Claude) に貼り付けてください。Web で調べて、機能・使い方をカタログに追加します。</p>
<p><button id="copy-unknown" type="button">調査依頼用の一覧をコピー</button> <span id="copy-msg" class="muted"></span></p>
<textarea id="unknown-text" readonly rows="6" style="width:100%;font-family:Consolas,monospace;font-size:0.8rem"></textarea>
<div id="errors"></div>
</main>
<script type="application/json" id="data">__DATA_JSON__</script>
<script>
function showFatal(msg) {
  const box = document.createElement('div');
  box.style.cssText = 'background:#fde8e8;color:#8a1c1c;border:1px solid #f5b5b5;border-radius:10px;padding:12px 16px;margin:16px 0;white-space:pre-wrap';
  box.textContent = '表示中にエラーが発生しました。この枠の文章をコピーして開発者に送ってください。\n\n' + msg;
  document.querySelector('main').insertBefore(box, document.getElementById('summary'));
}
try {
(function () {
  'use strict';
  // Windows PowerShell 5.1 は配列を {"value":[...],"Count":n} にすることがあるので、どちらでも受け付ける
  const arr = v => (v == null ? [] : Array.isArray(v) ? v : (typeof v === 'object' && Array.isArray(v.value)) ? v.value : [v]);
  const str = v => (v == null ? '' : typeof v === 'object' && !Array.isArray(v) && 'value' in v ? String(v.value) : Array.isArray(v) ? String(v.length ? v[0] : '') : String(v));
  let raw = document.getElementById('data').textContent.trim();
  if (raw === '__DATA' + '_JSON__') raw = 'null';
  const D = JSON.parse(raw) || { apps: [], plugins: [], categories: [], roots: {}, errors: ['データが埋め込まれていません'] };
  D.categories = arr(D.categories).map(str);
  D.errors = arr(D.errors).map(str);
  D.apps = arr(D.apps).map(a => ({
    name: str(a.name), category: str(a.category), purpose: str(a.purpose), url: str(a.url), howto: str(a.howto),
    launchNote: str(a.launchNote), location: str(a.location), size: Number(str(a.size)) || 0, sizeNote: str(a.sizeNote),
    launchFile: str(a.launchFile), shortcuts: arr(a.shortcuts).map(str).filter(Boolean), version: str(a.version),
    publisher: str(a.publisher), names: arr(a.names).map(str), kinds: arr(a.kinds).map(str), webUrl: str(a.webUrl),
    features: arr(a.features).map(str).filter(Boolean), usage: arr(a.usage).map(str).filter(Boolean),
    localUrls: arr(a.localUrls).map(str).filter(Boolean), packageName: str(a.packageName),
    runtime: str(a.runtime), gpu: str(a.gpu), portable: str(a.portable) || '？', portableReason: str(a.portableReason),
  }));
  D.links = arr(D.links).map(l => ({
    name: str(l.name), kind: str(l.kind), overview: str(l.overview), features: arr(l.features).map(str).filter(Boolean),
    usage: arr(l.usage).map(str).filter(Boolean), officialUrl: str(l.officialUrl), reason: str(l.reason),
    pageTitle: str(l.pageTitle), pageDescription: str(l.pageDescription), pageError: str(l.pageError), host: str(l.host),
    urls: arr(l.urls).map(str), shortcuts: arr(l.shortcuts).map(str), folders: arr(l.folders).map(str), isLocal: l.isLocal === true,
  }));
  D.nonMusicLinks = arr(D.nonMusicLinks).map(l => ({ name: str(l.name), url: str(l.url), path: str(l.path), title: str(l.title), error: str(l.error) }));
  D.plugins = arr(D.plugins).map(p => ({ name: str(p.name), format: str(p.format), folder: str(p.folder), size: Number(str(p.size)) || 0 }));
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const leaf = p => String(p).replace(/[\\/]+$/, '').split(/[\\/]/).pop();
  const stem = p => leaf(p).replace(/\.[^.]+$/, '');
  const human = n => {
    let v = Number(n);
    for (const u of ['B', 'KB', 'MB', 'GB']) {
      if (v < 1024) return u === 'B' ? v.toFixed(0) + u : v.toFixed(1) + u;
      v /= 1024;
    }
    return v.toFixed(1) + 'TB';
  };
  const fileUrl = p => 'file:///' + encodeURI(String(p).replace(/\\/g, '/')).replace(/#/g, '%23').replace(/\?/g, '%3F');
  const fileLink = (p, label) => p ? `<a href="${esc(fileUrl(p))}" title="${esc(p)}">${esc(label || p)}</a>` : '<span class="muted">不明</span>';
  const bullets = (items, empty, ordered) => items.length
    ? `<${ordered ? 'ol' : 'ul'} class="bl">${items.map(t => `<li>${esc(t)}</li>`).join('')}</${ordered ? 'ol' : 'ul'}>`
    : `<span class="muted">${esc(empty)}</span>`;
  const searchUrl = q => 'https://www.google.com/search?q=' + encodeURIComponent(q + ' github 音楽');
  const OTHER = (D.categories.length ? D.categories[D.categories.length - 1] : '');
  const PORT = { '○': 'ok', '△': 'warn', '×': 'ng', '－': 'na', '？': 'q' };
  const PORT_LABEL = { '○': '移動しても起動できます', '△': '条件付きで起動できます', '×': '移動すると起動できなくなります', '－': '関係ありません', '？': '判定できません' };
  const KIND = { registry: 'インストール情報', shortcut: 'ショートカット', url: 'Web ショートカット', folder: 'フォルダ' };

  function launchMethod(a) {
    const steps = [];
    const sc = arr(a.shortcuts);
    const desk = sc.filter(s => /[\\/](desktop|デスクトップ)[\\/]/i.test(s));
    const start = sc.filter(s => /start menu|スタート メニュー/i.test(s));
    if (desk.length) steps.push(`デスクトップの「${stem(desk[0])}」をダブルクリック`);
    if (start.length) steps.push(`スタートメニューで「${stem(start[0])}」を検索して起動`);
    if (a.launchFile && !desk.length) {
      const ext = (a.launchFile.match(/\.[^.\\/]+$/) || [''])[0].toLowerCase();
      if (ext === '.py') steps.push(`コマンドプロンプトでフォルダに移動し python ${leaf(a.launchFile)} を実行`);
      else if (ext === '.url') steps.push(`「${leaf(a.launchFile)}」をダブルクリック`);
      else steps.push(`${ext === '.bat' || ext === '.cmd' ? 'バッチファイル' : '起動ファイル'}「${leaf(a.launchFile)}」をダブルクリック`);
    }
    if (!steps.length && a.webUrl) steps.push(`ブラウザで ${a.webUrl} を開く`);
    if (!steps.length && a.usage && a.usage.length && a.location) steps.push('起動用のファイルはありません。下の「使い方」の手順 (コマンド) で起動します');
    if (!steps.length) steps.push(a.category && a.category.indexOf('プラグイン') >= 0 ? 'DAW を起動し、プラグインとして読み込む' : 'スタートメニューからアプリ名で検索して起動');
    let text = steps.join(' / ');
    if (a.launchNote) text += '。' + a.launchNote;
    return text;
  }

  const order = {};
  arr(D.categories).forEach((c, i) => { order[c] = i; });
  const apps = arr(D.apps).slice().sort((a, b) => ((a.category in order ? order[a.category] : 99) - (b.category in order ? order[b.category] : 99)) || a.name.localeCompare(b.name, 'ja'));
  const plugins = arr(D.plugins).slice().sort((a, b) => a.format.localeCompare(b.format) || a.name.localeCompare(b.name, 'ja'));
  apps.forEach(a => { a.method = launchMethod(a); });

  document.getElementById('when').textContent = `スキャン日時: ${D.scannedAt || ''}` + (D.computer ? ` / PC: ${D.computer}` : '');
  const total = apps.reduce((s, a) => s + (Number(a.size) || 0), 0);
  const ptotal = plugins.reduce((s, p) => s + (Number(p.size) || 0), 0);
  document.getElementById('summary').innerHTML = [
    ['アプリ', apps.length + ' 件'], ['アプリ合計容量', human(total)],
    ['音楽系リンク', D.links.length + ' 件'], ['プラグイン', plugins.length + ' 件'], ['プラグイン合計容量', human(ptotal)],
  ].map(([k, v]) => `<div class="stat">${k}<b>${v}</b></div>`).join('');

  const cats = arr(D.categories).filter(c => apps.some(a => a.category === c));
  document.getElementById('cat').insertAdjacentHTML('beforeend', cats.map(c => `<option value="${esc(c)}">${esc(c)}</option>`).join(''));

  const sizeHtml = a => a.size ? `${human(a.size)} <span class="muted">(${esc(a.sizeNote)})</span>` : `<span class="muted">${esc(a.sizeNote || '不明')}</span>`;
  const searchText = a => [a.name, a.category, a.purpose, a.runtime].concat(arr(a.names)).join(' ').toLowerCase();

  document.getElementById('list').innerHTML = apps.length ? `
<p class="note">「移動」は、アプリのフォルダを別の場所へ移しても起動できるかの目安です。 ○ 移動しても動く / △ 条件付きで動く / × 移動すると動かない / － 関係なし (Web サービス) / ？ 判定できない</p>
<table id="summary-table"><thead><tr><th>アプリ</th><th>カテゴリ</th><th>実行環境</th><th>移動</th><th>容量</th><th>起動ファイル</th></tr></thead><tbody>
${apps.map((a, i) => `<tr data-cat="${esc(a.category)}" data-search="${esc(searchText(a))}">
<td><a href="#app-${i}">${esc(a.name)}</a></td><td>${esc(a.category)}</td><td>${esc(a.runtime || '-')}</td>
<td class="mv mv-${PORT[a.portable] || 'q'}" title="${esc(a.portableReason)}">${esc(a.portable)}</td>
<td class="num" data-v="${Number(a.size) || 0}">${a.size ? human(a.size) : '-'}</td>
<td><code>${a.launchFile ? esc(leaf(a.launchFile)) : '-'}</code></td></tr>`).join('')}
</tbody></table>` : '<p>音楽関連のアプリは見つかりませんでした。</p>';

  document.getElementById('cards').innerHTML = apps.map((a, i) => {
    const meta = [a.version && 'バージョン ' + a.version, a.publisher].filter(Boolean).join(' / ');
    const sc = arr(a.shortcuts).slice(0, 5).map(s => `<li>${fileLink(s, leaf(s))}</li>`).join('');
    const kinds = arr(a.kinds).map(k => KIND[k] || k).join('、');
    return `
<article id="app-${i}" class="app" data-cat="${esc(a.category)}" data-search="${esc(searchText(a))}" data-size="${Number(a.size) || 0}" data-name="${esc(a.name)}">
  <header><h3>${esc(a.name)}</h3><span class="tag">${esc(a.category)}</span><span class="size">${sizeHtml(a)}</span></header>
  ${meta ? `<p class="meta">${esc(meta)}</p>` : ''}
  <dl>
    <dt>概要</dt><dd>${esc(a.purpose)}${a.packageName ? `<br><span class="muted">パッケージ名: ${esc(a.packageName)}</span>` : ''}</dd>
    <dt>主な機能</dt><dd>${bullets(a.features, '情報なし')}</dd>
    <dt>公式ページ</dt><dd>${a.url ? `<a href="${esc(a.url)}" target="_blank" rel="noopener">${esc(a.url)}</a>` : '<span class="muted">不明</span>'}</dd>
    <dt>容量</dt><dd>${sizeHtml(a)}</dd>
    <dt>起動方法</dt><dd>${esc(a.method)}</dd>
    <dt>実行環境</dt><dd>${esc(a.runtime || '不明')}${a.gpu ? `<br><span class="muted">GPU: ${esc(a.gpu)}</span>` : ''}</dd>
    <dt>フォルダ移動</dt><dd><span class="mv mv-${PORT[a.portable] || 'q'}">${esc(a.portable)} ${esc(PORT_LABEL[a.portable] || '')}</span><br>${esc(a.portableReason)}</dd>
    <dt>起動ファイル</dt><dd><code>${a.launchFile ? esc(a.launchFile) : '不明'}</code></dd>
    <dt>インストール先</dt><dd>${fileLink(a.location)}</dd>
    <dt>使い方</dt><dd>${a.usage.length ? bullets(a.usage, '', true) : esc(a.howto)}${a.localUrls.length ? `<p class="muted">画面のアドレス (推定): ${a.localUrls.map(u => `<a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a>`).join(' / ')}</p>` : ''}</dd>
    ${a.category === OTHER ? `<dt>Web で調べる</dt><dd><a href="${esc(searchUrl(a.packageName || a.name))}" target="_blank" rel="noopener">「${esc(a.packageName || a.name)}」を検索</a></dd>` : ''}
    ${sc ? `<dt>ショートカット</dt><dd><ul>${sc}</ul></dd>` : ''}
    <dt>検出元</dt><dd class="muted">${esc(kinds)} (${esc(arr(a.names).slice(0, 4).join(' / '))})</dd>
  </dl>
</article>`;
  }).join('');

  // インターネットショートカット
  const links = D.links.slice().sort((a, b) => a.kind.localeCompare(b.kind, 'ja') || a.name.localeCompare(b.name, 'ja'));
  const extLink = u => `<a href="${esc(u)}" target="_blank" rel="noopener">${esc(u)}</a>`;
  document.getElementById('links').innerHTML = (links.length ? `
<p class="note">デスクトップ・ユーザーフォルダ・C ドライブ・お気に入りの .url ファイルと、ブラウザの「アプリ」ショートカットを調べ、リンク先から音楽系かどうかを判定しました。同じサービスへのリンクは 1 つにまとめています。</p>
<table id="link-table"><thead><tr><th>名前</th><th>種類</th><th>リンク数</th><th>判定理由</th></tr></thead><tbody>
${links.map((l, i) => `<tr data-search="${esc((l.name + ' ' + l.kind + ' ' + l.overview).toLowerCase())}"><td><a href="#link-${i}">${esc(l.name)}</a></td><td>${esc(l.kind)}</td><td class="num" data-v="${l.shortcuts.length}">${l.shortcuts.length}</td><td>${esc(l.reason)}</td></tr>`).join('')}
</tbody></table>
${links.map((l, i) => `
<article id="link-${i}" class="app link" data-search="${esc((l.name + ' ' + l.kind + ' ' + l.overview).toLowerCase())}">
  <header><h3>${esc(l.name)}</h3><span class="tag">${esc(l.kind)}</span></header>
  <dl>
    <dt>概要</dt><dd>${esc(l.overview || l.pageDescription || '説明を取得できませんでした')}</dd>
    <dt>主な機能</dt><dd>${bullets(l.features, l.pageTitle ? 'リンク先のタイトル: ' + l.pageTitle : '情報なし')}</dd>
    <dt>使い方</dt><dd>${bullets(l.usage, l.isLocal ? 'このアドレスの画面を出すアプリを先に起動してから開いてください。' : 'リンクを開いてページの案内に従ってください。', true)}</dd>
    <dt>公式ページ</dt><dd>${l.officialUrl ? extLink(l.officialUrl) : '<span class="muted">不明</span>'}</dd>
    <dt>リンク先</dt><dd><ul>${l.urls.slice(0, 10).map(u => `<li>${extLink(u)}</li>`).join('')}</ul></dd>
    <dt>ショートカット</dt><dd><ul>${l.shortcuts.slice(0, 10).map(p => `<li>${fileLink(p, leaf(p))}</li>`).join('')}${l.shortcuts.length > 10 ? `<li class="muted">ほか ${l.shortcuts.length - 10} 件</li>` : ''}</ul></dd>
    <dt>置き場所</dt><dd>${l.folders.slice(0, 5).map(f => fileLink(f)).join('<br>')}</dd>
    <dt>判定理由</dt><dd class="muted">${esc(l.reason)}${l.pageTitle ? ` / ページのタイトル: ${esc(l.pageTitle)}` : ''}${l.pageError ? ` / ページを読めませんでした: ${esc(l.pageError)}` : ''}</dd>
    ${(!l.features.length && !l.isLocal) ? `<dt>Web で調べる</dt><dd><a href="${esc(searchUrl(l.name))}" target="_blank" rel="noopener">「${esc(l.name)}」を検索</a></dd>` : ''}
  </dl>
</article>`).join('')}` : '<p class="muted">音楽系のインターネットショートカットは見つかりませんでした。</p>') +
  (D.nonMusicLinks.length ? `
<details><summary class="note">音楽系ではないと判定したリンク (${D.nonMusicLinks.length} 件)</summary>
<table><thead><tr><th>名前</th><th>URL</th><th>ページのタイトル</th><th>場所</th></tr></thead><tbody>
${D.nonMusicLinks.slice(0, 500).map(l => `<tr><td>${esc(l.name)}</td><td>${extLink(l.url)}</td><td>${esc(l.title || l.error)}</td><td>${fileLink(l.path, leaf(l.path))}</td></tr>`).join('')}
</tbody></table></details>` : '');

  // 調査依頼用のテキスト
  const unknown = [];
  apps.filter(a => a.category === OTHER).forEach(a => unknown.push(
    `- アプリ: ${a.name}${a.packageName ? ' (パッケージ名 ' + a.packageName + ')' : ''} / 場所: ${a.location || '不明'} / 実行環境: ${a.runtime} / 公式?: ${a.url || '不明'} / 概要: ${a.purpose}`));
  links.filter(l => !l.features.length).forEach(l => unknown.push(`- リンク: ${l.name} / ${l.urls[0] || ''} / タイトル: ${l.pageTitle || '不明'}`));
  const ta = document.getElementById('unknown-text');
  ta.value = unknown.length ? '次のアプリ・リンクが何か、Web で調べて機能・使い方を教えてください。\n' + unknown.join('\n') : '調査が必要な項目はありません。';
  document.getElementById('copy-unknown').addEventListener('click', () => {
    ta.select();
    const done = () => { document.getElementById('copy-msg').textContent = 'コピーしました'; };
    if (navigator.clipboard) navigator.clipboard.writeText(ta.value).then(done, () => { document.execCommand('copy'); done(); });
    else { document.execCommand('copy'); done(); }
  });

  document.getElementById('plugins').innerHTML = plugins.length ? `
<p class="note">DAW から読み込んで使う音源・エフェクトです。単体では起動しません (DAW のプラグイン一覧から選びます)。</p>
<table id="plugin-table"><thead><tr><th>名前</th><th>形式</th><th>容量</th><th>場所</th></tr></thead><tbody>
${plugins.map(p => `<tr><td>${esc(p.name)}</td><td>${esc(p.format)}</td><td class="num" data-v="${Number(p.size) || 0}">${human(p.size || 0)}</td><td>${fileLink(p.folder)}</td></tr>`).join('')}
</tbody></table>` : '<p class="muted">プラグインフォルダに項目はありませんでした。</p>';

  const R = D.roots || {};
  document.getElementById('roots').innerHTML = [
    ['デスクトップ', R.desktops], ['スタートメニュー', R.startMenus], ['プログラムフォルダ', R.programDirs],
    ['C ドライブ直下ほか', R.shallowDirs], ['プラグインフォルダ', R.pluginDirs],
  ].map(([k, v]) => `<li><b>${k}</b>: ${esc(arr(v).join(', ') || '(なし)')}</li>`).join('');
  if (arr(D.errors).length) {
    document.getElementById('errors').innerHTML = `<details open><summary class="note">エラー</summary><ul class="note">${arr(D.errors).map(e => `<li>${esc(e)}</li>`).join('')}</ul></details>`;
  }

  // 絞り込み・並べ替え
  const q = document.getElementById('q'), cat = document.getElementById('cat'), sort = document.getElementById('sort');
  const cards = document.getElementById('cards');
  const original = Array.from(cards.children);
  function apply() {
    const text = q.value.trim().toLowerCase(), c = cat.value;
    document.querySelectorAll('#cards .app, #summary-table tbody tr, #links .link, #link-table tbody tr').forEach(el => {
      el.style.display = (!c || !el.dataset.cat || el.dataset.cat === c) && (!text || (el.dataset.search || '').includes(text)) ? '' : 'none';
    });
  }
  function reorder() {
    const items = original.slice();
    if (sort.value === 'size') items.sort((a, b) => b.dataset.size - a.dataset.size);
    if (sort.value === 'name') items.sort((a, b) => a.dataset.name.localeCompare(b.dataset.name, 'ja'));
    items.forEach(el => cards.appendChild(el));
  }
  q.addEventListener('input', apply);
  cat.addEventListener('change', apply);
  sort.addEventListener('change', reorder);
  document.querySelectorAll('table').forEach(table => {
    table.querySelectorAll('th').forEach((th, i) => th.addEventListener('click', () => {
      const body = table.tBodies[0], rows = Array.from(body.rows);
      const dir = th.dataset.dir === 'asc' ? -1 : 1;
      th.dataset.dir = dir === 1 ? 'asc' : 'desc';
      rows.sort((a, b) => {
        const x = a.cells[i], y = b.cells[i];
        if (x.dataset.v !== undefined) return (x.dataset.v - y.dataset.v) * dir;
        return x.textContent.localeCompare(y.textContent, 'ja') * dir;
      });
      rows.forEach(r => body.appendChild(r));
    }));
  });
})();
} catch (e) {
  showFatal((e && e.stack) || String(e));
}
</script>
</body>
</html>
'@

$Catalog = $CatalogJson | ConvertFrom-Json
$RxOpt = [Text.RegularExpressions.RegexOptions]::IgnoreCase
foreach ($e in $Catalog.entries) {
    $rx = @($e.match | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
    $e | Add-Member -NotePropertyName rx -NotePropertyValue $rx
}
$GenericRx = @($Catalog.generic | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$GenericExRx = @($Catalog.genericExclude | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$OtherCategory = $Catalog.categories[$Catalog.categories.Count - 1]
$PluginCategory = '音源・プラグイン・管理ツール'
# フォルダ名から音楽関連ツールを推定するための語
$FolderKeywordRx = @()
foreach ($p in $Catalog.folderKeywords.PSObject.Properties) {
    $FolderKeywordRx += [pscustomobject]@{ rx = (New-Object Text.RegularExpressions.Regex($p.Name, $RxOpt)); purpose = [string]$p.Value }
}

# 起動ファイルとして選ばないもの
$ExeSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|setup|install|update|crash|report|helper|service|vc_?redist|dotnet|python|pythonw|conhost|elevate|register|activation|repair|diag|bugsplat|cefsharp|squirrel|7z|ffmpeg|ffprobe)', $RxOpt)
# 一覧に載せないショートカット
$ShortcutSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|アンインストール|削除|readme|manual|マニュアル|help|ヘルプ|website|web site|homepage|license|ライセンス|changelog|release notes|documentation|ドキュメント)', $RxOpt)
$SkipDirs = @('windows', '$recycle.bin', 'system volume information', 'recovery', 'perflogs', 'msocache',
    '$windows.~bt', '$windows.~ws', '$winreagent', 'config.msi', 'programdata', 'users', 'program files',
    'program files (x86)', 'node_modules', '.git', '__pycache__', 'site-packages', 'appdata', '.cleaner_quarantine')
# フォルダ探索で中に入らないもの (Python の仮想環境・モデル置き場など)
$FolderSkipDirs = @('venv', 'env', 'lib', 'libs', 'models', 'checkpoints', 'output', 'outputs', 'cache', 'dist',
    'build', 'temp', 'tmp', 'node_modules', 'site-packages', 'scripts', 'include', 'share')
# アプリのフォルダらしいと判断する目印
$AppMarkers = @('requirements.txt', 'pyproject.toml', 'package.json', 'app.py', 'main.py', 'webui.py', 'launch.py',
    'docker-compose.yml', 'docker-compose.yaml', 'setup.py', 'environment.yml', 'pinokio.js')
$LaunchSkipDirs = @('models', 'venv', 'env', 'runtime', 'python_embeded', 'lib', 'libs')
$LaunchExts = @('.exe', '.bat', '.cmd', '.py')
$PluginExts = @{ '.vst3' = 'VST3'; '.dll' = 'VST2'; '.clap' = 'CLAP'; '.aaxplugin' = 'AAX' }

# ---------------------------------------------------------------------------
# 共通

function Write-Step([string]$msg) { Write-Host $msg }

function Get-Normalized([string]$s) {
    if (-not $s) { return '' }
    $s = [regex]::Replace($s.Trim(), '\.(lnk|url|exe|bat)$', '', 'IgnoreCase')
    return ($s -replace '_+', ' ').ToLowerInvariant()
}

function Find-CatalogEntry([string[]]$Names) {
    $texts = @($Names | Where-Object { $_ } | ForEach-Object { Get-Normalized $_ })
    foreach ($e in $Catalog.entries) {
        foreach ($t in $texts) {
            foreach ($r in $e.rx) {
                if ($r.IsMatch($t)) { return $e }
            }
        }
    }
    return $null
}

function Test-Musical([string]$Name) {
    $t = Get-Normalized $Name
    foreach ($r in $GenericExRx) { if ($r.IsMatch($t)) { return $false } }
    foreach ($r in $GenericRx) { if ($r.IsMatch($t)) { return $true } }
    return $false
}

function Test-Reparse($Attributes) { return (([int]$Attributes) -band 0x400) -ne 0 }

function Expand-PathText([string]$p) {
    if (-not $p) { return $null }
    $p = [Environment]::ExpandEnvironmentVariables($p.Trim().Trim('"'))
    if (-not $p) { return $null }
    return $p
}

function Test-Exists([string]$p, [switch]$Folder) {
    if (-not $p) { return $false }
    try {
        if ($Folder) { return [IO.Directory]::Exists($p) }
        return [IO.File]::Exists($p) -or [IO.Directory]::Exists($p)
    } catch { return $false }
}

function Get-Parent([string]$p) {
    try { return [IO.Path]::GetDirectoryName($p) } catch { return $null }
}

function Get-Leaf([string]$p) {
    try { return [IO.Path]::GetFileName($p.TrimEnd('\')) } catch { return $p }
}

function Get-Ext([string]$p) {
    try { return [IO.Path]::GetExtension($p).ToLowerInvariant() } catch { return '' }
}

function Get-Stem([string]$p) {
    try { return [IO.Path]::GetFileNameWithoutExtension($p) } catch { return $p }
}

function Get-UniquePaths($Paths) {
    $seen = @{}
    $out = New-Object System.Collections.ArrayList
    foreach ($p in $Paths) {
        if (-not $p) { continue }
        $k = $p.TrimEnd('\').ToLowerInvariant()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        if (Test-Exists $p -Folder) { [void]$out.Add($p) }
    }
    return , $out.ToArray()
}

function New-Source($Kind, $Name) {
    return [pscustomobject]@{
        kind = $Kind; name = $Name; location = $null; target = $null; shortcut = $null; url = $null
        size = $null; publisher = ''; version = ''; purpose = $null
    }
}

# JSON に変換する。Windows PowerShell 5.1 の ConvertTo-Json は配列を {"value":[...],"Count":n} に
# してしまうことや、深さ・長さの制限で失敗することがあるため使わない。
function ConvertTo-JsonText($Value) {
    $sb = New-Object Text.StringBuilder
    Add-JsonValue $sb $Value
    return $sb.ToString()
}

function Add-JsonString([Text.StringBuilder]$Sb, [string]$Text) {
    $e = $Text.Replace('\', '\\').Replace('"', '\"')
    # 制御文字と < > & は \uXXXX にする (HTML の <script> 内に安全に埋め込むため)
    $e = [regex]::Replace($e, '[\x00-\x1f<>&\u2028\u2029]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    [void]$Sb.Append('"').Append($e).Append('"')
}

function Add-JsonValue([Text.StringBuilder]$Sb, $Value) {
    if ($null -eq $Value) { [void]$Sb.Append('null'); return }
    $base = $Value
    if ($Value -is [Management.Automation.PSObject]) { $base = $Value.PSObject.BaseObject }
    if ($base -is [string] -or $base -is [char]) { Add-JsonString $Sb ([string]$base); return }
    if ($base -is [bool]) { if ($base) { [void]$Sb.Append('true') } else { [void]$Sb.Append('false') }; return }
    if ($base -is [int] -or $base -is [long] -or $base -is [double] -or $base -is [decimal] -or $base -is [single] -or
        $base -is [int16] -or $base -is [byte] -or $base -is [uint32] -or $base -is [uint64]) {
        $n = [Convert]::ToString($base, [Globalization.CultureInfo]::InvariantCulture)
        if ($n -match '^(NaN|-?Infinity|∞|-∞)$') { $n = 'null' }
        [void]$Sb.Append($n)
        return
    }
    if ($base -is [Management.Automation.PSCustomObject]) {
        [void]$Sb.Append('{')
        $first = $true
        foreach ($prop in $Value.PSObject.Properties) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonString $Sb $prop.Name
            [void]$Sb.Append(':')
            Add-JsonValue $Sb $prop.Value
        }
        [void]$Sb.Append('}')
        return
    }
    if ($base -is [Collections.IDictionary]) {
        [void]$Sb.Append('{')
        $first = $true
        foreach ($k in $base.Keys) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonString $Sb ([string]$k)
            [void]$Sb.Append(':')
            Add-JsonValue $Sb $base[$k]
        }
        [void]$Sb.Append('}')
        return
    }
    if ($base -is [Collections.IEnumerable]) {
        [void]$Sb.Append('[')
        $first = $true
        foreach ($item in $base) {
            if (-not $first) { [void]$Sb.Append(',') }
            $first = $false
            Add-JsonValue $Sb $item
        }
        [void]$Sb.Append(']')
        return
    }
    Add-JsonString $Sb ([string]$base)
}

# ---------------------------------------------------------------------------
# 調べる場所

$Desktops = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'))
foreach ($v in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
    if ($v) { $Desktops += @((Join-Path $v 'Desktop'), (Join-Path $v 'デスクトップ')) }
}
$Desktops = Get-UniquePaths $Desktops
$StartMenus = Get-UniquePaths @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('CommonPrograms'))
$ProgramFiles = Get-UniquePaths @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})
$ProgramDirs = Get-UniquePaths (@($ProgramFiles) + @((Join-Path $env:LOCALAPPDATA 'Programs')))
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive + '\' } else { 'C:\' }
$ShallowDirs = Get-UniquePaths @($SystemDrive, $env:USERPROFILE, [Environment]::GetFolderPath('MyDocuments'),
    (Join-Path $env:USERPROFILE 'Downloads'))
$PluginDirs = @()
foreach ($b in $ProgramFiles) {
    $PluginDirs += @("$b\Common Files\VST3", "$b\Common Files\VST2", "$b\Common Files\CLAP",
        "$b\Common Files\Avid\Audio\Plug-Ins", "$b\VSTPlugins", "$b\Steinberg\VSTPlugins", "$b\Vstplugins",
        "$b\Image-Line\Shared\Plugins")
}
$PluginDirs += @("$env:LOCALAPPDATA\Programs\Common\VST3", "$env:LOCALAPPDATA\Programs\Common\CLAP")
$PluginDirs = Get-UniquePaths $PluginDirs

# インストール先として扱わない場所 (ドライブ直下やデスクトップそのもの)
$NotLocation = @{}
foreach ($p in @($Desktops) + @($StartMenus) + @($ProgramDirs) + @($ShallowDirs)) {
    $NotLocation[$p.TrimEnd('\').ToLowerInvariant()] = $true
}

$Sources = New-Object System.Collections.ArrayList
$LinkFiles = New-Object System.Collections.ArrayList
$Errors = New-Object System.Collections.ArrayList

# ---------------------------------------------------------------------------
# 1. アンインストール情報 (レジストリ)

Write-Step 'インストール情報 (レジストリ) を確認しています…'
$seenReg = @{}
foreach ($rp in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
    foreach ($item in @(Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue)) {
        $name = [string]$item.DisplayName
        if (-not $name.Trim() -or $item.SystemComponent -eq 1 -or $item.ParentKeyName) { continue }
        $key = $name.ToLowerInvariant() + '|' + [string]$item.DisplayVersion
        if ($seenReg.ContainsKey($key)) { continue }
        $seenReg[$key] = $true
        $s = New-Source 'registry' $name.Trim()
        $s.location = Expand-PathText ([string]$item.InstallLocation)
        $icon = Expand-PathText (([string]$item.DisplayIcon).Split(',')[0])
        if ($icon -and $icon.ToLowerInvariant().EndsWith('.exe')) { $s.target = $icon }
        if ($item.EstimatedSize -and [int64]$item.EstimatedSize -gt 0) { $s.size = [int64]$item.EstimatedSize * 1024 }
        $s.publisher = [string]$item.Publisher
        $s.version = [string]$item.DisplayVersion
        $u = [string]$item.URLInfoAbout
        if (-not $u) { $u = [string]$item.HelpLink }
        if ($u) { $s.url = $u }
        [void]$Sources.Add($s)
    }
}

# ---------------------------------------------------------------------------
# 2. ショートカット (デスクトップ・スタートメニュー)

Write-Step 'デスクトップとスタートメニューのショートカットを確認しています…'
$Shell = $null
try { $Shell = New-Object -ComObject WScript.Shell } catch { [void]$Errors.Add("ショートカットを読めませんでした: $_") }

function Add-Shortcuts([string]$Dir, [switch]$Recurse) {
    $files = @(Get-ChildItem -LiteralPath $Dir -File -Force -Recurse:$Recurse -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $ext = $f.Extension.ToLowerInvariant()
        if ($ext -eq '.lnk' -and $Shell) {
            $s = New-Source 'shortcut' $f.BaseName
            $s.shortcut = $f.FullName
            $lnkArgs = ''
            try {
                $lnk = $Shell.CreateShortcut($f.FullName)
                $s.target = Expand-PathText $lnk.TargetPath
                $s.location = Expand-PathText $lnk.WorkingDirectory
                $lnkArgs = [string]$lnk.Arguments
            } catch { }
            $m = [regex]::Match($lnkArgs, 'https?://[^\s"'']+')
            if ($m.Success -and $s.target -and (Get-Leaf $s.target) -match '(?i)(chrome|msedge|firefox|brave|opera|vivaldi|chrome_proxy|msedge_proxy)\.exe$') {
                [void]$LinkFiles.Add([pscustomobject]@{ path = $f.FullName; url = $m.Value; name = $f.BaseName; from = 'app' })
                continue
            }
            [void]$Sources.Add($s)
        } elseif ($ext -eq '.url') {
            $url = $null
            try {
                $m = [regex]::Match([IO.File]::ReadAllText($f.FullName), '(?im)^\s*URL\s*=\s*(\S+)')
                if ($m.Success) { $url = $m.Groups[1].Value }
            } catch { }
            if (-not $url) { continue }
            if (-not $url.ToLowerInvariant().StartsWith('file:')) { continue }  # Web のリンクは 5. で調べる
            $s = New-Source 'shortcut' $f.BaseName
            try { $s.target = ([Uri]$url).LocalPath } catch { }
            $s.shortcut = $f.FullName
            [void]$Sources.Add($s)
        } elseif ($ext -eq '.exe' -or $ext -eq '.bat' -or $ext -eq '.cmd') {
            $s = New-Source 'shortcut' $f.BaseName
            $s.target = $f.FullName
            $s.shortcut = $f.FullName
            $s.location = $f.DirectoryName
            [void]$Sources.Add($s)
        }
    }
}
foreach ($d in $Desktops) { Add-Shortcuts $d }
foreach ($d in $StartMenus) { Add-Shortcuts $d -Recurse }

# ---------------------------------------------------------------------------
# 3. フォルダ (Program Files・C:\ 直下・ユーザーフォルダ・デスクトップ)

Write-Step 'Program Files と C ドライブのフォルダを確認しています…'
function Test-AppFolder([IO.DirectoryInfo]$Dir) {
    $files = @()
    try { $files = $Dir.GetFiles() } catch { return $false }
    foreach ($f in $files) {
        $low = $f.Name.ToLowerInvariant()
        if ($AppMarkers -contains $low) { return $true }
        $ext = $f.Extension.ToLowerInvariant()
        if ($ext -eq '.bat' -or $ext -eq '.cmd' -or ($ext -eq '.exe' -and -not $ExeSkip.IsMatch($low))) { return $true }
    }
    return $false
}

function Get-FolderPurpose([string]$Name) {
    $t = Get-Normalized $Name
    foreach ($r in $GenericExRx) { if ($r.IsMatch($t)) { return $null } }
    foreach ($k in $FolderKeywordRx) { if ($k.rx.IsMatch($t)) { return $k.purpose } }
    return $null
}

function Add-Folders([string]$Dir, [int]$Level, [int]$Depth, [bool]$Generic) {
    $children = @()
    try { $children = (New-Object IO.DirectoryInfo $Dir).GetDirectories() } catch { return }
    foreach ($c in $children) {
        $low = $c.Name.ToLowerInvariant()
        if ($SkipDirs -contains $low -or $FolderSkipDirs -contains $low -or $low.StartsWith('.') -or $low.StartsWith('$')) { continue }
        if (Test-Reparse $c.Attributes) { continue }
        $purpose = $null
        if (Find-CatalogEntry @($c.Name)) {
            $s = New-Source 'folder' $c.Name
            $s.location = $c.FullName
            [void]$Sources.Add($s)
        } elseif ($Generic -and ($purpose = Get-FolderPurpose $c.Name) -and (Test-AppFolder $c)) {
            $s = New-Source 'folder' $c.Name
            $s.location = $c.FullName
            $s.purpose = $purpose
            [void]$Sources.Add($s)
        } elseif ($Level -lt $Depth) {
            Add-Folders $c.FullName ($Level + 1) $Depth $Generic
        }
    }
}
foreach ($d in $ProgramDirs) { Add-Folders $d 1 2 $false }
foreach ($d in @($ShallowDirs) + @($Desktops)) { Add-Folders $d 1 3 $true }

# ---------------------------------------------------------------------------
# 容量・起動ファイル

$SizeCache = @{}
function Get-Size([string]$Path) {
    $k = $Path.TrimEnd('\').ToLowerInvariant()
    if ($SizeCache.ContainsKey($k)) { return $SizeCache[$k] }
    $total = [int64]0
    if ([IO.File]::Exists($Path)) {
        try { $total = (New-Object IO.FileInfo $Path).Length } catch { }
    } else {
        $stack = New-Object System.Collections.Stack
        $stack.Push($Path)
        while ($stack.Count -gt 0) {
            $d = $stack.Pop()
            $items = @()
            try { $items = (New-Object IO.DirectoryInfo $d).GetFileSystemInfos() } catch { continue }
            foreach ($i in $items) {
                if (Test-Reparse $i.Attributes) { continue }
                if ($i -is [IO.DirectoryInfo]) { $stack.Push($i.FullName) } else { $total += $i.Length }
            }
        }
    }
    $SizeCache[$k] = $total
    return $total
}

function Find-LaunchFile([string]$Folder, $Exes) {
    $script:LfWanted = @{}
    $n = 0
    foreach ($x in @($Exes)) {
        if ($x -and -not $script:LfWanted.ContainsKey($x)) { $script:LfWanted[$x] = $n }
        $n++
    }
    $script:LfBest = $null
    $script:LfFallback = New-Object System.Collections.ArrayList
    Find-LaunchWalk $Folder 1
    if ($script:LfBest) { return $script:LfBest.path }
    if ($script:LfFallback.Count -gt 0) {
        $f = $script:LfFallback | Sort-Object -Property @{ Expression = 'level'; Ascending = $true },
            @{ Expression = 'size'; Descending = $true } | Select-Object -First 1
        return $f.path
    }
    return $null
}

function Find-LaunchWalk([string]$Dir, [int]$Level) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $low = $i.Name.ToLowerInvariant()
        if ($i -is [IO.DirectoryInfo]) {
            if (Test-Reparse $i.Attributes) { continue }
            if ($Level -lt 3 -and -not ($SkipDirs -contains $low) -and -not ($LaunchSkipDirs -contains $low) -and
                -not $low.StartsWith('.') -and -not $low.StartsWith('_')) {
                Find-LaunchWalk $i.FullName ($Level + 1)
            }
            continue
        }
        if ($script:LfWanted.ContainsKey($low)) {
            $rank = $script:LfWanted[$low]
            $b = $script:LfBest
            if (-not $b -or $rank -lt $b.rank -or ($rank -eq $b.rank -and $Level -lt $b.level)) {
                $script:LfBest = [pscustomobject]@{ rank = $rank; level = $Level; path = $i.FullName }
            }
        } elseif ($low.EndsWith('.exe') -and -not $ExeSkip.IsMatch($low) -and $Level -le 2) {
            [void]$script:LfFallback.Add([pscustomobject]@{ level = $Level; size = $i.Length; path = $i.FullName })
        }
    }
}

function Test-UsableTarget([string]$p) {
    if (-not (Test-Exists $p)) { return $false }
    if ($p.ToLowerInvariant().Contains('\windows\installer')) { return $false }
    return -not $ExeSkip.IsMatch((Get-Leaf $p))
}

function Test-DesktopLike([string]$p) {
    return @('desktop', 'デスクトップ', 'downloads', 'ダウンロード') -contains (Get-Leaf $p).ToLowerInvariant()
}


# ---------------------------------------------------------------------------
# 実行環境・フォルダ移動の可否

function Read-TextSafe([string]$Path, [int]$MaxBytes = 262144) {
    try {
        $fi = New-Object IO.FileInfo $Path
        if (-not $fi.Exists -or $fi.Length -gt $MaxBytes) { return '' }
        $bytes = [IO.File]::ReadAllBytes($Path)
        $utf8 = New-Object Text.UTF8Encoding($false, $true)
        try { return $utf8.GetString($bytes) } catch { return [Text.Encoding]::Default.GetString($bytes) }
    } catch { return '' }
}

function Get-GitRemote([string]$Dir) {
    $text = Read-TextSafe (Join-Path $Dir '.git\config')
    $m = [regex]::Match($text, '(?m)^\s*url\s*=\s*(\S+)')
    if (-not $m.Success) { return '' }
    $u = $m.Groups[1].Value
    if ($u -match '^git@([^:]+):(.+)$') { $u = 'https://' + $Matches[1] + '/' + $Matches[2] }
    if ($u -notmatch '^https?://') { return '' }
    return ($u -replace '\.git$', '')
}

function Get-ReadmeSummary([string]$Dir) {
    foreach ($n in @('README_ja.md', 'README.ja.md', 'README-ja.md', 'README.md', 'readme.md', 'README.txt', 'readme.txt')) {
        $text = Read-TextSafe (Join-Path $Dir $n)
        if (-not $text) { continue }
        $inCode = $false
        foreach ($line in ($text -split "`r?`n")) {
            $t = $line.Trim()
            if ($t.StartsWith('```')) { $inCode = -not $inCode; continue }
            if ($inCode -or -not $t -or $t.StartsWith('#') -or $t.StartsWith('<') -or $t.StartsWith('![') -or
                $t.StartsWith('[!') -or $t.StartsWith('|') -or $t.StartsWith('---') -or $t.StartsWith('[![')) { continue }
            $t = [regex]::Replace($t, '!\[[^\]]*\]\([^)]*\)', '')
            $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
            $t = $t.Replace('**', '').Replace('`', '').Trim()
            if ($t.Length -lt 8) { continue }
            if ($t.Length -gt 180) { $t = $t.Substring(0, 180) + '…' }
            return $t
        }
    }
    return ''
}


function Clean-MarkdownLine([string]$t) {
    $t = [regex]::Replace($t, '!\[[^\]]*\]\([^)]*\)', '')
    $t = [regex]::Replace($t, '\[([^\]]*)\]\([^)]*\)', '$1')
    $t = [regex]::Replace($t, '<[^>]+>', '')
    $t = $t.Replace('**', '').Replace('__', '').Replace('`', '').Trim()
    if ($t.Length -gt 200) { $t = $t.Substring(0, 200) + '…' }
    return $t
}

# フォルダ内の README・package.json・pyproject.toml・起動スクリプトから、概要・機能・使い方を読み取る
function Get-LocalProjectInfo([string]$Dir) {
    $info = [pscustomobject]@{ overview = ''; features = @(); usage = @(); urls = @(); packageName = '' }
    $readme = ''
    foreach ($n in @('README_ja.md', 'README.ja.md', 'README-ja.md', 'README.md', 'readme.md', 'Readme.md', 'README.txt', 'readme.txt', 'README')) {
        $readme = Read-TextSafe (Join-Path $Dir $n) 1048576
        if ($readme) { break }
    }
    $features = New-Object System.Collections.ArrayList
    $usage = New-Object System.Collections.ArrayList
    if ($readme) {
        $info.overview = Get-ReadmeSummary $Dir
        $section = ''
        $inCode = $false
        foreach ($line in ($readme -split "`r?`n")) {
            $t = $line.Trim()
            if ($t.StartsWith('```')) { $inCode = -not $inCode; continue }
            if (-not $inCode -and $t -match '^#{1,6}\s*(.+)$') {
                $h = $Matches[1].ToLowerInvariant()
                if ($h -match '(feature|機能|特徴|what it does|highlight|できること|overview|概要)') { $section = 'f' }
                elseif ($h -match '(usage|使い方|使用方法|getting started|quick ?start|how to|run|起動|実行|install|インストール|setup|セットアップ|導入|docker)') { $section = 'u' }
                else { $section = '' }
                continue
            }
            if (-not $section -or -not $t) { continue }
            if ($inCode) {
                if ($section -eq 'u' -and $usage.Count -lt 12 -and -not $t.StartsWith('#')) { [void]$usage.Add('コマンド: ' + $t) }
                continue
            }
            $m = [regex]::Match($t, '^([-*+]|\d+[.)])\s+(.+)$')
            if (-not $m.Success) { continue }
            $item = Clean-MarkdownLine $m.Groups[2].Value
            if ($item.Length -lt 2) { continue }
            if ($section -eq 'f' -and $features.Count -lt 12) { [void]$features.Add($item) }
            elseif ($section -eq 'u' -and $usage.Count -lt 12) { [void]$usage.Add($item) }
        }
    }
    # package.json (Node.js)
    $pkgText = Read-TextSafe (Join-Path $Dir 'package.json')
    if ($pkgText) {
        try {
            $pkg = $pkgText | ConvertFrom-Json
            if ($pkg.name) { $info.packageName = [string]$pkg.name }
            if ($pkg.description -and -not $info.overview) { $info.overview = [string]$pkg.description }
            if ($pkg.scripts) {
                foreach ($k in @('dev', 'start', 'serve', 'server', 'build')) {
                    $v = $pkg.scripts.$k
                    if ($v -and $usage.Count -lt 14) { [void]$usage.Add("npm run $k  (実行される内容: $v)") }
                }
                if ($usage.Count -gt 0 -and -not (Test-Exists (Join-Path $Dir 'node_modules') -Folder)) {
                    [void]$usage.Insert(0, '初回のみ: このフォルダで npm install を実行して必要なパッケージを入れる')
                }
            }
        } catch { }
    }
    # pyproject.toml / setup.py (Python)
    $pyText = Read-TextSafe (Join-Path $Dir 'pyproject.toml')
    if ($pyText -and -not $info.overview) {
        $m = [regex]::Match($pyText, '(?m)^\s*description\s*=\s*"([^"]+)"')
        if ($m.Success) { $info.overview = $m.Groups[1].Value }
    }
    if ((Test-Exists (Join-Path $Dir 'requirements.txt')) -and $usage.Count -eq 0) {
        [void]$usage.Add('初回のみ: pip install -r requirements.txt で必要なライブラリを入れる')
    }
    foreach ($py in @('app.py', 'main.py', 'server.py', 'webui.py', 'launch.py', 'run.py')) {
        if ((Test-Exists (Join-Path $Dir $py)) -and $usage.Count -lt 14) { [void]$usage.Add("python $py で起動 (このフォルダで実行)"); break }
    }
    # 待ち受けるポート (ブラウザで開くアドレス)
    $ports = New-Object System.Collections.ArrayList
    $texts = @($pkgText)
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object {
                @('.py', '.js', '.ts', '.bat', '.cmd', '.env', '.json', '.yml', '.yaml', '.toml', '.ini') -contains $_.Extension.ToLowerInvariant() -or $_.Name -eq '.env' } |
            Select-Object -First 40)) {
        $texts += Read-TextSafe $f.FullName 131072
    }
    foreach ($t in $texts) {
        if (-not $t) { continue }
        foreach ($m in [regex]::Matches($t, '(?i)(?:--port[= ]+|\bport\s*[=:]\s*["'']?|localhost:|127\.0\.0\.1:|0\.0\.0\.0:)(\d{2,5})\b')) {
            $pn = [int]$m.Groups[1].Value
            if ($pn -ge 80 -and $pn -le 65535 -and -not $ports.Contains($pn)) { [void]$ports.Add($pn) }
        }
    }
    $info.urls = @($ports | Select-Object -First 3 | ForEach-Object { "http://localhost:$_" })
    $info.features = @($features.ToArray())
    $info.usage = @($usage.ToArray())
    return $info
}

function Get-PEArch([string]$Path) {
    try {
        $fs = [IO.File]::OpenRead($Path)
        try { $buf = New-Object byte[] 4096; $n = $fs.Read($buf, 0, 4096) } finally { $fs.Dispose() }
        if ($n -lt 64 -or $buf[0] -ne 0x4D -or $buf[1] -ne 0x5A) { return '' }
        $off = [BitConverter]::ToInt32($buf, 0x3C)
        if ($off -lt 0 -or $off + 6 -gt $n -or $buf[$off] -ne 0x50 -or $buf[$off + 1] -ne 0x45) { return '' }
        $mach = [BitConverter]::ToUInt16($buf, $off + 4)
        if ($mach -eq 0x8664) { return '64bit' }
        if ($mach -eq 0x14C) { return '32bit' }
        if ($mach -eq 0xAA64) { return 'ARM64' }
    } catch { }
    return ''
}

# フォルダ内を浅く調べて、実行環境の目印を集める
function Find-RuntimeMarkers([string]$Dir, [int]$Level, $M) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $low = $i.Name.ToLowerInvariant()
        if ($i -is [IO.DirectoryInfo]) {
            if (Test-Reparse $i.Attributes) { continue }
            if ($low -eq 'conda-meta') { [void]$M.conda.Add($Dir); continue }
            if ($low -eq 'node_modules') { $M.nodeModules = $true; continue }
            if (@('.git', '__pycache__', 'site-packages', 'models', 'checkpoints', 'output', 'outputs', 'cache') -contains $low) { continue }
            if ($Level -lt 3) { Find-RuntimeMarkers $i.FullName ($Level + 1) $M }
            continue
        }
        switch ($low) {
            'pyvenv.cfg' { [void]$M.venv.Add($Dir) }
            'python.exe' { if ((Get-Leaf $Dir).ToLowerInvariant() -ne 'scripts') { [void]$M.embedded.Add($Dir) } }
            'app.asar' { $M.electron = $true }
            'package.json' { if ($Level -le 2) { $M.node = $true } }
            'dockerfile' { if ($Level -le 2) { $M.docker = $true } }
            'docker-compose.yml' { if ($Level -le 2) { $M.docker = $true } }
            'docker-compose.yaml' { if ($Level -le 2) { $M.docker = $true } }
            'requirements.txt' { if ($Level -le 2) { $M.pyproject = $true } }
            'pyproject.toml' { if ($Level -le 2) { $M.pyproject = $true } }
            'environment.yml' { if ($Level -le 2) { $M.pyproject = $true } }
            default {
                if ($low.EndsWith('.jar') -and $Level -le 2) { $M.java = $true }
                if ($low.EndsWith('.py') -and $Level -eq 1) { $M.pyproject = $true }
                if ($Level -le 2 -and @('.bat', '.cmd', '.ps1') -contains $i.Extension.ToLowerInvariant()) { [void]$M.scripts.Add($i.FullName) }
                if ($Level -le 2 -and @('.json', '.yaml', '.yml', '.ini', '.cfg', '.toml', '.env') -contains $i.Extension.ToLowerInvariant() -and
                    $low -ne 'package.json' -and $low -ne 'package-lock.json' -and $low -ne 'pyvenv.cfg') { [void]$M.configs.Add($i.FullName) }
            }
        }
    }
}

function Get-PythonVersion([string]$EnvDir, [bool]$IsVenv) {
    if ($IsVenv) {
        $cfg = Read-TextSafe (Join-Path $EnvDir 'pyvenv.cfg')
        $m = [regex]::Match($cfg, '(?im)^\s*version(_info)?\s*=\s*(\d+\.\d+(\.\d+)?)')
        if ($m.Success) { return $m.Groups[2].Value }
    }
    try {
        foreach ($f in [IO.Directory]::GetFiles($EnvDir, 'python3*.dll')) {
            $m = [regex]::Match([IO.Path]::GetFileName($f), '^python3(\d+)\.dll$', 'IgnoreCase')
            if ($m.Success) { return '3.' + $m.Groups[1].Value }
        }
    } catch { }
    return ''
}

function Get-GpuInfo($EnvDirs) {
    $notes = @()
    foreach ($d in $EnvDirs) {
        foreach ($sp in @((Join-Path $d 'Lib\site-packages'), (Join-Path (Get-Parent $d) 'Lib\site-packages'))) {
            if (-not (Test-Exists $sp -Folder)) { continue }
            $torchLib = Join-Path $sp 'torch\lib'
            if (Test-Exists $torchLib -Folder) {
                $cuda = @()
                try { $cuda = [IO.Directory]::GetFiles($torchLib, 'torch_cuda*.dll') + [IO.Directory]::GetFiles($torchLib, 'cudnn*.dll') } catch { }
                if ($cuda.Count -gt 0) { $notes += 'NVIDIA GPU (CUDA) を使用' } else { $notes += 'PyTorch CPU 版 (GPU は使わない設定)' }
            }
            if (Test-Exists (Join-Path $sp 'torch_directml') -Folder) { $notes += 'DirectML (AMD / Intel の GPU も可)' }
            if (Test-Exists (Join-Path $sp 'onnxruntime\capi\onnxruntime_providers_cuda.dll')) { $notes += 'ONNX Runtime (CUDA)' }
        }
    }
    return (@($notes | Select-Object -Unique) -join '、')
}

function Get-RuntimeInfo($App, [string]$Location, [string]$Launch, $Kinds, $Shortcuts) {
    $r = [pscustomobject]@{ runtime = ''; gpu = ''; portable = '？'; portableReason = '' }
    $kindsArr = @($Kinds)
    if (@($kindsArr | Where-Object { $_ -ne 'url' }).Count -eq 0) {
        $r.runtime = 'Web ブラウザ (インターネット接続が必要)'
        $r.portable = '－'
        $r.portableReason = 'Web サービスのため、PC 内のフォルダの場所は関係ありません。'
        return $r
    }
    if (-not $Location) {
        if ($Launch -and (Get-Ext $Launch) -eq '.exe') {
            $arch = Get-PEArch $Launch
            $r.runtime = ('Windows アプリ ' + $arch).Trim()
        } elseif ($App.category -eq 'オーディオ設定・ドライバ') {
            $r.runtime = 'Windows ドライバ / 常駐ソフト'
        } else {
            $r.runtime = '不明'
        }
        if ($kindsArr -contains 'registry') {
            $r.portable = '×'
            $r.portableReason = 'インストーラーで導入されたソフトです。場所を変えると起動できなくなるため、移動したい場合はアンインストールしてから入れ直してください。'
        } else {
            $r.portableReason = 'インストール先が分からないため判定できません。'
        }
        return $r
    }

    $M = [pscustomobject]@{
        venv = (New-Object System.Collections.ArrayList); conda = (New-Object System.Collections.ArrayList)
        embedded = (New-Object System.Collections.ArrayList); scripts = (New-Object System.Collections.ArrayList)
        configs = (New-Object System.Collections.ArrayList)
        electron = $false; node = $false; nodeModules = $false; docker = $false; java = $false; pyproject = $false
    }
    Find-RuntimeMarkers $Location 1 $M

    # 実行環境
    $parts = @()
    $envDirs = @()
    foreach ($d in $M.venv) {
        $ver = Get-PythonVersion $d $true
        $rel = $d.Substring([Math]::Min($Location.Length, $d.Length)).TrimStart('\')
        if (-not $rel) { $rel = '(フォルダ自体)' }
        $parts += ('Python ' + $ver + ' (仮想環境 venv: ' + $rel + ')').Replace('Python  ', 'Python ')
        $envDirs += $d
    }
    foreach ($d in $M.conda) { $parts += 'Python (conda 環境)'; $envDirs += $d }
    $emb = @($M.embedded | Where-Object { $M.venv -notcontains $_ -and $M.conda -notcontains $_ })
    if ($emb.Count -gt 0) {
        $ver = Get-PythonVersion $emb[0] $false
        $parts += ('Python ' + $ver + ' (同梱版。PC に Python を入れなくても動く)').Replace('Python  ', 'Python ')
        $envDirs += $emb
    }
    if ($M.pyproject -and $envDirs.Count -eq 0) { $parts += 'Python (PC にインストールした Python を使用)' }
    if ($M.electron) { $parts += 'Electron デスクトップアプリ (実行環境は同梱)' }
    elseif ($M.node) {
        if ($M.nodeModules) { $parts += 'Node.js (PC に Node.js が必要)' } else { $parts += 'Node.js (PC に Node.js が必要・npm install 未実行の可能性)' }
    }
    if ($M.java) { $parts += 'Java (PC に Java が必要)' }
    if ($parts.Count -eq 0) {
        $exe = $Launch
        if (-not $exe -or (Get-Ext $exe) -ne '.exe') { $exe = $null }
        $arch = if ($exe) { Get-PEArch $exe } else { '' }
        if ($exe) { $parts += ('Windows ネイティブアプリ ' + $arch).Trim() }
        elseif ($App.category -eq $PluginCategory) { $parts += 'DAW 用プラグイン / 管理ツール' }
        else { $parts += '不明' }
    }
    if ($M.docker) { $parts += 'Docker でも起動可' }
    $r.runtime = $parts -join ' + '
    $r.gpu = Get-GpuInfo $envDirs

    # フォルダ移動の可否 (○ 移動しても動く / △ 条件付き / × 動かなくなる)
    $level = 0
    $reasons = New-Object System.Collections.ArrayList
    $lowLoc = $Location.ToLowerInvariant()
    if ($kindsArr -contains 'registry') {
        $level = 2
        [void]$reasons.Add('インストーラーで導入されたソフトです (場所がレジストリやスタートメニューに登録されています)。移動したい場合はアンインストールしてから、インストール先を指定して入れ直してください。')
    }
    if ($App.category -eq $PluginCategory -and $level -lt 2) {
        $level = 2
        [void]$reasons.Add('DAW は決まったフォルダからプラグインを読み込むため、移動すると認識されなくなります。')
    }
    if ($lowLoc.Contains('\pinokio\api\')) {
        $level = 2
        [void]$reasons.Add('Pinokio が管理するアプリです。Pinokio の画面から起動する前提のため、移動すると Pinokio から使えなくなります。')
    }
    if ($lowLoc.Contains('\stabilitymatrix\') -or $lowLoc.Contains('\data\packages\')) {
        $level = 2
        [void]$reasons.Add('Stability Matrix が管理するアプリです。移動する場合は Stability Matrix の設定から行ってください。')
    }
    if ($M.venv.Count -gt 0) {
        $level = 2
        [void]$reasons.Add('Python の仮想環境 (venv) は作った時の場所を記録しているため、移動すると起動用の命令 (activate・pip など) が動かなくなります。移動後に venv を作り直せば動きます (例: python -m venv venv → pip install -r requirements.txt)。')
    }
    if ($M.conda.Count -gt 0) {
        $level = 2
        [void]$reasons.Add('conda 環境は場所が固定されています。移動後は環境を作り直してください。')
    }
    $scripts = @($M.scripts)
    if ($Launch -and @('.bat', '.cmd', '.ps1') -contains (Get-Ext $Launch) -and $scripts -notcontains $Launch) { $scripts += $Launch }
    foreach ($f in $scripts) {
        $text = Read-TextSafe $f
        if (-not $text) { continue }
        $name = Get-Leaf $f
        if ($text.ToLowerInvariant().Contains($lowLoc) -or $text.ToLowerInvariant().Contains($lowLoc.Replace('\', '/'))) {
            $level = 2
            [void]$reasons.Add("起動ファイル「$name」に今のフォルダの場所 ($Location) が直接書かれています。移動後はこの部分を書き換える必要があります。")
        } else {
            $m = [regex]::Match($text, '(?i)(?<![\w%])[a-z]:[\\/][^\r\n"''<>|*?]{1,80}')
            if ($m.Success -and $m.Value -notmatch '(?i)^[a-z]:[\\/]windows') {
                if ($level -lt 1) { $level = 1 }
                [void]$reasons.Add("起動ファイル「$name」が別の場所 ($($m.Value.Trim())) を使っています。その場所がそのまま残っていれば、移動しても動きます。")
            }
        }
    }
    foreach ($f in @($M.configs)) {
        $text = Read-TextSafe $f
        if (-not $text) { continue }
        $low = $text.ToLowerInvariant()
        if ($low.Contains($lowLoc) -or $low.Contains($lowLoc.Replace('\', '\\')) -or $low.Contains($lowLoc.Replace('\', '/'))) {
            if ($level -lt 1) { $level = 1 }
            [void]$reasons.Add("設定ファイル「$(Get-Leaf $f)」に今のフォルダの場所が書かれています。移動後はその部分を新しい場所に書き換えてください。")
        }
    }
    if ($level -eq 0) {
        if ($emb.Count -gt 0) { [void]$reasons.Add('Python ごとフォルダ内に入っているため、フォルダごと移動しても動きます。') }
        elseif ($M.pyproject) { [void]$reasons.Add('フォルダごと移動しても動きます (PC にインストールした Python とライブラリを使います)。') }
        elseif ($M.node -or $M.electron) { [void]$reasons.Add('必要なファイルがフォルダ内にそろっているため、フォルダごと移動しても動きます。') }
        else { [void]$reasons.Add('場所に依存する設定は見つかりませんでした。フォルダごと移動しても動く見込みです。') }
    }
    if ($level -lt 2 -and @($Shortcuts).Count -gt 0) { [void]$reasons.Add('デスクトップなどのショートカットは移動後に作り直してください。') }
    $r.portable = @('○', '△', '×')[$level]
    $r.portableReason = ($reasons | Select-Object -Unique) -join ' '
    return $r
}

# ---------------------------------------------------------------------------
# 4. まとめる

$Apps = [ordered]@{}
foreach ($s in $Sources) {
    $names = @($s.name)
    if ($s.target) { $names += Get-Stem $s.target }
    if ($s.location) { $names += Get-Leaf $s.location }
    $entry = Find-CatalogEntry $names
    if (-not $entry -and $s.kind -eq 'url') { continue }
    if ($entry) {
        $key = $entry.id
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $entry.name; category = $entry.category; purpose = $entry.purpose
                url = $entry.url; howto = $entry.howto; launchNote = $entry.launch_note; exes = @($entry.exes)
                features = @($entry.features); usage = @($entry.usage)
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } elseif ($s.kind -eq 'registry' -and (Test-Musical $s.name)) {
        $key = 'other:' + $s.name.ToLowerInvariant()
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $s.name; category = $OtherCategory
                purpose = 'カタログ未登録のため自動判定。名前から音楽関連ソフトの可能性があります。'
                url = [string]$s.url; howto = '公式ページのマニュアルを参照してください。'; launchNote = ''; exes = @()
                features = @(); usage = @()
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } elseif ($s.kind -eq 'folder' -and $s.purpose) {
        $key = 'folder:' + $s.location.ToLowerInvariant()
        if (-not $Apps.Contains($key)) {
            $Apps[$key] = [pscustomobject]@{
                key = $key; name = $s.name; category = $OtherCategory; purpose = $s.purpose
                url = ''; howto = 'フォルダ内の README (説明書) を参照してください。'; launchNote = ''; exes = @('start.bat', 'run.bat', 'webui.bat', 'start.cmd', 'run.cmd')
                features = @(); usage = @()
                sources = (New-Object System.Collections.ArrayList)
            }
        }
    } else {
        continue
    }
    [void]$Apps[$key].sources.Add($s)
}

Write-Step ("{0} 件のアプリが見つかりました。容量と起動ファイルを調べています (数分かかることがあります)…" -f $Apps.Count)
$Result = New-Object System.Collections.ArrayList
foreach ($app in $Apps.Values) {
    Write-Step ('  - ' + $app.name)
    $src = @($app.sources)
    $names = New-Object System.Collections.ArrayList
    $kinds = New-Object System.Collections.ArrayList
    $shortcuts = New-Object System.Collections.ArrayList
    $version = ''; $publisher = ''; $webUrl = $null
    foreach ($s in $src) {
        if (-not $names.Contains($s.name)) { [void]$names.Add($s.name) }
        if (-not $kinds.Contains($s.kind)) { [void]$kinds.Add($s.kind) }
        if ($s.version -and -not $version) { $version = $s.version }
        if ($s.publisher -and -not $publisher) { $publisher = $s.publisher }
        if ($s.kind -eq 'url' -and -not $webUrl) { $webUrl = $s.url }
        if ($s.shortcut -and -not $shortcuts.Contains($s.shortcut) -and -not $ShortcutSkip.IsMatch((Get-Stem $s.shortcut))) {
            [void]$shortcuts.Add($s.shortcut)
        }
    }

    # インストール先: レジストリの InstallLocation > レジストリの DisplayIcon の場所 > 一致したフォルダ
    #                 > ショートカットのリンク先の場所
    $regTargets = @($src | Where-Object { $_.kind -eq 'registry' -and $_.target -and (Test-UsableTarget $_.target) } |
        ForEach-Object { $_.target })
    $scTargets = @($src | Where-Object { $_.kind -eq 'shortcut' -and $_.target -and (Test-UsableTarget $_.target) } |
        ForEach-Object { $_.target })
    $locs = @()
    $locs += @($src | Where-Object { $_.kind -eq 'registry' -and $_.location } | ForEach-Object { $_.location })
    $locs += @($regTargets | ForEach-Object { Get-Parent $_ })
    $locs += @($src | Where-Object { $_.kind -eq 'folder' } | ForEach-Object { $_.location })
    $locs += @($scTargets | ForEach-Object { Get-Parent $_ } | Where-Object { $_ -and -not (Test-DesktopLike $_) })
    $location = $null
    foreach ($l in $locs) {
        if (-not $l) { continue }
        $k = $l.TrimEnd('\').ToLowerInvariant()
        if ($NotLocation.ContainsKey($k) -or $k.Length -le 3) { continue }
        if (Test-Exists $l -Folder) { $location = $l.TrimEnd('\'); break }
    }

    # 起動ファイル: カタログの起動ファイル名 > ショートカットのリンク先 > DisplayIcon > フォルダ内の主な exe
    $launch = $null
    if ($location -and @($app.exes).Count -gt 0) { $launch = Find-LaunchFile $location $app.exes }
    if (-not $launch) {
        $launch = @(@($scTargets) + @($regTargets) | Where-Object { $LaunchExts -contains (Get-Ext $_) }) |
            Select-Object -First 1
    }
    if (-not $launch -and $location) { $launch = Find-LaunchFile $location @() }
    if (-not $launch) {
        $launch = @($src | Where-Object { $_.kind -eq 'url' -and $_.shortcut } | ForEach-Object { $_.shortcut }) |
            Select-Object -First 1
    }

    $launch = @($launch | Where-Object { $_ } | ForEach-Object { [string]$_ }) | Select-Object -First 1

    # 容量
    $size = $null; $sizeNote = ''
    if ($location) { $size = [int64](@(Get-Size $location) | Select-Object -Last 1); $sizeNote = 'フォルダ実測' }
    if (-not $size) {
        $reg = @($src | Where-Object { $_.size } | ForEach-Object { $_.size })
        if ($reg.Count -gt 0) {
            $size = [int64](($reg | Measure-Object -Maximum).Maximum)
            $sizeNote = 'インストール情報の推定値'
        } elseif (@($src | Where-Object { $_.kind -ne 'url' }).Count -eq 0) {
            $size = $null
            $sizeNote = 'Web サービスのため PC の容量は使いません'
        }
    }

    $purpose = $app.purpose
    $url = $app.url
    $features = @($app.features)
    $usage = @($app.usage)
    $localUrls = @()
    $packageName = ''
    if ($location -and ($app.key.StartsWith('folder:') -or $features.Count -eq 0)) {
        $pi = Get-LocalProjectInfo $location
        if ($pi.overview) { $purpose = $purpose + ' README より: ' + $pi.overview }
        if ($features.Count -eq 0) { $features = @($pi.features) }
        if ($usage.Count -eq 0) { $usage = @($pi.usage) }
        $localUrls = @($pi.urls)
        $packageName = $pi.packageName
        if ($localUrls.Count -gt 0 -and $app.key.StartsWith('folder:')) { $usage += ('起動したら、ブラウザで ' + ($localUrls -join ' または ') + ' を開く') }
    }
    if ($location -and -not $url) { $url = Get-GitRemote $location }
    $rt = Get-RuntimeInfo $app $location $launch @($kinds.ToArray()) @($shortcuts.ToArray())

    [void]$Result.Add([pscustomobject]@{
        name = $app.name; category = $app.category; purpose = $purpose; url = $url; howto = $app.howto
        launchNote = $app.launchNote; location = $location; size = $size; sizeNote = $sizeNote
        launchFile = $launch; shortcuts = @($shortcuts.ToArray()); version = $version; publisher = $publisher
        features = @($features); usage = @($usage); localUrls = @($localUrls); packageName = $packageName
        names = @($names.ToArray()); kinds = @($kinds.ToArray()); webUrl = $webUrl
        runtime = $rt.runtime; gpu = $rt.gpu; portable = $rt.portable; portableReason = $rt.portableReason
    })
}

# ---------------------------------------------------------------------------
# 5. インターネットショートカット (.url など): リンク先を調べて音楽系かどうかを判定する

Write-Step 'インターネットショートカットを探しています…'
$WebServices = @($Catalog.webServices)
$WebKeywordRx = @($Catalog.webKeywords | ForEach-Object { New-Object Text.RegularExpressions.Regex($_, $RxOpt) })
$HubKind = 'AI モデル・コード公開サイト'

function Find-UrlFiles([string]$Dir, [int]$Level, [int]$Depth, [string]$From = '') {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        if ($i -is [IO.DirectoryInfo]) {
            $low = $i.Name.ToLowerInvariant()
            if ($Level -ge $Depth -or $SkipDirs -contains $low -or $FolderSkipDirs -contains $low -or $low.StartsWith('.') -or
                $low.StartsWith('$') -or (Test-Reparse $i.Attributes)) { continue }
            Find-UrlFiles $i.FullName ($Level + 1) $Depth $From
            continue
        }
        if ($i.Extension.ToLowerInvariant() -ne '.url') { continue }
        $k = $i.FullName.ToLowerInvariant()
        if ($script:SeenUrlFiles.ContainsKey($k)) { continue }
        $script:SeenUrlFiles[$k] = $true
        $text = Read-TextSafe $i.FullName 65536
        $m = [regex]::Match($text, '(?im)^\s*URL\s*=\s*(\S+)')
        if (-not $m.Success) { continue }
        $u = $m.Groups[1].Value
        if ($u -notmatch '^(?i)https?://') { continue }
        [void]$LinkFiles.Add([pscustomobject]@{ path = $i.FullName; url = $u; name = [IO.Path]::GetFileNameWithoutExtension($i.Name); from = $From })
    }
}
$script:SeenUrlFiles = @{}
foreach ($d in @($Desktops)) { Find-UrlFiles $d 1 5 }
foreach ($d in @($ShallowDirs)) { Find-UrlFiles $d 1 4 }
foreach ($d in @($StartMenus)) { Find-UrlFiles $d 1 3 }
$fav = [Environment]::GetFolderPath('Favorites')
if ($fav -and (Test-Exists $fav -Folder)) { Find-UrlFiles $fav 1 4 'favorites' }

function Find-WebService([string]$HostName) {
    foreach ($w in $WebServices) {
        foreach ($d in @($w.domains)) {
            if ($HostName -eq $d -or $HostName.EndsWith('.' + $d)) { return $w }
        }
    }
    return $null
}

function Test-WebMusic([string]$Text) {
    if (-not $Text) { return $false }
    foreach ($r in $WebKeywordRx) { if ($r.IsMatch($Text)) { return $true } }
    return $false
}

# 親フォルダの名前 (music_ai など) が音楽系なら、その名前を返す
function Get-MusicFolderContext([string]$Path) {
    $d = Get-Parent $Path
    $n = 0
    while ($d -and $n -lt 6) {
        $leaf = Get-Leaf $d
        if (-not $leaf -or $NotLocation.ContainsKey($d.TrimEnd('\').ToLowerInvariant())) { break }
        if ((Get-FolderPurpose $leaf) -or (Find-CatalogEntry @($leaf))) { return $leaf }
        $d = Get-Parent $d
        $n++
    }
    return ''
}

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 -bor 12288 } catch {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }
}

# リンク先のページを読み、タイトルと説明文を取り出す
function Get-WebPageInfo([string]$Url) {
    $r = [pscustomobject]@{ title = ''; description = ''; error = '' }
    try {
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.Timeout = 8000
        $req.ReadWriteTimeout = 8000
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
        $req.Accept = 'text/html,application/xhtml+xml,*/*;q=0.8'
        $req.Headers.Add('Accept-Language', 'ja,en;q=0.8')
        $req.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $resp = $req.GetResponse()
        try {
            $ct = [string]$resp.ContentType
            $stream = $resp.GetResponseStream()
            $ms = New-Object IO.MemoryStream
            $buf = New-Object byte[] 65536
            while ($ms.Length -lt 786432) {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $ms.Write($buf, 0, $n)
            }
            $bytes = $ms.ToArray()
        } finally { $resp.Close() }
        $cs = ''
        $m = [regex]::Match($ct, '(?i)charset=([\w-]+)')
        if ($m.Success) { $cs = $m.Groups[1].Value }
        if (-not $cs) {
            $head = [Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min($bytes.Length, 8192))
            $m = [regex]::Match($head, '(?i)<meta[^>]+charset\s*=\s*["'']?([\w-]+)')
            if ($m.Success) { $cs = $m.Groups[1].Value }
        }
        $enc = [Text.Encoding]::UTF8
        if ($cs) { try { $enc = [Text.Encoding]::GetEncoding($cs) } catch { } }
        $html = $enc.GetString($bytes)
        $title = ''
        foreach ($pat in @('(?is)<meta[^>]+property\s*=\s*["'']og:title["''][^>]*content\s*=\s*"([^"]*)"',
                '(?is)<meta[^>]+content\s*=\s*"([^"]*)"[^>]*property\s*=\s*["'']og:title["'']',
                '(?is)<title[^>]*>(.*?)</title>')) {
            $m = [regex]::Match($html, $pat)
            if ($m.Success -and $m.Groups[1].Value.Trim()) { $title = $m.Groups[1].Value; break }
        }
        $desc = ''
        foreach ($pat in @('(?is)<meta[^>]+(?:name|property)\s*=\s*["''](?:og:)?description["''][^>]*content\s*=\s*"([^"]*)"',
                '(?is)<meta[^>]+content\s*=\s*"([^"]*)"[^>]*(?:name|property)\s*=\s*["''](?:og:)?description["'']')) {
            $m = [regex]::Match($html, $pat)
            if ($m.Success -and $m.Groups[1].Value.Trim()) { $desc = $m.Groups[1].Value; break }
        }
        $r.title = ([Net.WebUtility]::HtmlDecode($title) -replace '\s+', ' ').Trim()
        $r.description = ([Net.WebUtility]::HtmlDecode($desc) -replace '\s+', ' ').Trim()
        if ($r.description.Length -gt 300) { $r.description = $r.description.Substring(0, 300) + '…' }
    } catch {
        $msg = $_.Exception.Message
        if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
        $r.error = $msg
    }
    return $r
}

$Links = [ordered]@{}
$NonMusicLinks = New-Object System.Collections.ArrayList
$PageCache = @{}
$total = $LinkFiles.Count
Write-Step ("{0} 件のインターネットショートカットが見つかりました。リンク先を確認しています…" -f $total)
$idx = 0
foreach ($lf in $LinkFiles) {
    $idx++
    $uri = $null
    try { $uri = [Uri]$lf.url } catch { continue }
    $hostName = $uri.Host.ToLowerInvariant()
    if ($hostName.StartsWith('www.')) { $hostName = $hostName.Substring(4) }
    $svc = Find-WebService $hostName
    $isHub = ($svc -and $svc.kind -eq $HubKind)
    $isLocal = @('localhost', '127.0.0.1', '0.0.0.0', '::1') -contains $hostName
    $folderCtx = Get-MusicFolderContext $lf.path
    $urlText = [Uri]::UnescapeDataString($uri.AbsolutePath + ' ' + $uri.Query) + ' ' + $hostName
    $entry = Find-CatalogEntry @($lf.name)
    if (-not $entry -and $hostName -eq 'github.com') {
        foreach ($e in $Catalog.entries) {
            if ($e.url -and $e.url.ToLowerInvariant().StartsWith('https://github.com' + $uri.AbsolutePath.ToLowerInvariant().TrimEnd('/'))) {
                if ($uri.AbsolutePath.Trim('/').Split('/').Count -ge 2) { $entry = $e; break }
            }
        }
    }

    # 既知のサービス以外はリンク先を読んでタイトル・説明を得る (GitHub などはリポジトリの説明が分かる)
    $page = $null
    $wantPage = (-not $isLocal -and (-not $svc -or $isHub) -and ($lf.from -ne 'favorites' -or $folderCtx -or $isHub))
    if ($wantPage) {
        $ck = $lf.url.ToLowerInvariant()
        if (-not $PageCache.ContainsKey($ck) -and $PageCache.Count -ge 150) { $wantPage = $false }
    }
    if ($wantPage) {
        $ck = $lf.url.ToLowerInvariant()
        if (-not $PageCache.ContainsKey($ck)) {
            Write-Step ("  [{0}/{1}] {2}" -f $idx, $total, $lf.url)
            $PageCache[$ck] = Get-WebPageInfo $lf.url
        }
        $page = $PageCache[$ck]
    }
    $pageText = if ($page) { $page.title + ' ' + $page.description } else { '' }

    $reason = ''
    if ($entry) { $reason = "既知のアプリ「$($entry.name)」へのリンク" }
    elseif ($svc -and -not $isHub) { $reason = "既知の音楽系サービス「$($svc.name)」" }
    elseif (Test-WebMusic ($lf.name + ' ' + $urlText)) { $reason = 'ショートカット名・URL に音楽関連の語を含む' }
    elseif (Test-WebMusic $pageText) { $reason = 'リンク先ページのタイトル・説明に音楽関連の語を含む' }
    elseif ($folderCtx) { $reason = "音楽系のフォルダ「$folderCtx」に置かれている" }

    if (-not $reason) {
        [void]$NonMusicLinks.Add([pscustomobject]@{ name = $lf.name; url = $lf.url; path = $lf.path
            title = $(if ($page) { $page.title } else { '' }); error = $(if ($page) { $page.error } else { '' }) })
        continue
    }

    # 同じサービス・同じアプリへのリンクはまとめる
    if ($entry) { $gk = 'app:' + $entry.id }
    elseif ($svc -and -not $isHub) { $gk = 'svc:' + $svc.id }
    else { $gk = 'url:' + $lf.url.ToLowerInvariant().TrimEnd('/') }
    if (-not $Links.Contains($gk)) {
        $g = [pscustomobject]@{
            name = $lf.name; kind = ''; overview = ''; features = @(); usage = @(); officialUrl = ''
            reason = $reason; pageTitle = ''; pageDescription = ''; pageError = ''; host = $hostName
            urls = (New-Object System.Collections.ArrayList); shortcuts = (New-Object System.Collections.ArrayList)
            folders = (New-Object System.Collections.ArrayList); isLocal = $isLocal
        }
        if ($entry) {
            $g.name = $entry.name; $g.kind = $entry.category; $g.overview = $entry.purpose
            $g.features = @($entry.features); $g.usage = @($entry.usage); $g.officialUrl = $entry.url
        } elseif ($svc -and -not $isHub) {
            $g.name = $svc.name; $g.kind = $svc.kind; $g.overview = $svc.overview
            $g.features = @($svc.features); $g.usage = @($svc.usage); $g.officialUrl = 'https://' + @($svc.domains)[0] + '/'
        } else {
            if ($svc) { $g.kind = $svc.kind + ' (' + $svc.name + ')' }
            elseif ($isLocal) { $g.kind = 'この PC で動く Web 画面 (ローカルサーバー)' }
            else { $g.kind = 'Web ページ' }
            if ($page -and $page.title) { $g.name = $page.title }
            $parts = @()
            if ($page -and $page.description) { $parts += $page.description }
            if ($svc) { $parts += $svc.overview }
            if ($isLocal) { $parts += ('この PC 上のアプリ (ポート ' + $uri.Port + ') の画面です。そのアプリを起動している間だけ開けます。') }
            $g.overview = ($parts -join ' ')
            if ($svc) { $g.usage = @($svc.usage) }
            $g.officialUrl = $lf.url
        }
        if ($page) { $g.pageTitle = $page.title; $g.pageDescription = $page.description; $g.pageError = $page.error }
        $Links[$gk] = $g
    }
    $g = $Links[$gk]
    if (-not $g.urls.Contains($lf.url)) { [void]$g.urls.Add($lf.url) }
    [void]$g.shortcuts.Add($lf.path)
    $folder = Get-Parent $lf.path
    if ($folder -and -not $g.folders.Contains($folder)) { [void]$g.folders.Add($folder) }
}
$LinkResult = @($Links.Values | ForEach-Object {
        [pscustomobject]@{
            name = $_.name; kind = $_.kind; overview = $_.overview; features = @($_.features); usage = @($_.usage)
            officialUrl = $_.officialUrl; reason = $_.reason; pageTitle = $_.pageTitle; pageDescription = $_.pageDescription
            pageError = $_.pageError; host = $_.host; urls = @($_.urls.ToArray()); shortcuts = @($_.shortcuts.ToArray())
            folders = @($_.folders.ToArray()); isLocal = $_.isLocal
        }
    })

# ---------------------------------------------------------------------------
# 6. プラグイン

Write-Step 'VST / VST3 / CLAP / AAX プラグインを確認しています…'
$Plugins = New-Object System.Collections.ArrayList
$seenPlugin = @{}
function Add-Plugins([string]$Dir, [int]$Depth) {
    $items = @()
    try { $items = (New-Object IO.DirectoryInfo $Dir).GetFileSystemInfos() } catch { return }
    foreach ($i in $items) {
        $ext = $i.Extension.ToLowerInvariant()
        if ($PluginExts.ContainsKey($ext)) {
            $k = $i.FullName.ToLowerInvariant()
            if ($seenPlugin.ContainsKey($k)) { continue }
            $seenPlugin[$k] = $true
            [void]$Plugins.Add([pscustomobject]@{
                name = [IO.Path]::GetFileNameWithoutExtension($i.Name); format = $PluginExts[$ext]
                path = $i.FullName; folder = (Get-Parent $i.FullName); size = (Get-Size $i.FullName)
            })
        } elseif ($Depth -gt 1 -and $i -is [IO.DirectoryInfo] -and -not (Test-Reparse $i.Attributes)) {
            Add-Plugins $i.FullName ($Depth - 1)
        }
    }
}
foreach ($d in $PluginDirs) { Add-Plugins $d 3 }

# ---------------------------------------------------------------------------
# 7. HTML を書き出す

$Data = [pscustomobject]@{
    scannedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    computer = $env:COMPUTERNAME
    categories = @($Catalog.categories)
    apps = @($Result.ToArray())
    plugins = @($Plugins.ToArray())
    links = @($LinkResult)
    nonMusicLinks = @($NonMusicLinks.ToArray())
    roots = [pscustomobject]@{
        desktops = @($Desktops); startMenus = @($StartMenus); programDirs = @($ProgramDirs)
        shallowDirs = @($ShallowDirs); pluginDirs = @($PluginDirs)
    }
    errors = @($Errors.ToArray())
}
try {
    $json = ConvertTo-JsonText $Data
} catch {
    Write-Host "データの変換でエラーが発生しました: $_" -ForegroundColor Red
    $msg = ConvertTo-JsonText ([string]$_)
    $json = '{"apps":[],"plugins":[],"categories":[],"roots":{},"errors":[' + $msg + ']}'
}
$html = $Template.Replace('__DATA_JSON__', $json)

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Exists $desktop -Folder)) { $desktop = (Get-Location).Path }
$out = Join-Path $desktop '音楽アプリ一覧.html'
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding($false)))

Write-Host ''
if ($Errors.Count -gt 0) {
    Write-Host '一部でエラーがありました (HTML の最後にも載せています):' -ForegroundColor Yellow
    foreach ($e in $Errors) { Write-Host "  $e" -ForegroundColor Yellow }
}
Write-Host ("{0} 件のアプリ、{1} 件の音楽系リンク、{2} 件のプラグインを見つけました。" -f $Result.Count, @($LinkResult).Count, $Plugins.Count)
Write-Host "HTML を作成しました: $out"
try { Start-Process $out } catch { Write-Host 'ブラウザで開けませんでした。上のファイルをダブルクリックしてください。' }
