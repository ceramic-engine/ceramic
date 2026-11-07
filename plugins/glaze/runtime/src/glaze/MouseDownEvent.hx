// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A mouse down event from the platform.
 */
class MouseDownEvent extends PlatformInput {

    /** Which mouse button was pressed. */
    public var button:MouseButton;

    /** The position of the mouse on the window. */
    public var position:Point;

    /** The modifiers that were held down when the mouse was pressed. */
    public var modifiers:Modifiers;

    /** The number of times the button has been clicked. */
    public var clickCount:Int;

    /** Whether this is the first, focusing click. */
    public var firstMouse:Bool;

    public function new(button:MouseButton, position:Point, ?modifiers:Modifiers, clickCount:Int = 1, firstMouse:Bool = false) {
        super(MouseDown);
        this.button = button;
        this.position = position;
        this.modifiers = modifiers != null ? modifiers : Modifiers.none();
        this.clickCount = clickCount;
        this.firstMouse = firstMouse;
    }

    /**
     * Returns true if this mouse up event should focus the element.
     */
    public inline function isFocusing():Bool {
        return button == Left;
    }

    public function copy():MouseDownEvent {
        return new MouseDownEvent(button, position, modifiers, clickCount, firstMouse);
    }

}
