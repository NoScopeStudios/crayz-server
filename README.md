# CrayZ

**Codex-Refined Automated DayZ**

Experimental Docker Compose lab for creating a reliable, Unix-friendly DayZ Dedicated Server container with future Workshop mod support.

## Goals

- Build a reproducible DayZ Dedicated Server container setup.
- Keep server files, profiles, logs, config, and workshop mods persistent.
- Support vanilla server startup first.
- Add Workshop mod support in a later milestone.
- Keep Steam credentials out of Git.
- Use credentialed SteamCMD login for the first working install/update path.

## Non-Goals For First Milestone

- Public production-ready image.
- Automatic community modpack management.
- Web UI.
- RCON dashboard.
- Cluster orchestration.
- Commercial hosting panel behavior.

## Repository Layout

```text
config/
  User-editable DayZ config files.

scripts/
  Entrypoint, update, validation, and helper scripts.

data/
  Persistent runtime folders. Ignored by Git except placeholder files.

docs/
  Setup notes, troubleshooting, and mod documentation.
```

## First Steam Login

Copy `.env.example` to `.env` for local runtime values. A normal Steam account login is required for SteamCMD; anonymous SteamCMD login is intentionally not supported by CrayZ.

For the first login:

1. Set `STEAM_USERNAME` in `.env`.
2. Set `STEAM_PASSWORD` in `.env`.
3. Set `STEAM_GUARD_CODE` only when Steam Guard asks for it.
4. Set `DAYZ_ALLOW_STEAM_CREDENTIAL_LOGIN=1`.
5. Start the container and wait for SteamCMD login/install to finish.
6. After the first successful login, clear `STEAM_GUARD_CODE` from `.env`.
7. Recreate or restart the container and verify SteamCMD can reuse the persisted login/session state.

Steam state is persisted under `data/steam/` and mounted into the `dayz` user's home directory. Do not commit `.env`, downloaded server files, logs, or Steam runtime state.

## Docker Compose / OMV - GHCR Deployment

Use `docker-compose.yml` for local development builds. For OpenMediaVault or another host that should pull the prebuilt development image, use the files in `deploy/`.

First deployment flow:

1. Create a deployment folder on the host.
2. Copy `deploy/docker-compose.yml` into that folder.
3. Copy `deploy/.env.example` to `.env` in that folder.
4. Edit `.env` and set the Steam login values.
5. Pull the image.
6. Start the container.

```bash
docker compose pull
docker compose up -d
```

The deployment Compose uses `ghcr.io/noscopestudios/crayz-dayz-server:dev` and keeps runtime state beside the Compose file. On first startup, the container creates `config/serverDZ.cfg` and `config/mods.txt` if they are missing. Existing config files are preserved.

The same persistent folders are used for local Compose and deployment Compose, including `data/steam/` for Steam login/session state.

## Docker Compose / OMV Permissions

CrayZ supports `PUID` and `PGID` so files created in bind-mounted folders belong to the expected Linux host user instead of root or an arbitrary container id.

On the OMV/Linux host, find the ids for the user that should own the server files:

```bash
id yourusername
```

Example output:

```text
uid=1000(username) gid=1000(docker) groups=1000(docker),100(users)
```

Use those values in `.env`:

```env
PUID=1000
PGID=1000
```

At startup the container prepares the `dayz` user/group with those ids, checks the mounted runtime folders, then drops privileges before running SteamCMD or the DayZ server.

## Safety Notes

Do not commit Steam credentials, downloaded server files, workshop content, logs, or private server data.

Never commit `.env`.
