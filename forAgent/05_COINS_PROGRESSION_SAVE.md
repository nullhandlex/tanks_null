# Coins, Progression and Save System

## Global persistent state

The UE project stores persistent progression in `GI_TDGame` and `SG_TDGame`.

### `GI_TDGame`

Known variables:

- `TotalCoins : int`
- `CompletedLevels : int array`
- `UnlockedLevels : int array`

Default state when no save exists:

```text
TotalCoins = 0
CompletedLevels = []
UnlockedLevels = [1]
```

### `SG_TDGame`

Known saved fields:

- `TotalCoins`
- `CompletedLevels`
- `UnlockedLevels`

`SG_TDGame` is primarily a data container.

## Level-earned coins

The battle tracks coins earned during the current level separately from persistent `TotalCoins`.

Known flow:

`BP_Enemy.OnEnemyDefeated`
→ `GM_MainCamera.AddCoins(Reward)`

`Reward` belongs to the enemy.

## Win / Lose coin presentation

Canonical UI rule:

- Win widget displays coins earned for the current level
- Lose widget displays coins earned for the current level
- Main Menu displays global `TotalCoins`

Do not show global `TotalCoins` as the main reward value inside Win/Lose result UI.

## Reward claiming

Both Win and Lose result widgets have one primary button:

`Отримати коіни` / Get Coins

Known intended behavior:

1. take `CoinsEarnedForLevel`
2. apply any intended result multiplier
3. add final claimed amount to persistent `TotalCoins`
4. save progression
5. return to Main Menu

## Victory multiplier

A victory multiplier was planned / used in UI logic.

Important historical issue:

The multiplier initially affected only displayed UI reward and was not necessarily applied to the saved persistent amount.

Migration rule:

> Reward display and actually saved reward must use the same final calculated amount.

If a victory multiplier exists in the target implementation, calculate one `FinalReward` and use it for both UI and persistence.

## Defeat reward

Defeat can still award coins earned during the run.

Do not discard all level-earned coins simply because the player lost.

## Level completion

Known victory progression flow:

If `CompletedLevels` does not contain `CurrentLevelID`:

- add `CurrentLevelID`

Then:

`NextLevelID = CurrentLevelID + 1`

If `UnlockedLevels` does not contain `NextLevelID`:

- add `NextLevelID`

Then call/save progression.

## Save debugging

A print was used in `GI_TDGame.LoadOrCreateSave`:

`Loaded TotalCoins = ...`

This was used to confirm persistence.

Save files were sometimes manually deleted during testing to validate first-run behavior.

## Godot suggested data ownership

Use an Autoload singleton, for example:

`GameData.gd`

Suggested fields:

```gdscript
var total_coins: int = 0
var completed_levels: Array[int] = []
var unlocked_levels: Array[int] = [1]
```

Suggested responsibilities:

- load save on startup
- expose persistent values
- update progression
- save data

Do not make UI widgets themselves the authoritative owner of progression state.

## Suggested save format

Godot may use:

- JSON via `FileAccess`
- custom Resource
- another stable local save structure

The exact storage format is less important than preserving behavior.

## Safety against duplicate rewards

The target implementation should ensure the result reward is not claimed multiple times from repeated button presses or duplicate callbacks.

A simple guard is recommended:

- `reward_claimed: bool`

This is a Godot-side robustness recommendation, not a confirmed UE variable.
