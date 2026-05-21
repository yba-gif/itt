#!/usr/bin/env bash
# Upload v1 migration images to Cloudflare R2.
#
# Prerequisites:
#   1. Install wrangler:  npm install -g wrangler
#   2. Authenticate:      wrangler login   (or set CLOUDFLARE_API_TOKEN env var)
#   3. Set env vars:      export CLOUDFLARE_ACCOUNT_ID=<your-account-id>
#                         export R2_BUCKET=itt-media
#
# Run:
#   cd /Users/bek/itt/seeds
#   bash upload_to_r2.sh
#
# After upload, the images are served at:
#   https://<r2-public-url>/images/<uuid>.jpg
# Update S3_PUBLIC_URL in .env to point to the R2 public bucket URL.

set -euo pipefail

IMAGES_DIR="$(cd "$(dirname "$0")/images" && pwd)"
BUCKET="${R2_BUCKET:-itt-media}"
PREFIX="images"
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"

if [[ -z "$ACCOUNT_ID" ]]; then
  echo "❌  CLOUDFLARE_ACCOUNT_ID is not set. Export it and re-run."
  exit 1
fi

if ! command -v wrangler &>/dev/null; then
  echo "❌  wrangler not found. Run: npm install -g wrangler"
  exit 1
fi

FILES=("$IMAGES_DIR"/*)
TOTAL=${#FILES[@]}
OK=0
FAIL=0

echo "📤  Uploading $TOTAL images → r2://$BUCKET/$PREFIX/"
echo ""

for FILE in "${FILES[@]}"; do
  FILENAME=$(basename "$FILE")
  EXT="${FILENAME##*.}"

  case "${EXT,,}" in
    jpg|jpeg) MIME="image/jpeg" ;;
    png)      MIME="image/png"  ;;
    webp)     MIME="image/webp" ;;
    *)        MIME="application/octet-stream" ;;
  esac

  KEY="$PREFIX/$FILENAME"

  if wrangler r2 object put "$BUCKET/$KEY" \
      --file "$FILE" \
      --content-type "$MIME" \
      --account-id "$ACCOUNT_ID" \
      2>/dev/null; then
    echo "  ✓  $FILENAME"
    ((OK++))
  else
    echo "  ✗  $FILENAME"
    ((FAIL++))
  fi
done

echo ""
echo "Done: $OK uploaded, $FAIL failed (total $TOTAL)"

if [[ $FAIL -gt 0 ]]; then
  echo "Re-run the script — wrangler retries are safe (idempotent PUT)."
  exit 1
fi
