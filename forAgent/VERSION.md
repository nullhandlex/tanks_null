# Migration Knowledge Base Version

Current version: **v2**

Major v2 decisions:

- Godot target changed from optional 2D/3D to **canonical pure 2D**
- visual style defined as **2.5D / pseudo-isometric / tilted top-down**
- existing unit sprites should be preserved
- backgrounds may be repainted to match unit perspective
- source linear X/Y enemy movement is legacy only
- target enemy movement uses `NavigationAgent2D`
- attack uses range/target logic rather than `StopX`
- sprite rotation is tested before creating directional variants
- shadows remain separate
- strong Y-based perspective scaling is not a default requirement
- navigation/collisions are kept separate from painted backgrounds
