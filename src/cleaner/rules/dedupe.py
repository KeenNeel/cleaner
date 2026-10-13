"""F2: 重複ファイル検出 (仕様 5 章 F2)。

手順: サイズで絞る → 先頭/末尾 64KB のハッシュ → 全体ハッシュで確定。
ハッシュは hashcache.db にキャッシュし、サイズ・更新日時が変わっていなければ再計算しない。
(仕様では BLAKE3 だが、外部ライブラリを増やさないよう標準ライブラリの BLAKE2b を使う)

- 同一ドライブ内の重複: 残す 1 つ以外を隔離候補にする。
- ドライブをまたぐ重複: 意図的なバックアップの可能性が高いので承認待ち (設定で自動隔離も可)。
- 中身がすべて一致するフォルダ: フォルダ単位で承認待ちにし、中のファイルは自動では動かさない。
"""

from __future__ import annotations

import hashlib
import logging
import os
import sqlite3
import stat
from collections import defaultdict
from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

from cleaner.appdirs import AppPaths
from cleaner.drives import Drive
from cleaner.fsutil import file_hash, human_size, is_cloud_only, is_link, is_under, longpath, norm
from cleaner.models import Candidate, Skipped
from cleaner.protect import Protector
from cleaner.rules.cleanup import PARTIAL_DOWNLOAD_SUFFIXES

log = logging.getLogger(__name__)

FEATURE = "F2"

CATEGORY_LABELS = {
    "duplicate": "重複ファイル (同一ドライブ内)",
    "duplicate_cross_drive": "重複ファイル (ドライブをまたぐ)",
    "duplicate_folder": "重複フォルダ",
}

PARTIAL_BYTES = 64 * 1024
# これと同居するファイル (とその下のフォルダ) はアプリのインストールフォルダとみなして触らない
APP_EXTENSIONS = {".exe", ".dll"}
# フォルダ丸ごとの重複を調べるとき、これよりファイルが多いフォルダは比較しない
MAX_FOLDER_FILES = 5000
# フォルダ丸ごとの重複とみなす最小ファイル数 (1 ファイルだけのフォルダはファイル単位で扱う)
MIN_FOLDER_FILES = 2
# 1 つの重複グループ内でフォルダ一致を調べる組み合わせの上限 (先頭からこの数まで)
MAX_FOLDER_PEERS = 10
# ハッシュキャッシュで、これより長く見かけなかったファイルの記録は消す
CACHE_KEEP_DAYS = 90

Result = Candidate | Skipped


@dataclass
class FileInfo:
    path: Path
    size: int
    mtime_ns: int
    drive: Drive
    birthtime: float = 0.0
    # Git リポジトリ・アプリのフォルダ内 (scan_app_folders で調べたもの)。承認待ちにしかしない
    restricted: str | None = None


@dataclass
class DedupeContext:
    paths: AppPaths
    cfg: dict
    drives: list[Drive]
    now: datetime
    protector: Protector
    cache: HashCache


# ---- ハッシュとキャッシュ ----


def partial_hash(path: Path, size: int) -> str | None:
    """サイズ + 先頭/末尾 64KB のハッシュ。小さいファイルは全体のハッシュと同じ扱い。"""
    if size <= 2 * PARTIAL_BYTES:
        return file_hash(path, limit=None)
    try:
        h = hashlib.blake2b(digest_size=20)
        h.update(size.to_bytes(8, "little"))
        with open(longpath(path), "rb") as f:
            h.update(f.read(PARTIAL_BYTES))
            f.seek(-PARTIAL_BYTES, os.SEEK_END)
            h.update(f.read(PARTIAL_BYTES))
        return h.hexdigest()
    except OSError:
        return None


def full_hash(path: Path, size: int) -> str | None:
    return file_hash(path, limit=None)


