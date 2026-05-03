"""Events feed routes.

PRD §5.3: v1's "Gelecekteki Etkinlikler" did NOT actually filter by date and
showed past events too. v2 fixes this — the public feed shows only events
where ``starts_at >= now()``. A separate ``past=true`` query lists historical
events for the "Geçmiş Etkinlikler" sub-tab.

Anyone can submit an event (PRD §5.3: no account required); submissions go
through admin moderation before going live.
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, select

from app.deps import CurrentAdmin, CurrentUserOptional, DBSession
from app.models.event import Event, EventStatus
from app.schemas.event import EventIn, EventListOut, EventOut

router = APIRouter(prefix="/events", tags=["events"])


@router.get("", response_model=EventListOut)
async def list_events(
    db: DBSession,
    kanton: str | None = Query(default=None),
    past: bool = Query(default=False, description="If true, return events that already started."),
) -> EventListOut:
    """Public events feed. Default: only future-or-current events (PRD §5.3 bug fix)."""
    now = datetime.now(UTC)
    stmt = select(Event).where(Event.status == EventStatus.active)
    if past:
        stmt = stmt.where(Event.starts_at < now).order_by(Event.starts_at.desc())
    else:
        stmt = stmt.where(Event.starts_at >= now).order_by(Event.starts_at.asc())
    if kanton:
        stmt = stmt.where(Event.kanton == kanton.upper())

    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar_one()
    rows = (await db.execute(stmt.limit(500))).scalars().all()
    return EventListOut(items=[EventOut.model_validate(r) for r in rows], total=total)


@router.get("/{event_id}", response_model=EventOut)
async def get_event(event_id: UUID, db: DBSession) -> EventOut:
    event = await db.get(Event, event_id)
    if event is None or event.status != EventStatus.active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    return EventOut.model_validate(event)


@router.post("", response_model=EventOut, status_code=status.HTTP_201_CREATED)
async def submit_event(
    payload: EventIn,
    db: DBSession,
    user: CurrentUserOptional,
) -> EventOut:
    """Anyone can submit an event — login optional. Goes through moderation."""
    event = Event(
        title=payload.title,
        description=payload.description,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        kanton=payload.kanton.upper(),
        venue=payload.venue,
        address=payload.address,
        image_url=payload.image_url,
        submitter_email=payload.submitter_email or (user.email if user else None),
        submitter_user_id=user.id if user else None,
        status=EventStatus.pending,
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return EventOut.model_validate(event)


# ---- Admin moderation ----

admin_router = APIRouter(prefix="/admin/events", tags=["admin"])


@admin_router.get("/queue", response_model=list[EventOut])
async def admin_queue(
    admin: CurrentAdmin,
    db: DBSession,
    event_status: EventStatus = Query(default=EventStatus.pending, alias="status"),
) -> list[EventOut]:
    rows = (
        await db.execute(
            select(Event)
            .where(Event.status == event_status)
            .order_by(Event.created_at.asc())
            .limit(500)
        )
    ).scalars().all()
    return [EventOut.model_validate(r) for r in rows]


@admin_router.post("/{event_id}/approve", response_model=EventOut)
async def admin_approve(event_id: UUID, admin: CurrentAdmin, db: DBSession) -> EventOut:
    event = await db.get(Event, event_id)
    if event is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    if event.status != EventStatus.pending:
        raise HTTPException(status.HTTP_409_CONFLICT, detail=f"cannot_approve_from_{event.status.value}")
    event.status = EventStatus.active
    await db.commit()
    await db.refresh(event)
    return EventOut.model_validate(event)


@admin_router.post("/{event_id}/reject", response_model=EventOut)
async def admin_reject(event_id: UUID, admin: CurrentAdmin, db: DBSession) -> EventOut:
    event = await db.get(Event, event_id)
    if event is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="not_found")
    event.status = EventStatus.rejected
    await db.commit()
    await db.refresh(event)
    return EventOut.model_validate(event)
