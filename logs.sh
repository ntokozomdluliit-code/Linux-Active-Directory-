#!/usr/bin/env bash
# Follow logs: ./logs.sh samba   or   ./logs.sh lam
set -euo pipefail
cd "$(dirname "$0")/docker"

service="${1:-samba}"
case "$service" in
  samba|lam) ;;
  *) echo "usage: ./logs.sh [samba|lam]" >&2; exit 1 ;;
esac

docker compose logs -f --tail=100 "$service"
