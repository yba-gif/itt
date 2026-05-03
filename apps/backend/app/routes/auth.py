"""Auth routes: SIWA, email signup/login, /me, account deletion."""

from __future__ import annotations

from datetime import UTC, datetime

import jwt
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import delete, select, update

from app.deps import CurrentUser, DBSession
from app.models.listing import Listing, ListingStatus
from app.models.user import User
from app.schemas.auth import (
    EmailLoginIn,
    EmailSignupIn,
    MeOut,
    SIWAIn,
    TokenOut,
)
from app.services.auth import (
    hash_password,
    issue_jwt,
    verify_apple_identity_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/email/signup", response_model=TokenOut)
async def email_signup(payload: EmailSignupIn, db: DBSession) -> TokenOut:
    existing = (await db.execute(select(User).where(User.email == payload.email))).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="email_taken")
    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return TokenOut(
        access_token=issue_jwt(user.id, user.is_admin),
        user_id=user.id,
        is_admin=user.is_admin,
    )


@router.post("/email/login", response_model=TokenOut)
async def email_login(payload: EmailLoginIn, db: DBSession) -> TokenOut:
    user = (
        await db.execute(select(User).where(User.email == payload.email))
    ).scalar_one_or_none()
    if user is None or user.deleted_at is not None or user.password_hash is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="invalid_credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="invalid_credentials")
    return TokenOut(
        access_token=issue_jwt(user.id, user.is_admin),
        user_id=user.id,
        is_admin=user.is_admin,
    )


@router.post("/siwa", response_model=TokenOut)
async def sign_in_with_apple(payload: SIWAIn, db: DBSession) -> TokenOut:
    try:
        claims = await verify_apple_identity_token(payload.identity_token)
    except jwt.PyJWTError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail=f"siwa_invalid: {e}") from e

    apple_user_id = claims.get("sub")
    email = claims.get("email")
    if not apple_user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="siwa_no_sub")

    user = (
        await db.execute(select(User).where(User.apple_user_id == apple_user_id))
    ).scalar_one_or_none()

    if user is None and email:
        user = (
            await db.execute(select(User).where(User.email == email))
        ).scalar_one_or_none()
        if user is not None:
            user.apple_user_id = apple_user_id

    if user is None:
        if not email:
            # First SIWA login can elide email if user opted out; we synthesize a
            # placeholder per Apple's relay-email guidance.
            email = f"{apple_user_id}@privaterelay.appleid.com"
        user = User(
            email=email,
            apple_user_id=apple_user_id,
            display_name=payload.display_name,
        )
        db.add(user)

    await db.commit()
    await db.refresh(user)
    return TokenOut(
        access_token=issue_jwt(user.id, user.is_admin),
        user_id=user.id,
        is_admin=user.is_admin,
    )


@router.get("/me", response_model=MeOut)
async def me(user: CurrentUser) -> MeOut:
    return MeOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        is_admin=user.is_admin,
        language=user.language,
    )


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_me(user: CurrentUser, db: DBSession) -> None:
    """Self-serve account deletion (App Store 5.1.1(v)).

    PRD §5.6: active paid listings stay live until paid_until; ownership is anonymized.
    """
    now = datetime.now(UTC)
    # Anonymize active listings owned by this user.
    await db.execute(
        update(Listing)
        .where(
            Listing.owner_id == user.id,
            Listing.status == ListingStatus.active,
        )
        .values(owner_id=None)
    )
    # Hard-delete pending listings owned by this user.
    await db.execute(
        delete(Listing).where(
            Listing.owner_id == user.id, Listing.status == ListingStatus.pending
        )
    )
    user.deleted_at = now
    user.email = f"deleted-{user.id}@itt-rehber.invalid"
    user.password_hash = None
    user.apple_user_id = None
    user.display_name = None
    await db.commit()
