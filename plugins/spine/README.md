# Spine plugin

Plays [Spine](https://esotericsoftware.com) skeletal animations with the `ceramic.Spine` visual.

```yaml
# ceramic.yml
app:
    plugins:
        - spine
```

Using the Spine Runtimes requires a Spine license: see the [Spine Runtimes License](https://esotericsoftware.com/spine-runtimes-license).

## Runtimes

The plugin works with two runtimes:

| Runtime | Spine data | Selected with |
|---|---|---|
| Official [spine-haxe](https://github.com/EsotericSoftware/spine-runtimes/tree/4.3/spine-haxe) runtime | 4.3 | default |
| spine-hx (converted from the libGDX runtime) | 4.0 (and older 3.x exports) | `spine_legacy` define |

```yaml
# ceramic.yml: keep using Spine 4.0 data with the legacy runtime
app:
    defines:
        - spine_legacy
```

Skeleton data must be exported for the version of the runtime in use. With the default runtime, data exported for another Spine version is rejected with an explicit error: export it again with Spine 4.3 (`spine.version` in `ceramic.yml` for `ceramic spine export`), or add the `spine_legacy` define. Data of another version would otherwise load partially: Spine 4.3 changed how constraints are stored.

The legacy runtime renders exactly as before the official runtime was added.

## Data

A spine asset is a folder named `<name>.spine` in the assets, holding:

- the skeleton data: a JSON export (`.json`), or with the default runtime, a binary export (`.skel`) when there is no JSON;
- the texture atlas (`.atlas`) and its pages (`.png`).

Export atlases **without premultiplied alpha**: Ceramic premultiplies images itself, a page exported with premultiplied alpha would be premultiplied twice (dark edges). A warning is logged when such a page is loaded.

Animation name constants (`Spines.HERO.WALK`...) are generated from the JSON export. A binary only export has no generated animation constants: use animation names as strings.

## Features of the default runtime

- **Physics constraints** are updated with the elapsed time. A skeleton with physics constraints is never frozen automatically (it keeps moving after its animations end).
- **Sequences** (frame by frame attachments), **sliders**, multiple atlas pages.
- **Blend modes**: normal, additive, multiply and screen (`Blending.MULTIPLY`, `Blending.SCREEN`). With the legacy runtime, multiply and screen are rendered as normal.
- **Clipping**, with two modes (`spine.clipping`, or `Spine.defaultClipping` for all instances):
  - `SOFTWARE` (default): geometry is clipped on the CPU, as official renderers do. Clipped slots stay inside visuals that are themselves clipped (`clip` of a parent), keep draw batching, and inverse clipping is supported.
  - `STENCIL`: geometry is clipped by the GPU with the stencil buffer (the only mode of the legacy runtime). No CPU cost per clipped triangle, but a clipped slot ignores the `clip` of its parents and breaks draw batching. Inverse clipping uses an inverted clip (`Visual.clipInverted`).

## Migrating code from the legacy runtime

The Ceramic API (`Spine`, `SpineData`, `SpineAsset`, `SpineMontage`, `SpineBindVisual`, `SpineColors`, slot callbacks, slot binding, hidden/visible/disabled slots, hit tests...) is the same with both runtimes.

Code that uses the spine runtime directly (`spine.skeleton`, `spine.state`, `SlotInfo.slot`, `spineEvent` handlers...) uses the types of the runtime in use. Main differences with Spine 4.3:

| Spine 4.0 (legacy) | Spine 4.3 |
|---|---|
| `slot.color`, `slot.darkColor`, `slot.attachment` | `slot.appliedPose.color`, `.darkColor`, `.attachment` |
| `bone.worldX`, `bone.a`... | `bone.appliedPose.worldX`, `bone.appliedPose.a`... |
| `skeleton.drawOrder` | `skeleton.drawOrder.appliedPose` |
| `skeleton.setSkin(skin)`, `setSlotsToSetupPose()` | `skeleton.skin = skin`, `setupPoseSlots()` |
| `state.getCurrent(track)` | `state.getTrack(track)` |
| `entry.setTrackTime(t)` | `entry.trackTime = t` |
| `event.getData().name` | `event.data.name` |
| `spine.AnimationState`, `spine.Animation` | `spine.animation.AnimationState`, `spine.animation.Animation` |

`ceramic.SpineRuntime` gives the same access with both runtimes (`SpineRuntime.slotColor(slot)`, `SpineRuntime.boneWorldX(bone)`, `SpineRuntime.currentTrack(state, 0)`...), with no runtime cost (inline).

## Spine runtime used

The default runtime comes from the `ceramic` branch of [ceramic-engine/spine-runtimes](https://github.com/ceramic-engine/spine-runtimes), a fork of the official repository with fixes of spine-haxe (performance and correctness), meant to be proposed upstream.

## Known limitations

- Unity (C# target): spine-haxe does not compile for C#, use `spine_legacy`.
- Concave clipping polygons may draw outside of the clipping area with `SOFTWARE` clipping: use convex clipping attachments, or `STENCIL` clipping.
