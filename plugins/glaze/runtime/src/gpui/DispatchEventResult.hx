// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The result of `Window.dispatchEvent`: whether the event should go on to
 * the platform, and whether its default behavior was prevented.
 */
class DispatchEventResult {

    /** Whether the event should continue to the platform (not handled) */
    public final propagate:Bool;

    /** Whether a handler called `window.preventDefault()` */
    public final defaultPrevented:Bool;

    public function new(propagate:Bool, defaultPrevented:Bool) {
        this.propagate = propagate;
        this.defaultPrevented = defaultPrevented;
    }

}
