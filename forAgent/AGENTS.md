# AI Agent Instructions — Tower Defense Godot Migration

You are working on a Godot 4.x port of an existing Unreal Engine 5.6 mobile tower-defense game.

## Primary goal

Recreate the game's behavior while implementing the **approved new Godot architecture**.

Do not attempt a literal Unreal Blueprint-to-Godot mapping where Godot has a simpler native pattern.

## Required reading order

Before major changes, read:

1. `13_SESSION_HANDOFF.md` (living product decisions from Cursor chats)
2. `00_README_MIGRATION.md`
3. `01_GAME_ARCHITECTURE.md`
4. the system-specific document for the task
5. `09_KNOWN_BUGS_AND_FIXED_RULES.md`
6. `10_GODOT_TARGET_ARCHITECTURE.md`
7. `11_ART_DIRECTION_AND_2D_WORLD.md`

## Platform and renderer direction

Canonical target:

- Godot 4.x
- GDScript
- Android
- portrait
- 1080 × 1920 design resolution
- 9:16
- pure 2D
- mobile performance priority

Use:

- `Node2D`
- `CharacterBody2D`
- `Sprite2D`
- `Camera2D`
- `NavigationRegion2D`
- `NavigationAgent2D`
- `CollisionShape2D`
- `Control`

Do not create a 3D Godot world only to mimic Unreal's tilted camera.

## Source vs target movement

### Source UE behavior

The Unreal version currently uses:

- straight X-axis movement
- Y-axis sine sway/drift
- a hardcoded stop-X calculation
- timer-driven movement

This is **legacy source behavior**.

### Canonical Godot target

Use AI/navigation-based movement:

- `NavigationRegion2D`
- `NavigationAgent2D`
- Base/attack target
- pathfinding around obstacles
- optional agent avoidance
- attack range
- explicit movement/attack state

Do not implement the old X/Y linear system as the final migration movement unless explicitly asked for a temporary comparison prototype.

## Enemy state

Prefer an explicit state machine, e.g.:

```text
SPAWNING
MOVING
ATTACKING
DEAD
```

Add other states only when needed.

## Architecture rules

### GameManager

GameManager owns:

- battle flow
- wave state
- wave composition
- distribution of enemy queues
- battle-earned coins
- victory/defeat state

### GameData

GameData owns:

- persistent total coins
- completed levels
- unlocked levels
- load/save

### EnemySpawner

EnemySpawner must:

- receive a queue from GameManager
- spawn only from that queue
- do nothing when queue is empty
- assign the navigation/Base target to spawned enemies

EnemySpawner must NOT:

- decide wave composition during spawn
- choose pathfinding routes

### Enemy

EnemyBase owns common:

- navigation movement
- target following
- attack range
- state
- attack
- damage
- death/reward signal
- visual facing

Use derived scenes/resources for enemy variants.

### Base

Base owns HP and damage state.

Base should expose a usable attack target/area for navigation-based enemies.

UI observes the Base; UI does not own HP.

## Art rules

Existing unit sprites are approved assets.

Do not redraw them by default.

First test:

- direct import
- correct scale/pivot
- rotation toward movement direction
- separate shadow

Only create directional sprite variants if simple rotation clearly fails visually.

The background may be repainted/reworked to match the existing unit art.

Use the unit sprites as the perspective/style reference.

Prefer:

- mild pseudo-isometric / tilted top-down
- orthographic-like presentation
- separate shadows
- Y sorting where useful

Avoid:

- strong photographic perspective
- strong scale-by-Y
- a real 3D scene just for camera angle

## Background/gameplay separation

The painted background is not authoritative navigation data.

Keep separate:

- visual background
- NavigationRegion2D
- obstacle polygons/collisions
- spawn markers
- Base attack region

A background image should be replaceable without rewriting gameplay.

## Runtime rules

After implementing a feature:

1. save changed files
2. run the relevant scene/project
3. inspect Godot output/errors
4. fix errors
5. run again

Do not claim a feature is complete merely because the code appears correct.

## MCP usage

If Godot MCP tools are available:

- inspect the current scene before editing
- prefer valid editor operations over hand-editing complex `.tscn` where practical
- run/playtest scenes
- inspect errors
- verify nodes/resources exist
- verify navigation maps/regions are actually usable at runtime

## Performance

Mobile performance is a priority.

Navigation/pathfinding is intentionally part of the new design, but configure it responsibly.

- use `_physics_process` for simple CharacterBody2D navigation movement as needed
- use signals/timers for non-frame-critical logic
- test realistic enemy counts
- enable avoidance only when needed
- tune avoidance conservatively
- avoid unnecessary allocations during waves
- keep VFX lightweight
- watch large transparent textures/background memory

## Do not invent missing source behavior

If a source mechanic is not documented:

- mark it as unknown
- implement the minimum behavior necessary for the current task
- leave a TODO with the assumption

Especially do not invent implementations for:

- payment service
- registration service
- file-sync service

until their source/API is available.

## Preserve fixed behavior

Never reintroduce these known bugs:

- spawner calls GameManager for an enemy during `SpawnEnemy`
- final enemy lookup returns false despite finding an enemy
- empty queue accesses invalid index
- HP percent uses wrong denominator
- result UI saves a different reward than it displays
- gameplay depends on a UI widget being valid
- victory triggers merely because a queue is temporarily empty
- enemy moves while in ATTACKING state
- enemy attacks a destroyed Base
- final Godot architecture reverts to hardcoded `StopX`
- art and navigation become coupled
- existing unit assets are redrawn without a demonstrated need

## Migration sequence

Prefer:

1. pure 2D project bootstrap
2. import one real background + one real unit asset
3. BattleLevel + NavigationRegion2D
4. Base + HP + attack target
5. EnemyBase + NavigationAgent2D
6. test sprite rotation
7. avoidance/crowd test
8. attack
9. enemy defeat
10. EnemySpawner
11. wave orchestration
12. victory/defeat
13. battle coins
14. persistent GameData/save
15. Main Menu
16. enemy variants
17. final background/art pass
18. Android validation
19. external services

## Code style

- clear typed GDScript where useful
- small focused scripts
- signals for decoupled communication
- exported tuning values
- explicit state where it improves clarity
- avoid giant singleton scripts
- avoid copying Unreal boilerplate patterns Godot does not need

## Completion criteria for a mechanic

A mechanic is complete only if:

- relevant scene runs
- no new Godot errors are present
- behavior matches migration docs
- navigation actually works in runtime
- no fixed rule in `09_KNOWN_BUGS_AND_FIXED_RULES.md` is violated