class HashCache:
    """パスごとに (サイズ, 更新日時, 部分ハッシュ, 全体ハッシュ) を覚えておく。"""

    _COLUMNS = {"partial": partial_hash, "full": full_hash}

    def __init__(self, db_path: Path | None, now: datetime):
        self.now = now
        self._pending = 0
        self.db = self._connect(db_path)
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS hashes (path TEXT PRIMARY KEY, size INTEGER, mtime_ns INTEGER, "
            "partial TEXT, full TEXT, seen REAL)"
        )

    @staticmethod
    def _connect(db_path: Path | None) -> sqlite3.Connection:
        if db_path is not None:
            try:
                db_path.parent.mkdir(parents=True, exist_ok=True)
                return sqlite3.connect(db_path)
            except (OSError, sqlite3.Error) as e:
                log.warning("ハッシュキャッシュを開けません (今回はキャッシュなしで実行): %s", e)
        return sqlite3.connect(":memory:")

    def __enter__(self) -> HashCache:
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    def partial(self, path: Path, size: int, mtime_ns: int) -> str | None:
        return self._get("partial", path, size, mtime_ns)

    def full(self, path: Path, size: int, mtime_ns: int) -> str | None:
        return self._get("full", path, size, mtime_ns)

    def _get(self, column: str, path: Path, size: int, mtime_ns: int) -> str | None:
        key = norm(path)
        seen = self.now.timestamp()
        row = self.db.execute("SELECT size, mtime_ns, partial, full FROM hashes WHERE path = ?", (key,)).fetchone()
        unchanged = row is not None and (row[0], row[1]) == (size, mtime_ns)
        if unchanged:
            cached = row[2] if column == "partial" else row[3]
            if cached:
                self.db.execute("UPDATE hashes SET seen = ? WHERE path = ?", (seen, key))
                return cached
        value = self._COLUMNS[column](path, size)
        if value is None:
            return None
        if unchanged:
            self.db.execute(f"UPDATE hashes SET {column} = ?, seen = ? WHERE path = ?", (value, seen, key))
        else:
            self.db.execute(
                f"INSERT OR REPLACE INTO hashes (path, size, mtime_ns, {column}, seen) VALUES (?, ?, ?, ?, ?)",
                (key, size, mtime_ns, value, seen),
            )
        self._pending += 1
        if self._pending >= 500:
            self.db.commit()
            self._pending = 0
        return value

    def close(self) -> None:
        try:
            cutoff = (self.now - timedelta(days=CACHE_KEEP_DAYS)).timestamp()
            self.db.execute("DELETE FROM hashes WHERE seen < ?", (cutoff,))
            self.db.commit()
        except sqlite3.Error as e:
            log.warning("ハッシュキャッシュを保存できませんでした: %s", e)
        finally:
            self.db.close()


# ---- 残す 1 つの選び方 ----


class KeepRule:
    """① keep_priority の順 → ② パスが浅い → ③ 作成日時が古い。小さいキーほど残す。"""

    def __init__(self, paths: AppPaths, priorities: list[str]):
        self.roots = [None if p == "*" else paths.expand(p) for p in priorities]
        self.other = self.roots.index(None) if None in self.roots else len(self.roots)

    def rank(self, path: Path) -> int:
        for i, root in enumerate(self.roots):
            if root is not None and is_under(path, root):
                return i
        return self.other

    def key(self, path: Path, birthtime: float) -> tuple:
        return (self.rank(path), len(Path(norm(path)).parts), birthtime, norm(path))


def _birthtime(st: os.stat_result) -> float:
    return getattr(st, "st_birthtime", st.st_ctime)


def _user_folders(paths: AppPaths) -> list[Path]:
    """ホームと、その直下の標準フォルダ。フォルダ丸ごとの重複としては扱わない。"""
    home = paths.home
    names = ("Desktop", "Documents", "Pictures", "Videos", "Music")
    return [home, paths.downloads, *(home / n for n in names)]


# ---- 走査 ----


