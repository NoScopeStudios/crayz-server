# DayZ Vanilla Server Configuration And Persistence Reference

**Project context:** CrayZ — Codex-refined automated DayZ Dedicated Server Docker image  
**Primary use case:** Understand what belongs in `serverDZ.cfg`, what belongs in the vanilla DayZ mission folder, and what needs to be backed up for restore/migration.

Generated: 2026-06-19

---

## 1. CrayZ Source Of Truth

After CrayZ M012, the authoritative server config path is:

| Layer | Path |
|---|---|
| Docker host path | `/DockerData/crayz/config/serverDZ.cfg` |
| Container path | `/dayz/config/serverDZ.cfg` |
| DayZ launch parameter | `-config=/dayz/config/serverDZ.cfg` |

`/DockerData/crayz/...` is the current documented Docker host path layout used by the active CrayZ deployment. Other Docker hosts can use different host-side paths as long as the same container paths are mounted.

The old duplicate config location may still exist from older runs:

```text
/DockerData/crayz/data/server/serverDZ.cfg
```

That file should now be treated as legacy/stale unless a runtime validation proves otherwise. The running DayZ process should include:

```text
-config=/dayz/config/serverDZ.cfg
```

---

## 2. `serverDZ.cfg` Mental Model

`serverDZ.cfg` is the main DayZ dedicated server configuration file. It controls:

- server identity and visibility;
- passwords and admin password;
- max player count;
- Steam query port;
- signature/build compatibility behavior;
- BattlEye and basic security flags;
- first-person/third-person/crosshair/voice settings;
- server time and time acceleration;
- login queue behavior;
- persistence instance ID;
- mission template selection;
- optional switch for `cfggameplay.json`.

It does **not** control most loot, weather, animal territories, contaminated zones, event spawns, player spawn loadouts, or Workshop mods directly. Those belong to the mission folder XML/JSON files or to startup parameters.

`serverDZ.cfg` uses Arma/DayZ-style CFG syntax. A normal variable line looks like:

```cfg
settingName = value;
```

Strings are quoted:

```cfg
hostname = "CrayZ Test Server";
```

---

## 3. `serverDZ.cfg` Parameters

The list below focuses on vanilla DayZ dedicated server settings that are commonly documented and useful for a CrayZ-style server. Exact behavior can vary between DayZ versions, so runtime validation after edits is still important.

### 3.1 Server Identity And Access

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `hostname` | `"CrayZ Test Server"` | Server name shown in browser. | Set explicitly. |
| `description` | `"Private survival server"` | Server browser description / extra info where supported. | Optional, useful. |
| `password` | `""` | Join password. Empty string means public/no password. | Empty for open test server. |
| `passwordAdmin` | `""` | Admin password for server admin commands. | Set later if needed; do not commit real value. |
| `maxPlayers` | `10` | Maximum connected players. | Set based on hardware/uplink. |
| `enableWhitelist` | `0` | Enables whitelist behavior when configured. | Leave `0` unless a whitelist workflow is added. |
| `shardId` | `""` | Private shard identifier. | Leave empty for normal community-style setup. |

Example:

```cfg
hostname = "CrayZ Test Server";
description = "CrayZ vanilla test server";
password = "";
passwordAdmin = "";
maxPlayers = 10;
enableWhitelist = 0;
shardId = "";
```

---

### 3.2 Steam Query / Discovery

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `steamQueryPort` | `27016` | Steam query/server-browser discovery port. | Set explicitly to `27016`. |

CrayZ observed behavior:

| User action / UI | Port |
|---|---:|
| Add/search in Steam Game Servers | `27016` |
| Actual DayZ game endpoint displayed after discovery | `2302` |
| CrayZ game port startup parameter | `-port=2302` |

Important distinction:

```text
27016 = Steam query / discovery port
2302  = actual DayZ game traffic port
```

Example:

```cfg
steamQueryPort = 27016;
```

---

### 3.3 Security / Compatibility

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `verifySignatures` | `2` | Verifies client-side PBO signatures. | Keep `2` for normal public/friend play. |
| `forceSameBuild` | `1` | Requires matching game build/version. | Keep `1`. |
| `BattlEye` | `1` | Enables BattlEye anti-cheat. | Keep `1`. |
| `allowFilePatching` | `0` | Allows local file patching for clients/testing. | Keep `0` unless intentionally debugging/modding. |

Example:

