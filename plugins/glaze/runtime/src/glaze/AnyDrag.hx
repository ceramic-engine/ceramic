// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Contains state associated with an active drag operation, started by dragging an element
 * within the window or by dragging into the app from the underlying platform.
 */
class AnyDrag {

    /** The view used to render this drag */
    public var view:AnyView;

    /** The value of the dragged item, to be dropped */
    public var value:Dynamic;

    /**
     * This is used to render the dragged item in the same place
     * on the original element that the drag was initiated
     */
    public var cursorOffset:Point;

    /** The cursor style to use while dragging */
    public var cursorStyle:Null<CursorStyle>;

    public function new(view:AnyView, value:Dynamic, cursorOffset:Point, ?cursorStyle:CursorStyle) {
        this.view = view;
        this.value = value;
        this.cursorOffset = cursorOffset;
        this.cursorStyle = cursorStyle;
    }

    /**
     * Whether the dragged value is an instance of exactly the given class
     * (Rust compares the `TypeId` of the value).
     */
    public inline function valueIs(type:Class<Dynamic>):Bool {
        return Type.getClass(value) == type;
    }

}
