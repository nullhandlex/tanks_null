# Migration Checklist

## Phase 0 — Project bootstrap

- [ ] Create Godot 4.x project
- [ ] Configure portrait orientation
- [ ] Configure 1080 × 1920 design resolution
- [ ] Configure stretch/aspect behavior
- [ ] Confirm project is pure 2D
- [ ] Create repository folder structure
- [ ] Add `AGENTS.md`
- [ ] Configure Cursor/Claude Code project access
- [ ] Configure Godot MCP if used
- [ ] Confirm empty project launches on Android

## Phase 1 — Asset smoke test

- [ ] Import the current level background
- [ ] Import one real enemy PNG
- [ ] Import/use its separate shadow if available
- [ ] Verify transparency/import settings
- [ ] Verify sprite scale/pivot
- [ ] Create temporary `Sprite2D` enemy scene
- [ ] Test the existing art in Godot without redrawing it

## Phase 2 — Battle skeleton

- [ ] Create `BattleLevel.tscn` as `Node2D`
- [ ] Add `Camera2D`
- [ ] Add current background as temporary prototype art
- [ ] Add `NavigationRegion2D`
- [ ] Define initial walkable region
- [ ] Add obstacle/non-walkable areas
- [ ] Add Base placeholder
- [ ] Add one `Marker2D` spawn point
- [ ] Confirm 9:16 framing

## Phase 3 — Base

- [ ] Create `Base.tscn`
- [ ] Add `max_hp`
- [ ] Initialize HP
- [ ] Add `apply_damage`
- [ ] Add `health_changed` signal
- [ ] Add `destroyed` signal
- [ ] Create Base attack target / attack area
- [ ] Create HP UI
- [ ] Confirm HP percent = current / max
- [ ] Confirm defeat event at zero HP

## Phase 4 — EnemyBase navigation

- [ ] Create `EnemyBase.tscn` as `CharacterBody2D`
- [ ] Add `VisualRoot`
- [ ] Add `UnitSprite`
- [ ] Add separate `ShadowSprite`
- [ ] Add `CollisionShape2D`
- [ ] Add `NavigationAgent2D`
- [ ] Add `move_speed`
- [ ] Add Base target assignment
- [ ] Set navigation target position
- [ ] Follow navigation path
- [ ] Confirm obstacle routing
- [ ] Add explicit MOVING state
- [ ] Stop at attack range
- [ ] Do not implement old `StopX` as the final target system

## Phase 5 — Sprite direction test

- [ ] Determine sprite's forward-angle offset
- [ ] Rotate unit visual toward movement direction
- [ ] Keep shadow visually grounded
- [ ] Test 45° turns
- [ ] Test 90° turns
- [ ] Test 180° turns
- [ ] Decide whether simple rotation is acceptable
- [ ] Only create 4/8-direction art if rotation is visibly unacceptable

## Phase 6 — Avoidance and crowd movement

- [ ] Test several enemies on the same route
- [ ] Decide whether avoidance is required
- [ ] If used, configure avoidance conservatively
- [ ] Prevent severe unit stacking
- [ ] Test realistic enemy count on Android
- [ ] Avoid expensive avoidance settings without evidence

## Phase 7 — Attack

- [ ] Add `DamagePerShot`
- [ ] Add `AttackRate`
- [ ] Add `attack_range`
- [ ] Add ATTACKING state
- [ ] Stop navigation movement during attack
- [ ] Add repeating attack timer
- [ ] Validate Base before damage
- [ ] Apply direct damage
- [ ] Stop attacking after Base destruction
- [ ] Add placeholder 2D shot VFX

## Phase 8 — Enemy defeat/reward

- [ ] Add enemy HP if required by source gameplay
- [ ] Add `Reward`
- [ ] Add DEAD state
- [ ] Emit `defeated(reward)`
- [ ] Add battle-earned coins to GameManager
- [ ] Confirm defeated enemies are removed cleanly

## Phase 9 — Spawner

- [ ] Create `EnemySpawner.tscn` as `Node2D`
- [ ] Add local `enemy_queue`
- [ ] Add queue insertion API
- [ ] Spawn first queued enemy
- [ ] Remove/advance queue
- [ ] Empty queue does nothing
- [ ] Spawner never chooses wave composition itself
- [ ] Add valid navigation-safe spawn variation if desired
- [ ] Assign Base/navigation target to spawned enemies

