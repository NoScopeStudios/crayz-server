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
DAYZ_HOME="${DAYZ_HOME:-/home/dayz}"
STEAM_DOT_DIR=""
STEAM_HOME_DIR=""
DAYZ_RUNTIME_USER="${DAYZ_RUNTIME_USER:-dayz}"
DAYZ_RUNTIME_GROUP="${DAYZ_RUNTIME_GROUP:-dayz}"

log() {
  printf '[crayz] %s\n' "$*"
}

fail() {
  printf '[crayz] ERROR: %s\n' "$*" >&2
  exit 1
}

ensure_directories() {
  STEAM_DOT_DIR="$DAYZ_HOME/.steam"
  STEAM_HOME_DIR="$DAYZ_HOME/Steam"
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
  local group_for_gid

  group_for_gid="$(getent group "$PGID" | cut -d: -f1 || true)"

  if [[ -n "$group_for_gid" ]]; then
    DAYZ_RUNTIME_GROUP="$group_for_gid"
    log "Using existing group '$DAYZ_RUNTIME_GROUP' for PGID $PGID."
    return 0
  fi

  if ! getent group dayz >/dev/null; then
    groupadd --gid "$PGID" dayz
    log "Created group 'dayz' with PGID $PGID."
  else
    groupmod -g "$PGID" dayz
    log "Updated group 'dayz' to PGID $PGID."
  fi

  DAYZ_RUNTIME_GROUP="dayz"
}

ensure_dayz_user() {
  local current_uid
  local current_primary_group
  local existing_home
  local user_for_uid

  user_for_uid="$(getent passwd "$PUID" | cut -d: -f1 || true)"

  if [[ -n "$user_for_uid" && "$user_for_uid" != "dayz" ]]; then
    DAYZ_RUNTIME_USER="$user_for_uid"
    current_primary_group="$(id -gn "$DAYZ_RUNTIME_USER")"
    if [[ "$current_primary_group" != "$DAYZ_RUNTIME_GROUP" ]]; then
      if usermod -g "$DAYZ_RUNTIME_GROUP" "$DAYZ_RUNTIME_USER"; then
        log "Updated existing user '$DAYZ_RUNTIME_USER' primary group to '$DAYZ_RUNTIME_GROUP'."
      else
        log "Could not update existing user '$DAYZ_RUNTIME_USER' primary group from '$current_primary_group' to '$DAYZ_RUNTIME_GROUP'; mounted path writability will be checked before startup continues."
      fi
    fi

    if usermod -d "$DAYZ_HOME" -s /bin/bash "$DAYZ_RUNTIME_USER"; then
      log "Using '$DAYZ_HOME' as home for existing user '$DAYZ_RUNTIME_USER'."
    else
      existing_home="$(getent passwd "$DAYZ_RUNTIME_USER" | cut -d: -f6)"
      if [[ -n "$existing_home" ]]; then
        DAYZ_HOME="$existing_home"
        log "Could not update home for existing user '$DAYZ_RUNTIME_USER'; using existing home '$DAYZ_HOME'."
      else
        fail "Existing user '$DAYZ_RUNTIME_USER' does not have a usable home directory."
      fi
    fi

    log "Using existing user '$DAYZ_RUNTIME_USER' for PUID $PUID."
  elif id dayz >/dev/null 2>&1; then
    DAYZ_RUNTIME_USER="dayz"
    current_uid="$(id -u dayz)"
    if [[ "$current_uid" != "$PUID" ]]; then
      usermod -u "$PUID" dayz
    fi
    usermod -g "$DAYZ_RUNTIME_GROUP" -d "$DAYZ_HOME" -s /bin/bash dayz
  else
    DAYZ_RUNTIME_USER="dayz"
    useradd --uid "$PUID" --gid "$DAYZ_RUNTIME_GROUP" --home-dir "$DAYZ_HOME" --create-home --shell /bin/bash dayz
  fi

  log "Runtime user/group selected: '$DAYZ_RUNTIME_USER' (PUID $PUID) / '$DAYZ_RUNTIME_GROUP' (PGID $PGID)."
}

prepare_permissions() {
  ensure_directories

  # Only the small image-managed SteamCMD install is recursively owned. Bind
  # mounts are limited to top-level ownership to avoid expensive startup scans.
  chown -R "$DAYZ_RUNTIME_USER":"$DAYZ_RUNTIME_GROUP" "$STEAMCMD_ROOT"
  chown "$DAYZ_RUNTIME_USER":"$DAYZ_RUNTIME_GROUP" "$DAYZ_HOME"
  chown "$DAYZ_RUNTIME_USER":"$DAYZ_RUNTIME_GROUP" /dayz "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"
}

assert_runtime_writable() {
  local path

  for path in "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"; do
    if [[ ! -w "$path" ]]; then
      fail "Runtime user '$(id -un)' cannot write to $path. Check PUID=$PUID, PGID=$PGID, and host bind-mount ownership."
    fi
  done
}

log_steam_state_diagnostics() {
  local path

  log "Runtime user: $(id -un) ($(id -u)); group: $(id -gn) ($(id -g)); HOME=${HOME:-unset}."

  for path in "$STEAM_HOME_DIR" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR/config" "$STEAM_HOME_DIR/logs"; do
    if [[ -d "$path" && -w "$path" ]]; then
      log "Steam state directory $path is writable."
    elif [[ -d "$path" ]]; then
      log "Steam state directory $path exists but is not writable."
    else
      log "Steam state directory $path is missing."
    fi
  done
}

log_credential_diagnostics() {
  if [[ -n "${STEAM_USERNAME:-}" ]]; then
    log "STEAM_USERNAME is set."
  else
    log "STEAM_USERNAME is not set."
  fi

  if [[ -n "${STEAM_PASSWORD:-}" ]]; then
    log "STEAM_PASSWORD is set."
  else
    log "STEAM_PASSWORD is not set."
  fi

  if [[ -n "${STEAM_GUARD_CODE:-}" ]]; then
    log "STEAM_GUARD_CODE is set."
  else
    log "STEAM_GUARD_CODE is not set."
  fi

  log "DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=${DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN:-1}."
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
instanceId = 1;

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
  export DAYZ_HOME DAYZ_RUNTIME_USER DAYZ_RUNTIME_GROUP HOME="$DAYZ_HOME"
  exec gosu "$DAYZ_RUNTIME_USER" /usr/local/bin/dayz-entrypoint run-as-dayz
fi

shift

ensure_directories
assert_runtime_writable
log_steam_state_diagnostics
seed_server_config_if_missing
seed_mods_file_if_missing
log_credential_diagnostics

if [[ "$AUTO_UPDATE" == "1" ]]; then
  log "Installing/updating DayZ Dedicated Server with SteamCMD."
  /usr/local/bin/dayz-update-server
else
  log "Skipping SteamCMD update because DAYZ_AUTO_UPDATE is not 1."
fi

copy_config_if_present

if ! SERVER_BINARY="$(find_server_binary)"; then
  if [[ "$AUTO_UPDATE" == "1" ]]; then
    fail "DayZ server executable was not found after SteamCMD install/update."
  fi

  fail "DAYZ_AUTO_UPDATE is not 1 and no DayZ server executable was found in $SERVER_DIR. Run once with DAYZ_AUTO_UPDATE=1 to install/update server files, then set it back to 0 for normal runtime."
fi

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
