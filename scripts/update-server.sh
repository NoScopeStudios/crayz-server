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

  if [[ -n "${STEAM_USERNAME:-}" || -n "${STEAM_PASSWORD:-}" || -n "${STEAM_GUARD_CODE:-}" ]]; then
    if [[ "$ALLOW_CREDENTIAL_LOGIN" != "1" ]]; then
      fail "Steam credentials were provided, but credentialed login is disabled. Leave them empty for anonymous login or set DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1 after validating the strategy locally."
    fi

    # Credentialed Steam login for the DayZ server app still needs validation.
    # Keep this command file temporary and never echo its contents.
    # SteamCMD itself may print account-identifying status lines, so anonymous is the default lab path.
    {
      printf 'login "%s" "%s"' "${STEAM_USERNAME:-}" "${STEAM_PASSWORD:-}"
      if [[ -n "${STEAM_GUARD_CODE:-}" ]]; then
        printf ' "%s"' "$STEAM_GUARD_CODE"
      fi
      printf '\n'
    } >> "$command_file"
  else
    printf 'login anonymous\n' >> "$command_file"
  fi
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