```cfg
verifySignatures = 2;
forceSameBuild = 1;
BattlEye = 1;
allowFilePatching = 0;
```

---

### 3.4 Perspective, HUD, Personal Light, And Voice

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `disable3rdPerson` | `0` | `1` disables third-person view. | `0` for relaxed vanilla; `1` for hardcore. |
| `disableCrosshair` | `0` | `1` disables crosshair. | `0` for relaxed vanilla; `1` for hardcore. |
| `disablePersonalLight` | `1` | Disables personal night light/glow. | `1` for more authentic darkness. |
| `disableVoN` | `0` | `1` disables in-game voice. | Keep `0` unless using only external voice. |
| `vonCodecQuality` | `20` | Voice quality value. | `20` is a common good value. |

Example:

```cfg
disable3rdPerson = 0;
disableCrosshair = 0;
disablePersonalLight = 1;
disableVoN = 0;
vonCodecQuality = 20;
```

---

### 3.5 Time And Day/Night Cycle

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `serverTime` | `"SystemTime"` | Initial server time. Can use system time or fixed date/time string. | `"SystemTime"` for simple setup. |
| `serverTimeAcceleration` | `12` | In-game time acceleration. | Tune to taste. |
| `serverNightTimeAcceleration` | `1` | Night multiplier on top of time acceleration. | Tune to taste. |
| `serverTimePersistent` | `0` | Persists in-game time across restarts. | `0` for predictable restarts; `1` for persistent time. |

Examples:

```cfg
serverTime = "SystemTime";
serverTimeAcceleration = 12;
serverNightTimeAcceleration = 1;
serverTimePersistent = 0;
```

Fixed time example:

```cfg
serverTime = "2015/4/8/17/23";
```

---

### 3.6 Login Queue / Network Behavior

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `guaranteedUpdates` | `1` | Network update reliability behavior. | Keep `1`. |
| `loginQueueConcurrentPlayers` | `5` | How many players process through login queue concurrently. | Good small-server default. |
| `loginQueueMaxPlayers` | `500` | Maximum login queue length. | Fine default; can lower for small private server. |

Example:

```cfg
guaranteedUpdates = 1;
loginQueueConcurrentPlayers = 5;
loginQueueMaxPlayers = 500;
```

---

### 3.7 Respawn

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `respawnTime` | `5` | Delay before respawn. | Tune to taste. |

Example:

```cfg
respawnTime = 5;
```

---

### 3.8 Persistence / Instance

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `instanceId` | `1` | Required persistence instance identifier. | Must be present and valid. |
| `storageAutoFix` | `1` | Lets DayZ try to repair some storage consistency problems. | Keep `1` unless testing says otherwise. |

`instanceId` was previously a real startup blocker when missing. Keep it in the seeded default.

Example:

```cfg
instanceId = 1;
storageAutoFix = 1;
```

---

### 3.9 Admin / Debug / Logging-Related Settings

These settings can increase admin visibility. They are separate from startup flags such as `-adminlog` and `-netlog`.

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `enableDebugMonitor` | `0` | Enables debug monitor behavior where supported. | Keep `0` for normal play. |
| `adminLogPlayerHitsOnly` | `0` | Limits admin hit logging to players only. | Optional. |
| `adminLogPlacement` | `0` | Logs placement actions. | Enable only if you want extra moderation logs. |
| `adminLogBuildActions` | `0` | Logs base-building actions. | Enable only if you want extra moderation logs. |
| `adminLogPlayerList` | `0` | Logs player list periodically/when supported. | Optional. |

Example:

```cfg
enableDebugMonitor = 0;
adminLogPlayerHitsOnly = 0;
adminLogPlacement = 0;
adminLogBuildActions = 0;
adminLogPlayerList = 0;
```

---

### 3.10 Gameplay JSON Switch

| Parameter | Example | Purpose | CrayZ recommendation |
|---|---:|---|---|
| `enableCfgGameplayFile` | `0` | Enables reading `cfggameplay.json` from the mission folder. | Keep `0` until CrayZ explicitly supports/documents that file. |

Example:

```cfg
enableCfgGameplayFile = 0;
```

Do not enable this casually unless a valid `cfggameplay.json` exists and has been validated. A broken JSON file can create confusing server behavior or startup problems.

---

### 3.11 Mission Template

| Parameter / block | Example | Purpose | CrayZ recommendation |
|---|---|---|---|
| `class Missions` | `template = "dayzOffline.chernarusplus";` | Selects the mission/world. | Keep Chernarus unless intentionally switching map/mission. |

