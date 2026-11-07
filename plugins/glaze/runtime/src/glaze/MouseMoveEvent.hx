// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The platform event for a mouse move.
 */
class MouseMoveEvent extends PlatformInput {

    /** The position of the mouse on the window. */
    public var position:Point;

    /** The mouse button that was pressed, if any. */
    public var pressedButton:Null<MouseButton>;

    /** The modifiers that were held down when the mouse was moved. */
    public var modifiers:Modifiers;

    public function new(position:Point, ?pressedButton:MouseButton, ?modifiers:Modifiers) {
        super(MouseMove);
        this.position = position;
        this.pressedButton = pressedButton;
        this.modifiers = modifiers != null ? modifiers : Modifiers.none();
    }

    /**
     * Returns true if the left mouse button is currently held down.
     */
    public inline function dragging():Bool {
        return pressedButton == Left;
    }

}
