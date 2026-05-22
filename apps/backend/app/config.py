"""App configuration loaded from env vars."""

from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    app_secret: str = "dev-secret-change-me-32-bytes-or-more-please"

    database_url: str = "postgresql+asyncpg://itt:itt_dev@postgres:5432/itt"

    jwt_algorithm: str = "HS256"
    jwt_ttl_seconds: int = 60 * 60 * 24 * 30  # 30 days

    apple_bundle_id: str = "ch.itt-rehber.app"
    apple_team_id: str = ""
    apple_jwks_url: str = "https://appleid.apple.com/auth/keys"
    apple_issuer: str = "https://appleid.apple.com"

    sentry_dsn: str = ""

    admin_seed_email: str = "bek@itt-rehber.ch"
    admin_seed_password: str = "changeme"

    cors_origins: str = "http://localhost:5173,http://localhost:8000"

    s3_endpoint_url: str = "http://minio:9000"
    s3_region: str = "eu-central-1"
    s3_bucket: str = "itt-media"
    s3_access_key: str = "ittminio"
    s3_secret_key: str = "ittminio_dev"
    s3_public_url: str = "http://localhost:9000/itt-media"

    # SMTP (optional — empty = log-only fallback for dev).
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_starttls: bool = True
    smtp_from_email: str = ""
    smtp_from_name: str = "ITT-Rehber"

    # APNs (optional — empty = log-only push fallback for dev).
    apns_key_id: str = ""
    apns_key_p8_path: str = ""
    apns_topic: str = "ch.itt-rehber.app"
    apns_use_sandbox: bool = True

    # AI proxy keys — keep server-side, never in the iOS bundle.
    # GEMINI_API_KEY kept for compat in case we revert; OPENAI_API_KEY is current.
    gemini_api_key: str = ""
    openai_api_key: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
