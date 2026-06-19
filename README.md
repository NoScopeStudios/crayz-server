<p align="center">
  <img src="assets/crayz_logo_cr.jpg" alt="CrayZ logo" width="420">
</p>

# CrayZ

**Codex-Refined Automated DayZ**

CrayZ is a Docker-based DayZ Dedicated Server setup for Unix-based operating systems running Docker, including normal Linux Docker hosts, OpenMediaVault/OMV, and Unraid/UnRAID-style NAS deployments.


Supported platform note: after this introduction, the documentation generally refers to these supported targets simply as a **Docker host**. The only OMV-specific exception is the documented support for named OMV Compose stack files such as `crayz.yml` and `crayz.env`.

It is designed to make running a DayZ server less painful by keeping the server files, SteamCMD state, profiles, logs, and configuration in predictable persistent folders.

CrayZ is currently focused on a reliable vanilla DayZ server setup first, with layered mod support added only after the base server install and login flow are proven stable.

## What CrayZ Does

CrayZ provides:

* A Docker image for running a DayZ Dedicated Server.
* Docker Compose files for local builds and GHCR-based deployment.
* Persistent server files under `data/server/`.
* Persistent DayZ profiles under `data/profiles/`.
* Persistent logs under `data/logs/`.
* Persistent Steam login/session state under `data/steam/`.
* Local DayZ mod loading from already-present folders under `data/mods/workshop/`.
* SteamCMD Workshop download/update for individually listed mod IDs during install/update mode.
* First-run creation of default config files when missing.
* PUID/PGID support for Docker bind mounts.
* Credentialed SteamCMD login for installing/updating the DayZ server.

## Current Status

CrayZ currently targets a reliable vanilla DayZ Dedicated Server baseline with local mod loading and individual Workshop mod download/update.

Implemented:

* GHCR/Docker Compose deployment layout.
* Local Docker build layout.
* SteamCMD-based DayZ server install/update.
* Persistent Steam login/session state.
* First-run config seeding.
* PUID/PGID permission support.
* Local mod folder loading from `config/mods.txt`.
* Individual Steam Workshop mod download/update from `config/mods.txt`.

Not implemented yet:

* Workshop collection support.
* Automatic mod dependency resolution.
* RCON dashboard.
* Web UI.
* Hosting-panel style management.

## Requirements

You need:

* A Docker host.
* Docker Compose.
* A Steam account that can install the DayZ Dedicated Server through SteamCMD.
* A local `.env` file containing your private Steam login values.

Anonymous SteamCMD login is not supported at this point in time by DayZ so it is not possible with CrayZ.

## Quick Start - GHCR Deployment

Clone or copy this repository onto your Docker host, then enter the repo folder:

```bash
cd crayz
```

Create your private environment file:

```bash
cp .env.example .env
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

For the first install/update, keep `DAYZ_AUTO_UPDATE=1`, then pull and start the image:

```bash
docker compose pull
docker compose up
```

For the first run, starting in the foreground is recommended so you can watch the SteamCMD login and install process.

After the first successful login and install, stop the container with `Ctrl+C`, set `DAYZ_AUTO_UPDATE=0` in `.env`, and start normal runtime:

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
data/steam/Steam/
data/steam/dot-steam/
```

These folders map to `/home/dayz/Steam` and `/home/dayz/.steam` inside the container. Keeping both paths persistent helps SteamCMD reuse session state, but Steam Guard persistence is not guaranteed. Normal runtime should use `DAYZ_AUTO_UPDATE=0` so restarts do not invoke SteamCMD.

Do not commit or share your `.env` file.

## Safe SteamCMD Operating Model

CrayZ separates install/update mode from normal runtime mode.

First install or manual server/Workshop update:

1. Set `DAYZ_AUTO_UPDATE=1`.
2. Start the container in the foreground.
3. Approve Steam Guard if Steam asks.
4. Wait for SteamCMD to finish successfully.
5. Stop the container.
6. Set `DAYZ_AUTO_UPDATE=0`.

Normal runtime:

1. Start or recreate the container with `DAYZ_AUTO_UPDATE=0`.
2. Confirm logs show `Skipping SteamCMD update because DAYZ_AUTO_UPDATE is not 1.`
3. Confirm logs show `Starting vanilla DayZ server on UDP port 2302.`

