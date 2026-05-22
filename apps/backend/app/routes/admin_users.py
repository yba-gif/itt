"""Admin user management routes.

- GET  /admin/users           — paginated list of users with admin status
- PATCH /admin/users/{id}     — toggle is_admin (the only editable field for now)
- GET  /admin/ai-questions    — paginated log of user → AI questions

All routes require admin auth via CurrentAdmin.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select

from app.deps import CurrentAdmin, DBSession
from app.models.ai_question import AIQuestion
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["admin"])


# --- Schemas ---------------------------------------------------------------


class UserOut(BaseModel):
    id: UUID
    email: str
    display_name: str | None
    is_admin: bool
    created_at: datetime


class UsersPageOut(BaseModel):
    items: list[UserOut]
    total: int
    page: int
    page_size: int


class UserAdminToggleIn(BaseModel):
    is_admin: bool


class AIQuestionOut(BaseModel):
    id: UUID
    user_id: UUID | None
    question: str
    response_chars: int
    lang: str | None
    created_at: datetime


class AIQuestionsPageOut(BaseModel):
    items: list[AIQuestionOut]
    total: int
    page: int
    page_size: int


# --- Users -----------------------------------------------------------------


@router.get("/users", response_model=UsersPageOut)
async def list_users(
    admin: CurrentAdmin,
    db: DBSession,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    q: str | None = Query(default=None, description="email/name contains"),
    admins_only: bool = Query(default=False),
) -> UsersPageOut:
    stmt = select(User)
    count_stmt = select(func.count()).select_from(User)
    if admins_only:
        stmt = stmt.where(User.is_admin.is_(True))
        count_stmt = count_stmt.where(User.is_admin.is_(True))
    if q:
        like = f"%{q.strip()}%"
        stmt = stmt.where((User.email.ilike(like)) | (User.display_name.ilike(like)))
        count_stmt = count_stmt.where((User.email.ilike(like)) | (User.display_name.ilike(like)))

    total = (await db.execute(count_stmt)).scalar() or 0
    stmt = stmt.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    rows = (await db.execute(stmt)).scalars().all()

    return UsersPageOut(
        items=[
            UserOut(
                id=r.id,
                email=r.email,
                display_name=r.display_name,
                is_admin=r.is_admin,
                created_at=r.created_at,
            )
            for r in rows
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.patch("/users/{user_id}", response_model=UserOut)
async def set_user_admin(
    user_id: UUID,
    payload: UserAdminToggleIn,
    admin: CurrentAdmin,
    db: DBSession,
) -> UserOut:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "user not found")
    # Guard: don't allow an admin to demote themselves — would lock them out.
    if user.id == admin.id and payload.is_admin is False:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "An admin cannot demote themselves. Use another admin account.",
        )
    user.is_admin = payload.is_admin
    await db.commit()
    await db.refresh(user)
    return UserOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        is_admin=user.is_admin,
        created_at=user.created_at,
    )


# --- AI questions log ------------------------------------------------------


@router.get("/ai-questions", response_model=AIQuestionsPageOut)
async def list_ai_questions(
    admin: CurrentAdmin,
    db: DBSession,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
) -> AIQuestionsPageOut:
    total = (await db.execute(select(func.count()).select_from(AIQuestion))).scalar() or 0
    stmt = (
        select(AIQuestion)
        .order_by(AIQuestion.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return AIQuestionsPageOut(
        items=[
            AIQuestionOut(
                id=r.id,
                user_id=r.user_id,
                question=r.question,
                response_chars=r.response_chars,
                lang=r.lang,
                created_at=r.created_at,
            )
            for r in rows
        ],
        total=total,
        page=page,
        page_size=page_size,
    )