def _scan(ctx: DedupeContext, drive: Drive, min_size: int) -> Iterator[FileInfo]:
    """ドライブ内のファイルを列挙する。保護フォルダには入らない。

    Git リポジトリ・アプリのフォルダは、scan_app_folders が有効なら中も調べて restricted を付け、
    無効なら入らない。
    """
    include_restricted = ctx.cfg["dedupe"]["scan_app_folders"]
    # .exe が置かれていてもアプリのフォルダとはみなさない場所: ドライブ直下、ホームまでの途中のフォルダ
    # (C:\Users 等)、散らかりやすいユーザーフォルダ
    home = ctx.paths.home
    loose_dirs = {norm(p) for p in (drive.root, *home.parents, *_user_folders(ctx.paths))}
    other_roots = {norm(d.root) for d in ctx.drives if d.volume_id != drive.volume_id}
    stack: list[tuple[Path, str | None]] = [(drive.root, None)]
    while stack:
        current, restricted = stack.pop()
        try:
            entries = list(os.scandir(longpath(current)))
        except OSError as e:
            _log_skip(drive, current, f"開けません ({e.strerror})")
            continue
        if restricted is None:
            names = [e.name.lower() for e in entries]
            app_file = None
            if norm(current) not in loose_dirs:
                app_file = next((n for n in names if os.path.splitext(n)[1] in APP_EXTENSIONS), None)
            if ".git" in names:
                restricted = "Git リポジトリ"
            elif app_file:
                restricted = f"アプリのフォルダ ({app_file})"
            elif current.name.startswith(".") and current != drive.root:
                # .lmstudio や .cache など、アプリが設定・モデル等を置くフォルダ
                restricted = f"アプリのデータフォルダ ({current.name})"
            if restricted and not include_restricted:
                _log_skip(drive, current, restricted)
                continue
        for entry in entries:
            path = current / entry.name
            try:
                st = entry.stat(follow_symlinks=False)
            except OSError:
                continue
            if is_link(st):
                continue
            if stat.S_ISDIR(st.st_mode):
                if norm(path) not in other_roots and not ctx.protector.is_excluded_dir(path):
                    stack.append((path, restricted))
            elif stat.S_ISREG(st.st_mode) and st.st_size >= min_size:
                if path.suffix.lower() in PARTIAL_DOWNLOAD_SUFFIXES or is_cloud_only(st):
                    continue
                yield FileInfo(path, st.st_size, st.st_mtime_ns, drive, restricted=restricted)


def _log_skip(drive: Drive, folder: Path, reason: str) -> None:
    """浅い階層のフォルダを飛ばしたときだけ記録する (-v で表示。深い階層はきりがないので省略)。"""
    try:
        depth = len(folder.relative_to(drive.root).parts)
    except ValueError:
        depth = 0
    if depth <= 3:
        log.info("重複検出: %s を飛ばしました: %s", folder, reason)


def _drop_hardlinks(files: list[FileInfo]) -> list[FileInfo]:
    """ハードリンクされたファイルは除く (1 つ消しても容量が空かないため)。作成日時もここで取る。"""
    result = []
    for f in files:
        try:
            st = os.lstat(longpath(f.path))
        except OSError:
            continue
        if st.st_nlink > 1:
            continue
        f.birthtime = _birthtime(st)
        result.append(f)
    return result


def _split(files: list[FileInfo], key: Callable[[FileInfo], str | None]) -> list[list[FileInfo]]:
    groups: dict[str, list[FileInfo]] = defaultdict(list)
    for f in files:
        k = key(f)
        if k is not None:
            groups[k].append(f)
    return [g for g in groups.values() if len(g) >= 2]


def find_groups(ctx: DedupeContext, files: Iterable[FileInfo]) -> list[list[FileInfo]]:
    """同じ内容のファイルのグループ (2 件以上) の一覧。"""
    by_size: dict[int, list[FileInfo]] = defaultdict(list)
    for f in files:
        by_size[f.size].append(f)
    groups = []
    for same_size in by_size.values():
        if len(same_size) < 2:
            continue
        for same_partial in _split(_drop_hardlinks(same_size),
                                   lambda f: ctx.cache.partial(f.path, f.size, f.mtime_ns)):
            groups.extend(_split(same_partial, lambda f: ctx.cache.full(f.path, f.size, f.mtime_ns)))
    return groups


# ---- フォルダ丸ごとの重複 ----


