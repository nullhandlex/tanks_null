# Game Architecture

## Overview

The UE5 project is a portrait mobile tower-defense game.

The current architecture separates:

- global game/progression state
- battle flow
- enemy spawning
- enemy behavior
- base health/damage
- UI
- persistent save data
- native external services

## Important Unreal classes

### `GM_MainCamera`

Unreal GameMode responsible for battle-level orchestration.

Known responsibilities:

- wave management
- transitions between waves
- selection of enemy classes for waves
- filling enemy queues for spawners
- tracking coins earned during the level
- victory flow
- stopping combat logic where appropriate

Known functions/events:

- `StartWave`
- `Transition`
- `GM_GetEnemyClass`
- `AddCoins`
- `StopGame`

Important rule:

`GM_MainCamera` decides which enemy classes belong to the current wave.

`BP_EnemySpawner` must **not** independently ask the GameMode which enemy to spawn during `SpawnEnemy`.

---

### `BP_EnemySpawner`

Spawner actor.

There can be multiple instances in one battle level. At one point the project used four spawners.

Important state:

- `EnemyQueue`: array of enemy classes

Responsibilities:

- receive enemy classes from `GM_MainCamera`
- store them in `EnemyQueue`
- spawn only from its local queue
- stop spawning when instructed

Known functions/events:

- `AddEnemyToQueue`
- `SpawnEnemy`
- `StopSpawner`

Critical architecture rule:

> `SpawnEnemy` consumes `EnemyQueue`. It must not directly call `GM_GetEnemyClass`.

---

### `BP_Enemy`

Base enemy Blueprint.

Known child classes include:

- `BP_Enemy_Tank`
- `BP_Enemy_Fast`
- `BP_Enemy_Boss`

The shared base contains common movement, stopping, attack and death/reward behavior.

Known death event:

- `OnEnemyDefeated`

---

### `BP_Base`

Player base actor.

Responsibilities:

- store base HP
- receive damage from enemies
- update base HP UI
- trigger defeat when destroyed

Known variables:

- `BaseHP`
- `MaxBaseHP`
- `HPWidgetRef`

Known functions:

- `UpdateHP`
- `ApplyBaseDamage`

---

### `BPI_BaseDamage`

Blueprint Interface used to apply base damage.

Known function:

- `ApplyBaseDamage(float Amount)`

Enemy attack uses this interface rather than tightly coupling to the base Blueprint implementation.

---

### `GI_TDGame`

Blueprint GameInstance used for persistent/global progression data.

Known variables:

- `TotalCoins : int`
- `CompletedLevels : int array`
- `UnlockedLevels : int array`

Default state when no save exists:

- `TotalCoins = 0`
- `CompletedLevels = []`
- `UnlockedLevels = [1]`

Known persistence-related function:

- `SaveProgress`

Historical function / flow:

- `LoadOrCreateSave`

---

### `SG_TDGame`

SaveGame object.

Known fields:

- `TotalCoins`
- `CompletedLevels`
- `UnlockedLevels`

Its EventGraph is intentionally empty. It acts primarily as a data container.

---

### `W_BaseHealth`

Base HP widget.

Contains:

- HP progress bar (`HP_Bar`)

Known function:

- `UpdateHP(NewHP, MaxHP)`

---

### `W_MainMenu`

Main-menu widget on a separate Main Menu level.

Known pages:

- index 0 = `BattlePage`
- index 1 = `SettingsPage`
- index 2 = `BasePage`
- index 3 = `WalletPage`

Main menu displays `TotalCoins`.

---

### Win / Lose widgets

Separate battle-result widgets.

Design rule:

They should display **coins earned for the current level**, not the global `TotalCoins`.

Both victory and defeat can award earned coins.

There is one main button:

- `"Отримати коіни"` / Get Coins

That button:

1. claims/adds the earned level reward
2. saves progression/account coins
3. transitions back to Main Menu

---

## Level structure

The project uses a separate Main Menu level and battle level(s).

### Main Menu level

- creates/displays `W_MainMenu`
- mouse cursor is shown
- displays persistent `TotalCoins`

### Battle level

Contains or references:

- camera
- `GM_MainCamera`
- one or more `BP_EnemySpawner`
- `BP_Base`
- enemy actors
- battle UI

## Camera

The game is designed for portrait mode.

Known setup:

- resolution target: 1080 × 1920
- constrained aspect: 9:16
- static top-down angled camera
- tilt around -35° to -50°
- level startup camera can be selected using `Set View Target with Blend`

## Godot migration principle

Do not mechanically copy Unreal class names if a simpler Godot architecture is more natural.

However, preserve the behavioral responsibilities and ownership boundaries.


## Approved Godot interpretation

The UE source uses a 3D level and tilted camera, but this is **not** a target architecture requirement.

The Godot port should interpret the source systems as gameplay responsibilities and rebuild them in a pure 2D world.

Target equivalents should use:

- `Node2D` / `CharacterBody2D`
- `Sprite2D`
- `Camera2D`
- `NavigationAgent2D`
- `NavigationRegion2D`
- 2D collisions
- Godot `Control` UI

The visual impression of the old tilted camera should come from:

- background art drawn with a mild fake perspective
- the existing pseudo-isometric unit sprites
- separate ground shadows
- draw ordering / Y sorting where useful
- optional very subtle visual-only scale by screen Y, only if testing proves it helps

Do not build a 3D Godot scene solely to imitate the Unreal camera.
