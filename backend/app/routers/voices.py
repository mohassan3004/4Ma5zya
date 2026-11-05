from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, File, Form, UploadFile
from pydantic import BaseModel, Field

from ..audio_validation import new_workdir, save_and_validate, total_known_duration
from ..config import get_settings
from ..deps import get_provider, get_store
from ..errors import ApiError
from ..metadata_store import MetadataStore
from ..providers.base import ProviderError, VoiceProvider
from ..security import require_token

log = logging.getLogger("4ma5zya.voices")
router = APIRouter(prefix="/v1/voices", tags=["voices"], dependencies=[Depends(require_token)])

CONSENT_TYPES = ("self", "other_with_consent")


def _wrap(e: ProviderError) -> ApiError:
    return ApiError(e.status_code, e.code, e.message_ar)


def _clean_name(name: str) -> str:
    name = (name or "").strip()
    if not name or len(name) > 60:
        raise ApiError(422, "invalid_name", "اسم الصوت مطلوب ويجب ألا يتجاوز 60 حرفًا.")
    return name


def _public(v: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "voice_id": v["voice_id"],
        "name": v["name"],
        "provider": v["provider"],
        "status": v["status"],
        "consent_type": v["consent_type"],
        "consent_person": v.get("consent_person"),
        "sample_count": v["sample_count"],
        "total_seconds": v.get("total_seconds"),
        "created_at": v["created_at"],
        "updated_at": v["updated_at"],
    }


@router.get("")
async def list_voices(store: MetadataStore = Depends(get_store)) -> Dict[str, Any]:
    return {"voices": [_public(v) for v in store.list()]}


@router.get("/{voice_id}")
async def get_voice(
    voice_id: str,
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    meta = store.get(voice_id)
    if meta is None:
        raise ApiError(404, "voice_not_found", "الصوت غير موجود.")
    try:
        remote = await provider.get_voice(voice_id)
    except ProviderError as e:
        raise _wrap(e)
    status = "missing" if remote is None else remote.get("status", "ready")
    if status != meta["status"]:
        meta = store.update(voice_id, status=status) or meta
    return _public(meta)


@router.post("", status_code=201)
async def create_voice(
    name: str = Form(...),
    consent_type: str = Form(...),
    consent_confirmed: bool = Form(...),
    consent_person: Optional[str] = Form(default=None),
    description: str = Form(default=""),
    files: List[UploadFile] = File(...),
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    settings = get_settings()
    name = _clean_name(name)
    if consent_type not in CONSENT_TYPES:
        raise ApiError(422, "invalid_consent", "نوع الموافقة غير صالح.")
    if not consent_confirmed:
        raise ApiError(
            422, "consent_required", "يجب تأكيد الموافقة الصريحة لصاحب الصوت قبل الاستنساخ."
        )
    if consent_type == "other_with_consent" and not (consent_person or "").strip():
        raise ApiError(422, "consent_person_required", "يرجى كتابة اسم صاحب الصوت الذي وافق.")

    with new_workdir() as workdir:
        samples = await save_and_validate(
            files, workdir, settings.max_sample_bytes, settings.max_samples_per_request
        )
        total = total_known_duration(samples)
        if total is not None and total < settings.min_total_sample_seconds:
            raise ApiError(
                422,
                "insufficient_audio",
                "مدة التسجيلات ({0:.0f} ثانية) أقل من الحد الأدنى ({1:.0f} ثانية). "
                "يُنصح بدقيقة إلى ثلاث دقائق من الكلام الواضح.".format(
                    total, settings.min_total_sample_seconds
                ),
            )
        labels = {"language": "ar", "app": "4ma5zya", "consent": consent_type}
        try:
            created = await provider.create_voice(
                name, description[:400] if description else "", samples, labels
            )
        except ProviderError as e:
            raise _wrap(e)
    log.info("voice created provider=%s samples=%d", provider.name, len(samples))
    meta = store.add(
        voice_id=created.voice_id,
        name=name,
        provider=provider.name,
        status=created.status,
        consent_type=consent_type,
        consent_person=(consent_person or "").strip() or None,
        sample_count=len(samples),
        total_seconds=total,
    )
    return _public(meta)


class ImportVoiceBody(BaseModel):
    voice_id: str = Field(..., min_length=3, max_length=64)
    name: str = Field(..., min_length=1, max_length=60)
    consent_type: str
    consent_confirmed: bool
    consent_person: Optional[str] = None


@router.post("/import", status_code=201)
async def import_voice(
    body: ImportVoiceBody,
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    """Register a voice that already exists in the provider account (e.g. created on its website)."""
    if body.consent_type not in CONSENT_TYPES or not body.consent_confirmed:
        raise ApiError(422, "consent_required", "يجب تأكيد الموافقة الصريحة لصاحب الصوت.")
    try:
        remote = await provider.get_voice(body.voice_id)
    except ProviderError as e:
        raise _wrap(e)
    if remote is None:
        raise ApiError(404, "voice_not_found", "لم يُعثر على صوت بهذا المعرّف لدى مزود الخدمة.")
    meta = store.add(
        voice_id=body.voice_id,
        name=_clean_name(body.name),
        provider=provider.name,
        status=remote.get("status", "ready"),
        consent_type=body.consent_type,
        consent_person=(body.consent_person or "").strip() or None,
        sample_count=0,
        total_seconds=None,
    )
    return _public(meta)


@router.post("/{voice_id}/samples")
async def add_samples(
    voice_id: str,
    files: List[UploadFile] = File(...),
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    settings = get_settings()
    meta = store.get(voice_id)
    if meta is None:
        raise ApiError(404, "voice_not_found", "الصوت غير موجود.")
    with new_workdir() as workdir:
        samples = await save_and_validate(
            files, workdir, settings.max_sample_bytes, settings.max_samples_per_request
        )
        added = total_known_duration(samples)
        try:
            await provider.add_samples(voice_id, meta["name"], samples)
        except ProviderError as e:
            raise _wrap(e)
    total = meta.get("total_seconds")
    if added is not None:
        total = (total or 0.0) + added
    meta = store.update(
        voice_id, sample_count=meta["sample_count"] + len(samples), total_seconds=total
    )
    return _public(meta)  # type: ignore[arg-type]


class RenameBody(BaseModel):
    name: str


@router.patch("/{voice_id}")
async def rename_voice(
    voice_id: str,
    body: RenameBody,
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    name = _clean_name(body.name)
    if store.get(voice_id) is None:
        raise ApiError(404, "voice_not_found", "الصوت غير موجود.")
    try:
        await provider.rename_voice(voice_id, name)
    except ProviderError as e:
        raise _wrap(e)
    return _public(store.update(voice_id, name=name))  # type: ignore[arg-type]


@router.delete("/{voice_id}")
async def delete_voice(
    voice_id: str,
    store: MetadataStore = Depends(get_store),
    provider: VoiceProvider = Depends(get_provider),
) -> Dict[str, Any]:
    if store.get(voice_id) is None:
        raise ApiError(404, "voice_not_found", "الصوت غير موجود.")
    try:
        await provider.delete_voice(voice_id)
    except ProviderError as e:
        raise _wrap(e)
    store.delete(voice_id)
    log.info("voice deleted provider=%s", provider.name)
    return {"deleted": True}