Future manual server/Workshop update:

1. Temporarily set `DAYZ_AUTO_UPDATE=1`.
2. Run one update.
3. Set `DAYZ_AUTO_UPDATE=0` again before normal restarts.

If Steam Guard prompts repeat after a restart, stop the container. Do not keep approving repeated prompts. Verify the Steam state mounts and permissions before trying again.

## Docker Compose Environment Files And OMV Named Stack Files

Normal Docker Compose usage on a Docker host expects:

```text
docker-compose.yml
.env
```

OMV's native Compose stack handling may store stacks with names such as:

```text
crayz.yml
crayz.env
```

That layout works when Compose is told which env file to use:

```bash
docker compose -f crayz.yml --env-file crayz.env config
docker compose -f crayz.yml --env-file crayz.env up
```

For OMV native Compose usage, copy or paste the root `docker-compose.yml` contents into `crayz.yml`, then copy `.env.example` to `crayz.env` and edit only `crayz.env` with your local values.

The Compose files pass CrayZ runtime variables explicitly through `environment:`. This makes values from `.env`, `crayz.env`, or the shell visible inside the container. The optional `env_file: .env` entry is kept for the default filename/layout only; named OMV Compose files still need `--env-file crayz.env`.

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
    mods/
      workshop/
    steam/
      Steam/
      dot-steam/
```

If `config/serverDZ.cfg` does not exist, CrayZ creates a safe default vanilla server config.

If `config/mods.txt` does not exist, CrayZ creates a commented empty local mod list.

Existing config files are not overwritten.

## Docker Host Permissions

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

Use the UID and GID of the Docker host user that should own and manage the CrayZ files.

At startup, CrayZ prepares the internal `dayz` user/group with those IDs, checks the mounted folders, and then drops privileges before running SteamCMD or the DayZ server.

## Configuration

Main configuration files:

```text
.env
config/serverDZ.cfg
config/mods.txt
```

### Compose fallback values

In the Compose files, some values are written like this:

```yaml
PUID: "${PUID:-1000}"
PGID: "${PGID:-1000}"
```

This means:

```text
Use the value from `.env`, `--env-file`, or the shell when it exists.
If the value is missing or empty, use the fallback value after `:-`.
```

Example `.env` values:

```env
PUID=1000
PGID=4
```

With that `.env`, Docker Compose resolves the container environment as:

```yaml
PUID: "1000"
PGID: "4"
```

The fallback values in Compose are only used when the variable is not set in `.env`, the `--env-file` file, or the host environment.

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
DAYZ_STEAM_APP_ID=223350
DAYZ_WORKSHOP_APP_ID=221100
DAYZ_VALIDATE_INSTALL=1
DAYZ_AUTO_UPDATE=1
DAYZ_EXTRA_ARGS=
```

#### Environment variable reference

CrayZ uses `0` for **disabled** and `1` for **enabled** on toggle-style settings.

| Variable | Default | Description |
|---|---:|---|
| `PUID` | `1000` | Host user ID used inside the container. Files created in bind-mounted folders should be owned by this host user ID. Use `id yourusername` on the Docker host to find the correct value. |
| `PGID` | `1000` | Host group ID used inside the container. Files created in bind-mounted folders should belong to this host group ID. Use `id yourusername` on the Docker host to find the correct value. |
| `STEAM_USERNAME` | empty | Steam account username used by SteamCMD. Required when `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`. |
| `STEAM_PASSWORD` | empty | Steam account password used by SteamCMD. Required when `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`. Never commit this value. |
| `STEAM_GUARD_CODE` | empty | Optional Steam Guard verification code. Leave empty unless Steam gives you a code. If Steam asks for mobile approval instead, approve the login in the Steam mobile app and leave this empty. |
| `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN` | `1` | SteamCMD credential-login toggle. See notes below for toggle values and testing guidance. |
| `DAYZ_SERVER_NAME` | `CrayZ Test Server` | Friendly server name used by CrayZ defaults. The visible DayZ server name is normally controlled by `config/serverDZ.cfg`. |
| `DAYZ_SERVER_PORT` | `2302` | UDP game port exposed by Docker and passed to the DayZ server. |
| `DAYZ_STEAM_QUERY_PORT` | `27016` | UDP Steam server browser query port exposed by Docker. |
| `DAYZ_SERVER_CONFIG` | `serverDZ.cfg` | Config filename inside `config/` that DayZ should use. Most users should leave this as `serverDZ.cfg`. |
| `DAYZ_STEAM_APP_ID` | `223350` | Steam app ID for the DayZ Dedicated Server. Most users should not change this. |
| `DAYZ_WORKSHOP_APP_ID` | `221100` | Steam Workshop app ID used when downloading DayZ Workshop items. This is separate from `DAYZ_STEAM_APP_ID`. |
| `DAYZ_VALIDATE_INSTALL` | `1` | Controls SteamCMD file validation during install/update. `1` validates server files and can repair missing or corrupted files. `0` skips validation and may be faster. |
| `DAYZ_AUTO_UPDATE` | `1` | Controls startup update behavior. `1` is install/update mode and runs SteamCMD once at container start. `0` is normal runtime mode and skips SteamCMD, then starts the existing installed server files. |
| `DAYZ_EXTRA_ARGS` | empty | Optional extra command-line arguments appended to the DayZ server launch command. Advanced users only. |

