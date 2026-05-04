"""Email service.

Phase 3 ships an SMTP path (env-driven) and a logger-only fallback for dev.
Real production deployments wire SENDGRID / Resend / Mailgun via SMTP relay.
"""

from __future__ import annotations

import logging
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import formataddr
from typing import Optional

from app.config import settings

log = logging.getLogger("itt.email")


def _smtp_configured() -> bool:
    return bool(settings.smtp_host and settings.smtp_from_email)


def send_email(
    to: str,
    subject: str,
    body_text: str,
    *,
    body_html: Optional[str] = None,
    attachments: Optional[list[tuple[str, bytes, str]]] = None,
) -> bool:
    """Send an email. Returns True on success, False otherwise.

    attachments: list of (filename, bytes, content_type).
    """
    if not _smtp_configured():
        log.info(
            "email[no-smtp] to=%s subject=%r body=%r attachments=%s",
            to, subject, body_text[:160],
            [(name, len(data), ct) for name, data, ct in (attachments or [])],
        )
        return True  # treat as delivered for dev

    msg = EmailMessage()
    msg["From"] = formataddr((settings.smtp_from_name, settings.smtp_from_email))
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body_text)
    if body_html:
        msg.add_alternative(body_html, subtype="html")
    for filename, data, ct in attachments or []:
        maintype, _, subtype = ct.partition("/")
        msg.add_attachment(data, maintype=maintype or "application", subtype=subtype or "octet-stream", filename=filename)

    try:
        ctx = ssl.create_default_context()
        if settings.smtp_starttls:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as s:
                s.starttls(context=ctx)
                if settings.smtp_user:
                    s.login(settings.smtp_user, settings.smtp_password)
                s.send_message(msg)
        else:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, context=ctx, timeout=10) as s:
                if settings.smtp_user:
                    s.login(settings.smtp_user, settings.smtp_password)
                s.send_message(msg)
        return True
    except Exception:
        log.exception("smtp send failed")
        return False