## Phase 10 — Waves

- [ ] Implement current wave index
- [ ] Implement `StartWave` equivalent
- [ ] Implement transition state
- [ ] Build enemy queues in GameManager
- [ ] Distribute enemies to multiple spawners
- [ ] Confirm final queue item is handled correctly
- [ ] Detect actual wave completion
- [ ] Do not treat inter-wave empty queue as victory
- [ ] Detect final-wave victory

## Phase 11 — Lose / Win

- [ ] Defeat when Base reaches zero
- [ ] Stop spawners on defeat
- [ ] Stop enemy navigation/attacks on defeat
- [ ] Show Lose screen
- [ ] Show Win screen after final wave
- [ ] Keep victory and defeat state separate

## Phase 12 — Coins

- [ ] Track `CoinsEarnedForLevel`
- [ ] Reward coins per enemy
- [ ] Lose can retain earned coins
- [ ] Implement optional win multiplier
- [ ] Calculate one `FinalReward`
- [ ] Display and save identical `FinalReward`
- [ ] Prevent duplicate reward claims

## Phase 13 — Persistent progression

- [ ] Create `GameData.gd` Autoload
- [ ] `total_coins = 0`
- [ ] `completed_levels = []`
- [ ] `unlocked_levels = [1]`
- [ ] Implement load
- [ ] Implement save
- [ ] Add completed level only once
- [ ] Unlock next level only once
- [ ] Verify save after app restart

## Phase 14 — Main Menu

- [ ] Create separate `MainMenu.tscn`
- [ ] Show persistent TotalCoins
- [ ] Create BattlePage
- [ ] Create SettingsPage
- [ ] Create BasePage
- [ ] Create WalletPage
- [ ] Preserve intended page ordering
- [ ] Add Start flow to battle
- [ ] Result button returns to Main Menu
- [ ] Test responsive layout on phone

## Phase 15 — Enemy variants

- [ ] Create EnemyTank
- [ ] Create EnemyFast
- [ ] Create EnemyBoss
- [ ] Reuse existing source sprites
- [ ] Move shared behavior into EnemyBase
- [ ] Override stats/visuals only where practical
- [ ] Confirm each asset rotates/animates acceptably

## Phase 16 — Final background/art pass

- [ ] Keep the source level layout as reference
- [ ] Repaint/rework background to match unit perspective
- [ ] Use mild pseudo-isometric / tilted top-down perspective
- [ ] Avoid strong vanishing-point perspective
- [ ] Match light/shadow direction to unit art
- [ ] Improve wall/ruin thickness and side faces
- [ ] Preserve path readability
- [ ] Keep final background separate from navigation
- [ ] Replace prototype background without breaking gameplay
- [ ] Evaluate Y sorting
- [ ] Evaluate subtle visual-only scale-by-Y
- [ ] Keep scale constant if subtle scaling does not improve the result

## Phase 17 — Android validation

- [ ] Test startup on target Android device
- [ ] Test on weaker secondary device
- [ ] Test realistic navigation agent count
- [ ] Test avoidance cost
- [ ] Test battle performance
- [ ] Test large background texture memory
- [ ] Test particles
- [ ] Test menu
- [ ] Test save persistence
- [ ] Test orientation
- [ ] Test touch input
- [ ] Test app restart

## Phase 18 — Native/external services

- [ ] Inspect actual service source/API
- [ ] Determine Godot integration method
- [ ] Port payment service separately
- [ ] Test Android startup
- [ ] Port registration service separately
- [ ] Test Android startup
- [ ] Port file-sync service separately
- [ ] Test Android startup
- [ ] Do not enable all services at once during initial debugging

## Final validation

- [ ] Project remains pure 2D unless a documented exception was approved
- [ ] Existing unit art was preserved where practical
- [ ] No known fixed bug has returned
- [ ] Full level can start
- [ ] navigation works around obstacles
- [ ] enemies reach and attack Base
- [ ] Base can lose
- [ ] final wave can win
- [ ] rewards are correct
- [ ] progress persists
- [ ] Main Menu reflects saved state
- [ ] final background visually matches the unit art
- [ ] Android build behaves consistently
