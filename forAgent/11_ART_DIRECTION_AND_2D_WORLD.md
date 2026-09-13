# Art Direction and 2D World

This document records the approved visual direction for the Godot migration.

---

# Canonical visual target

The Godot version should be a **pure 2D game that visually reads as 2.5D / pseudo-isometric / tilted top-down**.

The Unreal source used a 3D scene and an angled camera, but most actual visible game assets are flat 2D images.

Therefore the Godot port should not recreate a 3D world solely for camera perspective.

Instead, the illusion of depth should be baked into:

- background artwork
- existing unit sprite perspective
- shadows
- draw order
- overlap
- optional subtle visual scaling
- 2D VFX

---

# Existing unit assets

Existing enemy/unit artwork should be preserved.

Example source assets are already:

- top-down / pseudo-isometric
- shaded
- volumetric-looking
- designed to sit on a ground plane
- suitable for `Sprite2D`

Default migration rule:

> Do not redraw unit assets unless testing proves a specific asset cannot work in the new 2D presentation.

## Import workflow

If original source files exist as:

- PNG
- WebP
- JPG/JPEG
- TGA
- SVG

copy/import them directly into the Godot project.

Suggested structure:

```text
res://assets/
├── enemies/
├── base/
├── backgrounds/
├── shadows/
├── effects/
└── ui/
```

If an image exists only inside Unreal as a `.uasset`, export it from Unreal into a normal image format first.

Do not attempt to parse or migrate the `.uasset` image directly as the final asset pipeline.

---

# Unit direction and rotation

The new navigation system means enemies can move along non-linear paths.

Therefore a unit may need to face different movement directions.

## First implementation to test

Use the existing sprite and rotate it toward movement direction.

Example:

```gdscript
var direction := velocity.normalized()

if direction.length_squared() > 0.0:
    unit_sprite.rotation = direction.angle() + sprite_angle_offset
```

This must be tested visually before producing directional sprite variants.

## Fallback

Only if full sprite rotation looks visually wrong:

- create 4-direction sprites
- or 8-direction sprites
- or directional animation sets

Do not assume these are needed in advance.

---

# Shadows

The source game already uses separate shadow treatment.

Preserve this concept.

Suggested hierarchy:

```text
VisualRoot
├── ShadowSprite
└── UnitSprite
```

Benefits:

- shadow can stay oriented to the ground
- unit can rotate independently
- shadow opacity/scale can be tuned separately
- visual depth is preserved without 3D lighting

For many assets, a soft oval/painted shadow is sufficient.

---

# Background direction

The current background layout is useful as a **gameplay/layout reference**, but the final background may be redrawn/reworked to better match the existing unit perspective.

Important:

Do not introduce strong photographic perspective.

The existing unit art is closer to:

- orthographic
- mild pseudo-isometric
- tilted top-down

Therefore the background should use a similar mild perspective.

## Keep the current layout where practical

Preserve:

- routes
- obstacle locations
- large landmarks
- spawn-side composition
- Base-side composition
- general map readability

The purpose of repainting is visual integration, not random redesign of gameplay.

## Improve visual depth with art

Possible improvements:

- clearer top and side faces on walls/ruins
- consistent object thickness
- consistent lighting direction
- matching cast/contact shadows
- stronger separation of walkable roads from blocked ruins
- larger/more detailed foreground elements where appropriate
- controlled overlap

Avoid extreme vanishing-point convergence.

---

# Perspective scaling

Do not make scale-by-Y a required mechanic.

Default:

```text
all unit visual scales remain constant
```

If a live test shows that a tiny amount helps:

```text
far/top visual scale ≈ 0.95
near/bottom visual scale ≈ 1.00
```

This is only an example, not a fixed rule.

Apply perspective scale only to:

- visual nodes

Do not automatically scale:

- `CollisionShape2D`
- navigation agent radius
- attack range
- gameplay coordinates

---

# Y sorting / draw order

Use draw ordering only where it improves the illusion of depth.

Possible techniques:

- `y_sort_enabled`
- controlled `z_index`
- separate world layers

Typical goal:

An object lower on the screen may render in front of an object higher on the screen.

However, large background elements that never need to overlap units can remain baked into the background image.

---

# Background vs gameplay data

The background image is **not** collision/navigation data.

Canonical structure:

```text
Visible:
    background image

Invisible gameplay:
    NavigationRegion2D
    obstacle polygons
    collision shapes
    spawn markers
    Base target / attack area
```

This means the background can be repainted or replaced without changing the core gameplay systems.

---

# Navigation art workflow

Recommended workflow per level:

1. Import/use existing background as temporary prototype art.
2. Build `NavigationRegion2D`.
3. Mark non-walkable obstacles.
4. Add Base target/attack region.
5. Add spawners.
6. Run real enemies through the level.
7. Confirm pathfinding and attack behavior.
8. Test unit sprite rotations.
9. Repaint/finalize background to match the unit art.
10. Swap final background without changing navigation unless gameplay geometry changed.

This prevents art production from blocking gameplay migration.

---

# Lighting consistency

Because lighting is painted into the sprites, the final background should use a compatible light direction.

Do not create a background whose highlights/shadows strongly contradict the existing unit sprites.

Exact physical correctness is less important than stylistic consistency.

---

# Reference philosophy for AI agents

When modifying visual presentation:

1. preserve existing unit assets
2. use the unit art as the style/perspective reference
3. adapt/repaint the background before demanding unit redraws
4. keep navigation independent from art
5. test in motion before creating additional directional assets
6. favor a clean stylized mobile-game look over physically correct perspective
