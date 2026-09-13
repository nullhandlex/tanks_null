# UI and Level Flow

## Main Menu

Widget:

- `W_MainMenu`

The Main Menu exists on a separate level.

Known page index mapping:

- `0 = BattlePage`
- `1 = SettingsPage`
- `2 = BasePage`
- `3 = WalletPage`

## Main Menu coins

On menu construction/start, UI reads persistent:

- `GI_TDGame.TotalCoins`

It displays:

`Coins: X`

Canonical rule:

> Persistent TotalCoins belong in Main Menu. Result screens primarily show coins earned for that battle.

## Mouse / pointer

On the Main Menu level, mouse cursor was enabled using the PlayerController.

For Godot desktop testing, normal mouse input is fine.

For Android target, UI must remain touch-friendly.

## Battle HUD

An older battle-start HUD creation path was removed.

After removing it, some errors appeared in `StartWave` / `GM_GetEnemyClass`, which were fixed using validity checks.

Migration lesson:

Do not let wave logic assume an unrelated HUD reference always exists.

Keep gameplay state independent from optional UI references.

## Base HP UI

Widget:

- `W_BaseHealth`

Known component relation:

- base has a WidgetComponent with HP bar

Known bar:

- `HP_Bar`

Known function:

- `UpdateHP(NewHP, MaxHP)`

Correct normalized percentage:

`Clamp(NewHP / MaxHP, 0..1)`

## Win / Lose

There are separate Win and Lose result widgets.

Both use a single main button:

- `Отримати коіни`

Button behavior:

1. claim/save coins
2. save relevant progression
3. open Main Menu level

## Victory

Victory happens after the final wave has completed.

A separate Win widget is shown.

Victory flow should not be conflated with base-destruction defeat logic.

## Defeat

Defeat occurs when base HP reaches zero.

Spawner/enemy combat logic is stopped.

Lose widget is shown.

## Start button

Main Menu has a Start button implemented as Button + Image.

Visual style/animations were planned separately.

No migration-critical behavior depends on the exact Unreal styling.

## Mobile layout issue discovered

A UI issue occurred where the `TotalCoins` text shifted upward on device compared with editor.

The layout was corrected using proper anchors / ScaleBox-style responsive layout.

Migration rule:

> Do not rely on fixed desktop/editor pixel placement.

Godot UI should use:

- anchors
- containers
- size flags
- stretch/aspect settings
- 9:16 test resolutions

## Godot UI recommendation

Suggested hierarchy:

```text
MainMenu
├── PageContainer
│   ├── BattlePage
│   ├── SettingsPage
│   ├── BasePage
│   └── WalletPage
└── PersistentCurrencyHUD
```

Battle:

```text
BattleUI
├── BaseHealth
├── WaveInfo
└── LevelCoins
```

Results:

```text
WinScreen
LoseScreen
```

Use Godot `Control` nodes and containers rather than manually positioning everything.


## 2D world/UI separation

In the Godot target, battle world content is pure 2D.

Keep UI in a separate `CanvasLayer` / `Control` hierarchy so:

- Y sorting affects world sprites only
- fake perspective does not distort HUD
- responsive portrait UI remains independent from world transforms
