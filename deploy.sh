#!/bin/bash
# Flappy Fever: 検証込みデプロイ(compile→smoke→export→build→push→deploy)
# 使い方: ./deploy.sh [tag]
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
GC="$HOME/google-cloud-sdk/bin/gcloud"
PROJ="flappy-fever-2071ed"; REGION="asia-northeast1"
TAG="${1:-r$(date +%s)}"
IMG="$REGION-docker.pkg.dev/$PROJ/web/flappy-fever:$TAG"

echo "== compile =="
if "$GODOT" --headless --editor --quit --path . 2>&1 | grep -iE "SCRIPT ERROR|parse error" | grep -vi update_scripts; then
  echo "!! COMPILE FAILED"; exit 1
fi

echo "== smoke (300f) =="
if "$GODOT" --headless --path . --quit-after 300 2>&1 | grep -iE "SCRIPT ERROR|Invalid|nil\b" | grep -vi update_scripts; then
  echo "!! SMOKE FAILED"; exit 1
fi

echo "== export web =="
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" "$PWD/build/web/index.html" >/dev/null 2>&1 || true
[ -f build/web/index.wasm ] || { echo "!! EXPORT FAILED"; exit 1; }

echo "== build/push/deploy ($TAG) =="
docker build --platform linux/amd64 -t "$IMG" . >/dev/null
docker push "$IMG" >/dev/null
"$GC" run deploy flappy-fever --image "$IMG" --region "$REGION" --allow-unauthenticated \
  --port 8080 --memory 256Mi --cpu 1 --min-instances 0 --max-instances 3 --concurrency 80 \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJ" --quiet 2>&1 | tail -2
echo "== DONE $TAG =="
