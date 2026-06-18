# CrayZ - Project Rules

## Product

| Item | Value |
|------|-------|
| Name | CrayZ |
| Tagline | Codex-Refined Automated DayZ |
| Type | Docker Compose lab for DayZ Dedicated Server |
| Target host | Unix/Linux Docker host, developed from Windows + WSL |
| Goal | Reproducible DayZ Dedicated Server container with persistent config and future Workshop mod support |

## Engineering Rules

- Prefer explicit, readable Bash over clever shell tricks.
- Do not commit Steam credentials.
- Do not bake Steam credentials into Docker images.
- Do not use anonymous SteamCMD login; CrayZ intentionally requires credentialed SteamCMD login for DayZ server install/update.
- Do not commit downloaded server files, workshop files, profiles, or logs.
- Persist Steam auth/session state before adding Workshop mod support.
- Persist both `/home/dayz/Steam` and `/home/dayz/.steam` for SteamCMD auth/session state.
- Keep first milestone focused on vanilla server boot.
- Add mod support only after vanilla install/start flow works.
- Make failure messages human-readable.
- Preserve Unix file permissions and avoid root-owned persistent files where possible.
- Support `PUID`/`PGID` for Linux bind mounts and drop privileges before running SteamCMD or DayZ.
- Avoid expensive recursive ownership changes on large persistent runtime folders during startup.
- Use Docker Compose for the default local workflow.
- Keep scripts small and purpose-specific.
- Deployment Compose files must mount config writable when first-run seeding is enabled.
- Entrypoint first-run seeding must never overwrite user-edited config files.

## Milestone Order

1. Vanilla Docker Compose boot.
2. Server install/update via SteamCMD.
3. Persistent config/profiles/logs.
4. Workshop mod download support.
5. Generated `-mod=` launch argument from `config/mods.txt`.
6. Hardening, troubleshooting docs, and validation scripts.

## Out Of Scope Initially

- Web UI.
- Commercial hosting panel.
- Kubernetes.
- Automatic mod dependency solving.
- RCON dashboard.
- Public Docker Hub image.
