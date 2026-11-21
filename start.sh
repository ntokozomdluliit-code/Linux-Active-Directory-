#!/usr/bin/env bash
# Start the AD Stack (Samba AD DC + LDAP Account Manager).
set -euo pipefail
cd "$(dirname "$0")"
exec ./docker/start.sh
