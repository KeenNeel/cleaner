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
  "DAW (作曲・録音・編集)",
  "楽譜作成・MIDI",
  "波形編集・録音・変換",
  "音源・プラグイン・管理ツール",
  "オーディオ設定・ドライバ",
  "その他 (音楽関連の可能性)"
 ],
 "entries": [
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
   "launch_note": "Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。"
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
   "launch_note": "Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。"
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
   "launch_note": ""
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
   "launch_note": "起動後に表示される http://127.0.0.1:xxxx をブラウザで開きます。"
  },
  {
   "id": "acestep",
   "name": "ACE-Step",
   "category": "AI作曲・音楽生成",
   "purpose": "歌詞とタグから歌入り楽曲を生成するオープンソースの音楽生成モデル。",
   "url": "https://github.com/ace-step/ACE-Step",
   "match": [
    "ace[\\s_-]?step"
   ],
   "exes": [
    "run.bat",
    "start.bat",
    "acestep.exe"
   ],
   "howto": "起動バッチで Gradio 画面を開き、Tags (ジャンル等) と Lyrics を入力して Generate。",
   "launch_note": "起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。"
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": "起動後に http://127.0.0.1:8188 をブラウザで開きます (デスクトップ版はアプリが直接開きます)。"
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": "起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。"
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": ""
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
   "launch_note": "単体では起動しません。DAW のオーディオ設定から選択して使います。"
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
   "launch_note": "単体では起動しません。DAW のオーディオ設定から選択して使います。"
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
   "launch_note": ""
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
   "launch_note": ""
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
th { cursor:pointer; user-select:none; background:var(--tag); }
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
<div id="errors"></div>
</main>
<script>const DATA = /*__DATA__*/null;</script>
<script>
(function () {
  'use strict';
  const D = DATA || { apps: [], plugins: [], categories: [], roots: {}, errors: [] };
  const arr = v => (v == null ? [] : Array.isArray(v) ? v : [v]);
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
    if (!steps.length) steps.push(a.category && a.category.indexOf('プラグイン') >= 0 ? 'DAW を起動し、プラグインとして読み込む' : 'スタートメニューからアプリ名で検索して起動');
    let text = steps.join(' / ');
    if (a.launchNote) text += '。' + a.launchNote;
    return text;
  }

  const order = {};
  arr(D.categories).forEach((c, i) => { order[c] = i; });
  const apps = arr(D.apps).slice().sort((a, b) => ((order[a.category] ?? 99) - (order[b.category] ?? 99)) || a.name.localeCompare(b.name, 'ja'));
  const plugins = arr(D.plugins).slice().sort((a, b) => a.format.localeCompare(b.format) || a.name.localeCompare(b.name, 'ja'));
  apps.forEach(a => { a.method = launchMethod(a); });

  document.getElementById('when').textContent = `スキャン日時: ${D.scannedAt || ''}` + (D.computer ? ` / PC: ${D.computer}` : '');
  const total = apps.reduce((s, a) => s + (Number(a.size) || 0), 0);
  const ptotal = plugins.reduce((s, p) => s + (Number(p.size) || 0), 0);
  document.getElementById('summary').innerHTML = [
    ['アプリ', apps.length + ' 件'], ['アプリ合計容量', human(total)],
    ['プラグイン', plugins.length + ' 件'], ['プラグイン合計容量', human(ptotal)],
  ].map(([k, v]) => `<div class="stat">${k}<b>${v}</b></div>`).join('');

  const cats = arr(D.categories).filter(c => apps.some(a => a.category === c));
  document.getElementById('cat').insertAdjacentHTML('beforeend', cats.map(c => `<option value="${esc(c)}">${esc(c)}</option>`).join(''));

  const sizeHtml = a => a.size ? `${human(a.size)} <span class="muted">(${esc(a.sizeNote)})</span>` : `<span class="muted">${esc(a.sizeNote || '不明')}</span>`;
  const searchText = a => [a.name, a.category, a.purpose].concat(arr(a.names)).join(' ').toLowerCase();

  document.getElementById('list').innerHTML = apps.length ? `
<table id="summary-table"><thead><tr><th>アプリ</th><th>カテゴリ</th><th>容量</th><th>起動ファイル</th></tr></thead><tbody>
${apps.map((a, i) => `<tr data-cat="${esc(a.category)}" data-search="${esc(searchText(a))}">
<td><a href="#app-${i}">${esc(a.name)}</a></td><td>${esc(a.category)}</td>
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
    <dt>用途</dt><dd>${esc(a.purpose)}</dd>
    <dt>公式ページ</dt><dd>${a.url ? `<a href="${esc(a.url)}" target="_blank" rel="noopener">${esc(a.url)}</a>` : '<span class="muted">不明</span>'}</dd>
    <dt>容量</dt><dd>${sizeHtml(a)}</dd>
    <dt>起動方法</dt><dd>${esc(a.method)}</dd>
    <dt>起動ファイル</dt><dd><code>${a.launchFile ? esc(a.launchFile) : '不明'}</code></dd>
    <dt>インストール先</dt><dd>${fileLink(a.location)}</dd>
    <dt>簡単な利用方法</dt><dd>${esc(a.howto)}</dd>
    ${sc ? `<dt>ショートカット</dt><dd><ul>${sc}</ul></dd>` : ''}
    <dt>検出元</dt><dd class="muted">${esc(kinds)} (${esc(arr(a.names).slice(0, 4).join(' / '))})</dd>
  </dl>
</article>`;
  }).join('');

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
    document.querySelectorAll('#cards .app, #summary-table tbody tr').forEach(el => {
      el.style.display = (!c || el.dataset.cat === c) && (!text || el.dataset.search.includes(text)) ? '' : 'none';
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

# 起動ファイルとして選ばないもの
$ExeSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|setup|install|update|crash|report|helper|service|vc_?redist|dotnet|python|pythonw|conhost|elevate|register|activation|repair|diag|bugsplat|cefsharp|squirrel|7z|ffmpeg|ffprobe)', $RxOpt)
# 一覧に載せないショートカット
$ShortcutSkip = New-Object Text.RegularExpressions.Regex(
    '(unins|uninstall|アンインストール|削除|readme|manual|マニュアル|help|ヘルプ|website|web site|homepage|license|ライセンス|changelog|release notes|documentation|ドキュメント)', $RxOpt)
$SkipDirs = @('windows', '$recycle.bin', 'system volume information', 'recovery', 'perflogs', 'msocache',
    '$windows.~bt', '$windows.~ws', '$winreagent', 'config.msi', 'programdata', 'users', 'program files',
    'program files (x86)', 'node_modules', '.git', '__pycache__', 'site-packages', 'appdata', '.cleaner_quarantine')
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
        size = $null; publisher = ''; version = ''
    }
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
            try {
                $lnk = $Shell.CreateShortcut($f.FullName)
                $s.target = Expand-PathText $lnk.TargetPath
                $s.location = Expand-PathText $lnk.WorkingDirectory
            } catch { }
            [void]$Sources.Add($s)
        } elseif ($ext -eq '.url') {
            $url = $null
            try {
                $m = [regex]::Match([IO.File]::ReadAllText($f.FullName), '(?im)^\s*URL\s*=\s*(\S+)')
                if ($m.Success) { $url = $m.Groups[1].Value }
            } catch { }
            if (-not $url) { continue }
            if ($url.ToLowerInvariant().StartsWith('file:')) {
                $s = New-Source 'shortcut' $f.BaseName
                try { $s.target = ([Uri]$url).LocalPath } catch { }
            } else {
                $s = New-Source 'url' $f.BaseName
                $s.url = $url
            }
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
function Add-Folders([string]$Dir, [int]$Level, [int]$Depth) {
    $children = @()
    try { $children = (New-Object IO.DirectoryInfo $Dir).GetDirectories() } catch { return }
    foreach ($c in $children) {
        $low = $c.Name.ToLowerInvariant()
        if ($SkipDirs -contains $low -or $low.StartsWith('.')) { continue }
        if (Test-Reparse $c.Attributes) { continue }
        if (Find-CatalogEntry @($c.Name)) {
            $s = New-Source 'folder' $c.Name
            $s.location = $c.FullName
            [void]$Sources.Add($s)
        } elseif ($Level -lt $Depth) {
            Add-Folders $c.FullName ($Level + 1) $Depth
        }
    }
}
foreach ($d in @($ProgramDirs) + @($ShallowDirs) + @($Desktops)) { Add-Folders $d 1 2 }

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

    # 容量
    $size = $null; $sizeNote = ''
    if ($location) { $size = Get-Size $location; $sizeNote = 'フォルダ実測' }
    if (-not $size) {
        $reg = @($src | Where-Object { $_.size } | ForEach-Object { $_.size })
        if ($reg.Count -gt 0) {
            $size = ($reg | Measure-Object -Maximum).Maximum
            $sizeNote = 'インストール情報の推定値'
        } elseif (@($src | Where-Object { $_.kind -ne 'url' }).Count -eq 0) {
            $size = $null
            $sizeNote = 'Web サービスのため PC の容量は使いません'
        }
    }

    [void]$Result.Add([pscustomobject]@{
        name = $app.name; category = $app.category; purpose = $app.purpose; url = $app.url; howto = $app.howto
        launchNote = $app.launchNote; location = $location; size = $size; sizeNote = $sizeNote
        launchFile = $launch; shortcuts = @($shortcuts.ToArray()); version = $version; publisher = $publisher
        names = @($names.ToArray()); kinds = @($kinds.ToArray()); webUrl = $webUrl
    })
}

# ---------------------------------------------------------------------------
# 5. プラグイン

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
# 6. HTML を書き出す

$Data = [pscustomobject]@{
    scannedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    computer = $env:COMPUTERNAME
    categories = @($Catalog.categories)
    apps = @($Result.ToArray())
    plugins = @($Plugins.ToArray())
    roots = [pscustomobject]@{
        desktops = @($Desktops); startMenus = @($StartMenus); programDirs = @($ProgramDirs)
        shallowDirs = @($ShallowDirs); pluginDirs = @($PluginDirs)
    }
    errors = @($Errors.ToArray())
}
$json = ConvertTo-Json -InputObject $Data -Depth 6 -Compress
$json = $json.Replace('</', '<\/')
$html = $Template.Replace('/*__DATA__*/null', $json)

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Exists $desktop -Folder)) { $desktop = (Get-Location).Path }
$out = Join-Path $desktop '音楽アプリ一覧.html'
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ("{0} 件のアプリ、{1} 件のプラグインを見つけました。" -f $Result.Count, $Plugins.Count)
Write-Host "HTML を作成しました: $out"
try { Start-Process $out } catch { Write-Host 'ブラウザで開けませんでした。上のファイルをダブルクリックしてください。' }
