// Ported from gpui-pre 0.3.10: src/elements/div.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An event for when a drag is moving over this element, with the given state type.
 */
class DragMoveEvent<T> {

    /** The mouse move event that triggered this drag move event. */
    public final event:MouseMoveEvent;

    /** The bounds of this element. */
    public final bounds:Bounds;

    final draggedItem:Dynamic;

    public function new(event:MouseMoveEvent, bounds:Bounds, draggedItem:Dynamic) {
        this.event = event;
        this.bounds = bounds;
        this.draggedItem = draggedItem;
    }

    /**
     * Returns the value being dragged.
     */
    public inline function drag(cx:App):T {
        return cast draggedItem;
    }

    /**
     * Returns the dragged item, untyped.
     */
    public inline function getDraggedItem():Dynamic {
        return draggedItem;
    }

}
