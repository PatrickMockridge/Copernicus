#!/usr/bin/env bash
# Boot/stop a local RChain devnet and fund wallets.
# Thin wrapper around ~/RNodeRust/tools/devnet.sh (Docker-based).
set -euo pipefail

RNODE_ROOT="${RNODE_ROOT:-$HOME/RNodeRust}"
DEVNET="$RNODE_ROOT/tools/devnet.sh"
PUBLIC_API="${RCHAIN_PUBLIC_API:-http://localhost:40403}"

usage() {
  echo "Usage: $0 {up|down|status|faucet <addr>|deploy <file>|query <name>}"
  exit 1
}

case "${1:-}" in
  up)
    "$DEVNET" up --validators 1
    echo "RNode public API: $PUBLIC_API"
    ;;
  down)
    "$DEVNET" down
    ;;
  status)
    curl -s "$PUBLIC_API/api/status"
    echo
    ;;
  faucet)
    addr="${2:?usage: faucet <address>}"
    curl -s -X POST "$PUBLIC_API/api/faucet" -H 'Content-Type: application/json' \
      -d "{\"address\":\"$addr\"}"
    echo
    ;;
  deploy)
    file="${2:?usage: deploy <file>}"
    "$DEVNET" deploy "$file"
    ;;
  query)
    name="${2:?usage: query <name>}"
    "$DEVNET" query "$name"
    ;;
  *)
    usage
    ;;
esac