Example:

```cfg
class Missions
{
    class DayZ
    {
        template = "dayzOffline.chernarusplus";
    };
};
```

For vanilla Chernarus:

```text
dayzOffline.chernarusplus
```

---

## 4. Suggested Explicit Vanilla `serverDZ.cfg` Baseline For CrayZ

This is not a promise that every line is mandatory. It is a clear, explicit, human-editable baseline that avoids hidden defaults where possible.

```cfg
hostname = "CrayZ Test Server";
description = "CrayZ vanilla DayZ server";
password = "";
passwordAdmin = "";
maxPlayers = 10;

verifySignatures = 2;
forceSameBuild = 1;
BattlEye = 1;
allowFilePatching = 0;

steamQueryPort = 27016;

disable3rdPerson = 0;
disableCrosshair = 0;
disablePersonalLight = 1;
disableVoN = 0;
vonCodecQuality = 20;

serverTime = "SystemTime";
serverTimeAcceleration = 12;
serverNightTimeAcceleration = 1;
serverTimePersistent = 0;

guaranteedUpdates = 1;
loginQueueConcurrentPlayers = 5;
loginQueueMaxPlayers = 500;
respawnTime = 5;

instanceId = 1;
storageAutoFix = 1;

enableWhitelist = 0;
shardId = "";

enableDebugMonitor = 0;
adminLogPlayerHitsOnly = 0;
adminLogPlacement = 0;
adminLogBuildActions = 0;
adminLogPlayerList = 0;

enableCfgGameplayFile = 0;

class Missions
{
    class DayZ
    {
        template = "dayzOffline.chernarusplus";
    };
};
```

Do not commit real passwords into Git. For public examples, leave:

```cfg
password = "";
passwordAdmin = "";
```

---

## 5. Vanilla DayZ Server File Mental Model

A vanilla DayZ dedicated server has three broad categories of files:

| Category | Meaning | Should be backed up? |
|---|---|---|
| Static server binaries/game files | Reinstallable DayZ Dedicated Server files downloaded by SteamCMD. | Usually no. |
| Mission configuration/economy files | XML/JSON files that define loot economy, events, weather, spawns, territories, gameplay config, etc. | Yes. |
| Live persistence/save-state | Binary database/state files generated by the running server. | Yes. |

For CrayZ, the main server install folder is:

```text
/DockerData/crayz/data/server/
```

Inside that folder, most files are static/reinstallable DayZ server files, **except** the mission folder:

```text
/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/
```

That mission folder contains both the editable server economy/configuration files and the live persistence storage.

---

## 6. Important CrayZ Paths

| Purpose | Host path | Container path |
|---|---|---|
| Authoritative `serverDZ.cfg` | `/DockerData/crayz/config/serverDZ.cfg` | `/dayz/config/serverDZ.cfg` |
| DayZ Dedicated Server install | `/DockerData/crayz/data/server/` | `/dayz/server/` |
| Vanilla Chernarus mission | `/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/` | `/dayz/server/mpmissions/dayzOffline.chernarusplus/` |
| Persistence storage | `/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/storage_1/` | `/dayz/server/mpmissions/dayzOffline.chernarusplus/storage_1/` |
| Profiles/logs | `/DockerData/crayz/data/profiles/` | `/dayz/profiles/` |
| CrayZ app/config folder | `/DockerData/crayz/config/` | `/dayz/config/` |
| SteamCMD/Steam state | `/DockerData/crayz/data/steam/` | `/home/dayz/Steam` and `/home/dayz/.steam` |

---

## 7. Mission Folder Overview

For vanilla Chernarus, the mission folder is:

```text
dayzOffline.chernarusplus/
```

CrayZ host path:

```text
/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/
```

High-level structure:

```text
dayzOffline.chernarusplus/
├── db/
│   ├── types.xml
│   ├── events.xml
│   ├── globals.xml
│   ├── economy.xml
│   ├── messages.xml
│   └── other Central Economy database/config files
│
├── env/
│   └── environment-related config files
│
├── cfg*.xml
│   └── spawn, event, random preset, gameplay/economy support files
│
├── *.json
│   └── optional gameplay/effect-area related config depending on version/setup
│
└── storage_1/
    ├── players.db
    └── data/
        ├── types.bin
        ├── events.bin
        ├── dynamic_000.bin
        ├── vehicles.bin
        └── other live persistence files
```

