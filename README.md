# Vanilla RPG

A Roblox RPG inspired by collection-based progression. First milestone: player
data and stats. Inventory ownership and equipment are implemented for the starter kit. Inventory transfer/stack handling and level-based expansion are implemented.
Placeable oak and tool-free raspberry harvesting, collection tracking and passive talismans are implemented.
Crafting remains pending; enchanted material definitions are ready.

## Linux Mint / Vinegar quick start

Install the [Rojo 7.7.1 CLI and matching Studio plugin](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1).
Vinegar runs Studio; run the Linux Rojo CLI in your normal Linux terminal.

```bash
git clone https://github.com/vanilla222222/vanilla-rpg.git
cd vanilla-rpg
mkdir -p build
rojo build -o build/vanilla-rpg.rbxlx
rojo serve
```

Keep the terminal running. In Studio, open `build/vanilla-rpg.rbxlx`, open the
Rojo plugin and connect to `localhost:34872`. Press **Play**. Expect a baseplate,
a bottom-left resource HUD and **Inventory / Stats / Collections** buttons. Open Studio's Output
window when reporting errors. Press I for Inventory or C for Stats.

Studio defaults to **temporary in-memory data**: no API access is required and
stopping the Studio server clears it. This mode is labelled on screen.
Do not expect coins to survive Stop → Play in this default mode.

### Testing actual persistence

Use a separate private testing experience. Publish the place there. In Studio's
experience security settings, enable **Studio Access to API Services** and set
`PersistStudio = true` in `src/server/Config.lua`. Studio uses a separate store
name from published servers. Published servers use DataStore persistence by default;
there is no temporary fallback if loading fails. A failed/corrupt load kicks the
player rather than creating and saving a blank replacement profile.

Save/publish changes in Studio when testing published servers. Rojo live sync
updates the open Studio session, not the published experience automatically.

See [Studio acceptance checks](docs/TESTING.md) before enabling real-player use.
Engine behavior and real DataStore requests have not been verified in this environment.

## Implemented foundation

- Version 2 profiles, version 1 migration, missing-field reconciliation and safe
  integer balances. See [the player-data contract](docs/PLAYER-DATA.md) for all fields.
- Fail-closed unsupported-version handling and explicit deprecated-field migration.
  Legacy combat XP is archived without duplicating it into four new skill tracks.
- Atomic UpdateAsync session lease; 60-second autosaves, three request attempts,
  ownership checks, expiration watchdog, leave/shutdown saves and late-load release.
- Definitive stats, formula-only defined stats and dynamic health/stamina/mana.
  See [the stat contract](docs/STATS.md) for defaults, caps and probability rules.
- Deterministic source-keyed modifiers:
  `(base + sum(flat)) × (1 + sum(percent)) × product(multiplier)`, then clamps.
- Server-only PlayerService APIs for coins and modifiers. Derived stats and current resources are not saved.
- Private client snapshots, rate-limited snapshot requests and validated sprint controls.
- One-time starter kit on join: axe, pickaxe, sword, hoe and fishing rod.
- Validated item catalog: nine types, rarity/policy metadata, stat modifiers and
  thirty-three provisional items. See [item definitions](docs/ITEMS.md).
- Move/swap/split/merge modes, paged level-based inventory expansion, server reward
  APIs and stale-request protection. See [inventory](docs/INVENTORY.md).
- Inventory equip/unequip controls, configurable item image assets with name fallback, complete Stats
  window and compact bottom-left resource HUD. See [equipment](docs/EQUIPMENT.md).
- Placeable resource folders for every skill; oak and raspberry loot, XP, fortune/wisdom and
  automatic talisman bag bonuses. See [placing resources](docs/RESOURCES.md).
- Initial test baseplate. Unspecified numeric ceilings remain provisional balance.

## Content editing

The framework is built to make new content quick to configure so most development
time can go into map design. Item properties, loot, timers and images belong in
named definition files; reusable systems apply them. See the
[content editing guide](docs/CONTENT-AUTHORING.md).

## Source layout

| Path | Responsibility |
| --- | --- |
| `src/shared` | Display definitions, permanent item IDs, table utilities |
| `src/server/Inventory.lua` | Atomic transfers, stack rewards and removals |
| `src/server/Profile.lua` | Schema, validation and currency rules |
| `src/server/SessionStore.lua` | Dependency-injected persistence/lease protocol |
| `src/server/Stats.lua` | Definitive modifiers and defined dependency engine |
| `src/server/Resources.lua` | Current health/stamina/mana and regeneration |
| `src/shared/StatRules.lua` | Fortune, wisdom, crit, ability and mining spread helpers |
| `src/server/PlayerService.lua` | Active-session mutation and snapshot API |
| `src/server/Bootstrap.server.lua` | Roblox services, lifecycle and remote wiring |
| `src/client` | Player HUD; no authority over progression |
| `tests/run.lua` | Headless core and persistence fault tests |

The bootstrap is the composition root. Activity services receive PlayerService
there; clients never receive session tokens or raw profile tables. Oak and raspberry harvests
award collection credit; ordinary inventory grants and transfers do not. Storage,
crafting, other resource types and skill/collection level formulas are pending.

Hub storage has no intended gameplay stack-capacity limit, but Roblox storage and
number limits still exist. Stack quantities are safe integers; unique equipment
will need per-instance records and capacity/sharding decisions before release.

## Local checks

With Lua 5.3+ installed:

```bash
lua tests/run.lua
```

`texlua tests/run.lua` also runs the portable core tests if TeX Live is available.
These test logic using a fake atomic store; they do not emulate Roblox scheduling,
network replication, Studio/Vinegar, platform throttling or DataStore availability.

Build the place with Rojo to check instance mapping. No GitHub Actions workflows,
paid services or monetization have been configured.

## Development order

1. Stats and player data — initial implementation; Studio acceptance pending.
2. Inventory and equipment.
3. Crafting.
4. Collections and hub storage.
5. Foraging.
6. Mining.
7. Combat.
8. Fishing.
