#!/usr/bin/env bash
# Delete the AD Stack containers AND all domain data, then leave a clean slate.
set -euo pipefail
cd "$(dirname "$0")/docker"

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "This deletes the domain and ALL data. Continue? [y/N] " answer
  [[ "$answer" == [yY] ]] || { echo "Aborted."; exit 1; }
fi

docker compose down -v
echo "[OK] Containers and volumes removed."
echo "     Run ./start.sh to provision a fresh domain."