---

## 8. Important Mission Configuration / Economy Files

These files define how the world should behave. They are not the same as the current live state, but they are essential to preserve a customized server.

### 8.1 `db/types.xml`

Path:

```text
dayzOffline.chernarusplus/db/types.xml
```

Purpose:

- item loot economy;
- nominal/min/max values;
- item lifetime;
- restock behavior;
- category/tag/usage/value placement metadata.

This is one of the most commonly edited DayZ server files.

---

### 8.2 `db/events.xml`

Path:

```text
dayzOffline.chernarusplus/db/events.xml
```

Purpose:

- dynamic event definitions;
- vehicle event rules;
- infected/animal/event spawner definitions;
- event active/min/max/nominal timing behavior.

---

### 8.3 `db/globals.xml`

Path:

```text
dayzOffline.chernarusplus/db/globals.xml
```

Purpose:

- global Central Economy values;
- broad economy/system tuning values.

---

### 8.4 `db/economy.xml`

Path:

```text
dayzOffline.chernarusplus/db/economy.xml
```

Purpose:

- Central Economy behavior switches and high-level economy configuration.

---

### 8.5 `db/messages.xml`

Path:

```text
dayzOffline.chernarusplus/db/messages.xml
```

Purpose:

- server/economy messages where supported by the mission setup.

---

### 8.6 `cfgspawnabletypes.xml`

Path:

```text
dayzOffline.chernarusplus/cfgspawnabletypes.xml
```

Purpose:

- attachments on spawned items;
- cargo contents;
- presets for items/vehicles/containers;
- what certain spawned entities can contain when created.

This file is important when tuning vehicles, weapons with attachments, containers, and spawned item contents.

---

### 8.7 `cfgrandompresets.xml`

Path:

```text
dayzOffline.chernarusplus/cfgrandompresets.xml
```

Purpose:

- random preset definitions used by spawnable types and economy configuration.

---

### 8.8 `cfgweather.xml`

Path:

```text
dayzOffline.chernarusplus/cfgweather.xml
```

Purpose:

- weather configuration;
- overcast/rain/fog/wind behavior;
- weather timing and limits.

Weather is not primarily configured in `serverDZ.cfg`.

---

### 8.9 `cfgeventspawns.xml`

Path:

```text
dayzOffline.chernarusplus/cfgeventspawns.xml
```

Purpose:

- dynamic event spawn positions;
- where events such as crashes, convoys, vehicle events, and other configured events may spawn.

---

### 8.10 `cfgeventgroups.xml`

Path:

```text
dayzOffline.chernarusplus/cfgeventgroups.xml
```

Purpose:

- event group definitions;
- sets or groups used by event spawning.

---

### 8.11 `cfgplayerspawnpoints.xml`

Path:

```text
dayzOffline.chernarusplus/cfgplayerspawnpoints.xml
```

Purpose:

- player spawn point configuration;
- spawn region/group behavior depending on version and mission setup.

---

### 8.12 `cfgeconomycore.xml`

Path:

```text
dayzOffline.chernarusplus/cfgeconomycore.xml
```

Purpose:

- Central Economy core setup;
- can be used by advanced/custom economy setups.

---

### 8.13 `mapgrouppos.xml`

Path:

```text
dayzOffline.chernarusplus/mapgrouppos.xml
```

Purpose:

- building/object group positions used by Central Economy.

---

### 8.14 `mapgroupproto.xml`

Path:

```text
dayzOffline.chernarusplus/mapgroupproto.xml
```

Purpose:

- group prototype definitions used by Central Economy.

---

### 8.15 `cfgignorelist.xml`

Path:

```text
dayzOffline.chernarusplus/cfgignorelist.xml
```

Purpose:

- ignore list for map/group/economy processing.

---

### 8.16 Territory Files

Common paths vary by version/mission layout, often under mission subfolders.

Purpose:

- animal territories;
- infected territories;
- static/dynamic territory definitions.

Examples of what these files influence:

- where wolves/bears/deer/etc. can spawn;
- where infected can spawn;
- territory-based event behavior.

---

### 8.17 Contaminated / Gas Area Files

Common files may include JSON/XML mission config such as effect-area configuration, depending on DayZ version and mission setup.

Purpose:

- static contaminated areas;
- dynamic contaminated/gas events;
- area definitions and behavior.

