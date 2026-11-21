#!/usr/bin/env bash
# Show AD Stack health: containers, domain users, DNS, web GUI.
set -euo pipefail
cd "$(dirname "$0")/docker"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a; source .env; set +a
fi
AD_REALM="${AD_REALM:-AD.EXAMPLE.COM}"

LAN_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

echo "== Containers =="
docker compose ps

echo
echo "== Domain =="
echo "  Realm : ${AD_REALM}"
echo "  Host  : ${LAN_IP:-unknown}"

if docker exec samba-ad true >/dev/null 2>&1; then
  echo
  echo "== AD users =="
  docker exec samba-ad samba-tool user list 2>/dev/null | sed 's/^/  /' || true

  echo
  echo "== DNS =="
  docker exec samba-ad host -t A "dc1.${AD_REALM,,}" 127.0.0.1 2>/dev/null \
    | grep 'has address' | sed 's/^/  /' || echo "  no A record found"
else
  echo
  echo "Samba container is not running."
fi

echo
echo "== Web GUI =="
code=$(curl -sS -m 5 -o /dev/null -w '%{http_code}' \
  http://localhost:8080/templates/login.php 2>/dev/null || true)
if [[ "$code" == "200" ]]; then
  echo "  OK  http://localhost:8080/templates/login.php (HTTP 200)"
else
  echo "  Not reachable (HTTP ${code:-000}). Try ./logs.sh lam"
fi
