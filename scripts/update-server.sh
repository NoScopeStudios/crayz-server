#!/usr/bin/env bash
set -Eeuo pipefail

STEAMCMD_ROOT="${STEAMCMD_ROOT:-/opt/steamcmd}"
SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
CONFIG_DIR="${DAYZ_CONFIG_DIR:-/dayz/config}"
MOD_ROOT="${DAYZ_MOD_ROOT:-/dayz/mods/workshop}"
MODS_FILE="$CONFIG_DIR/mods.txt"
APP_ID="${DAYZ_STEAM_APP_ID:-223350}"
WORKSHOP_APP_ID="${DAYZ_WORKSHOP_APP_ID:-221100}"
VALIDATE_INSTALL="${DAYZ_VALIDATE_INSTALL:-1}"
ALLOW_CREDENTIAL_LOGIN="${DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN:-1}"
command_file=""
WORKSHOP_IDS=()
WORKSHOP_FOLDERS=()

log() {
  printf '[crayz] %s\n' "$*"
}

fail() {
  printf '[crayz] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup_command_file() {
  if [[ -n "${command_file:-}" && -e "$command_file" ]]; then
    rm -f -- "$command_file"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

steamcmd_binary() {
  local binary="$STEAMCMD_ROOT/steamcmd.sh"

  if [[ ! -x "$binary" ]]; then
    fail "SteamCMD was not found or is not executable at $binary"
  fi

  printf '%s\n' "$binary"
}

parse_mods_file() {
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

  WORKSHOP_IDS=()
  WORKSHOP_FOLDERS=()

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

    if [[ -n "$workshop_id" ]]; then
      WORKSHOP_IDS+=("$workshop_id")
      WORKSHOP_FOLDERS+=("$folder_name")
    fi
  done < "$MODS_FILE"
}

write_login_commands() {
  local command_file="$1"

  if [[ "$ALLOW_CREDENTIAL_LOGIN" != "1" ]]; then
    fail "Credentialed SteamCMD login is required. Set DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1 in your local .env after adding Steam credentials."
  fi

  if [[ -z "${STEAM_USERNAME:-}" ]]; then
    fail "STEAM_USERNAME is required for DayZ Dedicated Server installation."
  fi

  if [[ -z "${STEAM_PASSWORD:-}" ]]; then
    fail "STEAM_PASSWORD is required for DayZ Dedicated Server installation."
  fi

  # Anonymous SteamCMD login is intentionally unsupported for CrayZ.
  # Keep this command file temporary and never echo its contents.
  {
    if [[ -n "${STEAM_GUARD_CODE:-}" ]]; then
      printf 'set_steam_guard_code "%s"\n' "$STEAM_GUARD_CODE"
    fi
    printf 'login "%s" "%s"\n' "$STEAM_USERNAME" "$STEAM_PASSWORD"
  } >> "$command_file"
}

write_workshop_download_commands() {
  local command_file="$1"
  local workshop_id

  for workshop_id in "${WORKSHOP_IDS[@]}"; do
    printf 'workshop_download_item %s %s\n' "$WORKSHOP_APP_ID" "$workshop_id" >> "$command_file"
  done
}

workshop_item_candidates() {
  local workshop_id="$1"

  printf '%s\n' \
    "$SERVER_DIR/steamapps/workshop/content/$WORKSHOP_APP_ID/$workshop_id" \
    "$STEAMCMD_ROOT/steamapps/workshop/content/$WORKSHOP_APP_ID/$workshop_id" \
    "$STEAMCMD_ROOT/Steam/steamapps/workshop/content/$WORKSHOP_APP_ID/$workshop_id"

  if [[ -n "${HOME:-}" ]]; then
    printf '%s\n' \
      "$HOME/Steam/steamapps/workshop/content/$WORKSHOP_APP_ID/$workshop_id" \
      "$HOME/.steam/steam/steamapps/workshop/content/$WORKSHOP_APP_ID/$workshop_id"
  fi
}

find_downloaded_workshop_item() {
  local workshop_id="$1"
  local candidate

  while IFS= read -r candidate; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(workshop_item_candidates "$workshop_id")

  return 1
}

sync_workshop_item() {
  local workshop_id="$1"
  local folder_name="$2"
  local source_dir
  local target_dir="$MOD_ROOT/$folder_name"

  if [[ "$folder_name" == */* || "$folder_name" == *\\* ]]; then
    fail "Refusing to sync Workshop item $workshop_id because folder name contains a path separator: $folder_name"
  fi

  if ! source_dir="$(find_downloaded_workshop_item "$workshop_id")"; then
    fail "SteamCMD finished, but Workshop item $workshop_id was not found for Workshop app $WORKSHOP_APP_ID. Checked paths:
$(workshop_item_candidates "$workshop_id" | sed 's/^/  - /')"
  fi

  mkdir -p "$MOD_ROOT" "$target_dir"

  case "$target_dir" in
    "$MOD_ROOT"/*) ;;
    *) fail "Refusing to sync Workshop item $workshop_id outside mod root: $target_dir" ;;
  esac

  # Stale file removal is intentionally limited to this one enabled mod folder.
  find "$target_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  cp -a "$source_dir"/. "$target_dir"/

  log "Synced Workshop item $workshop_id to $target_dir."
}

sync_workshop_items() {
  local index

  if (( ${#WORKSHOP_IDS[@]} == 0 )); then
    log "No Workshop mods listed for download/update."
    return 0
  fi

  for index in "${!WORKSHOP_IDS[@]}"; do
    sync_workshop_item "${WORKSHOP_IDS[$index]}" "${WORKSHOP_FOLDERS[$index]}"
  done
}

main() {
  mkdir -p "$SERVER_DIR" "$MOD_ROOT"
  parse_mods_file

  trap cleanup_command_file EXIT

  command_file="$(mktemp)"
  chmod 0600 "$command_file"

  {
    printf 'force_install_dir "%s"\n' "$SERVER_DIR"
  } >> "$command_file"

  write_login_commands "$command_file"

  {
    if [[ "$VALIDATE_INSTALL" == "1" ]]; then
      printf 'app_update %s validate\n' "$APP_ID"
    else
      printf 'app_update %s\n' "$APP_ID"
    fi
  } >> "$command_file"

  write_workshop_download_commands "$command_file"

  {
    printf 'quit\n'
  } >> "$command_file"

  log "Running SteamCMD app update for DayZ Dedicated Server app $APP_ID."
  if (( ${#WORKSHOP_IDS[@]} > 0 )); then
    log "Running SteamCMD Workshop download/update for ${#WORKSHOP_IDS[@]} item(s) using Workshop app $WORKSHOP_APP_ID."
  fi

  if ! "$(steamcmd_binary)" +runscript "$command_file"; then
    fail "SteamCMD app update or Workshop download/update failed."
  fi

  sync_workshop_items
  log "SteamCMD update finished."
}

main "$@"
