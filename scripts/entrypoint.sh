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
  mkdir -p "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR"
}

write_default_server_config() {
  local target_config="$1"

  cat > "$target_config" <<'EOF'
// CrayZ - default vanilla DayZ server config
// This file was created automatically on first startup.
// Edit it locally; CrayZ will not overwrite an existing config file.

hostname = "CrayZ Test Server";
password = "";
passwordAdmin = "ChangeThisAdminPassword";
maxPlayers = 10;

verifySignatures = 2;
forceSameBuild = 1;

disableVoN = 0;
vonCodecQuality = 20;

persistent = 1;
timeStampFormat = "Short";

serverTime = "SystemTime";
serverTimeAcceleration = 1;
serverNightTimeAcceleration = 1;

class Missions
{
    class DayZ
    {
        template = "dayzOffline.chernarusplus";
    };
};
EOF
}

seed_server_config_if_missing() {
  local default_config="$CONFIG_DIR/serverDZ.cfg"
  local selected_config="$CONFIG_DIR/$SERVER_CONFIG"

  if [[ ! -f "$default_config" ]]; then
    log "Creating default vanilla DayZ server config at $default_config."
    write_default_server_config "$default_config"
  fi

  if [[ "$selected_config" != "$default_config" && ! -f "$selected_config" ]]; then
    log "Creating selected DayZ server config at $selected_config."
    write_default_server_config "$selected_config"
  fi
}

seed_mods_file_if_missing() {
  local target_mods="$CONFIG_DIR/mods.txt"

  if [[ -f "$target_mods" ]]; then
    return 0
  fi

  log "Creating default empty mod list at $target_mods."

  cat > "$target_mods" <<'EOF'
# CrayZ mod list
#
# Workshop mod support is intentionally not implemented yet.
# Future format:
# WORKSHOP_ID|@LocalModFolderName
#
# Example:
# 1559212036|@CF
EOF
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
seed_server_config_if_missing
seed_mods_file_if_missing

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
