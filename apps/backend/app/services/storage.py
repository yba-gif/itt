"""S3-compatible object storage (MinIO in dev, R2 in prod).

Phase 1: presigned upload URL helper. Image moderation runs at moderation step.
"""

from __future__ import annotations

from functools import lru_cache

import boto3

from app.config import settings


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
