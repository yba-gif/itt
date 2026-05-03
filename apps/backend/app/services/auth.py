"""Auth service — JWT issuance, password hashing, Apple SIWA verification."""

from __future__ import annotations

import time
from datetime import UTC, datetime, timedelta
from uuid import UUID

import httpx
import jwt
from passlib.hash import argon2

from app.config import settings

# JWKS cache (Apple keys rotate but rarely; refresh hourly).
_jwks_cache: dict[str, dict] = {}
_jwks_fetched_at: float = 0.0
_JWKS_TTL = 3600


def hash_password(password: str) -> str:
    return argon2.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return argon2.verify(password, hashed)
    except Exception:
        return False


def issue_jwt(user_id: UUID, is_admin: bool = False) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "is_admin": is_admin,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=settings.jwt_ttl_seconds)).timestamp()),
    }
    return jwt.encode(payload, settings.app_secret, algorithm=settings.jwt_algorithm)


def decode_jwt(token: str) -> dict:
    return jwt.decode(token, settings.app_secret, algorithms=[settings.jwt_algorithm])


async def _fetch_apple_jwks() -> dict[str, dict]:
    global _jwks_cache, _jwks_fetched_at
    if _jwks_cache and (time.time() - _jwks_fetched_at) < _JWKS_TTL:
        return _jwks_cache
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(settings.apple_jwks_url)
        resp.raise_for_status()
        keys = resp.json().get("keys", [])
    _jwks_cache = {k["kid"]: k for k in keys}
    _jwks_fetched_at = time.time()
    return _jwks_cache


async def verify_apple_identity_token(identity_token: str) -> dict:
    """Verify an Apple ID identity_token and return the decoded claims.

    Raises:
        jwt.PyJWTError: if signature, audience, issuer, or expiry is invalid.
    """
    headers = jwt.get_unverified_header(identity_token)
    kid = headers.get("kid")
    if not kid:
        raise jwt.InvalidTokenError("missing kid")

    jwks = await _fetch_apple_jwks()
    key_data = jwks.get(kid)
    if not key_data:
        # Try refreshing once in case keys rotated.
        global _jwks_fetched_at
        _jwks_fetched_at = 0
        jwks = await _fetch_apple_jwks()
        key_data = jwks.get(kid)
    if not key_data:
        raise jwt.InvalidTokenError(f"unknown kid {kid}")

    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key_data)
    return jwt.decode(
        identity_token,
        public_key,
        algorithms=["RS256"],
        audience=settings.apple_bundle_id,
        issuer=settings.apple_issuer,
    )
