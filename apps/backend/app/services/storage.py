"""S3-compatible object storage (MinIO in dev, R2 in prod).

Phase 3: server-side image upload + validation (Pillow):
- accept JPG/PNG only
- min 200x200, max 4000x4000
- normalize to JPEG, strip EXIF
- max 5MB after normalization
"""

from __future__ import annotations

import io
from functools import lru_cache
from uuid import uuid4

import boto3
from fastapi import HTTPException, status
from PIL import Image, UnidentifiedImageError

from app.config import settings

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/jpg"}
MIN_DIMENSION = 200
MAX_DIMENSION = 4000
MAX_OUTPUT_BYTES = 5 * 1024 * 1024


@lru_cache(maxsize=1)
def s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
    )


def presigned_put_url(key: str, content_type: str = "image/jpeg", expires_in: int = 600) -> str:
    return s3_client().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": settings.s3_bucket,
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )


def public_url(key: str) -> str:
    return f"{settings.s3_public_url}/{key}"


def normalize_and_upload_image(raw: bytes, content_type: str, prefix: str = "listings") -> str:
    """Validate, normalize, EXIF-strip, and upload an image. Return public URL."""
    if content_type.lower() not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"unsupported_content_type: {content_type}",
        )
    try:
        img = Image.open(io.BytesIO(raw))
        img.load()
    except UnidentifiedImageError:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="not_an_image")

    w, h = img.size
    if w < MIN_DIMENSION or h < MIN_DIMENSION:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="image_too_small")
    if w > MAX_DIMENSION or h > MAX_DIMENSION:
        # Resize down rather than rejecting outright.
        img.thumbnail((MAX_DIMENSION, MAX_DIMENSION), Image.LANCZOS)

    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGB")

    out = io.BytesIO()
    img.save(out, format="JPEG", quality=82, optimize=True)
    data = out.getvalue()
    if len(data) > MAX_OUTPUT_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="image_too_large")

    key = f"{prefix}/{uuid4().hex}.jpg"
    s3_client().put_object(
        Bucket=settings.s3_bucket,
        Key=key,
        Body=data,
        ContentType="image/jpeg",
    )
    return public_url(key)