class FolderMatcher:
    def __init__(self, ctx: DedupeContext):
        self.ctx = ctx
        self._listings: dict[str, dict[str, tuple[Path, int, int]] | None] = {}
        self._matches: dict[tuple[str, str], bool] = {}
        # ドライブ直下やユーザーの標準フォルダそのものは、フォルダ単位の重複として扱わない
        self._never = {norm(p) for p in (*_user_folders(ctx.paths), *(d.root for d in ctx.drives))}

    def listing(self, folder: Path) -> dict[str, tuple[Path, int, int]] | None:
        """相対パス -> (パス, サイズ, 更新日時)。ファイルが多すぎる・読めない場合は None。"""
        key = norm(folder)
        if key not in self._listings:
            self._listings[key] = self._list(folder)
        return self._listings[key]

    @staticmethod
    def _list(folder: Path) -> dict[str, tuple[Path, int, int]] | None:
        result: dict[str, tuple[Path, int, int]] = {}
        stack = [folder]
        while stack:
            current = stack.pop()
            try:
                entries = list(os.scandir(longpath(current)))
            except OSError:
                return None
            for entry in entries:
                path = current / entry.name
                try:
                    st = entry.stat(follow_symlinks=False)
                except OSError:
                    return None
                if is_link(st) or is_cloud_only(st):
                    return None
                if stat.S_ISDIR(st.st_mode):
                    stack.append(path)
                    continue
                result[os.path.normcase(os.path.relpath(path, folder))] = (path, st.st_size, st.st_mtime_ns)
                if len(result) > MAX_FOLDER_FILES:
                    return None
        return result

    def match(self, a: Path, b: Path) -> bool:
        """2 つのフォルダの中身 (ファイル構成と内容) が完全に一致するか。"""
        if is_under(a, b) or is_under(b, a) or norm(a) in self._never or norm(b) in self._never:
            return False
        key = tuple(sorted((norm(a), norm(b))))
        if key not in self._matches:
            self._matches[key] = self._compare(a, b)
        return self._matches[key]

    def _compare(self, a: Path, b: Path) -> bool:
        la, lb = self.listing(a), self.listing(b)
        if la is None or lb is None or len(la) < MIN_FOLDER_FILES or la.keys() != lb.keys():
            return False
        if any(la[rel][1] != lb[rel][1] for rel in la):
            return False
        cache = self.ctx.cache
        for rel in la:
            ha = cache.full(*la[rel])
            if ha is None or ha != cache.full(*lb[rel]):
                return False
        return True

    def top_pair(self, a: FileInfo, b: FileInfo) -> tuple[Path, Path] | None:
        """2 つの重複ファイルを含む、中身が一致するフォルダの組のうち最も上のもの。"""
        da, db = a.path.parent, b.path.parent
        best = None
        while self.match(da, db):
            best = (da, db)
            if da.parent == da or db.parent == db:
                break
            da, db = da.parent, db.parent
        return best


def _folder_clusters(matcher: FolderMatcher, groups: list[list[FileInfo]]) -> list[list[Path]]:
    """中身が完全に一致するフォルダのまとまり (3 か所以上に同じフォルダがあれば 1 つにまとめる)。"""
    parent: dict[str, str] = {}
    folders: dict[str, Path] = {}

    def find(k: str) -> str:
        while parent[k] != k:
            parent[k] = parent[parent[k]]
            k = parent[k]
        return k

    for group in groups:
        peers = group[:MAX_FOLDER_PEERS]
        for i, a in enumerate(peers):
            for b in peers[i + 1:]:
                pair = matcher.top_pair(a, b)
                if not pair:
                    continue
                keys = [norm(f) for f in pair]
                for k, f in zip(keys, pair, strict=True):
                    parent.setdefault(k, k)
                    folders[k] = f
                parent[find(keys[0])] = find(keys[1])

    clusters: dict[str, list[Path]] = defaultdict(list)
    for k, f in folders.items():
        clusters[find(k)].append(f)
    return list(clusters.values())


# ---- 判定 ----


@dataclass
class Decision:
    dup: FileInfo
    keep: FileInfo
    cross_drive: bool


def decide(rule: KeepRule, group: list[FileInfo]) -> list[Decision]:
    """ドライブごとに 1 つ残し、さらにドライブ間で 1 つ残す。"""
    def order(files: list[FileInfo]) -> list[FileInfo]:
        return sorted(files, key=lambda f: rule.key(f.path, f.birthtime))

    by_drive: dict[str, list[FileInfo]] = defaultdict(list)
    for f in group:
        by_drive[f.drive.volume_id].append(f)
    decisions = []
    drive_keepers = []
    for files in by_drive.values():
        keep, *dups = order(files)
        drive_keepers.append(keep)
        decisions.extend(Decision(d, keep, False) for d in dups)
    keep, *others = order(drive_keepers)
    decisions.extend(Decision(d, keep, True) for d in others)
    return decisions