Recommended install/update settings:

```env
DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1
DAYZ_VALIDATE_INSTALL=1
DAYZ_AUTO_UPDATE=1
DAYZ_EXTRA_ARGS=
```

Recommended normal runtime settings after install/update succeeds:

```env
DAYZ_AUTO_UPDATE=0
```

Use `DAYZ_AUTO_UPDATE=1` only when installing or intentionally updating server files. SteamCMD login persistence with Steam Guard is not guaranteed, so normal restarts should use `DAYZ_AUTO_UPDATE=0`.

`DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN` values:

* `0` means disabled; CrayZ blocks credentialed SteamCMD login.
* `1` means enabled; CrayZ may use `STEAM_USERNAME`, `STEAM_PASSWORD`, and optional `STEAM_GUARD_CODE`.

The default is `1`. Set it to `0` only when intentionally testing config generation or startup behavior without allowing Steam login.

Never commit `.env`.

### `config/serverDZ.cfg`

The authoritative DayZ server configuration file.

Inside the container, CrayZ starts DayZ with:

```text
-config=/dayz/config/serverDZ.cfg
```

For normal repo-relative deployments, edit:

```text
config/serverDZ.cfg
```

For deployments using the documented absolute Docker host layout, edit:

```text
/DockerData/crayz/config/serverDZ.cfg
```

This controls settings such as:

* server name
* password
* admin password
* max players
* mission template
* server time behavior
* signature verification

### `config/mods.txt`

The human-editable mod list.

CrayZ keeps mod content persistently under:

```text
/dayz/mods/workshop/<folder_name>
```

For deployments using the documented absolute Docker host layout, place local mod folders under:

```text
/DockerData/crayz/data/mods/workshop/
```

The Compose files mount that host folder to `/dayz/mods/workshop/` inside the container.

At startup, CrayZ creates DayZ-native server-root symlinks for enabled mods:

```text
/dayz/server/<folder_name> -> /dayz/mods/workshop/<folder_name>
```

DayZ is then launched with relative server-root mod names:

```text
-mod=@ModName;@OtherMod
-servermod=@ServerOnlyMod
```

CrayZ does not launch DayZ with absolute `/dayz/mods/workshop/...` mod paths.

Supported formats:

```text
folder_name|load_type
workshop_id|folder_name|load_type
```

Blank lines and lines starting with `#` are ignored.

Local-only lines use `folder_name|load_type`. The folder must already exist under `/dayz/mods/workshop/`.

Workshop lines use `workshop_id|folder_name|load_type`. When `DAYZ_AUTO_UPDATE=1`, CrayZ downloads or updates the item with SteamCMD and syncs it into `/dayz/mods/workshop/<folder_name>`. When `DAYZ_AUTO_UPDATE=0`, SteamCMD is skipped and CrayZ only loads the already-present local folder.

`workshop_id` must be numeric. `DAYZ_WORKSHOP_APP_ID=221100` is used for DayZ Workshop item downloads. `DAYZ_STEAM_APP_ID=223350` remains the DayZ Dedicated Server app ID.

`load_type` values:

* `client` adds the folder name to the DayZ `-mod=` launch parameter.
* `server` adds the folder name to the DayZ `-servermod=` launch parameter.

