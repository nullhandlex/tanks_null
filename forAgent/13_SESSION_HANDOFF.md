# Session handoff — Cursor chats → Codex

Distilled from the long Cursor Agent thread on this repo (not a raw transcript dump). Treat this as current product truth when it conflicts with older Unreal-oriented notes in `06_UI_AND_LEVEL_FLOW.md`.

Cursor transcript (human-only): [TD Cursor session](4d856206-3fb5-42d2-a917-448fb0bcc498).

Last distilled: 2026-09-12.

## Repo and tools

- GitHub: https://github.com/I551188/TD (private), branch `main`
- Godot **4.7.2** in `tools/godot/` (Git LFS)
- Autoloads: `GameData`, `GameManager`
- Package: `org.projectx.td`, version `0.1.0`
- Owner speaks Ukrainian; in-game UI copy is Russian
- Windows PowerShell: no `&&`, no bash heredocs
- Do not commit unless asked. Do not force-push `main` unless the user explicitly wants a history rewrite

### Git notes (do not revive)

- User logo/icon work: `6b36e2e`
- Dropped gerry cannon-shot commit `81889bd`; kept crater work via cherry-pick `8e65dd7` onto `6b36e2e` → `6736059`, force-with-lease to `origin/main`
- Account screen + Android 8–9 preset: `feea204`
- If another clone still has `81889bd` on `main`: `git fetch` then `git reset --hard origin/main`

Archived Android 8–9 build: `export/android/TD-debug-api26.apk` (built 2026-09-11, stored in Git LFS). It predates the death VFX and header-avatar fixes below.

## What is already in the game

- Boot: `scenes/boot/LoadScreen.tscn` → main menu (no long splash of the app icon)
- Main menu: arena select, settings, account
- Battle: waves, `NavigationRegion2D` + `NavigationAgent2D` to Base, Base HP, energy + ults (machine gun / mortar)
- Pause: music / vibro / SFX toggles, quit to menu
- Win / lose result screens
- Save: `GameData` → `user://savegame.json` (coins, levels, profile fields, sound toggles)

## Architecture (canonical)

| Owner | Owns |
| --- | --- |
| `GameManager` | battle flow, waves, spawner queues, battle coins, victory/defeat, energy |
| `GameData` | persistent coins, levels, profile, settings, load/save |
| `EnemySpawner` | spawn only from the queue it was given; do nothing if empty |
| `EnemyBase` | nav, attack range, state, damage, death/reward, facing |
| `Base` | HP and damage; exposes an attack target. UI observes HP, does not own it |

Enemy states: `SPAWNING` → `MOVING` → `ATTACKING` → `DEAD`. Enemies must not move while attacking and must not attack a destroyed Base.

Victory must not trigger merely because a queue is temporarily empty.

## Account screen (easy to regress)

Figma node `262:704` in file `mFCEuX1NOJiDpDOtqYQPaH`.

Implemented in `scenes/ui/MainMenu.tscn`, `scripts/ui/main_menu.gd`, `AccountField.tscn`, `account_field.gd`.

- **Do not add a header or bottom tabs** on the account page
- Default avatar stub = same header knight (`ellipse_fill.svg` + `soldier.svg`), **not** the Figma stock photo
- Plus icon: `assets/ui/figma_account/plus.svg` (50×50)
- Fields are fillable; placeholders stay empty until the user types
- Right-hand preview (name / age / email / phone) stays empty until **Сохранить**
- **Назад** discards drafts (does not save)
- Saved name replaces header «Зарегистрироваться» (`MenuHeader`)
- Tap avatar → native file picker → copy to `user://avatar.png`, persist immediately in `GameData`
- Uploaded photo clip: `shaders/ui/rounded_rect_clip.gdshader` (346×330, r32)
- Header photo: `HeaderAvatar` uses `KEEP_ASPECT_COVERED` and `circle_clip_local.gdshader` in a 142×142 box. Keep the mask in local coordinates; masking texture UVs made rectangular photos look oval. Photos fill the circle proportionally with centered cropping.
- Probe: `tools/tests/account_menu_probe.gd`

`GameData` profile fields: `player_name`, `player_email`, `player_phone`, `player_age`, `player_avatar_path`. Ignore leftover names `зарегистрироваться` / `нужно ввести данные`.

