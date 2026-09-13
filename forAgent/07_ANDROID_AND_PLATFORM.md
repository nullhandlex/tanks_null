# Android and Platform Notes

## Target

- Android
- Portrait
- 1080 × 1920 design resolution
- 9:16
- mobile performance is a priority

## Unreal platform history

The project had previous Android deployment/debugging issues.

### Long launch / black screen

Investigation included:

- verify correct Game Default Map
- include required maps in packaged build
- ensure camera is selected on startup
- verify content/materials/lights
- inspect logcat
- use Development build while debugging
- use arm64

Potential Unreal-side mitigations discussed included:

- avoid Android File Server / cook-on-the-fly dependency for normal packaged tests
- package data correctly
- test OpenGL ES 3.1 if Vulkan causes device-specific issues
- disable unnecessary plugins
- test Mobile HDR settings

These are Unreal-specific diagnostics and do not need to be copied literally into Godot.

## APK installation issue seen historically

One APK installation failure was:

`INSTALL_FAILED_VERIFICATION_FAILURE`

This came from Android package verification / Play Protect behavior, not from the Unreal compile itself.

## Device-specific startup issue with native services

After external C++ services were integrated, the game:

- worked in editor
- started on one Android device
- failed to start on another device

The suspected cause was related to the connected native services or device compatibility/load rather than graphics alone.

This remains relevant when those services are migrated.

## Godot migration requirements

The Godot project should be tested early on Android, not only at the end.

Recommended checkpoints:

1. empty Godot project launches on target device
2. camera + level launches
3. Base + Enemy prototype launches
4. full wave loop launches
5. persistence works
6. external/native services are added last and tested one by one

## Mobile performance principles

- avoid unnecessary per-frame logic
- use timers/signals where appropriate
- keep enemy behavior simple
- reuse/shared resources
- avoid excessive allocations during combat
- avoid overly expensive 3D/VFX features
- test on weaker target devices

## Orientation

Godot project settings should be configured for portrait orientation.

UI should adapt to different phone aspect/safe-area conditions while preserving the 9:16 intended layout.


## Approved 2D renderer direction

The Godot migration should be pure 2D unless a later mechanic proves that real 3D is necessary.

This is expected to simplify the Android build because the game can use:

- `Sprite2D`
- 2D navigation
- 2D collisions
- 2D particles
- `Control` UI

The game should not carry a 3D scene/camera stack only to reproduce the old Unreal viewing angle.

Performance testing must still include realistic:

- enemy counts
- `NavigationAgent2D` usage
- avoidance settings
- particles
- large background textures

Navigation avoidance should be tuned rather than enabled at maximum complexity by default.
