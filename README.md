<p align="center">
  <img src="assets/crayz_logo_cr.jpg" alt="CrayZ logo" width="420">
</p>

# CrayZ

**Codex-Refined Automated DayZ**

CrayZ is a Docker-based DayZ Dedicated Server setup for Linux and self-hosted systems such as OpenMediaVault.

It is designed to make running a DayZ server less painful by keeping the server files, SteamCMD state, profiles, logs, and configuration in predictable persistent folders.

CrayZ is currently focused on a reliable vanilla DayZ server setup first. Workshop mod support is planned, but should only be used once the base server install and login flow are proven stable.

## What CrayZ Does

CrayZ provides:

* A Docker image for running a DayZ Dedicated Server.
* Docker Compose files for local builds and GHCR-based deployment.
* Persistent server files under `data/server/`.
* Persistent DayZ profiles under `data/profiles/`.
* Persistent logs under `data/logs/`.
* Persistent Steam login/session state under `data/steam/`.
* First-run creation of default config files when missing.
* PUID/PGID support for Linux and OpenMediaVault-style bind mounts.
* Credentialed SteamCMD login for installing/updating the DayZ server.

## Current Status

CrayZ currently targets a vanilla DayZ Dedicated Server.

Implemented:

* GHCR/Docker Compose deployment layout.
* Local Docker build layout.
* SteamCMD-based DayZ server install/update.
* Persistent Steam login/session state.
* First-run config seeding.
* PUID/PGID permission support.

Not implemented yet:

* Workshop mod download support.
* Automatic mod loading.
* RCON dashboard.
* Web UI.
* Hosting-panel style management.

## Requirements

You need:

* A Linux Docker host, such as OpenMediaVault, Debian, Ubuntu, or another Docker-capable Linux system.
* Docker Compose.
* A Steam account that can install the DayZ Dedicated Server through SteamCMD.
* A local `.env` file containing your private Steam login values.

Anonymous SteamCMD login is intentionally not supported by CrayZ.

## Quick Start - GHCR Deployment

Create a folder for CrayZ on your Docker host:

```bash
mkdir -p crayz
cd crayz
```

Copy the deployment Compose file and environment example from the repository:

```bash
cp deploy/docker-compose.yml docker-compose.yml
cp deploy/.env.example .env
```

Edit `.env`:

```bash
nano .env
```

At minimum, set:

```env
STEAM_USERNAME=
STEAM_PASSWORD=
STEAM_GUARD_CODE=
DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1
```

Fill `STEAM_USERNAME` and `STEAM_PASSWORD` only in your private `.env`.

Then pull and start the image:

```bash
docker compose pull
docker compose up
```

For the first run, starting in the foreground is recommended so you can watch the SteamCMD login and install process.

After the first successful login and install, you can stop the container with `Ctrl+C` and later run it detached:

```bash
docker compose up -d
```

## First Steam Login

CrayZ uses credentialed SteamCMD login.

For the first login:

1. Set `STEAM_USERNAME` in `.env`.
2. Set `STEAM_PASSWORD` in `.env`.
3. Leave `STEAM_GUARD_CODE` empty unless Steam gives you a code.
4. Set `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`.
5. Start the container.
6. Approve the login in the Steam mobile app if Steam sends a mobile approval request.
7. If Steam gives you a Steam Guard code, place that code in `STEAM_GUARD_CODE` and rerun the container.
8. After login succeeds, clear `STEAM_GUARD_CODE` from `.env`.

Steam login/session state is stored persistently under:

```text
data/steam/
```

This helps prevent Steam Guard from being required again every time the container is recreated.

Do not commit or share your `.env` file.

## First-Run Generated Files

On first startup, CrayZ creates missing folders and default config files.

Expected folder layout after first run:

```text
crayz/
  docker-compose.yml
  .env
  config/
    serverDZ.cfg
    mods.txt
  data/
    server/
    profiles/
    logs/
    steam/
```

If `config/serverDZ.cfg` does not exist, CrayZ creates a safe default vanilla server config.

If `config/mods.txt` does not exist, CrayZ creates a commented empty mod list for future mod support.

Existing config files are not overwritten.

## OpenMediaVault / Linux Permissions

CrayZ supports `PUID` and `PGID` so files created inside bind-mounted folders belong to the expected host user.

On the Docker host, run:

```bash
id yourusername
```

Example:

```text
uid=1000(username) gid=1000(username) groups=1000(username),100(users)
```

Use those values in `.env`:

```env
PUID=1000
PGID=1000
```

For OpenMediaVault, use the UID and GID of the user that should own and manage the CrayZ files.

At startup, CrayZ prepares the internal `dayz` user/group with those IDs, checks the mounted folders, and then drops privileges before running SteamCMD or the DayZ server.

## Configuration

Main configuration files:

```text
.env
config/serverDZ.cfg
config/mods.txt
```

### `.env`

Private runtime settings.

This file contains values such as:

```env
PUID=1000
PGID=1000

STEAM_USERNAME=
STEAM_PASSWORD=
STEAM_GUARD_CODE=
DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1

DAYZ_SERVER_PORT=2302
DAYZ_STEAM_QUERY_PORT=27016
DAYZ_SERVER_CONFIG=serverDZ.cfg
DAYZ_VALIDATE_INSTALL=1
DAYZ_AUTO_UPDATE=1
DAYZ_EXTRA_ARGS=
```

#### Environment variable reference

CrayZ uses `0` for **disabled** and `1` for **enabled** on toggle-style settings.

