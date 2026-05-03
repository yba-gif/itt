# Hetzner Cloud deployment (Phase 1 default)

Single VPS running docker-compose with Postgres, the FastAPI backend, and a Traefik reverse proxy. Object storage runs on Cloudflare R2 (separate account).

## One-time setup

1. Create a Hetzner CX22 (or larger) in `nbg1` (Nuremberg) or `fsn1` (Falkenstein).
2. SSH in, install Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
3. Set DNS:
   - `api.itt-rehber.ch` A-record → VPS IP
   - `admin.itt-rehber.ch` A-record → Cloudflare Pages (admin panel deploys there)
   - `itt-rehber.ch` A-record → Cloudflare Pages (marketing site)
4. Cloudflare R2: create a bucket `itt-media`, generate API tokens, attach a public custom domain (e.g. `media.itt-rehber.ch`).
5. Copy `.env.example` from repo root to `/etc/itt/.env` and fill it in:
   - Strong `APP_SECRET` (≥32 bytes random)
   - Strong `POSTGRES_PASSWORD`
   - R2 access/secret in `S3_ACCESS_KEY` / `S3_SECRET_KEY`
   - `S3_ENDPOINT_URL=https://<account>.r2.cloudflarestorage.com`
   - `S3_PUBLIC_URL=https://media.itt-rehber.ch/itt-media`
   - `LETSENCRYPT_EMAIL=admin@itt-rehber.ch`
6. Bring it up:
   ```bash
   cd /opt/itt
   docker compose -f infra/hetzner/docker-compose.prod.yml --env-file /etc/itt/.env up -d
   ```

## Backups

`pg_dump` daily, encrypted to a Hetzner Storage Box. Cron skeleton:

```bash
0 3 * * * pg_dump -U itt itt | gpg --encrypt -r backup@itt-rehber.ch | rsync -e ssh - storagebox:itt/$(date +\%Y\%m\%d).sql.gpg
```

Wire this in Phase 4 alongside an automated restore drill.

## Future

- Hetzner Load Balancer + multiple backend replicas when concurrent users justify it.
- Replace single-VPS Postgres with managed Postgres (Hetzner does not offer one — fall back to `Crunchy Bridge` or `Neon`'s EU region) when DR matters more than cost.
