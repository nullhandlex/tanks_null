# Spawner and Wave System

## Core ownership rule

Wave composition is owned by `GM_MainCamera`.

Actual spawn execution is owned by `BP_EnemySpawner`.

This distinction is important and was the source of a previous bug.

## `BP_EnemySpawner`

Known variable:

- `EnemyQueue` — array of enemy classes

Known functions:

- `AddEnemyToQueue`
- `SpawnEnemy`
- `StopSpawner`

## Correct `SpawnEnemy` behavior

`SpawnEnemy` must:

1. inspect its own `EnemyQueue`
2. take the next class from that queue
3. spawn that class
4. remove/advance the queue entry
5. do nothing if the queue is empty

It must **not** directly call:

- `GM_GetEnemyClass`

## Historical bug

An earlier implementation let `SpawnEnemy` directly call `GM_GetEnemyClass`.

That caused incorrect responsibility sharing and broken wave behavior.

Canonical rule:

> GameMode prepares queues. Spawners only consume queues.

## Multiple spawners

The battle can have multiple `BP_EnemySpawner` instances.

At one stage the project used four.

`GM_MainCamera` distributes enemy classes into their queues.

## Random spawn lateral position

Randomness on the lateral Y axis was added so enemies do not all use an identical line.

Preserve visual variation in Godot.

## `GM_MainCamera`

Known wave-related functions/events:

- `StartWave`
- `Transition`
- `GM_GetEnemyClass`

GameMode prepares wave data and populates spawner queues.

## `GM_GetEnemyClass`

Important fixed bug:

When the requested/selected enemy is the **last matching element**, the function must still return:

- `Success = true`

A previous implementation incorrectly failed at the final element.

Do not reintroduce this off-by-one / final-item bug.

## Empty queue behavior

Spawner timers may still be active while the queue is empty.

This is acceptable as long as:

- an empty queue causes no spawn
- no invalid class is requested
- no fallback call to `GM_GetEnemyClass` occurs

## Debugging note

A debug message similar to:

`EnemyPool KEYS EMPTY`

was used while debugging wave selection.

The keys were confirmed not to be empty in the corrected setup.

## Wave completion and victory

Victory is tied to completion of the final wave.

The known flow is conceptually:

`final wave completes`
→ `Transition`
→ detect no next wave / final completion
→ show Win UI

Victory does not rely on defeat-style `StopGame` flow in the same way.

## Defeat

Base destruction triggers defeat and stops spawners.

Known path:

`BP_Base destroyed / HP reaches zero`
→ `StopGame(GameOver = true)`
→ `StopSpawner`

## Godot migration recommendation

Suggested ownership:

### `GameManager`
- owns current wave index
- defines/builds wave composition
- distributes enemy scene references/classes into spawner queues
- detects final wave completion
- owns battle reward state

### `EnemySpawner`
- owns only its local queue
- has spawn timer
- instantiates queued enemy scenes
- emits useful signals if needed

Suggested queue type in Godot:

- array of `PackedScene`
- or wave entries containing `PackedScene` + parameters

Do not let `EnemySpawner` choose wave composition independently.


## 2D navigation target after spawn

In the Godot target architecture, a spawned enemy should not receive a hardcoded straight-line movement lane.

After instantiation:

1. the spawner places the enemy at its 2D spawn position
2. the enemy receives the current Base / attack target
3. its `NavigationAgent2D` receives the destination
4. the enemy begins pathfinding through the battle `NavigationRegion2D`

Random lateral spawn variation may still be used if it keeps the spawn point inside valid navigation space.

The spawner still owns only **when/what to instantiate**.

It does not own pathfinding decisions or wave composition.
