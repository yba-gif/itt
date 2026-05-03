"""FastAPI dependencies: current user, current admin, DB session."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models.user import User
from app.services.auth import decode_jwt

DBSession = Annotated[AsyncSession, Depends(get_session)]


async def _current_user_optional(
    authorization: str | None,
    db: AsyncSession,
) -> User | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    try:
        claims = decode_jwt(token)
    except jwt.PyJWTError:
        return None
    user_id_str = claims.get("sub")
    if not user_id_str:
        return None
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        return None
    return await db.get(User, user_id)


async def current_user(
    db: DBSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    user = await _current_user_optional(authorization, db)
    if user is None or user.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid or missing token"
        )
    return user


async def current_user_optional(
    db: DBSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User | None:
    user = await _current_user_optional(authorization, db)
    if user and user.deleted_at is None:
        return user
    return None


async def current_admin(user: Annotated[User, Depends(current_user)]) -> User:
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="admin required")
    return user


CurrentUser = Annotated[User, Depends(current_user)]
CurrentUserOptional = Annotated[User | None, Depends(current_user_optional)]
CurrentAdmin = Annotated[User, Depends(current_admin)]
