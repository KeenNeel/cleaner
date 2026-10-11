"""多重起動防止のロック。"""

from __future__ import annotations

import os
from pathlib import Path

from cleaner import winapi


class AlreadyRunning(Exception):
    pass


class RunLock:
    def __init__(self, path: Path):
        self.path = path
        self._f = None

    def __enter__(self) -> RunLock:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        f = open(self.path, "a+")
        try:
            if winapi.IS_WINDOWS:  # pragma: no cover
                import msvcrt

                f.seek(0)
                msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as e:
            f.close()
            raise AlreadyRunning("別の cleaner が実行中です") from e
        f.seek(0)
        f.truncate()
        f.write(str(os.getpid()))
        f.flush()
        self._f = f
        return self

    def __exit__(self, *exc) -> None:
        if self._f is None:
            return
        try:
            if winapi.IS_WINDOWS:  # pragma: no cover
                import msvcrt

                self._f.seek(0)
                msvcrt.locking(self._f.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(self._f.fileno(), fcntl.LOCK_UN)
        finally:
            self._f.close()
            self._f = None