| Variable | Default | Description |
|---|---:|---|
| `PUID` | `1000` | Linux user ID used inside the container. Files created in bind-mounted folders should be owned by this host user ID. Use `id yourusername` on the Docker host to find the correct value. |
| `PGID` | `1000` | Linux group ID used inside the container. Files created in bind-mounted folders should belong to this host group ID. Use `id yourusername` on the Docker host to find the correct value. |
| `STEAM_USERNAME` | empty | Steam account username used by SteamCMD. Required when `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`. |
| `STEAM_PASSWORD` | empty | Steam account password used by SteamCMD. Required when `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`. Never commit this value. |
| `STEAM_GUARD_CODE` | empty | Optional Steam Guard verification code. Leave empty unless Steam gives you a code. If Steam asks for mobile approval instead, approve the login in the Steam mobile app and leave this empty. |
| `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN` | `1` | SteamCMD credential-login toggle. See notes below for toggle values and testing guidance. |
| `DAYZ_SERVER_NAME` | `CrayZ Test Server` | Friendly server name used by CrayZ defaults. The visible DayZ server name is normally controlled by `config/serverDZ.cfg`. |
| `DAYZ_SERVER_PORT` | `2302` | UDP game port exposed by Docker and passed to the DayZ server. |
| `DAYZ_STEAM_QUERY_PORT` | `27016` | UDP Steam server browser query port exposed by Docker. |
| `DAYZ_SERVER_CONFIG` | `serverDZ.cfg` | Config filename inside `config/` that DayZ should use. Most users should leave this as `serverDZ.cfg`. |
| `DAYZ_STEAM_APP_ID` | `223350` | Steam app ID for the DayZ Dedicated Server. Most users should not change this. |
| `DAYZ_VALIDATE_INSTALL` | `1` | Controls SteamCMD file validation during install/update. `1` validates server files and can repair missing or corrupted files. `0` skips validation and may be faster. |
| `DAYZ_AUTO_UPDATE` | `1` | Controls startup update behavior. `1` runs SteamCMD install/update when the container starts. `0` skips automatic update and tries to start the existing installed server files. |
| `DAYZ_EXTRA_ARGS` | empty | Optional extra command-line arguments appended to the DayZ server launch command. Advanced users only. |

Recommended defaults for most users:

```env
DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1
DAYZ_VALIDATE_INSTALL=1
DAYZ_AUTO_UPDATE=1
DAYZ_EXTRA_ARGS=
```

Use `DAYZ_AUTO_UPDATE=0` only when you intentionally want to prevent CrayZ from checking Steam for server updates during container startup.

`DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN` values:

* `0` means disabled; CrayZ blocks credentialed SteamCMD login.
* `1` means enabled; CrayZ may use `STEAM_USERNAME`, `STEAM_PASSWORD`, and optional `STEAM_GUARD_CODE`.

The default is `1`. Set it to `0` only when intentionally testing config generation or startup behavior without allowing Steam login.

Never commit `.env`.

### `config/serverDZ.cfg`

The DayZ server configuration file.

This controls settings such as:

* server name
* password
* admin password
* max players
* mission template
* server time behavior
* signature verification

### `config/mods.txt`

Reserved for future Workshop mod support.

CrayZ does not currently implement Workshop mod download or automatic mod loading.

## Starting and Stopping

Start in foreground:

```bash
docker compose up
```

Start in background:

```bash
docker compose up -d
```

Stop:

```bash
docker compose down
```

View logs:

```bash
docker logs -f crayz-dayz
```

Update image:

```bash
docker compose pull
docker compose up -d
```

## Local Development Build

For local development, use the local Compose file:

```bash
docker compose -f docker-compose.local.yml build
docker compose -f docker-compose.local.yml up
```

The normal deployment Compose file should use the prebuilt GHCR image.

## Persistent Data

CrayZ stores persistent runtime data outside the container.

```text
data/server/
  Installed DayZ server files.

data/profiles/
  DayZ profile and runtime state.

data/logs/
  Server logs.

data/steam/
  SteamCMD login/session state.

config/
  User-editable configuration files.
```

These folders should be backed up if you care about preserving the server state.

## Security Notes

Do not commit or share:

* `.env`
* Steam usernames/passwords
* Steam Guard codes
* downloaded server files
* logs containing private data
* Steam runtime/session state

Safe to commit:

* `.env.example`
* Compose files
* scripts
* documentation
* default example config templates

## Troubleshooting

### Docker cannot pull the image

Check that the image exists and that the GHCR package is public or that your Docker host is logged in to GHCR.

```bash
docker compose pull
```

### Steam Guard keeps asking again

Check that `data/steam/` is mounted and writable.

Also verify that the container is using consistent `PUID` and `PGID` values between runs.

### Files are owned by the wrong user

Check your `.env`:

```env
PUID=1000
PGID=1000
```

Then compare with:

```bash
id yourusername
```

### Config files are not created

Make sure the `config/` folder is mounted writable.

The container cannot create default config files if the config mount is read-only.

### DayZ server executable is missing

SteamCMD may not have completed the install/update.

Check the container logs:

```bash
docker logs -f crayz-dayz
```

## Project Scope

CrayZ is not a commercial hosting panel or web dashboard.

The goal is to provide a reliable, understandable, self-hosted Docker setup for DayZ Dedicated Server hosting.

Workshop mod support is planned, but the base server install, Steam login persistence, permissions, and restart behavior are the foundation.
