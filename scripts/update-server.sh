#!/usr/bin/env bash
set -Eeuo pipefail

STEAMCMD_ROOT="${STEAMCMD_ROOT:-/opt/steamcmd}"
SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
APP_ID="${DAYZ_STEAM_APP_ID:-223350}"
VALIDATE_INSTALL="${DAYZ_VALIDATE_INSTALL:-1}"
ALLOW_CREDENTIAL_LOGIN="${DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN:-1}"
command_file=""

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

steamcmd_binary() {
  local binary="$STEAMCMD_ROOT/steamcmd.sh"

  if [[ ! -x "$binary" ]]; then
    fail "SteamCMD was not found or is not executable at $binary"
  fi

  printf '%s\n' "$binary"
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

main() {
  mkdir -p "$SERVER_DIR"

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
    printf 'quit\n'
  } >> "$command_file"

  log "Running SteamCMD app update for DayZ Dedicated Server app $APP_ID."
  if ! "$(steamcmd_binary)" +runscript "$command_file"; then
    fail "SteamCMD app update failed for DayZ Dedicated Server app $APP_ID."
  fi
  log "SteamCMD update finished."
}

main "$@"