These are mission configuration files, not `serverDZ.cfg` settings.

---

### 8.18 `cfggameplay.json`

Path:

```text
dayzOffline.chernarusplus/cfggameplay.json
```

Purpose:

- advanced gameplay settings controlled through JSON;
- only active when `serverDZ.cfg` contains:

```cfg
enableCfgGameplayFile = 1;
```

Keep this disabled unless the file exists, is valid, and CrayZ intentionally supports it.

---

## 9. Live Persistence / Save-State

The current world and player state is stored under:

```text
dayzOffline.chernarusplus/storage_1/
```

CrayZ host path:

```text
/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/storage_1/
```

This folder is **not static game data**. It is generated and updated by the running server.

### 9.1 `storage_1/players.db`

Purpose:

- player character database;
- alive/dead character state;
- player inventory on character;
- player identity-linked character data.

This is the closest equivalent to a “player database.”

---

### 9.2 `storage_1/data/`

Purpose:

- live world persistence / Central Economy storage;
- world state generated by the server;
- saved loot economy state;
- vehicles;
- dynamic events;
- many placed/dropped/stored world objects.

Examples seen in CrayZ logs:

```text
storage_1/data/types.bin
storage_1/data/events.bin
storage_1/data/dynamic_000.bin
storage_1/data/dynamic_001.bin
storage_1/data/dynamic_002.bin
storage_1/data/dynamic_003.bin
storage_1/data/building.bin
storage_1/data/vehicles.bin
```

These are active save-state files. DayZ logs showed them being restored during startup, which confirms they are not merely static templates.

---

### 9.3 Common Persistence Files

| File | General meaning |
|---|---|
| `players.db` | Player character database. |
| `data/types.bin` | Saved Central Economy item/type state. |
| `data/types.001`, `data/types.002` | Backup/alternate copies for CE storage recovery. |
| `data/events.bin` | Saved dynamic event state. |
| `data/events.001`, `data/events.002` | Backup/alternate event storage copies. |
| `data/dynamic_*.bin` | Dynamic world entities/items/objects. |
| `data/vehicles.bin` | Vehicle persistence. |
| `data/building.bin` | Building/base-related persistence where used by the current version/setup. |

Do not edit these binary files manually.

---

## 10. Backup And Restore Model

### 10.1 Minimal World + Player Backup

Back up:

```text
/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/storage_1/
```

This preserves:

- players;
- character state;
- live world persistence;
- vehicles;
- bases/stashes/containers where stored by persistence;
- dynamic world economy state.

It does **not** preserve your edited economy XML/JSON config if you changed those outside `storage_1`.

---

### 10.2 Recommended Mission Backup

Back up the entire mission folder:

```text
/DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus/
```

This preserves both:

```text
db/         = economy/config rules
storage_1/  = live save-state
```

This is usually the cleanest backup unit for a custom vanilla server.

---

### 10.3 Recommended CrayZ Backup Set

For Duplicati or another backup system, back up:

```text
/DockerData/crayz/config/
/DockerData/crayz/data/server/mpmissions/
/DockerData/crayz/data/profiles/
/DockerData/crayz/data/logs/        optional
/DockerData/crayz/data/steam/       optional, sensitive
```

Also keep deployment files somewhere safe:

```text
/Docker/crayz/crayz.yml
/Docker/crayz/crayz.env
```

Warning: `crayz.env` can contain Steam credentials. Treat backups containing it as sensitive.

---

### 10.4 Static DayZ Game Files To Exclude From Backups

The reinstallable DayZ server files are mostly under:

```text
/DockerData/crayz/data/server/
```

But do **not** exclude the entire folder blindly, because this important mission folder lives underneath it:

```text
/DockerData/crayz/data/server/mpmissions/
```

If using Duplicati, the practical model is:

```text
Back up:
  /DockerData/crayz/

Exclude most static files under:
  /DockerData/crayz/data/server/

But include:
  /DockerData/crayz/data/server/mpmissions/**
```

If Duplicati include-after-exclude behavior is awkward, use explicit source folders instead:

```text
/DockerData/crayz/config/
/DockerData/crayz/data/profiles/
/DockerData/crayz/data/logs/
/DockerData/crayz/data/steam/
/DockerData/crayz/data/server/mpmissions/
```

---

## 11. Wipe / Reset Patterns

Always stop the server before deleting or restoring persistence files.

### 11.1 Full World + Player Wipe

Move or delete:

