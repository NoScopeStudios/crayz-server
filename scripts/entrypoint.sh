#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
PROFILE_DIR="${DAYZ_PROFILE_DIR:-/dayz/profiles}"
LOG_DIR="${DAYZ_LOG_DIR:-/dayz/logs}"
CONFIG_DIR="${DAYZ_CONFIG_DIR:-/dayz/config}"
SERVER_CONFIG="${DAYZ_SERVER_CONFIG:-serverDZ.cfg}"
SERVER_PORT="${DAYZ_SERVER_PORT:-2302}"
AUTO_UPDATE="${DAYZ_AUTO_UPDATE:-1}"

log() {
  printf '[crayz] %s\n' "$*"
}

fail() {
  printf '[crayz] ERROR: %s\n' "$*" >&2
  exit 1
}

ensure_directories() {
  mkdir -p "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR"
}

copy_config_if_present() {
  local source_config="$CONFIG_DIR/$SERVER_CONFIG"
  local target_config="$SERVER_DIR/$SERVER_CONFIG"

  if [[ ! -f "$source_config" ]]; then
    fail "Expected DayZ config file not found: $source_config"
  fi

  cp "$source_config" "$target_config"
}

find_server_binary() {
  local candidates=(
    "$SERVER_DIR/DayZServer"
    "$SERVER_DIR/DayZServer_x64"
    "$SERVER_DIR/DayZServer_x64.exe"
    "$SERVER_DIR/DayZServer.exe"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_directories

if [[ "$AUTO_UPDATE" == "1" ]]; then
  log "Installing/updating DayZ Dedicated Server with SteamCMD."
  /usr/local/bin/dayz-update-server
else
  log "Skipping SteamCMD update because DAYZ_AUTO_UPDATE is not 1."
fi

copy_config_if_present

SERVER_BINARY="$(find_server_binary)" || fail "DayZ server executable was not found after install/update."

if [[ ! -x "$SERVER_BINARY" && "$SERVER_BINARY" != *.exe ]]; then
  chmod +x "$SERVER_BINARY" || fail "Could not mark server executable as runnable: $SERVER_BINARY"
fi

log "Starting vanilla DayZ server on UDP port $SERVER_PORT."

cd "$SERVER_DIR"

exec "$SERVER_BINARY" \
  "-config=$SERVER_CONFIG" \
  "-profiles=$PROFILE_DIR" \
  "-port=$SERVER_PORT" \
  "-adminlog" \
  "-netlog" \
  "-freezecheck" \
  ${DAYZ_EXTRA_ARGS:-}
