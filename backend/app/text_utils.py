from __future__ import annotations

import re
import unicodedata

from .errors import ApiError

_CONTROL = re.compile(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]")
_SPACES = re.compile(r"[ \t ]+")


def clean_tts_text(text: str, max_chars: int) -> str:
    # NFKC folds Arabic presentation forms (common in PDF extraction) back to base letters.
    text = unicodedata.normalize("NFKC", text or "")
    text = _CONTROL.sub(" ", text)
    text = _SPACES.sub(" ", text).strip()
    if not text:
        raise ApiError(422, "empty_text", "لا يوجد نص لقراءته.")
    if len(text) > max_chars:
        raise ApiError(
            413, "text_too_long", "النص أطول من الحد المسموح ({0} حرفًا).".format(max_chars)
        )
    return text


def clean_context(text: str, keep: str = "tail", limit: int = 600) -> str:
    """Context passed to the provider for smoother prosody across chunks.

    previous_text keeps its tail (closest to the current chunk); next_text keeps its head.
    """
    text = unicodedata.normalize("NFKC", text or "")
    text = _SPACES.sub(" ", _CONTROL.sub(" ", text)).strip()
    if len(text) <= limit:
        return text
    return text[-limit:] if keep == "tail" else text[:limit]
