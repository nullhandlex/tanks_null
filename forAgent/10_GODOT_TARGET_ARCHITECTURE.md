# Proposed Godot Target Architecture

This document defines the **canonical target architecture** for the migration.

The target is no longer a 3D Godot recreation.

It is a **pure 2D game with a fake-3D / 2.5D presentation**.

---

# Core platform

- Godot 4.x
- GDScript
- Android
- portrait
- design resolution 1080 × 1920
- 9:16
- mobile performance priority

Core engine classes:

- `Node2D`
- `CharacterBody2D`
- `Sprite2D`
- `AnimatedSprite2D` where needed
- `Camera2D`
- `CollisionShape2D`
- `NavigationRegion2D`
- `NavigationAgent2D`
- `Control`

---

# Global Autoloads

## `GameManager.gd`

Battle/game-flow manager.

Responsibilities:

- current level ID
- battle state
- current wave
- wave progression
- build/distribute spawn queues
- track coins earned during current battle
- victory/defeat state
- Base reference / target access where appropriate
- emit battle-state signals

Avoid putting persistent save serialization here if `GameData` owns it.

## `GameData.gd`

Persistent progression singleton.

Suggested fields:

```gdscript
var total_coins: int = 0
var completed_levels: Array[int] = []
var unlocked_levels: Array[int] = [1]
```

Responsibilities:

- load
- save
- progression updates
- persistent currency

---

# Suggested project layout

```text
res://
├── assets/
│   ├── backgrounds/
│   ├── enemies/
│   ├── base/
│   ├── shadows/
│   ├── effects/
│   └── ui/
├── scenes/
│   ├── main_menu/
│   │   └── MainMenu.tscn
│   ├── battle/
│   │   ├── BattleLevel.tscn
│   │   ├── Base.tscn
│   │   ├── EnemySpawner.tscn
│   │   └── ui/
│   │       ├── BattleUI.tscn
│   │       ├── WinScreen.tscn
│   │       └── LoseScreen.tscn
│   └── enemies/
│       ├── EnemyBase.tscn
│       ├── EnemyTank.tscn
│       ├── EnemyFast.tscn
│       └── EnemyBoss.tscn
└── scripts/
    ├── autoload/
    │   ├── game_manager.gd
    │   └── game_data.gd
    ├── battle/
    │   ├── base.gd
    │   ├── enemy_spawner.gd
    │   └── battle_level.gd
    ├── enemies/
    │   └── enemy_base.gd
    └── ui/
        ├── main_menu.gd
        ├── battle_ui.gd
        ├── result_screen.gd
        └── base_health.gd
```

---

# Battle level

Suggested hierarchy:

```text
BattleLevel (Node2D)
├── BackgroundLayer
│   └── Background (Sprite2D)
├── World
│   ├── NavigationRegion2D
│   ├── Obstacles
│   ├── Base
│   ├── Spawners
│   └── Enemies
├── Effects
├── Camera2D
└── UI (CanvasLayer)
```

The background is visual only.

Gameplay navigation/collision must be separate.

---

# EnemyBase

Suggested hierarchy:

```text
EnemyBase (CharacterBody2D)
├── VisualRoot (Node2D)
│   ├── ShadowSprite (Sprite2D)
│   └── UnitSprite (Sprite2D / AnimatedSprite2D)
├── CollisionShape2D
├── NavigationAgent2D
├── AttackTimer
└── optional VFX
```

## Responsibilities

- receive destination/Base target
- follow `NavigationAgent2D` path
- obstacle/path navigation
- optional avoidance
- detect attack range
- state transition to ATTACKING
- direct repeating damage
- defeat/reward signal
- VFX trigger

## Recommended state

```gdscript
enum State {
    SPAWNING,
    MOVING,
    ATTACKING,
    DEAD
}
```

Add extra states only when mechanics require them.

## Movement

Do not use the old Unreal X line + Y sine sway as the final system.

Canonical Godot movement:

```text
spawn
→ set navigation target
→ follow path
→ reach attack range
→ stop movement
→ attack
```

## Visual rotation

First prototype:

- rotate the unit visual toward movement direction
- keep shadow independent if needed
- do not create 4/8 directional sprite sets until simple rotation is tested

## Visual scale

Default:

- constant scale

Optional:

- subtle visual-only scale by Y if it improves perspective

Never use strong perspective scaling by default.

---

# Navigation

Use:

- `NavigationRegion2D`
- `NavigationAgent2D`

Walkable space must be defined independently from the background image.

Obstacles may be represented by:

- holes/cut-outs in navigation polygons
- navigation obstacles where appropriate
- collision shapes for physical interaction if needed

Navigation must support multiple spawn points reaching the Base.

## Avoidance

Use only if needed.

Test realistic enemy counts on Android before enabling expensive avoidance behavior globally.

---

# EnemySpawner

Suggested root:

- `Node2D`

Children:

- `Timer`
- optional `Marker2D` spawn marker

State:

```gdscript
var enemy_queue: Array[PackedScene] = []
```

Rules:

- queue is filled externally by GameManager
- spawner only consumes queue
- empty queue does nothing
- after spawn, enemy receives Base/navigation target
- spawner does not choose a route

---

# Base

Suggested root:

- `Node2D`

Possible children:

```text
Base
├── Visual
├── Collision / Area2D
└── AttackTargetMarker(s)
```

State:

```gdscript
@export var max_hp: float = 100.0
var hp: float
```

Signals:

```gdscript
signal health_changed(current_hp: float, max_hp: float)
signal destroyed
```

The Base may expose:

- center target position
- one or more attack markers
- attack radius / region

This replaces the old hardcoded `StopX` concept.

---

# Battle state

Recommended explicit state:

```text
PREPARING
WAVE_ACTIVE
TRANSITION
VICTORY
DEFEAT
```

This prevents accidental victory during an inter-wave empty period.

---

# Wave data

Possible representation:

```gdscript
class_name WaveEntry
extends Resource

@export var enemy_scene: PackedScene
@export var count: int
@export var spawner_index: int
```

Plain dictionaries are acceptable for the first prototype.

Favor simplicity first.

---

# Visual direction

The 2.5D feeling should come from:

- existing pseudo-isometric/top-down unit sprites
- repainted/reworked perspective-aware backgrounds
- separate ground shadows
- correct draw order / Y sorting where useful
- mild object overlap
- lightweight 2D effects

Do not emulate a tilted 3D camera with actual Godot 3D unless a later mechanic requires it.

See:

- `11_ART_DIRECTION_AND_2D_WORLD.md`

---

# UI

Use Godot `Control` nodes with:

- anchors
- containers
- size flags
- safe responsive layout

UI should live independently of world draw ordering.

Suggested:

- `CanvasLayer`

Avoid hard-coded desktop positions.

---

# Save

Suggested file:

`user://savegame.json`

Possible structure:

```json
{
  "total_coins": 0,
  "completed_levels": [],
  "unlocked_levels": [1]
}
```

---

# Android

Configure portrait orientation immediately.

Test throughout migration.

Important performance test areas:

- NavigationAgent2D count
- avoidance
- large transparent sprites
- large background textures
- particles
- draw calls
- memory usage

---

# External services

Do not include payment / registration / file-sync services in the first gameplay prototype.

Core gameplay must work fully without them.

Integrate services only after:

- battle loop works
- save works
- Android build works
