#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
PROFILE_DIR="${DAYZ_PROFILE_DIR:-/dayz/profiles}"
LOG_DIR="${DAYZ_LOG_DIR:-/dayz/logs}"
CONFIG_DIR="${DAYZ_CONFIG_DIR:-/dayz/config}"
SERVER_CONFIG="${DAYZ_SERVER_CONFIG:-serverDZ.cfg}"
ACTIVE_CONFIG="$CONFIG_DIR/$SERVER_CONFIG"
MOD_ROOT="${DAYZ_MOD_ROOT:-/dayz/mods/workshop}"
MODS_FILE="$CONFIG_DIR/mods.txt"
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
CLIENT_MOD_PATHS=()
SERVER_MOD_PATHS=()
DAYZ_MOD_ARGS=()

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
  mkdir -p "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$MOD_ROOT" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"
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
  chown "$DAYZ_RUNTIME_USER":"$DAYZ_RUNTIME_GROUP" /dayz "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$MOD_ROOT" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"
}

assert_runtime_writable() {
  local path

  for path in "$SERVER_DIR" "$PROFILE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$MOD_ROOT" "$STEAM_DOT_DIR" "$STEAM_HOME_DIR"; do
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
steamQueryPort = 27016;

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
# This file loads local mod folders and can list individual Workshop items.
#
# Format:
# folder_name|load_type
# workshop_id|folder_name|load_type
#
# Local-only lines require the folder to already exist.
# Workshop lines are downloaded/updated only when DAYZ_AUTO_UPDATE=1.
# Normal runtime with DAYZ_AUTO_UPDATE=0 only loads already-present folders.
#
# load_type:
# client = add the folder to the DayZ -mod= parameter and copy .bikey files from keys/ or Keys/
# server = add the folder to the DayZ -servermod= parameter
#
# Mod folders are expected under /dayz/mods/workshop inside the container.
# CrayZ creates matching symlinks under /dayz/server and launches DayZ with relative @ModName entries.
#
# Examples:
# @CF|client
# 1559212036|@CF|client
# @VPPAdminTools|server
# @Some Server Mod|client
EOF
}