For `client` mods, CrayZ copies `.bikey` files into `/dayz/server/keys/` from both:

```text
keys/
Keys/
```

Missing or empty key folders are non-fatal. CrayZ logs what it found and continues.

Examples:

```text
@CF|client
1559212036|@CF|client
@VPPAdminTools|server
@Some Server Mod|client
```

CrayZ preserves the order from `mods.txt`. If a listed folder is missing, startup fails before DayZ is launched with a clear error. If `/dayz/server/<folder_name>` already exists as a real file or directory, startup fails instead of overwriting it.

No-space folder aliases are recommended for easier troubleshooting and cleaner launch output, for example `@BetterMovement` instead of `@Better Movement`. Folder names with spaces may still work, but they make logs and manual checks easier to misread.

Tested conservative Workshop example:

```text
1559212036|@CommunityFramework|client
2545327648|@DabsFramework|client
3046779255|@BetterMovement|client
1560819773|@UnlimitedStamina|client
```

Workshop download/update uses the same credentialed SteamCMD login path as server updates. Steam Guard/session persistence is still not guaranteed, so run Workshop install/update intentionally with `DAYZ_AUTO_UPDATE=1`, then return to `DAYZ_AUTO_UPDATE=0` for normal restarts.

Workshop collections and automatic dependency resolution are not supported yet. List each Workshop item explicitly.

## Workshop Mod Install/Update

To install or update individual Workshop mods:

1. Add Workshop lines to `config/mods.txt`.
2. Set `DAYZ_AUTO_UPDATE=1` in `.env`.
3. Start the container and approve Steam Guard if Steam asks.
4. Wait for SteamCMD to finish and for CrayZ to sync the listed Workshop items.
5. Stop the container.
6. Set `DAYZ_AUTO_UPDATE=0`.
7. Restart normally.

Example:

```text
1559212036|@CF|client
```

During install/update, SteamCMD downloads item `1559212036` for Workshop app `221100`, then CrayZ syncs it into:

```text
/dayz/mods/workshop/@CF
```

On startup, CrayZ enables it for DayZ with:

```text
/dayz/server/@CF -> /dayz/mods/workshop/@CF
-mod=@CF
```

Normal runtime with `DAYZ_AUTO_UPDATE=0` does not run SteamCMD. It only loads folders that already exist under `/dayz/mods/workshop/`, through server-root symlinks under `/dayz/server/`.

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

data/mods/workshop/
  Local and synced Workshop DayZ mod folders mounted to /dayz/mods/workshop.

data/steam/
  SteamCMD login/session state.

data/steam/Steam/
  Mounted to /home/dayz/Steam.

data/steam/dot-steam/
  Mounted to /home/dayz/.steam.

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

Check that both Steam state mounts are present and writable:

```yaml
- ./data/steam/Steam:/home/dayz/Steam
- ./data/steam/dot-steam:/home/dayz/.steam
```

For absolute-path Docker host deployments, use the same container targets:

```yaml
- /DockerData/crayz/data/steam/Steam:/home/dayz/Steam
- /DockerData/crayz/data/steam/dot-steam:/home/dayz/.steam
```

If Steam Guard prompts repeat after a successful approval, stop the container before further login attempts and verify these mounts. Repeated failed or repeated new-device logins can trigger Steam account protection.

For normal restarts, set:

```env
DAYZ_AUTO_UPDATE=0
```

SteamCMD login persistence with Steam Guard is not guaranteed yet. Safe runtime mode avoids depending on SteamCMD login for every restart.

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

### DayZ reports missing instanceId

Fresh CrayZ configs include `instanceId = 1;`. If DayZ logs `instanceId parameter is mandatory`, your existing `config/serverDZ.cfg` was created before this default was added or was edited manually. Add this line near the other top-level server settings:

```cpp
instanceId = 1;
```

### DayZ server executable is missing

SteamCMD may not have completed the install/update.

Check the container logs:

```bash
docker logs -f crayz-dayz
```

## Project Scope

CrayZ is not a commercial hosting panel or web dashboard.

The goal is to provide a reliable, understandable, self-hosted Docker setup for DayZ Dedicated Server hosting.

Workshop collection support is planned, but the base server install, local mod loading, individual Workshop mod updates, Steam login safety, permissions, and restart behavior are the foundation.
