#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
PROFILE_DIR="${DAYZ_PROFILE_DIR:-/dayz/profiles}"
LOG_DIR="${DAYZ_LOG_DIR:-/dayz/logs}"
CONFIG_DIR="${DAYZ_CONFIG_DIR:-/dayz/config}"
SERVER_CONFIG="${DAYZ_SERVER_CONFIG:-serverDZ.cfg}"
SERVER_PORT="${DAYZ_SERVER_PORT:-2302}"
AUTO_UPDATE="${DAYZ_AUTO_UPDATE:-1}"
STEAMCMD_ROOT="${STEAMCMD_ROOT:-/opt/steamcmd}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
DAYZ_HOME="/home/dayz"
STEAM_DOT_DIR="$DAYZ_HOME/.steam"
STEAM_HOME_DIR="$DAYZ_HOME/Steam"

log() {
  printf '[crayz] %s\n' "$*"
}

fail() {
  printf '[crayz] ERROR: %s\n' "$*" >&2
  exit 1
}

ensure_directories() {
  mkdir -p "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"
}

require_root() {
  if [[ "$(id -u)" != "0" ]]; then
    fail "Entrypoint must start as root so it can apply PUID/PGID ownership before dropping privileges."
  fi
}

validate_id() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    fail "$name must be a numeric Linux id, got '$value'."
  fi
}

ensure_dayz_group() {
  local current_gid
  local group_for_gid

  group_for_gid="$(getent group "$PGID" | cut -d: -f1 || true)"

  if getent group dayz >/dev/null; then
    current_gid="$(getent group dayz | cut -d: -f3)"
    if [[ "$current_gid" != "$PGID" ]]; then
      if [[ -n "$group_for_gid" && "$group_for_gid" != "dayz" ]]; then
        fail "PGID $PGID is already used by group '$group_for_gid'. Choose another PGID or adjust the image."
      fi
      groupmod -g "$PGID" dayz
    fi
  else
    if [[ -n "$group_for_gid" ]]; then
      fail "PGID $PGID is already used by group '$group_for_gid'. Cannot create required dayz group."
    fi
    groupadd --gid "$PGID" dayz
  fi
}

ensure_dayz_user() {
  local current_uid
  local user_for_uid

  user_for_uid="$(getent passwd "$PUID" | cut -d: -f1 || true)"

  if id dayz >/dev/null 2>&1; then
    current_uid="$(id -u dayz)"
    if [[ "$current_uid" != "$PUID" ]]; then
      if [[ -n "$user_for_uid" && "$user_for_uid" != "dayz" ]]; then
        fail "PUID $PUID is already used by user '$user_for_uid'. Choose another PUID or adjust the image."
      fi
      usermod -u "$PUID" dayz
    fi
    usermod -g dayz -d "$DAYZ_HOME" -s /bin/bash dayz
  else
    if [[ -n "$user_for_uid" ]]; then
      fail "PUID $PUID is already used by user '$user_for_uid'. Cannot create required dayz user."
    fi
    useradd --uid "$PUID" --gid dayz --home-dir "$DAYZ_HOME" --create-home --shell /bin/bash dayz
  fi
}

prepare_permissions() {
  ensure_directories

  # Only the small image-managed SteamCMD install is recursively owned. Bind
  # mounts are limited to top-level ownership to avoid expensive startup scans.
  chown -R dayz:dayz "$STEAMCMD_ROOT"
  chown dayz:dayz "$DAYZ_HOME"
  chown dayz:dayz /dayz "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"
}

configure_runtime_user() {
  require_root
  validate_id PUID "$PUID"
  validate_id PGID "$PGID"
  ensure_dayz_group
  ensure_dayz_user
  prepare_permissions
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

if [[ "${1:-}" != "run-as-dayz" ]]; then
  configure_runtime_user
  exec gosu dayz /usr/local/bin/dayz-entrypoint run-as-dayz
fi

shift

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