```text
storage_1/
```

DayZ recreates it on next start.

---

### 11.2 Keep Players, Wipe World

Keep:

```text
storage_1/players.db
```

Move/delete:

```text
storage_1/data/
```

Result:

- player characters remain;
- world loot/base/vehicle/event persistence resets.

Use carefully.

---

### 11.3 Keep World, Wipe Players

Keep:

```text
storage_1/data/
```

Move/delete:

```text
storage_1/players.db
```

Result:

- world persistence remains;
- player characters reset.

Use carefully.

---

## 12. Safe Backup Command Examples

### Stop Server

```bash
# (execute on Docker host:)
cd /Docker/crayz
sudo docker compose -f crayz.yml --env-file crayz.env down
```

### Back Up Mission + Config

```bash
# (execute on Docker host:)
sudo tar -czf "/DockerData/crayz-mission-config-backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
  /DockerData/crayz/data/server/mpmissions/dayzOffline.chernarusplus \
  /DockerData/crayz/config \
  /Docker/crayz/crayz.yml \
  /Docker/crayz/crayz.env
```

### Start Server

```bash
# (execute on Docker host:)
cd /Docker/crayz
sudo docker compose -f crayz.yml --env-file crayz.env up -d
```

---

## 13. Validation Commands

### Confirm Active Config Path

```bash
# (execute on Docker host:)
sudo docker exec crayz-dayz sh -lc 'tr "\0" " " < /proc/1/cmdline; echo'
```

Expected DayZ command contains:

```text
-config=/dayz/config/serverDZ.cfg
```

### Confirm Server Startup

```bash
# (execute on Docker host:)
sudo docker logs crayz-dayz | grep -E "Player connect enabled|Mission read|Connected to Steam|Steam policy response"
```

Expected lines:

```text
Player connect enabled
Mission read.
Connected to Steam
Steam policy response
```

### Confirm LAN Discovery / Join Ports

```text
Steam Favorites / server query address:
192.168.1.240:27016

Displayed/game server address after discovery:
192.168.1.240:2302
```

Observed successful player login line:

```text
Player "DamaniaC" (...) is connected
```

---

## 14. What Belongs Where

| Thing you want to change | File/location |
|---|---|
| Server name | `/DockerData/crayz/config/serverDZ.cfg` |
| Server password | `/DockerData/crayz/config/serverDZ.cfg` |
| Admin password | `/DockerData/crayz/config/serverDZ.cfg` |
| Max players | `/DockerData/crayz/config/serverDZ.cfg` |
| Steam query port | `/DockerData/crayz/config/serverDZ.cfg` |
| Third person / crosshair / VoN | `/DockerData/crayz/config/serverDZ.cfg` |
| Time acceleration | `/DockerData/crayz/config/serverDZ.cfg` |
| Mission/map selection | `/DockerData/crayz/config/serverDZ.cfg` |
| Loot amounts / item economy | `dayzOffline.chernarusplus/db/types.xml` |
| Event definitions | `dayzOffline.chernarusplus/db/events.xml` |
| Vehicle/event spawn positions | `dayzOffline.chernarusplus/cfgeventspawns.xml` |
| Spawnable attachments/cargo | `dayzOffline.chernarusplus/cfgspawnabletypes.xml` |
| Weather | `dayzOffline.chernarusplus/cfgweather.xml` |
| Animal/infected territories | mission territory files |
| Gas/contaminated areas | mission effect-area/event config files |
| Advanced gameplay JSON settings | `dayzOffline.chernarusplus/cfggameplay.json` plus `enableCfgGameplayFile = 1;` |
| Current player characters | `storage_1/players.db` |
| Current world state | `storage_1/data/` |
| Mods | DayZ startup parameters such as `-mod=...`, not `serverDZ.cfg` |

---

## 15. Sources / Reference Notes

Primary references used for this document:

- Bohemia Interactive Community Wiki: DayZ Server Configuration.
- Bohemia Interactive Community Wiki: DayZ Gameplay Settings.
- Bohemia Interactive DayZ Central Economy public GitHub repository.
- DayZ server hosting documentation and community references for persistence layout and common `serverDZ.cfg` variables.
- CrayZ runtime logs and paths observed during local Docker host testing.

Version-sensitive warning:

DayZ server configuration evolves over time. Before making a polished public “complete reference,” compare against the current official DayZ server configuration documentation and the current vanilla mission files installed by SteamCMD.
