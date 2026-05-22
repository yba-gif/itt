#!/usr/bin/env bash
# Pull latest code + restart backend on an already-deployed Hetzner VPS.
# Run from your Mac:  bash scripts/redeploy.sh <VPS_IP>
#
# What it does:
#   1. SSHes into the VPS
#   2. Pulls latest code in /opt/itt
#   3. Uploads your local .env.prod (overwrites server's .env)
#   4. Rebuilds + restarts the backend container
#
# Prerequisites:
#   - First-time deploy already done via scripts/deploy.sh
#   - infra/hetzner/.env.prod has correct values (incl. GEMINI_API_KEY)

set -euo pipefail

VPS_IP="${1:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "Usage: bash scripts/redeploy.sh <VPS_IP>"
  echo ""
  echo "Tip: api.clawdcloud.xyz resolves to your VPS — find the IP with:"
  echo "     dig +short api.clawdcloud.xyz"
  exit 1
fi

ENV_FILE="$(dirname "$0")/../infra/hetzner/.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

# Sanity check — warn if GEMINI_API_KEY is empty
if ! grep -E '^GEMINI_API_KEY=.+' "$ENV_FILE" >/dev/null; then
  echo "⚠️  GEMINI_API_KEY is empty in .env.prod — İTT AI will return 502."
  echo "   Continue anyway? (y/N)"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

SSH="ssh -o StrictHostKeyChecking=accept-new root@$VPS_IP"

echo "==> Pulling latest code on $VPS_IP..."
$SSH bash << 'REMOTE'
set -euo pipefail
cd /opt/itt
git fetch --all
# Use the branch currently checked out on the server (likely main or ui/design-system-sprints-1-5)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Server is on branch: $CURRENT_BRANCH"
git pull origin "$CURRENT_BRANCH"
REMOTE

echo "==> Uploading .env..."
scp -o StrictHostKeyChecking=accept-new "$ENV_FILE" "root@$VPS_IP:/opt/itt/.env"

echo "==> Rebuilding + restarting backend..."
$SSH bash << 'REMOTE'
set -euo pipefail
cd /opt/itt
docker compose -f infra/hetzner/docker-compose.prod.yml --env-file .env up -d --build backend
echo ""
echo "==> Backend status:"
docker compose -f infra/hetzner/docker-compose.prod.yml --env-file .env ps backend
REMOTE

echo ""
echo "✅ Redeploy complete. Verify with:"
echo "   curl https://api.clawdcloud.xyz/openapi.json | jq '.paths | keys[]' | grep ai"
