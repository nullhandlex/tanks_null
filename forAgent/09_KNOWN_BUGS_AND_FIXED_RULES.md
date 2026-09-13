# Known Bugs, Fixes and Non-Negotiable Rules

This file exists to prevent an AI agent from reintroducing problems already solved in the Unreal implementation.

## 1. Spawner must not select enemies during spawn

### Wrong

`BP_EnemySpawner.SpawnEnemy`
→ call `GM_GetEnemyClass`
→ spawn returned class

### Correct

`GM_MainCamera`
→ builds/fills `EnemyQueue`

Then:

`BP_EnemySpawner.SpawnEnemy`
→ consumes its own `EnemyQueue`

This is a core architecture rule.

---

## 2. Final enemy lookup must return success

`GM_GetEnemyClass` previously failed when the selected matching enemy was the final element.

Correct behavior:

If a valid class was found, including the last element:

`Success = true`

Avoid off-by-one/final-item failure.

---

## 3. Empty queue must not cause invalid spawn

Spawner timer may fire while:

`EnemyQueue` is empty.

Correct behavior:

- do nothing
- no invalid array access
- no emergency call to GameMode for another class

---

## 4. HP percentage denominator

Correct:

`CurrentHP / MaxHP`

Not:

`CurrentHP / CurrentHP`
or another wrong runtime value.

Clamp result to:

`0..1`

---

## 5. Enemy movement axes

Current canonical version:

- X = forward movement toward base
- Y = sway/lateral drift
- Z = preserved

Old prototype notes with Y-forward/X-sway are obsolete.

---

## 6. Enemy movement stops on attack

When `StartAttack` occurs:

- save/lock lateral position
- set attacking state
- stop movement timer
- start attack timer

Do not allow attack state and movement state to continue simultaneously.

---

## 7. Base validity before attack

Before damage:

- ensure base reference still exists/is valid
- do not continue attacks after base destruction

---

## 8. UI must not own core gameplay state

Removing an old battle HUD caused errors in wave functions because logic assumed UI references existed.

Godot rule:

- `GameManager` owns battle state
- UI observes/displays it
- gameplay must not fail because a widget is missing

---

## 9. Reward multiplier consistency

Historical issue:

A win multiplier could affect displayed coins without affecting the amount actually persisted.

Correct rule:

`FinalReward` is calculated once.

The same value is:

- displayed
- added to `TotalCoins`
- saved

---

## 10. Result UI vs persistent currency

Win/Lose:

- show level-earned / final claimed battle reward

Main Menu:

- show persistent `TotalCoins`

Do not mix these values.

---

## 11. First level unlock

When no save exists:

`UnlockedLevels = [1]`

Do not initialize it as empty.

---

## 12. Duplicate level progression

On victory:

Only add `CurrentLevelID` to `CompletedLevels` if it is not already present.

Only add `NextLevelID` to `UnlockedLevels` if it is not already present.

---

## 13. Separate victory and defeat semantics

Defeat:

- base destroyed
- stop game/spawners
- show Lose

Victory:

- final wave completed
- show Win

Do not trigger victory merely because spawners are temporarily empty between waves.

---

## 14. Android / external services

Native services caused device-specific startup problems.

When migrating:

- add them only after gameplay works
- integrate one service at a time
- test every addition on real Android hardware

---

## 15. Legacy straight-line movement is not the final Godot target

The current UE game uses deterministic X movement + Y sway.

That is a source implementation detail.

The approved Godot target now uses:

- `NavigationRegion2D`
- `NavigationAgent2D`
- pathfinding
- attack range
- an explicit enemy state system

Do not rebuild the old `StopX` system as the final migration architecture.

It may be implemented only as a temporary comparison/prototype if explicitly requested.


---

## 16. Godot target is pure 2D

Do not reproduce Unreal's 3D world merely to mimic the angled camera.

Canonical target:

- Node2D
- CharacterBody2D
- Sprite2D
- Camera2D
- NavigationAgent2D
- NavigationRegion2D
- 2D collision
- Control UI

The pseudo-3D look belongs in art/presentation.

---

## 17. Preserve existing unit art

Existing enemy/unit sprites are already stylized pseudo-isometric/top-down assets.

Do not redraw them by default.

First test:

- direct import
- correct pivot
- correct scale
- sprite rotation toward movement direction
- separate shadow handling

Only request directional/redrawn variants if visual testing proves simple rotation is unacceptable.

---

## 18. Background art and gameplay navigation are separate

The painted level background must never be the authoritative gameplay collision/navigation representation.

Keep separate:

- visual background
- walkable navigation polygons
- obstacle/non-walkable polygons
- spawn positions
- Base attack region

This allows background art to be replaced without rewriting gameplay.

---

## 19. Do not force strong perspective scaling

Default unit visual scale should remain constant.

If a fake perspective scale-by-Y is tested, keep it subtle and apply it only to the visual subtree.

Do not scale:

- collisions
- navigation agent radius
- gameplay ranges

unless there is a specific gameplay reason.

---

## 20. Use the unit art as the perspective reference

When backgrounds are repainted, their perspective should match the existing unit sprites.

Prefer a mild orthographic / pseudo-isometric 2.5D look.

Avoid strong vanishing-point perspective that makes the existing unit sprites look pasted onto the scene.
