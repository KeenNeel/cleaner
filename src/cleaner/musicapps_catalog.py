"""音楽生成アプリ・関連ソフトの既知カタログ。

match はアプリ名・フォルダ名・ショートカット名 (小文字) に対する正規表現。
exes は起動ファイルの候補 (優先順、ファイル名のみ・小文字で比較)。
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class CatalogEntry:
    id: str
    name: str
    category: str
    purpose: str
    url: str
    match: tuple[str, ...]
    exes: tuple[str, ...] = ()
    howto: str = ""
    launch_note: str = ""  # 起動方法の補足 (ブラウザで開く等)
    exclude: tuple[str, ...] = field(default=())  # 誤検出を避けるための除外パターン


AI_MUSIC = "AI作曲・音楽生成"
AI_VOICE = "AI歌声・音声合成"
AI_SEP = "AI音源分離・声質変換"
DAW = "DAW (作曲・録音・編集)"
SCORE = "楽譜作成・MIDI"
WAVE = "波形編集・録音・変換"
PLUGIN = "音源・プラグイン・管理ツール"
AUDIO_SYS = "オーディオ設定・ドライバ"

CATEGORY_ORDER = (AI_MUSIC, AI_VOICE, AI_SEP, DAW, SCORE, WAVE, PLUGIN, AUDIO_SYS, "その他 (音楽関連の可能性)")

CATALOG: tuple[CatalogEntry, ...] = (
    # ---- AI 作曲・音楽生成 ----
    CatalogEntry(
        "suno", "Suno", AI_MUSIC,
        "歌詞やスタイルの指示文から、ボーカル入りの楽曲を丸ごと AI 生成する Web サービス。",
        "https://suno.com/", (r"\bsuno\b",),
        howto="ブラウザで suno.com を開いてログイン → Create で曲のスタイル (例: J-POP, 女性ボーカル) と歌詞を入力 → Create を押すと 2 曲生成される。",
        launch_note="Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。",
    ),
    CatalogEntry(
        "udio", "Udio", AI_MUSIC,
        "テキストの指示から歌入りの楽曲を生成・延長 (Extend) できる AI 作曲 Web サービス。",
        "https://www.udio.com/", (r"\budio\b",),
        howto="udio.com にログイン → プロンプトに曲の雰囲気を書いて Create → 気に入った曲を Extend で伸ばして 1 曲に仕上げる。",
        launch_note="Web サービスのため、ショートカット (URL) をダブルクリックするとブラウザで開きます。",
    ),
    CatalogEntry(
        "stableaudio", "Stable Audio", AI_MUSIC,
        "Stability AI のテキストから音楽・効果音を生成する AI (Web 版 / ローカルモデル版)。",
        "https://stableaudio.com/", (r"stable[\s_-]?audio",),
        howto="Web 版はプロンプトと長さを指定して Generate。ローカル版 (stable-audio-tools / ComfyUI) はモデルを読み込んでプロンプトを入力する。",
    ),
    CatalogEntry(
        "musicgen", "MusicGen / AudioCraft (Meta)", AI_MUSIC,
        "Meta のオープンソース音楽生成 AI。テキストやメロディから BGM を生成する (Python / Gradio)。",
        "https://github.com/facebookresearch/audiocraft", (r"audiocraft", r"musicgen"),
        exes=("run.bat", "start.bat", "webui.bat", "app.py"),
        howto="付属の起動バッチ (または python app.py) で Web 画面を起動 → ブラウザで表示された URL を開き、説明文を入力して Generate。",
        launch_note="起動後に表示される http://127.0.0.1:xxxx をブラウザで開きます。",
    ),
    CatalogEntry(
        "acestep", "ACE-Step", AI_MUSIC,
        "歌詞とタグから歌入り楽曲を生成するオープンソースの音楽生成モデル。",
        "https://github.com/ace-step/ACE-Step", (r"ace[\s_-]?step",),
        exes=("run.bat", "start.bat", "acestep.exe"),
        howto="起動バッチで Gradio 画面を開き、Tags (ジャンル等) と Lyrics を入力して Generate。",
        launch_note="起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。",
    ),
    CatalogEntry(
        "yue", "YuE", AI_MUSIC,
        "歌詞から長尺のボーカル入り楽曲を生成するオープンソースモデル。",
        "https://github.com/multimodal-art-projection/YuE", (r"^yue\b", r"yue[\s_-]?(gp|ui|exllamav2)"),
        exes=("run.bat", "start.bat"),
        howto="ジャンル指定 (genre.txt) と歌詞 (lyrics.txt) を用意して推論スクリプト/Web UI から生成する。",
    ),
    CatalogEntry(
        "riffusion", "Riffusion", AI_MUSIC,
        "スペクトログラム画像生成を応用した AI 作曲ツール / Web サービス。",
        "https://www.riffusion.com/", (r"riffusion",),
        howto="Web 版はプロンプトを入力して生成。ローカル版は付属の起動手順に従ってサーバーを立ち上げる。",
    ),
    CatalogEntry(
        "comfyui", "ComfyUI", AI_MUSIC,
        "ノードをつなぐ方式の生成 AI 実行環境。Stable Audio / ACE-Step 等の音楽生成モデルも動かせる。",
        "https://www.comfy.org/", (r"comfyui", r"comfy[\s_-]?ui"),
        exes=("comfyui.exe", "run_nvidia_gpu.bat", "run_cpu.bat", "main.py"),
        howto="run_nvidia_gpu.bat (GPU なしは run_cpu.bat) を実行 → ブラウザで http://127.0.0.1:8188 → 音楽用ワークフローを読み込んで Queue Prompt。",
        launch_note="起動後に http://127.0.0.1:8188 をブラウザで開きます (デスクトップ版はアプリが直接開きます)。",
    ),
    CatalogEntry(
        "magenta", "Magenta Studio", AI_MUSIC,
        "Google Magenta の AI による MIDI フレーズ生成・続き生成・ドラム生成ツール (単体版 / Ableton 用)。",
        "https://magenta.tensorflow.org/studio", (r"magenta",),
        exes=("magenta studio.exe", "continue.exe", "generate.exe"),
        howto="Generate / Continue / Drumify などのツールを開き、MIDI ファイルを入力して生成 → 結果の MIDI を DAW に読み込む。",
    ),
    CatalogEntry(
        "aiva", "AIVA", AI_MUSIC,
        "スタイルやコード進行を指定して BGM を AI 作曲するサービス (デスクトップ版あり)。",
        "https://www.aiva.ai/", (r"\baiva\b",),
        exes=("aiva.exe",),
        howto="ログイン → Create track でスタイル・キー・長さを選んで生成 → MIDI / WAV で書き出し。",
    ),
    CatalogEntry(
        "orbplugins", "Orb Producer Suite", AI_MUSIC,
        "コード・メロディ・ベース・アルペジオを AI 生成する DAW 用プラグイン。",
        "https://www.orbplugins.com/", (r"orb\s?producer", r"orb\s?(chords|melody|bass|arpeggio)"),
        howto="DAW のインストゥルメント/MIDI トラックに挿してスタイルを選び、生成された MIDI をドラッグ&ドロップ。",
    ),
    CatalogEntry(
        "scaler", "Scaler 2/3", AI_MUSIC,
        "コード進行の提案・生成を行う作曲支援プラグイン/スタンドアロン。",
        "https://www.pluginboutique.com/product/2-Effects/58-Chord-Generator/14431-Scaler-3",
        (r"^scaler\s?\d?\b",),
        exes=("scaler 3.exe", "scaler 2.exe", "scaler.exe"),
        howto="キーやジャンルを選ぶとコード候補が表示される → 並べて進行を作り MIDI として DAW へドラッグ。",
    ),
    # ---- AI 歌声・音声合成 ----
    CatalogEntry(
        "synthv", "Synthesizer V Studio", AI_VOICE,
        "AI 歌声合成ソフト。MIDI と歌詞を入力するだけで人間らしい歌声を生成する。",
        "https://dreamtonics.com/synthesizerv/", (r"synthesizer\s?v", r"synthv", r"dreamtonics"),
        exes=("synthv studio pro.exe", "synthv studio basic.exe", "synthesizer v studio pro.exe",
              "synthesizer v studio 2 pro.exe", "synthv studio.exe"),
        howto="ボイスデータベースを選択 → ピアノロールにノートを描いて歌詞を入力 → 再生して確認 → WAV で書き出し。",
    ),
    CatalogEntry(
        "vocaloid", "VOCALOID", AI_VOICE,
        "ヤマハの歌声合成ソフト。メロディと歌詞から歌声を作る。",
        "https://www.vocaloid.com/", (r"vocaloid",),
        exes=("vocaloid6.exe", "vocaloid5.exe", "vocaloid editor.exe"),
        howto="Voice Bank を選んでトラックを作成 → ノートと歌詞を入力 → 表情パラメータを調整 → オーディオ書き出し。",
    ),
    CatalogEntry(
        "piapro", "Piapro Studio (初音ミク NT 等)", AI_VOICE,
        "クリプトン社の歌声合成エディタ (VSTi / スタンドアロン)。",
        "https://ec.crypton.co.jp/", (r"piapro",),
        exes=("piapro studio nt.exe", "piapro studio.exe"),
        howto="DAW にプラグインとして挿す (または単体起動) → ノートと歌詞を入力して歌わせる。",
    ),
    CatalogEntry(
        "cevio", "CeVIO AI", AI_VOICE,
        "AI による歌声・トーク音声の合成ソフト。",
        "https://cevio.jp/", (r"cevio",),
        exes=("cevio ai.exe", "cevio creative studio.exe"),
        howto="ソングトラックを追加 → 楽譜にノートと歌詞を入力 → 調声して書き出し。トークは文章を入力して再生。",
    ),
    CatalogEntry(
        "voisona", "VoiSona", AI_VOICE,
        "AI 歌声合成ソフト (CeVIO 系技術、基本無料)。",
        "https://voisona.com/", (r"voisona",),
        exes=("voisona.exe",),
        howto="ボイスライブラリを有効化 → ノートと歌詞を入力 → 再生・WAV 書き出し。",
    ),
    CatalogEntry(
        "neutrino", "NEUTRINO", AI_VOICE,
        "MusicXML の楽譜から AI が歌声を合成する無料ソフト。",
        "https://studio-neutrino.com/", (r"neutrino",),
        exes=("neutrino.exe", "run.bat", "run_musicxml.bat"),
        howto="楽譜ソフトで歌詞付き MusicXML を作成 → score\\musicxml に置く → Run.bat を編集して実行 → output に WAV が出力される。",
    ),
    CatalogEntry(
        "utau", "UTAU / OpenUtau", AI_VOICE,
        "音声ライブラリを使って歌わせる歌声合成ソフト (OpenUtau は後継のオープンソース版)。",
        "https://www.openutau.com/", (r"\butau\b", r"openutau"),
        exes=("openutau.exe", "utau.exe"),
        howto="音源 (歌声ライブラリ) を導入 → ピアノロールにノートと歌詞を入力 → レンダリングして WAV 書き出し。",
    ),
    CatalogEntry(
        "acestudio", "ACE Studio", AI_VOICE,
        "AI 歌声合成・AI 楽器演奏ソフト。MIDI から歌声やバイオリン等を生成する。",
        "https://acestudio.ai/", (r"ace\s?studio",),
        exes=("ace studio.exe", "acestudio.exe"),
        howto="ボイス (歌手) を選んでトラック作成 → MIDI を読み込むかノートを入力 → 歌詞を流し込み → 書き出し。",
    ),
    CatalogEntry(
        "voicevox", "VOICEVOX", AI_VOICE,
        "無料の AI 音声合成 (読み上げ) ソフト。ソング機能で簡単な歌唱も可能。",
        "https://voicevox.hiroshiba.jp/", (r"voicevox",),
        exes=("voicevox.exe",),
        howto="キャラクターを選んで文章を入力 → 再生 → 音声書き出し。ソングタブでは MIDI を読み込み歌わせられる。",
    ),
    CatalogEntry(
        "aivoice", "A.I.VOICE", AI_VOICE,
        "AI 音声合成 (トーク) ソフト。",
        "https://aivoice.jp/", (r"a\.?i\.?voice",),
        exes=("aivoiceeditor.exe", "a.i.voice editor.exe"),
        howto="ボイスを選び文章を入力 → 抑揚や話速を調整 → 音声保存。",
    ),
    # ---- AI 音源分離・声質変換 ----
    CatalogEntry(
        "uvr", "Ultimate Vocal Remover (UVR5)", AI_SEP,
        "AI で楽曲をボーカルと伴奏 (ドラム・ベース等) に分離する無料ソフト。",
        "https://ultimatevocalremover.com/", (r"ultimate\s?vocal\s?remover", r"^uvr\d?\b"),
        exes=("ultimate vocal remover.exe", "uvr.exe", "uvr.py"),
        howto="入力ファイルと出力先を選択 → 処理方法 (MDX-Net / Demucs 等) とモデルを選ぶ → Start Processing。",
    ),
    CatalogEntry(
        "demucs", "Demucs", AI_SEP,
        "Meta のオープンソース音源分離 AI。ボーカル・ドラム・ベース・その他に分ける。",
        "https://github.com/facebookresearch/demucs", (r"demucs",),
        exes=("demucs.exe", "demucs-gui.exe", "run.bat"),
        howto="コマンド `demucs 曲.mp3` (または GUI 版) で実行 → separated フォルダにパートごとの WAV が出力される。",
    ),
    CatalogEntry(
        "spleeter", "Spleeter", AI_SEP,
        "Deezer のオープンソース音源分離ツール。",
        "https://github.com/deezer/spleeter", (r"spleeter",),
        exes=("spleeter.exe", "spleetergui.exe"),
        howto="コマンド `spleeter separate -p spleeter:2stems -o 出力先 曲.mp3` で 2/4/5 パートに分離。",
    ),
    CatalogEntry(
        "rvc", "RVC (Retrieval-based Voice Conversion)", AI_SEP,
        "歌声・話し声を別の人の声質に変換する AI ボイスチェンジャー / 学習ツール。",
        "https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI",
        (r"\brvc\b", r"retrieval[\s_-]?based", r"rvc[\s_-]?webui", r"applio"),
        exes=("go-web.bat", "go-web-dml.bat", "applio.exe", "run-applio.bat", "infer-web.py"),
        howto="go-web.bat を実行 → ブラウザの WebUI で声モデル (.pth) を選択 → 変換したい音声を指定して Convert。",
        launch_note="起動後に表示される http://127.0.0.1:7865 等をブラウザで開きます。",
    ),
    CatalogEntry(
        "sovits", "so-vits-svc", AI_SEP,
        "歌声を別の声質に変換する歌声変換 (SVC) AI。",
        "https://github.com/svc-develop-team/so-vits-svc", (r"so[\s_-]?vits", r"sovits"),
        exes=("webui.bat", "run.bat", "webui.py"),
        howto="起動バッチで WebUI を開き、モデルと設定ファイルを読み込み → 変換する音声をアップロードして変換。",
    ),
    CatalogEntry(
        "wokada", "VC Client (w-okada)", AI_SEP,
        "RVC モデルなどを使ってリアルタイムに声を変換するボイスチェンジャー。",
        "https://github.com/w-okada/voice-changer", (r"mmvcserversio", r"voice[\s_-]?changer", r"vcclient"),
        exes=("start_http.bat", "mmvcserversio.exe", "vcclient.exe"),
        howto="start_http.bat を実行 → ブラウザ画面でモデルを選び、入力マイク・出力デバイスを設定して start。",
    ),
    CatalogEntry(
        "lalal", "LALAL.AI", AI_SEP,
        "AI による音源分離 (ステム分割) サービス / デスクトップアプリ。",
        "https://www.lalal.ai/", (r"lalal",),
        exes=("lalal.ai.exe", "lalal.exe"),
        howto="分離したいパート (Vocal, Drum 等) を選び、ファイルをドラッグ&ドロップ → 分離結果をダウンロード。",
    ),
    # ---- DAW ----
    CatalogEntry(
        "flstudio", "FL Studio", DAW,
        "ループ・パターン中心の作曲がしやすい人気 DAW。ビートメイク・EDM 制作に強い。",
        "https://www.image-line.com/fl-studio/", (r"fl\s?studio(?!\s?asio)",),
        exes=("fl64.exe", "fl.exe", "fl studio.exe"),
        howto="チャンネルラックで音色を選び、ステップ/ピアノロールでパターンを作る → プレイリストに並べて曲にする → File > Export で WAV/MP3 書き出し。",
    ),
    CatalogEntry(
        "ableton", "Ableton Live", DAW,
        "ループを組み合わせる「セッションビュー」が特徴の DAW。ライブ演奏・電子音楽向け。",
        "https://www.ableton.com/", (r"ableton",),
        exes=("ableton live 12 suite.exe", "ableton live 12 standard.exe", "ableton live 12 intro.exe",
              "ableton live 12 lite.exe", "ableton live 11 suite.exe", "ableton live 11 standard.exe",
              "ableton live 11 lite.exe", "ableton live 11 intro.exe"),
        howto="ブラウザから音源やループをトラックへドラッグ → クリップを録音/打ち込み → アレンジメントビューで曲にまとめ → ファイル > 書き出し。",
    ),
    CatalogEntry(
        "cubase", "Cubase", DAW,
        "Steinberg の定番 DAW。打ち込み・録音・ミックスまで幅広く対応。",
        "https://www.steinberg.net/ja/cubase/", (r"cubase",),
        exes=("cubase14.exe", "cubase13.exe", "cubase12.exe", "cubase11.exe", "cubase10.5.exe", "cubase.exe"),
        howto="プロジェクトを新規作成 → インストゥルメントトラックを追加して打ち込み/録音 → ミックス → ファイル > 書き出し > オーディオミックスダウン。",
    ),
    CatalogEntry(
        "studioone", "Studio One", DAW,
        "ドラッグ&ドロップ操作中心で使いやすい DAW (PreSonus / Fender)。",
        "https://www.presonus.com/studioone", (r"studio\s?one",),
        exes=("studio one.exe",),
        howto="新規ソング作成 → 右側ブラウザから音源をドラッグしてトラック作成 → 打ち込み/録音 → ソング > ミックスダウンをエクスポート。",
    ),
    CatalogEntry(
        "reaper", "REAPER", DAW,
        "軽量・高機能で低価格な DAW。カスタマイズ性が高い。",
        "https://www.reaper.fm/", (r"\breaper\b",),
        exes=("reaper.exe",),
        howto="トラックを追加 (Ctrl+T) → FX から音源を挿して MIDI を打ち込む/録音 → File > Render で書き出し。",
    ),
    CatalogEntry(
        "bitwig", "Bitwig Studio", DAW,
        "モジュレーション機能が強力な DAW。電子音楽・サウンドデザイン向け。",
        "https://www.bitwig.com/", (r"bitwig",),
        exes=("bitwig studio.exe",),
        howto="トラックにデバイスをドラッグ → クリップを作って打ち込み → アレンジャーで並べる → File > Export Audio。",
    ),
    CatalogEntry(
        "cakewalk", "Cakewalk / Sonar", DAW,
        "BandLab 提供の DAW (Cakewalk by BandLab / Sonar)。",
        "https://www.cakewalk.com/", (r"cakewalk", r"\bsonar\b"),
        exes=("cakewalk.exe", "sonar.exe"),
        howto="新規プロジェクト → インストゥルメントトラックを挿入して打ち込み/録音 → ファイル > エクスポート > オーディオ。",
    ),
    CatalogEntry(
        "lmms", "LMMS", DAW,
        "無料・オープンソースの作曲ソフト。シンセやビートメイク機能を内蔵。",
        "https://lmms.io/", (r"\blmms\b",),
        exes=("lmms.exe",),
        howto="Song Editor にインストゥルメントを追加 → Piano Roll で打ち込み → Beat+Bassline でリズム → File > Export。",
    ),
    CatalogEntry(
        "protools", "Pro Tools", DAW,
        "Avid のプロ向け録音・ミックス DAW。スタジオ標準。",
        "https://www.avid.com/pro-tools", (r"pro\s?tools",),
        exes=("protools.exe",),
        howto="新規セッション作成 → トラック作成 → 録音/編集 → File > Bounce Mix で書き出し。",
    ),
    CatalogEntry(
        "reason", "Reason", DAW,
        "ラック型の仮想機材で音作りする DAW / プラグイン (Reason Studios)。",
        "https://www.reasonstudios.com/", (r"^reason\b", r"reason\s?(studios|\d+|rack)"),
        exes=("reason.exe", "reason 13.exe", "reason 12.exe"),
        howto="ラックに音源やエフェクトを追加 → シーケンサーで打ち込み → File > Export Song as Audio File。",
    ),
    CatalogEntry(
        "mixcraft", "Mixcraft", DAW,
        "Acoustica の初心者向け DAW。ループ素材が豊富。",
        "https://acoustica.com/mixcraft", (r"mixcraft",),
        exes=("mixcraft10.exe", "mixcraft9.exe", "mixcraft.exe"),
        howto="ループライブラリから素材をドラッグ → 打ち込み/録音 → ミックスダウン。",
    ),
    CatalogEntry(
        "musicmaker", "MAGIX Music Maker", DAW,
        "ループを並べるだけで曲を作れる初心者向け作曲ソフト。",
        "https://www.magix.com/music-maker/", (r"music\s?maker",),
        exes=("musicmaker.exe", "music maker.exe"),
        howto="サウンドプールからループをトラックへドラッグ → 並べて曲にする → ファイル > 書き出し。",
    ),
    CatalogEntry(
        "soundit", "Sound it!", DAW,
        "インターネット社の国産 DAW / 波形編集ソフト。",
        "https://www.ssw.co.jp/", (r"sound\s?it!?",),
        exes=("soundit.exe",),
        howto="新規作成 → オーディオ/MIDI トラックを追加 → 録音・編集 → ミックスダウンして書き出し。",
    ),
    CatalogEntry(
        "abilitypro", "ABILITY", DAW,
        "インターネット社の国産 DAW。日本語環境で使いやすい。",
        "https://www.ssw.co.jp/products/ability/", (r"^ability\b",),
        exes=("ability.exe",),
        howto="新規ソング → トラック追加 → スコア/ピアノロールで打ち込み → ミックスダウン。",
    ),
    CatalogEntry(
        "bandlab", "BandLab", DAW,
        "無料のオンライン DAW / コラボレーション作曲サービス。",
        "https://www.bandlab.com/", (r"bandlab(?!\s?assistant)",),
        exes=("bandlab.exe",),
        howto="Create → Studio でトラックを追加 → 録音やループで曲を作る → 保存して公開または書き出し。",
    ),
    # ---- 楽譜作成・MIDI ----
    CatalogEntry(
        "musescore", "MuseScore", SCORE,
        "無料の楽譜作成ソフト。入力した楽譜を再生・MIDI/MusicXML 書き出しできる。",
        "https://musescore.org/", (r"musescore", r"muse\s?hub"),
        exes=("musescore4.exe", "musescore3.exe", "musescore.exe", "musehub.exe"),
        howto="新しいスコアで楽器と拍子を選ぶ → N キーで音符入力 → 再生で確認 → ファイル > エクスポート (PDF / MIDI / MusicXML / MP3)。",
    ),
    CatalogEntry(
        "domino", "Domino", SCORE,
        "無料の国産 MIDI シーケンサ。ピアノロールで細かく打ち込める。",
        "https://takabosoft.com/domino", (r"^domino\b",),
        exes=("domino.exe",),
        howto="音源 (MIDI 出力) を設定 → ピアノロールで打ち込み → 保存 (SMF/MIDI 形式で DAW に持っていける)。",
    ),
    CatalogEntry(
        "dorico", "Dorico", SCORE,
        "Steinberg のプロ向け楽譜作成ソフト。",
        "https://www.steinberg.net/ja/dorico/", (r"dorico",),
        exes=("dorico5.exe", "dorico4.exe", "dorico.exe"),
        howto="新規プロジェクトで楽器を追加 → 記譜モードで音符入力 → 再生モードで確認 → PDF/オーディオ書き出し。",
    ),
    CatalogEntry(
        "sibelius", "Sibelius", SCORE,
        "Avid の楽譜作成ソフト。",
        "https://www.avid.com/sibelius", (r"sibelius",),
        exes=("sibelius.exe",),
        howto="新規スコアで編成を選ぶ → 音符入力 → 再生 → PDF / MIDI / オーディオで書き出し。",
    ),
    CatalogEntry(
        "finale", "Finale", SCORE,
        "MakeMusic の楽譜作成ソフト (2024 年に開発終了)。",
        "https://www.finalemusic.com/", (r"^finale\b", r"makemusic"),
        exes=("finale.exe",),
        howto="セットアップウィザードで編成を選ぶ → 高速入力/ステップ入力で音符入力 → 印刷・書き出し。",
    ),
    CatalogEntry(
        "guitarpro", "Guitar Pro", SCORE,
        "ギター TAB 譜・楽譜の作成と再生ソフト。",
        "https://www.guitar-pro.com/", (r"guitar\s?pro",),
        exes=("guitarpro.exe", "guitarpro8.exe", "guitarpro7.exe"),
        howto="トラックに楽器を選ぶ → TAB 譜または五線譜で入力 → 再生で確認 → MIDI / オーディオ書き出し。",
    ),
    CatalogEntry(
        "melodyne", "Melodyne", WAVE,
        "録音した歌や楽器の音程・タイミングを 1 音ずつ修正できるピッチ編集ソフト。",
        "https://www.celemony.com/", (r"melodyne", r"celemony"),
        exes=("melodyne.exe", "melodyne 5.exe"),
        howto="DAW のトラックに ARA プラグインとして挿す (または単体でファイルを開く) → 音の塊 (blob) をドラッグして音程・長さを修正。",
    ),
    # ---- 波形編集 ----
    CatalogEntry(
        "audacity", "Audacity", WAVE,
        "無料の録音・波形編集ソフト。カット・ノイズ除去・形式変換などに便利。",
        "https://www.audacityteam.org/", (r"audacity",),
        exes=("audacity.exe",),
        howto="ファイルを開くか録音 → 範囲を選択してカット/エフェクト (ノイズ除去等) → ファイル > 書き出し で MP3/WAV に保存。",
    ),
    CatalogEntry(
        "ocenaudio", "ocenaudio", WAVE,
        "軽量で使いやすい無料の波形編集ソフト。",
        "https://www.ocenaudio.com/", (r"ocenaudio",),
        exes=("ocenaudio.exe",),
        howto="ファイルを開く → 範囲選択して編集/エフェクト → 名前を付けて保存。",
    ),
    CatalogEntry(
        "wavelab", "WaveLab", WAVE,
        "Steinberg のマスタリング・波形編集ソフト。",
        "https://www.steinberg.net/ja/wavelab/", (r"wavelab",),
        exes=("wavelab pro 12.exe", "wavelab elements 12.exe", "wavelab pro 11.exe", "wavelab.exe"),
        howto="オーディオファイルを開く → マスターセクションでエフェクト → レンダリングして書き出し。",
    ),
    CatalogEntry(
        "soundforge", "SOUND FORGE", WAVE,
        "MAGIX の波形編集・マスタリングソフト。",
        "https://www.magix.com/sound-forge/", (r"sound\s?forge",),
        exes=("soundforge.exe", "sound forge pro.exe"),
        howto="ファイルを開いて編集 → エフェクト/マスタリング → 名前を付けて保存。",
    ),
    CatalogEntry(
        "rx", "iZotope RX", WAVE,
        "ノイズ・クリック・リップノイズ除去などの音声修復ソフト。",
        "https://www.izotope.com/en/products/rx.html", (r"izotope\s?rx", r"^rx\s?\d+"),
        exes=("izotope rx 11 audio editor.exe", "izotope rx 10 audio editor.exe", "izotope rx audio editor.exe"),
        howto="ファイルを開く → スペクトログラムで問題箇所を選択 → De-noise 等のモジュールを適用 → 書き出し。",
    ),
    CatalogEntry(
        "audiotools", "fre:ac / foobar2000 (変換)", WAVE,
        "音声ファイルの形式変換・タグ編集に使える無料ツール。",
        "https://www.freac.org/", (r"fre[:\s]?ac", r"foobar2000"),
        exes=("freac.exe", "foobar2000.exe"),
        howto="ファイルを追加 → 出力形式 (MP3/FLAC 等) を選んで変換開始。",
    ),
    # ---- 音源・プラグイン・管理ツール ----
    CatalogEntry(
        "nativeaccess", "Native Access / Kontakt (Native Instruments)", PLUGIN,
        "Native Instruments 製品 (Kontakt, Komplete 等) のインストール・アクティベーション管理と、サンプラー音源。",
        "https://www.native-instruments.com/", (r"native\s?access", r"native\s?instruments", r"kontakt",
                                                r"komplete", r"maschine", r"massive"),
        exes=("native access.exe", "kontakt 8.exe", "kontakt 7.exe", "kontakt.exe", "komplete kontrol.exe"),
        howto="Native Access でログインして製品をインストール/更新 → DAW から Kontakt 等をプラグインとして読み込む。",
    ),
    CatalogEntry(
        "arturia", "Arturia Software Center / V Collection", PLUGIN,
        "Arturia のシンセ音源 (Analog Lab, Pigments 等) と、その管理ツール。",
        "https://www.arturia.com/", (r"arturia", r"analog\s?lab", r"pigments"),
        exes=("arturia software center.exe", "analog lab v.exe", "pigments.exe"),
        howto="Software Center でログインして製品をインストール → DAW でプラグインとして使う (単体起動も可)。",
    ),
    CatalogEntry(
        "spitfire", "Spitfire Audio", PLUGIN,
        "オーケストラ・映画音楽向け音源 (BBC Symphony Orchestra, LABS 等) と管理アプリ。",
        "https://www.spitfireaudio.com/", (r"spitfire",),
        exes=("spitfire audio.exe",),
        howto="Spitfire Audio アプリで音源をダウンロード → DAW でプラグインとして読み込む。LABS は無料。",
    ),
    CatalogEntry(
        "splice", "Splice", PLUGIN,
        "サンプル素材 (ループ・ワンショット) のサブスク配信とプラグイン管理アプリ。",
        "https://splice.com/", (r"\bsplice\b",),
        exes=("splice.exe",),
        howto="Web/アプリでサンプルを検索して取得 → Splice フォルダの素材を DAW にドラッグ。",
    ),
    CatalogEntry(
        "serum", "Serum (Xfer Records)", PLUGIN,
        "EDM で定番のウェーブテーブルシンセ プラグイン。",
        "https://xferrecords.com/products/serum-2", (r"\bserum\b", r"xfer"),
        howto="DAW のインストゥルメントトラックにプラグインとして挿す → プリセットを選んで演奏/打ち込み。",
    ),
    CatalogEntry(
        "vital", "Vital", PLUGIN,
        "無料から使えるウェーブテーブルシンセ プラグイン。",
        "https://vital.audio/", (r"^vital\b(?!source)",),
        exes=("vital.exe",),
        howto="DAW にプラグインとして挿す → プリセットを選ぶ / 波形を描いて音作り。",
    ),
    CatalogEntry(
        "izotope", "iZotope Product Portal / Ozone / Neutron", PLUGIN,
        "AI アシスタント付きのマスタリング (Ozone)・ミックス (Neutron) プラグインと管理ツール。",
        "https://www.izotope.com/", (r"izotope", r"\bozone\b", r"neutron", r"native\s?instruments\s?product\s?portal"),
        exes=("izotope product portal.exe", "izotope ozone 11.exe", "izotope ozone 10.exe"),
        howto="マスタートラックに Ozone を挿す → Master Assistant で自動調整 → 好みで微調整。",
    ),
    CatalogEntry(
        "waves", "Waves Central", PLUGIN,
        "Waves プラグインのインストール・ライセンス管理ツール。",
        "https://www.waves.com/", (r"waves\s?central", r"^waves\b"),
        exes=("waves central.exe",),
        howto="Waves Central でログイン → 製品をインストール/ライセンスを有効化 → DAW でプラグインを使う。",
    ),
    CatalogEntry(
        "autotune", "Antares Auto-Tune", PLUGIN,
        "ボーカルの音程補正・ケロケロボイス効果の定番プラグイン。",
        "https://www.antarestech.com/", (r"auto[\s-]?tune", r"antares"),
        exes=("antares central.exe",),
        howto="ボーカルトラックにプラグインとして挿す → Key と Scale を曲に合わせ、Retune Speed で補正の強さを調整。",
    ),
    CatalogEntry(
        "steinbergtools", "Steinberg Download Assistant / Activation Manager", PLUGIN,
        "Cubase など Steinberg 製品のダウンロードとライセンス管理ツール。",
        "https://www.steinberg.net/", (r"steinberg\s?(download|activation|library)", r"elicenser"),
        exes=("steinberg download assistant.exe", "steinberg activation manager.exe"),
        howto="アプリを起動して Steinberg ID でログイン → 製品・音源をダウンロード / ライセンスを有効化。",
    ),
    CatalogEntry(
        "ilok", "iLok License Manager", PLUGIN,
        "多くのプラグイン (Pro Tools, UAD, Softube 等) のライセンス管理ツール。",
        "https://www.ilok.com/", (r"\bilok\b", r"pace\s?license"),
        exes=("license support.exe", "ilok license manager.exe"),
        howto="iLok アカウントでサインイン → 購入したライセンスをこの PC (または iLok USB) に割り当てる。",
    ),
    CatalogEntry(
        "plugin_alliance", "Plugin Alliance / Plugin Boutique / UAD", PLUGIN,
        "プラグイン販売サイトの製品管理アプリ (Installation Manager / UA Connect 等)。",
        "https://www.plugin-alliance.com/",
        (r"plugin\s?alliance", r"plugin\s?boutique", r"ua\s?connect", r"universal\s?audio"),
        exes=("installation manager.exe", "ua connect.exe"),
        howto="管理アプリでログイン → 購入済みプラグインをインストール → DAW を起動してプラグインを再スキャン。",
    ),
    CatalogEntry(
        "ezdrummer", "Toontrack EZdrummer / Superior Drummer", PLUGIN,
        "生ドラム音源と MIDI グルーブを提供するドラム音源。",
        "https://www.toontrack.com/", (r"toontrack", r"ez\s?(drummer|keys|bass)", r"superior\s?drummer"),
        exes=("ezdrummer 3.exe", "superior drummer 3.exe", "toontrack product manager.exe"),
        howto="DAW にプラグインとして挿す → Grooves から好みのリズムパターンを曲にドラッグ。",
    ),
    # ---- オーディオ設定・ドライバ ----
    CatalogEntry(
        "asio4all", "ASIO4ALL", AUDIO_SYS,
        "専用ドライバのないオーディオ機器でも DAW を低遅延で使えるようにする汎用 ASIO ドライバ。",
        "https://asio4all.org/", (r"asio4all",),
        howto="DAW のオーディオ設定でドライバに ASIO4ALL を選択 → 使う入出力デバイスを有効化し、バッファサイズを調整。",
        launch_note="単体では起動しません。DAW のオーディオ設定から選択して使います。",
    ),
    CatalogEntry(
        "flasio", "FL Studio ASIO", AUDIO_SYS,
        "FL Studio に付属する汎用 ASIO ドライバ (他の DAW でも使用可)。",
        "https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/envsettings_audio.htm",
        (r"fl\s?studio\s?asio",),
        howto="DAW のオーディオ設定でデバイスに「FL Studio ASIO」を選ぶ。",
        launch_note="単体では起動しません。DAW のオーディオ設定から選択して使います。",
    ),
    CatalogEntry(
        "voicemeeter", "VoiceMeeter", AUDIO_SYS,
        "PC 内の音声を自由にミックス・ルーティングできる仮想ミキサー。配信・録音で便利。",
        "https://vb-audio.com/Voicemeeter/", (r"voicemeeter", r"vb-?audio", r"vb-?cable"),
        exes=("voicemeeter8x64.exe", "voicemeeterpro_x64.exe", "voicemeeter_x64.exe", "voicemeeter.exe"),
        howto="起動して HARDWARE INPUT にマイク、A1 に出力デバイスを割り当て → 各アプリの出力を VoiceMeeter に向ける。",
    ),
    CatalogEntry(
        "audiointerface", "オーディオインターフェース設定ツール", AUDIO_SYS,
        "Steinberg / Yamaha / Focusrite / Roland / Behringer 等のオーディオインターフェース用ドライバと設定アプリ。",
        "https://focusrite.com/downloads",
        (r"yamaha\s?steinberg\s?usb", r"focusrite", r"scarlett", r"roland\s?(rubix|quad|duo|octa)",
         r"behringer", r"motu", r"presonus\s?universal", r"audient", r"zoom\s?(uac|livetrak|l-)"),
        exes=("focusrite control 2.exe", "focusrite control.exe", "dspmixfx_ur-c.exe"),
        howto="機器を USB 接続 → 設定アプリで入出力・サンプルレートを確認 → DAW のオーディオ設定でその機器の ASIO ドライバを選ぶ。",
    ),
)

# カタログにないが音楽関連の可能性があるもの (アンインストール一覧の名前で判定)
GENERIC_KEYWORDS = (
    r"\bvst[i3]?\b", r"\bclap\b", r"\baax\b", r"\bdaw\b", r"synth", r"sampler", r"\bmidi\b", r"vocal",
    r"music", r"\bbeat", r"drum", r"\bpiano\b", r"orchestra", r"音楽", r"音源", r"作曲", r"歌声", r"楽譜",
    r"\bsong\b", r"\bmixer\b", r"mastering", r"reverb", r"\bcompressor\b", r"\beq\b",
)
GENERIC_EXCLUDE = (
    r"realtek", r"nvidia", r"\bamd\b", r"intel", r"microsoft", r"windows", r"high definition audio",
    r"\bhd audio\b", r"conexant", r"dolby", r"dts", r"itunes", r"apple", r"spotify", r"amazon music",
    r"youtube", r"steam", r"epic games", r"xbox", r"discord",
)
