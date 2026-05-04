"""Push routes: device-token registration + admin broadcast."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, status
from sqlalchemy import select

from app.deps import CurrentAdmin, CurrentUser, DBSession
from app.models.device_token import DeviceToken
from app.schemas.payment import PushBroadcastIn, PushBroadcastOut, PushRegisterIn
from app.services.push import send_push

router = APIRouter(prefix="/push", tags=["push"])


@router.post("/register", status_code=status.HTTP_204_NO_CONTENT)
async def register_token(payload: PushRegisterIn, user: CurrentUser, db: DBSession) -> None:
    """Idempotent: upsert by token."""
    existing = (
        await db.execute(select(DeviceToken).where(DeviceToken.token == payload.token))
    ).scalar_one_or_none()

    categories_str = ",".join(sorted(set(payload.categories))) or "events,editorial,my_listing"
    if existing is None:
        existing = DeviceToken(
            token=payload.token,
            user_id=user.id,
            categories=categories_str,
            kanton=payload.kanton.upper() if payload.kanton else None,
        )
        db.add(existing)
    else:
        existing.user_id = user.id
        existing.categories = categories_str
        existing.kanton = payload.kanton.upper() if payload.kanton else existing.kanton
        existing.last_seen_at = datetime.now(UTC)
    await db.commit()


# Admin broadcast
admin_router = APIRouter(prefix="/admin/push", tags=["admin"])


@admin_router.post("/broadcast", response_model=PushBroadcastOut)
async def admin_broadcast(
    payload: PushBroadcastIn, admin: CurrentAdmin, db: DBSession
) -> PushBroadcastOut:
    stmt = select(DeviceToken)
    if payload.kanton:
        stmt = stmt.where(DeviceToken.kanton == payload.kanton.upper())
    rows = (await db.execute(stmt)).scalars().all()
    targeted = [
        r for r in rows if payload.category in (r.categories or "").split(",")
    ]
    sent = await send_push(
        [t.token for t in targeted],
        title=payload.title,
        body=payload.body,
        data={"category": payload.category},
    )
    return PushBroadcastOut(sent=sent, targeted=len(targeted))
