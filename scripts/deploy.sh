#!/usr/bin/env bash
# First-time deploy to a fresh Hetzner Ubuntu VPS.
# Run from your Mac: bash scripts/deploy.sh <VPS_IP>
#
# What it does:
#   1. SSHes into the VPS, installs Docker + git
#   2. Clones the repo to /opt/itt
#   3. Uploads your .env.prod as /opt/itt/.env
#   4. Runs docker compose build + up
#
# Prerequisites:
#   - VPS is Ubuntu 22.04+ with your SSH key authorised
#   - infra/hetzner/.env.prod exists locally (copy from .env.prod.example and fill in)
#   - DNS A-records for api.<DOMAIN> and admin.<DOMAIN> already point to the VPS IP

set -euo pipefail

VPS_IP="${1:-}"
if [[ -z "$VPS_IP" ]]; then
  echo "Usage: bash scripts/deploy.sh <VPS_IP>"
  exit 1
fi

ENV_FILE="$(dirname "$0")/../infra/hetzner/.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy infra/hetzner/.env.prod.example and fill in values."
  exit 1
fi

SSH="ssh -o StrictHostKeyChecking=accept-new root@$VPS_IP"

echo "==> Connecting to $VPS_IP..."

$SSH bash << 'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Installing Docker..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
echo "Docker $(docker --version) installed."

echo "==> Cloning repo..."
mkdir -p /opt/itt
if [[ -d /opt/itt/.git ]]; then
  cd /opt/itt && git pull
else
  git clone https://github.com/yba-gif/itt.git /opt/itt
fi
REMOTE

echo "==> Uploading .env..."
scp -o StrictHostKeyChecking=accept-new "$ENV_FILE" "root@$VPS_IP:/opt/itt/.env"

$SSH bash << 'REMOTE'
set -euo pipefail
cd /opt/itt
echo "==> Building and starting services..."
docker compose -f infra/hetzner/docker-compose.prod.yml --env-file .env up -d --build 2>&1
echo ""
echo "==> Status:"
docker compose -f infra/hetzner/docker-compose.prod.yml --env-file .env ps
REMOTE

echo ""
echo "✅ Deploy complete."
echo "   API:   https://api.$(grep '^DOMAIN=' "$ENV_FILE" | cut -d= -f2)/healthz"
echo "   Admin: https://admin.$(grep '^DOMAIN=' "$ENV_FILE" | cut -d= -f2)"
echo ""
echo "⏳ TLS certs provision automatically on first HTTPS request (30-60s)."
