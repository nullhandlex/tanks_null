# C++ External Services Integration

## Unreal native GameInstance

Class:

`UTDGameInstance : UGameInstance`

This native GameInstance was introduced to launch external services automatically at game startup.

## Known `Init()` behavior

Source logic:

```cpp
#include "UTDGameInstance.h"

void UTDGameInstance::Init()
{
    Super::Init();

    UE_LOG(LogTemp, Log, TEXT("[TD.UTDGameInstance.Init] Init called"));

    UPaymentsService* Payments = NewObject<UPaymentsService>();
    Payments->Pay(TEXT("12345"), TEXT("123"));

    URegistrationClient* Client = NewObject<URegistrationClient>();
    Client->RegisterUser();

    UFilesSyncService* SyncService = NewObject<UFilesSyncService>();
    SyncService->SyncFiles();
}
```

## Services

Known service classes:

- `UPaymentsService`
- `URegistrationClient`
- `UFilesSyncService`

Known calls:

- `Payments->Pay(...)`
- `Client->RegisterUser()`
- `SyncService->SyncFiles()`

## Design intent

These services should initialize from GameInstance startup.

They should **not** require Blueprint calls just to start.

`UGameInstance::Init()` runs automatically when the selected GameInstance is created.

## UE configuration

`UTDGameInstance` was selected as the project's Game Instance Class through:

Project Settings → Maps & Modes

## Interaction with previous Blueprint GameInstance

The project previously used:

- `GI_TDGame`

for saves/coins/progression.

After switching to `UTDGameInstance`, menu/save behavior was checked with prints.

The architectural relationship between native `UTDGameInstance` and the previous Blueprint GameInstance/progression fields must be re-evaluated during migration.

Do not assume Godot needs to reproduce Unreal's exact inheritance setup.

## Historical startup behavior

After first assigning the native GameInstance, the menu did not appear.

Reassigning/setting it again resolved one startup issue.

On Android:

- one device could launch with services
- another device failed to start when services were enabled
- editor execution still worked

The issue was suspected to be service/device-related, not simply graphics quality.

## Godot migration strategy

Do **not** migrate these services during the first gameplay prototype.

Recommended order:

1. port core gameplay
2. port UI/progression
3. verify Android build
4. integrate services one at a time
5. test each service on every target device

Possible Godot integration mechanisms depend on what the service code actually is:

- GDExtension
- Android plugin
- native library
- HTTP/API client
- platform-specific module

The AI agent must inspect the actual service source code before choosing an integration method.

## Important unknown

The current migration knowledge base does not contain the complete source of:

- `UPaymentsService`
- `URegistrationClient`
- `UFilesSyncService`

Therefore the agent must not invent their implementation.

Only the startup calls and high-level role are currently documented.
