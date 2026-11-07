// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * This is provided when subscribing for `Context.onFocusOut` events.
 * Rust gives a `WeakFocusHandle`: here the id of the blurred handle.
 */
class FocusOutEvent {

    /**
     * The id of the focus handle that was blurred.
     */
    public final blurredId:Int;

    public function new(blurredId:Int) {
        this.blurredId = blurredId;
    }

}