## Logo / icon

User asset `TD_assets/UI/logo.png` was resized and used as the **app icon only**.

- Do **not** put the logo on the main menu (user rejected that)
- `assets/ui/logo.png` 512 → `project.godot` `config/icon`
- `logo_192.png` / `logo_432.png` + `logo_bg_432.png` for Android launcher / adaptive
- Flattened onto slate `(55, 71, 79)`

## Figma → Godot UI

- File: `mFCEuX1NOJiDpDOtqYQPaH`
- MCP CSS **drops text stroke**. Default Figma text: Stroke Outside **3px**, black **25%**
- Godot: `outline_size = 12` (¼-pixel units: `3px × 4`), `outline_color = Color(0, 0, 0, 0.25)`
- Reuse `res://resources/ui/label_heading.tres` (64 white) and `res://resources/ui/label_stat.tres` (40 `#F6EFC3`)
- IBM Plex Mono **must** be MSDF (`multichannel_signed_distance_field=true`, `msdf_pixel_range=16`, `msdf_size=64`). Raster outlines turn 25% alpha into a solid black halo
- Also imported: `IBMPlexMono-Medium.ttf`, `IBMPlexMono-LightItalic.ttf` (MSDF)

## Android

| Preset | Path | minSdk | ABI |
| --- | --- | --- | --- |
| Android (runnable) | `export/android/TD-debug.apk` | 29 | arm64-v8a |
| Android 8-9 | `export/android/TD-debug-api26.apk` | 26 | arm64-v8a + armeabi-v7a |

- `project.godot`: `renderer/fallback_to_opengl3=true`
- Both presets: gallery permissions `read_external_storage`, `read_media_images`, `read_media_visual_user_selected`
- JAVA_HOME: `C:\Program Files\Java\jdk-17`
- Export often hangs after `[ DONE ] export`; kill hung Godot; the APK can still be valid
- Test device: Blackview BV6600, serial `BV6600EEA0022703`
- Launch: `adb shell monkey -p org.projectx.td -c android.intent.category.LAUNCHER 1`

## Art / world

- Existing unit sprites are approved. Do not redraw them unless rotation clearly fails
- Painted background is not navigation data. Keep visual, nav region, obstacles, spawn markers, and Base attack region separate
- Prefer mild pseudo-isometric / tilted top-down, separate shadows, Y-sort. No 3D scene just for camera tilt

## Death effects and ground marks (Codex, 2026-09-12)

- `EnemyBase.death_style` selects one of ten `UnitDeathVfx.Style` profiles. `death_effect_scale` tunes size independently of the decal and weapon style.
- Soldier death uses red droplets and a brief blood mist, with no fire/metal explosion. Its ground mark is a dark blood pool with scattered drops (three variants).
- Vehicles use flash, fire, rising smoke, flying fragments and ground dust. Cars have sootier smoke; light weapon units scatter more fragments; mines throw more dirt; heavy units have larger blasts. TOS, Dora and Anigil have secondary detonations.
- `CombatVfx.spawn_explosion` still defaults to `GENERIC` for projectile/ultimate impacts. Do not infer death style from projectile style or `explosion_tint`.
- `GroundCrater` uses `assets/effects/crater.svg`: 10 profiles × 3 variants, 5 columns × 6 rows. Rebuild with `python tools/asset_pipeline/make_crater_atlas.py`; infantry generates blood, vehicles generate earth/scorch/debris.
- Ground marks hold for about 14 seconds, then fade over 7 seconds. Lifetimes and secondary bursts pause with gameplay and cancel on scene teardown. Caps: 80 ground marks, 32 explosion effects.
- Validation: `tools/tests/unit_death_vfx_probe.gd`, `crater_decal_probe.gd`, `ult_energy_probe.gd`. Death probe also supports `-- --capture` with a graphical Godot run; captures go to ignored `tools/asset_pipeline/_preview/unit_deaths/`.
- Checked in Windows Godot 4.7.2 with Mobile/Vulkan. Android APKs have not been rebuilt for these VFX changes.

## Still out of scope

Do not invent implementations for:

- payment service
- registration service
- file-sync service

until their source/API exists (`forAgent/08_CPP_EXTERNAL_SERVICES.md`).
