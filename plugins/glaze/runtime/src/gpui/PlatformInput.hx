// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An event from a platform input source (Rust enum `PlatformInput`, and
 * trait `InputEvent`).
 *
 * Differences with GPUI: Rust wraps each event struct in an enum variant and
 * listeners downcast `&dyn Any`. Here every event class extends this one and
 * carries its `kind`: the event object is the platform input
 * (`to_platform_input()` is the identity). Pinch, pressure, back gesture
 * and file drop events are not ported.
 */
abstract class PlatformInput {

    /**
     * The kind of this event.
     */
    public final kind:PlatformInputKind;

    function new(kind:PlatformInputKind) {
        this.kind = kind;
    }

    /**
     * Rust `InputEvent::to_platform_input`: the event itself.
     */
    public inline function toPlatformInput():PlatformInput {
        return this;
    }

}