def _unchanged(f: FileInfo) -> bool:
    try:
        st = os.lstat(longpath(f.path))
    except OSError:
        return False
    return (st.st_size, st.st_mtime_ns) == (f.size, f.mtime_ns)


def collect(ctx: DedupeContext) -> Iterator[Result]:
    c = ctx.cfg["dedupe"]
    min_size = c["min_size_kb"] * 1024
    files = [f for drive in ctx.drives for f in _scan(ctx, drive, min_size)]
    log.info("重複検出: %d ファイルを走査", len(files))

    groups = []
    for group in find_groups(ctx, files):
        members = []
        for f in group:
            reason = ctx.protector.check(f.path, newest_mtime=f.mtime_ns / 1e9, allow_git=bool(f.restricted))
            if reason:
                yield Skipped(f.path, "duplicate", reason)
            else:
                members.append(f)
        if len(members) >= 2:
            groups.append(members)

    rule = KeepRule(ctx.paths, c["keep_priority"])

    # フォルダ丸ごとの重複は承認待ちにし、その中のファイルは個別には動かさない
    frozen: list[Path] = []
    reported: list[Path] = []
    matcher = FolderMatcher(ctx)

    def folder_size(folder: Path) -> int:
        return sum(s for _, s, _ in (matcher.listing(folder) or {}).values())

    # 外側の (大きい) フォルダから処理し、すでに候補にしたフォルダの中にあるものは重ねて出さない
    clusters = sorted(_folder_clusters(matcher, groups), key=lambda c: -folder_size(c[0]))
    for cluster in clusters:
        frozen.extend(cluster)

        def covered(folder: Path) -> bool:
            return any(is_under(folder, r) for r in reported)

        keep, *dups = sorted(cluster, key=lambda f: (covered(f), rule.key(f, _folder_birthtime(f))))
        for dup in dups:
            if covered(dup):
                continue
            reported.append(dup)
            listing = matcher.listing(dup) or {}
            newest = max((m for _, _, m in listing.values()), default=0) / 1e9
            reason = ctx.protector.check(dup, newest_mtime=newest)
            if reason:
                yield Skipped(dup, "duplicate_folder", reason)
                continue
            yield Candidate(
                path=dup, feature=FEATURE, category="duplicate_folder",
                reason=f"フォルダの中身がすべて {keep} と同じ ({len(listing)} ファイル)",
                size=folder_size(dup), is_dir=True, approval=True,
            )

    decisions = [d for g in groups for d in decide(rule, g)
                 if not any(is_under(d.dup.path, r) or is_under(d.keep.path, r) for r in frozen)]
    # 同一ドライブ内を先に処理し、大きいものから並べる
    decisions.sort(key=lambda d: (d.cross_drive, -d.dup.size, norm(d.dup.path)))
    for d in decisions:
        # 走査後に変更・削除されていたら触らない (残す側が消えていたら特に危険)
        if not (_unchanged(d.dup) and _unchanged(d.keep)):
            log.info("走査後に変更されたためスキップ: %s", d.dup.path)
            continue
        # Git リポジトリ・アプリのフォルダが絡む重複は、消すとアプリが動かなくなりうるので承認待ち
        restricted = d.dup.restricted or d.keep.restricted
        note = f" ※{restricted}内のため自動では隔離しません" if restricted else ""
        yield Candidate(
            path=d.dup.path,
            feature=FEATURE,
            category="duplicate_cross_drive" if d.cross_drive else "duplicate",
            reason=f"{d.keep.path} と同じ内容 ({human_size(d.dup.size)}){note}",
            size=d.dup.size,
            approval=bool(restricted) or (d.cross_drive and c["cross_drive"] == "report"),
        )


def _folder_birthtime(path: Path) -> float:
    try:
        return _birthtime(os.lstat(longpath(path)))
    except OSError:
        return 0.0
