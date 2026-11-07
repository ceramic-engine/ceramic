// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Marks views of a window dirty. Registered per entity on `App` with
 * `App.addWindowInvalidator` (GPUI's `window_invalidators_by_entity`), so that
 * `cx.notify()` and tracker reactions reach the windows displaying the entity
 * (the entities each window accessed during its last draw).
 * Implemented by `Window` (step 7).
 */
interface WindowInvalidator {

    /**
     * Marks the view of the given entity dirty. Returns `false` while the
     * window draws (Rust `invalidate_view`): `App.notify` then pushes no
     * `Notify` effect for this window.
     */
    function invalidateView(entityId:Int, cx:App):Bool;

}
