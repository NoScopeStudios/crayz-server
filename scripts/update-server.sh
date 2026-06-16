#!/usr/bin/env bash
set -Eeuo pipefail

STEAMCMD_ROOT="${STEAMCMD_ROOT:-/opt/steamcmd}"
SERVER_DIR="${DAYZ_SERVER_DIR:-/dayz/server}"
APP_ID="${DAYZ_STEAM_APP_ID:-223350}"
VALIDATE_INSTALL="${DAYZ_VALIDATE_INSTALL:-1}"
ALLOW_CREDENTIAL_LOGIN="${DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN:-0}"

log() {
  printf '[crayz] %s\n' "$*"
}

fail() {
  printf '[crayz] ERROR: %s\n' "$*" >&2
  exit 1
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
    printf 'login "%s" "%s"' "$STEAM_USERNAME" "$STEAM_PASSWORD"
    if [[ -n "${STEAM_GUARD_CODE:-}" ]]; then
      printf ' "%s"' "$STEAM_GUARD_CODE"
    fi
    printf '\n'
  } >> "$command_file"
}

main() {
  mkdir -p "$SERVER_DIR"

  local command_file
  command_file="$(mktemp)"
  chmod 0600 "$command_file"

  trap 'rm -f "$command_file"' EXIT

  write_login_commands "$command_file"

  {
    printf 'force_install_dir "%s"\n' "$SERVER_DIR"
    if [[ "$VALIDATE_INSTALL" == "1" ]]; then
      printf 'app_update %s validate\n' "$APP_ID"
    else
      printf 'app_update %s\n' "$APP_ID"
    fi
    printf 'quit\n'
  } >> "$command_file"

  log "Running SteamCMD app update for DayZ Dedicated Server app $APP_ID."
  "$(steamcmd_binary)" +runscript "$command_file"
  log "SteamCMD update finished."
}

main "$@"
