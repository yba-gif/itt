"""FastAPI entry point."""

from __future__ import annotations

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routes import auth, content, events, health, listings, me, moderation, reference, search

if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.app_env,
        traces_sample_rate=0.05,
    )

app = FastAPI(
    title="ITT-Rehber API",
    version="0.1.0",
    description="Backend for ITT-Rehber 2.0 — Turkish community directory in Switzerland.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(reference.router)
app.include_router(listings.router)
app.include_router(events.router)
app.include_router(events.admin_router)
app.include_router(content.router)
app.include_router(me.router)
app.include_router(search.router)
app.include_router(moderation.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"name": "ITT-Rehber API", "version": "0.1.0"}
