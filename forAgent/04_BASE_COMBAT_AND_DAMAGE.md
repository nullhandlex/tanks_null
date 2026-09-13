# Base, Combat and Damage

## `BP_Base`

The player base stores health and receives enemy damage.

Known variables:

- `BaseHP`
- `MaxBaseHP`
- `HPWidgetRef`

Example values used during development:

- `BaseHP = 100`
- `MaxBaseHP = 100`

These were example/default values and may later be tuned.

## Damage interface

Unreal uses:

- `BPI_BaseDamage`

Known interface function:

- `ApplyBaseDamage(float Amount)`

Enemy attack checks the base reference before calling the interface.

## `ApplyBaseDamage`

Conceptual behavior:

1. subtract incoming damage from `BaseHP`
2. clamp HP to valid range
3. update UI
4. if HP reaches zero, trigger defeat

Equivalent concept:

`BaseHP = Clamp(BaseHP - Amount, 0, MaxBaseHP)`

Then:

`UpdateHP(BaseHP, MaxBaseHP)`

## Health UI

Widget:

- `W_BaseHealth`

Progress bar:

- `HP_Bar`

Known function:

- `UpdateHP(NewHP, MaxHP)`

Correct percentage calculation:

`Percent = Clamp(NewHP / MaxHP, 0 .. 1)`

## Historical HP UI bug

The denominator was previously wrong in the HP percent calculation.

Canonical rule:

> Divide current HP by `MaxHP`, not by another current/runtime value.

Godot should preserve this correct calculation.

## Defeat flow

When base HP reaches zero:

1. base is considered destroyed
2. GameMode combat-stop flow is triggered
3. spawners are stopped
4. enemy attack should no longer continue
5. Lose UI is shown

Known UE flow uses:

- `StopGame`
- `GameOver = true`
- `StopSpawner`

## Enemy attack

Enemy attack does direct damage rather than requiring a projectile.

Known source variables:

- `DamagePerShot`
- `AttackRate`

Attack loop:

`AttackTimer`
→ `AttackOnce`
→ validate base
→ `ApplyBaseDamage(DamagePerShot)`
→ play shot VFX

## Godot suggested implementation

Base scene:

```text
Base
├── Visual
├── Collision
└── BaseHealthUI
```

Suggested API:

```gdscript
func apply_damage(amount: float) -> void:
    hp = clamp(hp - amount, 0.0, max_hp)
    health_changed.emit(hp, max_hp)

    if hp <= 0.0:
        destroyed.emit()
```

Suggested signals:

- `health_changed(current_hp, max_hp)`
- `destroyed`

This replaces Unreal interface/event plumbing while keeping systems decoupled.


## Godot navigation / attack target note

Because the target movement system is navigation-based, the Base should expose a usable 2D target/attack position or attack region.

Enemies should stop and attack based on:

- target distance
- attack range
- optional designated attack points around the Base

Do not port the old UE `StopX` rule as the final Godot condition.
