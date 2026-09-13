# Enemy System

## Source class

Base UE class:

- `BP_Enemy`

Known child variants:

- `BP_Enemy_Tank`
- `BP_Enemy_Fast`
- `BP_Enemy_Boss`

Different child classes may override stats/visuals while sharing base behavior.

---

# Part A — Legacy Unreal movement

This section documents the **current UE implementation** for reference.

It is not the final movement architecture for Godot.

## Current UE movement model

Enemies currently move without AI navigation and without splines.

Legacy source behavior:

- primary movement along X
- sinusoidal sway along Y
- Z remains fixed

### Stored initial values

Known stored values include:

- `BaseX`
- `ZKeep`
- `StartY`
- `PositionY`
- `LockY`

Initial relationships:

- `PositionY = StartY`
- `LockY = StartY`

### Legacy movement parameters

- `SpeedX`
- `StopDistanceFromBase`
- `StopTolerance`
- `SwayAmp`
- `SwayFreq`
- `SwayPhase`
- `DriftY`

`SwayPhase` is randomized in approximately:

`0 .. 2π`

### Legacy stop position

`StopX = BaseX - StopDistanceFromBase`

### Legacy sway calculation

Conceptually:

`Y = PositionY + sin(Age * SwayFreq + SwayPhase) * SwayAmp + DriftY * Age`

### Legacy update mechanism

The UE implementation used a movement timer rather than Tick.

Typical interval:

- `0.03 – 0.05 sec`

Known event/function:

- `MoveStep`

### Legacy attack transition

Known boolean:

- `bAttacking`

Concept:

`NOT bAttacking AND WithinStopRange -> StartAttack`

Where:

`Within = abs(NextX - StopX) <= StopTolerance`

When attack starts:

1. save current lateral position into `LockY`
2. set `bAttacking = true`
3. clear movement timer
4. start attack timer

This entire X/Y movement model is preserved only so the AI agent understands the source behavior.

---

# Part B — Canonical Godot target movement

The approved target is **AI/navigation-based 2D movement**.

Do not implement the old X-line + sine sway as the final Godot movement system unless explicitly requested for a temporary prototype.

## Target node structure

Suggested enemy scene:

```text
EnemyBase (CharacterBody2D)
├── VisualRoot (Node2D)
│   ├── ShadowSprite (Sprite2D)
│   └── UnitSprite (Sprite2D / AnimatedSprite2D)
├── CollisionShape2D
├── NavigationAgent2D
├── AttackTimer
└── optional VFX nodes
```

## Navigation

Use:

- `NavigationRegion2D` in the battle level
- `NavigationAgent2D` per enemy

Target behavior:

1. Enemy receives a target position / Base target.
2. `NavigationAgent2D.target_position` is set.
3. Enemy follows the calculated path.
4. Static obstacles are excluded from the navigable region or represented correctly in navigation.
5. Optional avoidance can be enabled for dynamic separation between enemies.
6. Enemy stops when it reaches an appropriate attack range.
7. AI state changes from Moving to Attacking.
8. Movement stops while attacking.

## Enemy AI state

Recommended explicit states:

```text
SPAWNING
MOVING
ATTACKING
STUNNED      # optional/future
DEAD
```

A simple enum/state machine is preferred over scattered booleans.

Example:

```gdscript
enum State {
    SPAWNING,
    MOVING,
    ATTACKING,
    STUNNED,
    DEAD
}
```

Only add states that are currently needed.

## Attack range

The target Godot implementation should use a distance/range concept rather than a hardcoded X stop coordinate.

Suggested logic:

```text
distance to Base / attack point <= attack_range
→ stop navigation movement
→ enter ATTACKING
```

This allows enemies to approach the Base from different paths.

## Obstacle/path behavior

The new system should support:

- route changes around obstacles
- irregular paths
- multiple spawners
- future dynamic map objects if desired

Do not use Unreal-style spline movement unless later design requires fixed authored lanes.

## Agent avoidance

`NavigationAgent2D` avoidance may be used to reduce enemies stacking directly on top of one another.

Important:

Avoidance and pathfinding are separate concerns.

Do not enable expensive settings blindly for every unit. Test on Android with realistic enemy counts.

## Existing sprite orientation

The current enemy art is already pseudo-isometric / top-down.

Default first prototype:

- use the existing sprite unchanged
- rotate `UnitSprite` or a `VisualRoot` toward movement direction
- keep the separate ground shadow independent where visually appropriate

Example concept:

```gdscript
var direction := (next_path_position - global_position).normalized()
velocity = direction * move_speed

if direction.length_squared() > 0.0:
    $VisualRoot/UnitSprite.rotation = direction.angle() + sprite_angle_offset
```

The exact angle offset depends on the source sprite's forward direction.

## Directional art fallback

Before creating 4-way or 8-way sprite sets, test simple sprite rotation.

Only introduce directional sprite variants if rotation visibly breaks the art style.

## Separate shadow

Existing source assets already use separate shadow treatment.

Recommended:

- shadow is its own sprite/node
- shadow remains visually attached to the ground
- unit rotation should not force the shadow lighting to rotate if that looks wrong

## Perspective scaling

Do **not** assume strong scale-by-Y.

The current unit artwork is closer to an orthographic/pseudo-isometric style.

Default:

- `visual_scale = 1.0`

Optional after visual testing:

- a very subtle scale range, e.g. roughly 0.95–1.0

Never scale collision/navigation radii just to create fake perspective.

If used, scale only the visual subtree.

---

# Attack behavior

Known source variables:

- `DamagePerShot`
- `AttackRate`

The attack can remain direct damage; a physical projectile actor is not required.

## `StartAttack`

Target behavior:

1. enter `ATTACKING`
2. stop movement/navigation velocity
3. start repeating attack timer
4. retain target/base reference if valid

## `AttackOnce`

1. verify Base still exists and combat is active
2. apply `DamagePerShot`
3. trigger shot VFX
4. wait for `AttackRate`

## VFX

Unreal used Niagara.

Godot may use:

- `GPUParticles2D`
- `AnimatedSprite2D`
- shader effects
- lightweight custom VFX

The migration only needs equivalent visible feedback.

## Base destruction

Enemies must stop attacking after Base destruction / battle end.

---

# Enemy defeat and reward

Known UE event:

- `OnEnemyDefeated`

Known reward flow:

`BP_Enemy.OnEnemyDefeated`
→ `GM_MainCamera.AddCoins(Reward)`

Known variable:

- `Reward`

Suggested Godot signal:

```gdscript
signal defeated(reward: int)
```

The GameManager should listen for this and update battle-earned coins.
