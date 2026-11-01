// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * These effects are processed at the end of each application update cycle.
 *
 * Releases are not in this queue: like GPUI's `release_dropped_entities`,
 * destroyed entities are released at the start of each iteration of
 * `App.flushEffects`, before the next effect.
 */
enum Effect {

    Notify(emitter:Int);

    Emit(emitter:Int, event:Dynamic);

    RefreshWindows;

    NotifyGlobalObservers(globalType:Int);

    Defer(callback:App->Void);

    EntityCreated(entity:Model, typeId:Int);

}
