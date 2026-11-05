"""Validation of uploaded voice samples: extension, magic bytes, size and duration.

Samples are written to a private temporary directory only for the duration of the request and
are deleted immediately afterwards. They are never served back or stored permanently.
"""
from __future__ import annotations

import os
import tempfile
from dataclasses import dataclass
from typing import List, Optional

from fastapi import UploadFile

from .errors import ApiError

ALLOWED_EXTENSIONS = {
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".m4a": "audio/mp4",
    ".mp4": "audio/mp4",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".opus": "audio/ogg",
    ".flac": "audio/flac",
    ".webm": "audio/webm",
}

MIN_SAMPLE_BYTES = 2048


@dataclass
class ValidatedSample:
    path: str
    filename: str
    mime: str
    size: int
    duration: Optional[float]


def sniff_audio(head: bytes) -> Optional[str]:
    """Detect the container from magic bytes. Returns a short format name or None."""
    if len(head) < 12:
        return None
    if head[:4] == b"RIFF" and head[8:12] == b"WAVE":
        return "wav"
    if head[4:8] == b"ftyp":
        return "m4a"
    if head[:4] == b"OggS":
        return "ogg"
    if head[:4] == b"fLaC":
        return "flac"
    if head[:4] == b"\x1a\x45\xdf\xa3":
        return "webm"
    if head[:3] == b"ID3":
        return "mp3"
    if head[0] == 0xFF and (head[1] & 0xF6) == 0xF0:
        return "aac"  # ADTS
    if head[0] == 0xFF and (head[1] & 0xE0) == 0xE0:
        return "mp3"
    return None


def audio_duration(path: str) -> Optional[float]:
    try:
        import mutagen  # type: ignore

        f = mutagen.File(path)
        if f is not None and f.info is not None and getattr(f.info, "length", 0):
            return float(f.info.length)
    except Exception:
        return None
    return None


def _safe_name(name: str, index: int, ext: str) -> str:
    # Never trust client-supplied paths; keep only a generic name.
    return "sample_{0:02d}{1}".format(index + 1, ext)


async def save_and_validate(
    files: List[UploadFile],
    workdir: str,
    max_bytes: int,
    max_count: int,
) -> List[ValidatedSample]:
    if not files:
        raise ApiError(422, "no_samples", "لم يتم إرسال أي تسجيل صوتي.")
    if len(files) > max_count:
        raise ApiError(
            422, "too_many_samples", "عدد التسجيلات كبير. الحد الأقصى {0} ملفًا.".format(max_count)
        )
    out: List[ValidatedSample] = []
    for i, up in enumerate(files):
        ext = os.path.splitext(up.filename or "")[1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            raise ApiError(
                415,
                "unsupported_format",
                "صيغة الملف غير مدعومة. الصيغ المدعومة: MP3, WAV, M4A, AAC, OGG, FLAC, WEBM.",
            )
        path = os.path.join(workdir, _safe_name(up.filename or "", i, ext))
        size = 0
        head = b""
        with open(path, "wb") as fh:
            while True:
                chunk = await up.read(1024 * 256)
                if not chunk:
                    break
                if not head:
                    head = chunk[:16]
                size += len(chunk)
                if size > max_bytes:
                    raise ApiError(
                        413,
                        "sample_too_large",
                        "حجم أحد التسجيلات أكبر من الحد المسموح ({0} ميغابايت).".format(
                            max_bytes // (1024 * 1024)
                        ),
                    )
                fh.write(chunk)
        if size < MIN_SAMPLE_BYTES:
            raise ApiError(422, "sample_too_small", "أحد التسجيلات فارغ أو قصير جدًا.")
        if sniff_audio(head) is None:
            raise ApiError(415, "invalid_audio", "أحد الملفات ليس ملفًا صوتيًا صالحًا.")
        out.append(
            ValidatedSample(
                path=path,
                filename=os.path.basename(path),
                mime=ALLOWED_EXTENSIONS[ext],
                size=size,
                duration=audio_duration(path),
            )
        )
    return out


def total_known_duration(samples: List[ValidatedSample]) -> Optional[float]:
    known = [s.duration for s in samples if s.duration is not None]
    if not known:
        return None
    return float(sum(known))


def new_workdir() -> tempfile.TemporaryDirectory:
    return tempfile.TemporaryDirectory(prefix="4ma5zya_")
