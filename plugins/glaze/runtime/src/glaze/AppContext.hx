// Ported from gpui-pre 0.3.10: src/gpui.rs (AppContext trait)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Anything that gives access to the `App`: an `App` (or `AsyncApp`) or a
 * `Context<T>`. Used by `Entity` and `WeakEntity` methods taking `cx`.
 */
@:forward
abstract AppContext(App) from App to App {

    @:from static inline function fromContext(cx:EntitySlot):AppContext {
        return cast cx.app;
    }

}
