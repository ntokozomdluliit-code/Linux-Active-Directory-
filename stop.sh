#!/usr/bin/env bash
# Stop the AD Stack. All data is preserved in Docker volumes.
set -euo pipefail
cd "$(dirname "$0")/docker"

docker compose down
echo "[OK] Stack stopped. AD data preserved (run ./start.sh to resume)."
