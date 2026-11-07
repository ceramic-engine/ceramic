// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.base.dock.DockPlacement;

/**
 * A dock that the user opened or closed with one of `DockSkin`'s controls:
 * the collapse button in a tab bar, the strip of a collapsed bottom dock, or
 * a resize handle dragged past the closed strip and released.
 *
 * A `DockArea` drawn by `DockSkin` emits it after the dock has changed.
 * `DockArea.toggleDock` and the other dock setters do not, so an
 * application can tell a user's toggle from one its own code made.
 * Subscribe with `cx.subscribe(area, DockToggleEvent, ...)`.
 */
class DockToggleEvent {

    final placementValue:DockPlacement;

    final open:Bool;

    @:allow(gpui.component.dock)
    function new(placement:DockPlacement, open:Bool) {
        this.placementValue = placement;
        this.open = open;
    }

    /**
     * The dock that was toggled.
     */
    public inline function placement():DockPlacement {
        return placementValue;
    }

    /**
     * Whether the dock is open now.
     */
    public inline function isOpen():Bool {
        return open;
    }

    public function toString():String {
        return 'DockToggleEvent($placementValue, $open)';
    }

}
