"""Image upload endpoint — server-side validation + EXIF strip + R2 PUT."""

from __future__ import annotations

from fastapi import APIRouter, File, UploadFile

from app.deps import CurrentUser
from app.services.storage import normalize_and_upload_image

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/image")
async def upload_image(
    user: CurrentUser,
    file: UploadFile = File(...),
) -> dict[str, str]:
    raw = await file.read()
    url = normalize_and_upload_image(
        raw,
        content_type=file.content_type or "application/octet-stream",
        prefix="listings",
    )
    return {"image_url": url}
