"""Backend-side voice metadata (no audio is stored). SQLite, one file under DATA_DIR."""
from __future__ import annotations

import os
import sqlite3
import threading
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


class MetadataStore:
    def __init__(self, data_dir: str) -> None:
        os.makedirs(data_dir, exist_ok=True)
        self._path = os.path.join(data_dir, "voices.db")
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(self._path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        with self._lock:
            self._conn.execute(
                """
                CREATE TABLE IF NOT EXISTS voices (
                    voice_id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    provider TEXT NOT NULL,
                    status TEXT NOT NULL,
                    consent_type TEXT NOT NULL,
                    consent_person TEXT,
                    consent_at TEXT NOT NULL,
                    sample_count INTEGER NOT NULL DEFAULT 0,
                    total_seconds REAL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )
            self._conn.commit()

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    def add(
        self,
        voice_id: str,
        name: str,
        provider: str,
        status: str,
        consent_type: str,
        consent_person: Optional[str],
        sample_count: int,
        total_seconds: Optional[float],
    ) -> Dict[str, Any]:
        now = _now()
        with self._lock:
            self._conn.execute(
                "INSERT OR REPLACE INTO voices VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (
                    voice_id,
                    name,
                    provider,
                    status,
                    consent_type,
                    consent_person,
                    now,
                    sample_count,
                    total_seconds,
                    now,
                    now,
                ),
            )
            self._conn.commit()
        return self.get(voice_id)  # type: ignore[return-value]

    def get(self, voice_id: str) -> Optional[Dict[str, Any]]:
        with self._lock:
            row = self._conn.execute(
                "SELECT * FROM voices WHERE voice_id = ?", (voice_id,)
            ).fetchone()
        return dict(row) if row else None

    def list(self) -> List[Dict[str, Any]]:
        with self._lock:
            rows = self._conn.execute("SELECT * FROM voices ORDER BY created_at DESC").fetchall()
        return [dict(r) for r in rows]

    def update(self, voice_id: str, **fields: Any) -> Optional[Dict[str, Any]]:
        if not fields:
            return self.get(voice_id)
        fields["updated_at"] = _now()
        cols = ", ".join("{0} = ?".format(k) for k in fields)
        with self._lock:
            self._conn.execute(
                "UPDATE voices SET {0} WHERE voice_id = ?".format(cols),
                list(fields.values()) + [voice_id],
            )
            self._conn.commit()
        return self.get(voice_id)

    def delete(self, voice_id: str) -> None:
        with self._lock:
            self._conn.execute("DELETE FROM voices WHERE voice_id = ?", (voice_id,))
            self._conn.commit()
