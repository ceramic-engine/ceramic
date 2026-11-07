// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Represents the two different phases when dispatching events.
 */
enum abstract DispatchPhase(Int) {

    /**
     * After the capture phase comes the bubble phase, in which mouse event listeners are
     * invoked front to back and keyboard event listeners are invoked from the focused element
     * to the root of the element tree. This is the phase you'll most commonly want to use when
     * registering event listeners.
     */
    var Bubble = 0;

    /**
     * During the initial capture phase, mouse event listeners are invoked back to front, and keyboard
     * listeners are invoked from the root of the tree downward toward the focused element. This phase
     * is used for special purposes such as clearing the "pressed" state for click events. If
     * you stop event propagation during this phase, you need to know what you're doing. Handlers
     * outside of the immediate region may rely on detecting non-local events during this phase.
     */
    var Capture = 1;

    /**
     * Is this the bubble phase?
     */
    public inline function bubble():Bool {
        return this == 0;
    }

    /**
     * Is this the capture phase?
     */
    public inline function capture():Bool {
        return this == 1;
    }

}
