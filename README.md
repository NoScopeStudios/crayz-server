# CrayZ

**Codex-Refined Automated DayZ**

Experimental Docker Compose lab for creating a reliable, Unix-friendly DayZ Dedicated Server container with future Workshop mod support.

## Goals

- Build a reproducible DayZ Dedicated Server container setup.
- Keep server files, profiles, logs, config, and workshop mods persistent.
- Support vanilla server startup first.
- Add Workshop mod support in a later milestone.
- Keep Steam credentials out of Git.

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

## Safety Notes

Do not commit Steam credentials, downloaded server files, workshop content, logs, or private server data.
