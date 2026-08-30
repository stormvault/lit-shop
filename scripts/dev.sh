#!/usr/bin/env bash
#
# dev.sh - automate dependency installation and launch the SHOP dev server.
#
# polymer-cli@1.9.11 (what `npm start` uses) relies on `spdy`, which calls the
# internal `process.binding('http_parser')` removed in Node 12. So the dev
# server only runs on Node 10. This script pins Node 10 via nvm, installs
# dependencies against that runtime, then starts `polymer serve`.
#
# Usage:
#   scripts/dev.sh                 # install if needed, then serve on :8080
#   scripts/dev.sh --force         # wipe node_modules, reinstall, then serve
#   PORT=9000 scripts/dev.sh       # serve on a custom port
#
# Env:
#   PORT       port to serve on            (default: 8080)
#   HOST       hostname to bind            (default: 127.0.0.1)
#   NODE_VER   Node version for nvm        (default: contents of .nvmrc, i.e. 10)

set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"
NODE_VER="${NODE_VER:-$(cat .nvmrc 2>/dev/null || echo 10)}"

log() { printf '\033[1;34m[dev]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[dev] %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. Load nvm and pin the Node version -----------------------------------
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || die "nvm not found at $NVM_DIR - install it: https://github.com/nvm-sh/nvm"

if ! nvm which "$NODE_VER" >/dev/null 2>&1; then
  log "Installing Node $NODE_VER via nvm"
  nvm install "$NODE_VER"
fi
nvm use "$NODE_VER" >/dev/null
log "Using $(node --version) (npm $(npm --version))"

# --- 2. Install dependencies (idempotent) ----------------------------------
if [ "${1:-}" = "--force" ]; then
  log "Removing node_modules for a clean install"
  rm -rf node_modules
fi

# Reinstall when node_modules is missing, older than the lockfile, or was
# built against a different Node ABI than the one we're pinned to now.
abi_stamp="node_modules/.dev-sh-node-abi"
want_abi="$(node -p 'process.versions.modules')"
if [ ! -d node_modules ] \
   || [ package-lock.json -nt node_modules ] \
   || [ "$(cat "$abi_stamp" 2>/dev/null || echo none)" != "$want_abi" ]; then
  log "Installing dependencies (npm ci)"
  npm ci
  echo "$want_abi" > "$abi_stamp"
else
  log "Dependencies already up to date - skipping install"
fi

# --- 3. Launch the dev server --------------------------------------------------
log "Starting polymer serve -> http://${HOST}:${PORT}"
exec node_modules/.bin/polymer serve --hostname "$HOST" --port "$PORT"
