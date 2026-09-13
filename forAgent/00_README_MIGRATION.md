# UE5 Tower Defense → Godot Migration Knowledge Base

## Purpose

This folder is a structured knowledge base for an AI coding agent (Claude Code, Cursor, or similar) that will recreate an existing Unreal Engine 5.6 mobile tower-defense game in Godot 4.x.

The goal is **behavioral and visual migration**, not a literal 1:1 conversion of Unreal assets or Blueprint graphs.

## Current source project

- Engine: Unreal Engine 5.6
- Target: Android
- Orientation: Portrait
- Design resolution: 1080 × 1920
- Aspect ratio: 9:16
- Source world: Unreal 3D scene
- Source camera: static angled / tilted top-down camera
- Camera tilt used in UE: approximately -35° to -50°
- Primary implementation: Blueprint
- Additional native integration: C++
- Visual assets: primarily flat 2D image assets used inside the 3D UE scene

## Target project — canonical decision

The Godot port should be built as a **pure 2D game with a 2.5D / fake-perspective visual presentation**.

Canonical target:

- Godot 4.x
- GDScript
- Android
- Portrait 1080 × 1920
- `Node2D`
- `Camera2D`
- `CharacterBody2D`
- `Sprite2D`
- `NavigationRegion2D`
- `NavigationAgent2D`
- `CollisionShape2D`
- Godot `Control` UI
- mobile performance priority

Do **not** reproduce Unreal's 3D scene merely because the UE source uses a tilted 3D camera.

The source game's 3D feeling came mostly from:

- the angled camera
- already pseudo-isometric / top-down 2D sprites
- separate shadows
- background artwork

The Godot version should reproduce the **final visual result**, not the unnecessary 3D infrastructure.

## Enemy movement — source vs target

### Legacy UE behavior

The current Unreal implementation uses deterministic movement:

- X = forward movement toward base
- Y = sinusoidal sway/lateral drift
- Z = preserved
- timer-driven movement
- stop at a calculated X position
- then attack

This behavior is documented because it is the current source implementation.

### Target Godot behavior

The intended future Godot implementation should use **AI/navigation-based movement**.

Target components:

- `NavigationRegion2D`
- `NavigationAgent2D`
- pathfinding toward the Base / attack target
- obstacle avoidance
- optional agent avoidance
- AI state logic such as Moving / Attacking / Dead
- attack begins when the enemy reaches attack range

The old straight-line X/Y movement is **legacy reference behavior only** and must not be treated as the final Godot architecture.

## Visual assets

Existing unit assets should be preserved when practical.

The unit sprites are already stylized pseudo-isometric / top-down assets and should **not be redrawn by default**.

The background may be redrawn/reworked so its fake perspective, light direction, object thickness and shadows visually match the existing unit sprites.

Art and gameplay/navigation must remain separate:

- background = visual
- NavigationRegion2D = walkable space
- obstacle polygons/collisions = gameplay
- spawn markers = gameplay
- base/attack area = gameplay

## Migration philosophy

Do not attempt to convert `.uasset` files directly.

Instead:

1. Read these documents.
2. Recreate source behavior where needed.
3. Implement the new approved 2D architecture.
4. Preserve existing 2D art where practical.
5. Test each mechanic before moving to the next.
6. Run the project after changes.
7. Read Godot errors/output.
8. Fix errors before continuing.
9. Test on Android early.

## Suggested migration order

1. Create the 2D project and visual prototype
2. Import one real enemy sprite and the existing level background
3. Create Base
4. Create EnemyBase
5. Implement NavigationAgent2D movement
6. Test sprite rotation / direction handling
7. Implement attack
8. Implement EnemySpawner
9. Implement waves
10. Implement victory/defeat
11. Implement coins
12. Implement save/progression
13. Implement Main Menu
14. Replace/rework level backgrounds with final fake-perspective art
15. Android validation
16. External/native services last

## Source-of-truth rule

When documentation and old prototype behavior conflict, follow the newest explicit target rules recorded in:

- `09_KNOWN_BUGS_AND_FIXED_RULES.md`
- `10_GODOT_TARGET_ARCHITECTURE.md`
- `11_ART_DIRECTION_AND_2D_WORLD.md`
- `AGENTS.md`

## Documents

- `00_README_MIGRATION.md`
- `01_GAME_ARCHITECTURE.md`
- `02_ENEMY_SYSTEM.md`
- `03_SPAWNER_AND_WAVES.md`
- `04_BASE_COMBAT_AND_DAMAGE.md`
- `05_COINS_PROGRESSION_SAVE.md`
- `06_UI_AND_LEVEL_FLOW.md`
- `07_ANDROID_AND_PLATFORM.md`
- `08_CPP_EXTERNAL_SERVICES.md`
- `09_KNOWN_BUGS_AND_FIXED_RULES.md`
- `10_GODOT_TARGET_ARCHITECTURE.md`
- `11_ART_DIRECTION_AND_2D_WORLD.md`
- `12_MIGRATION_CHECKLIST.md`
- `13_SESSION_HANDOFF.md` — current product / UI / Android decisions from Cursor sessions
- `AGENTS.md`
