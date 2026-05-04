"""APNs push service.

Phase 3: env-driven APNs sender with a logger-only fallback when the
``APNS_KEY_P8_PATH`` is not configured. Real production deployments need:

  - APNS_KEY_ID    (the Key ID from Apple Developer)
  - APNS_KEY_P8_PATH (path to the .p8 file inside the container)
  - APNS_TOPIC     (defaults to ch.itt-rehber.app)
  - APNS_USE_SANDBOX = false in prod, true in dev
  - APPLE_TEAM_ID  (set in app.config)

Categories per PRD §5.9: "events", "editorial", "saved_search", "my_listing".
"""

from __future__ import annotations

import logging
from typing import Iterable

from app.config import settings

log = logging.getLogger("itt.push")

# Lazy-import aioapns to avoid blowing up at import time when the package
# isn't yet installed (e.g., during Alembic-only contexts).
_apns_client = None


async def _get_client():
    global _apns_client
    if _apns_client is not None:
        return _apns_client
    if not settings.apns_key_id or not settings.apns_key_p8_path:
        return None
    try:
        from aioapns import APNs  # type: ignore
    except Exception:
        log.warning("aioapns not importable; falling back to logger-only push")
        return None
    _apns_client = APNs(
        key=settings.apns_key_p8_path,
        key_id=settings.apns_key_id,
        team_id=settings.apple_team_id,
        topic=settings.apns_topic,
        use_sandbox=settings.apns_use_sandbox,
    )
    return _apns_client


async def send_push(
    tokens: Iterable[str],
    *,
    title: str,
    body: str,
    data: dict | None = None,
) -> int:
    """Send a push to a batch of device tokens. Returns the number sent
    (or 0 in fallback mode)."""
    tokens = list(tokens)
    if not tokens:
        return 0

    client = await _get_client()
    if client is None:
        log.info(
            "push[no-apns] tokens=%d title=%r body=%r data=%s",
            len(tokens), title, body, data,
        )
        return 0

    try:
        from aioapns import NotificationRequest  # type: ignore
    except Exception:
        return 0

    sent = 0
    for token in tokens:
        request = NotificationRequest(
            device_token=token,
            message={
                "aps": {
                    "alert": {"title": title, "body": body},
                    "sound": "default",
                },
                **(data or {}),
            },
        )
        try:
            await client.send_notification(request)
            sent += 1
        except Exception:
            log.exception("push send failed for token=%s", token[:12])
    return sent