require_active_config() {
  if [[ ! -f "$ACTIVE_CONFIG" ]]; then
    fail "Expected DayZ config file not found: $ACTIVE_CONFIG"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

copy_client_mod_keys() {
  local mod_path="$1"
  local server_key_dir="$SERVER_DIR/keys"
  local key_dir
  local key_file
  local key_count=0
  local key_dir_count=0
  local seen_key_dir
  local skip_key_dir
  local target_key
  local seen_key_dirs=()
  local key_dirs=(
    "$mod_path/keys"
    "$mod_path/Keys"
  )

  for key_dir in "${key_dirs[@]}"; do
    if [[ ! -d "$key_dir" ]]; then
      continue
    fi

    skip_key_dir=0
    for seen_key_dir in "${seen_key_dirs[@]}"; do
      if [[ "$key_dir" -ef "$seen_key_dir" ]]; then
        skip_key_dir=1
        break
      fi
    done

    if (( skip_key_dir == 1 )); then
      continue
    fi

    seen_key_dirs+=("$key_dir")
    key_dir_count=$((key_dir_count + 1))
    mkdir -p "$server_key_dir"

    while IFS= read -r -d '' key_file; do
      key_count=$((key_count + 1))
      target_key="$server_key_dir/$(basename "$key_file")"
      if [[ -f "$target_key" ]] && cmp -s "$key_file" "$target_key"; then
        log "Client mod key already current: $(basename "$key_file")"
      else
        cp "$key_file" "$target_key"
        log "Copied client mod key: $(basename "$key_file")"
      fi
    done < <(find "$key_dir" -maxdepth 1 -type f -name '*.bikey' -print0)
  done

  if (( key_dir_count == 0 )); then
    log "Client mod $(basename "$mod_path") has no keys/ or Keys/ directory; no .bikey files copied."
  elif (( key_count == 0 )); then
    log "Client mod $(basename "$mod_path") has keys/ or Keys/ directories but no .bikey files were found."
  fi
}

warn_if_no_addons_dir() {
  local mod_path="$1"

  if [[ ! -d "$mod_path/addons" && ! -d "$mod_path/Addons" ]]; then
    log "Mod $(basename "$mod_path") has no addons/ or Addons/ directory; verify this mod layout is expected."
  fi
}

ensure_server_mod_link() {
  local folder_name="$1"
  local mod_path="$2"
  local link_path="$SERVER_DIR/$folder_name"
  local existing_target

  if [[ -L "$link_path" ]]; then
    existing_target="$(readlink "$link_path")"
    if [[ "$existing_target" == "$mod_path" ]]; then
      log "Enabled mod link already current: $link_path -> $mod_path"
      return 0
    fi

    rm -f -- "$link_path"
    ln -s "$mod_path" "$link_path"
    log "Refreshed enabled mod link: $link_path -> $mod_path"
    return 0
  fi

  if [[ -e "$link_path" ]]; then
    fail "Cannot enable mod '$folder_name': $link_path already exists and is not a symlink. Move or remove it before starting CrayZ."
  fi

  ln -s "$mod_path" "$link_path"
  log "Created enabled mod link: $link_path -> $mod_path"
}

load_mods_file() {
  local line_number=0
  local raw_line
  local line
  local trimmed_line
  local field1
  local field2
  local field3
  local extra_field
  local workshop_id
  local folder_name
  local load_type
  local mod_path

  CLIENT_MOD_PATHS=()
  SERVER_MOD_PATHS=()
  DAYZ_MOD_ARGS=()

  if [[ ! -f "$MODS_FILE" ]]; then
    return 0
  fi

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line="${raw_line%$'\r'}"
    trimmed_line="$(trim "$line")"

    if [[ -z "$trimmed_line" || "${trimmed_line:0:1}" == "#" ]]; then
      continue
    fi

    field1=""
    field2=""
    field3=""
    extra_field=""
    workshop_id=""
    IFS='|' read -r field1 field2 field3 extra_field <<< "$trimmed_line"

    if [[ -n "$extra_field" ]]; then
      fail "Invalid mods.txt line $line_number. Expected format: folder_name|load_type or workshop_id|folder_name|load_type"
    fi

    if [[ -n "$field3" ]]; then
      workshop_id="$(trim "$field1")"
      folder_name="$(trim "$field2")"
      load_type="$(trim "$field3")"

      if [[ ! "$workshop_id" =~ ^[0-9]+$ ]]; then
        fail "Invalid mods.txt line $line_number. Workshop ID must be numeric."
      fi
    else
      folder_name="$(trim "$field1")"
      load_type="$(trim "$field2")"
    fi

    if [[ -z "$folder_name" ]]; then
      fail "Invalid mods.txt line $line_number. Mod folder name is empty."
    fi

    if [[ "$folder_name" == */* || "$folder_name" == *\\* ]]; then
      fail "Invalid mods.txt line $line_number. Mod folder name must not contain path separators."
    fi

    if [[ "$load_type" != "client" && "$load_type" != "server" ]]; then
      fail "Invalid mods.txt line $line_number. load_type must be 'client' or 'server'."
    fi

    mod_path="$MOD_ROOT/$folder_name"
    if [[ ! -d "$mod_path" ]]; then
      fail "Listed $load_type mod folder is missing: $mod_path"
    fi

    if [[ "$load_type" == "client" ]]; then
      ensure_server_mod_link "$folder_name" "$mod_path"
      warn_if_no_addons_dir "$mod_path"
      CLIENT_MOD_PATHS+=("$folder_name")
      copy_client_mod_keys "$mod_path"
    else
      ensure_server_mod_link "$folder_name" "$mod_path"
      warn_if_no_addons_dir "$mod_path"
      SERVER_MOD_PATHS+=("$folder_name")
    fi
  done < "$MODS_FILE"
}

join_mod_paths() {
  local IFS=';'
  printf '%s' "$*"
}

build_mod_args() {
  if (( ${#CLIENT_MOD_PATHS[@]} > 0 )); then
    DAYZ_MOD_ARGS+=("-mod=$(join_mod_paths "${CLIENT_MOD_PATHS[@]}")")
    log "Loaded ${#CLIENT_MOD_PATHS[@]} client mod(s) from $MODS_FILE."
  fi

  if (( ${#SERVER_MOD_PATHS[@]} > 0 )); then
    DAYZ_MOD_ARGS+=("-servermod=$(join_mod_paths "${SERVER_MOD_PATHS[@]}")")
    log "Loaded ${#SERVER_MOD_PATHS[@]} server mod(s) from $MODS_FILE."
  fi

  if (( ${#DAYZ_MOD_ARGS[@]} == 0 )); then
    log "No local mods enabled from $MODS_FILE."
  fi
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

require_active_config
load_mods_file
build_mod_args

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
log "Using DayZ config at $ACTIVE_CONFIG."

cd "$SERVER_DIR"

exec "$SERVER_BINARY" \
  "-config=$ACTIVE_CONFIG" \
  "-profiles=$PROFILE_DIR" \
  "-port=$SERVER_PORT" \
  "-adminlog" \
  "-netlog" \
  "-freezecheck" \
  "${DAYZ_MOD_ARGS[@]}" \
  ${DAYZ_EXTRA_ARGS:-}
