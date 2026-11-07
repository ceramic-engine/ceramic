// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A handle which can be used to track and manipulate the focused element in a window.
 *
 * Differences with GPUI: handles are plain shared objects (no reference
 * counting, no `FocusMap`): cloning returns the same handle, and a handle
 * is never released. Rust has both a field and a builder named `tab_index`
 * (and `tab_stop`): the fields are `tabIndexValue` and `isTabStop`, the
 * builders `tabIndex()` and `tabStop()` (which change the handle in place,
 * like GPUI updates the shared `FocusRef`).
 */
class FocusHandle {

    static var nextId:Int = 1;

    /**
     * The id of this handle (Rust `FocusId`).
     */
    public final id:Int;

    /**
     * The index of this element in the tab order.
     */
    public var tabIndexValue(default, null):Int = 0;

    /**
     * Whether this element can be focused by tab navigation.
     */
    public var isTabStop(default, null):Bool = false;

    @:allow(glaze)
    function new() {
        id = nextId++;
    }

    /**
     * Sets the tab index of the element associated with this handle.
     */
    public function tabIndex(index:Int):FocusHandle {
        tabIndexValue = index;
        return this;
    }

    /**
     * Sets whether the element associated with this handle is a tab stop.
     * When `false`, the element will not be included in the tab order.
     */
    public function tabStop(tabStop:Bool):FocusHandle {
        isTabStop = tabStop;
        return this;
    }

    /**
     * Rust `clone()`: handles are shared, this returns the same handle.
     */
    public inline function clone():FocusHandle {
        return this;
    }

    /**
     * Converts this focus handle into a weak variant (the same handle here).
     */
    public inline function downgrade():FocusHandle {
        return this;
    }

    /**
     * Moves the focus to the element associated with this handle.
     */
    public function focus(window:Window, cx:App):Void {
        window.focus(this, cx);
    }

    /**
     * Obtains whether the element associated with this handle is currently focused.
     */
    public function isFocused(window:Window):Bool {
        return window.focusId() == id;
    }

    /**
     * Obtains whether the element associated with this handle contains the focused
     * element or is itself focused.
     */
    public function containsFocused(window:Window, cx:App):Bool {
        final focused = window.focusId();
        return focused != -1 && window.focusContains(id, focused);
    }

    /**
     * Obtains whether the element associated with this handle is contained within the
     * focused element or is itself focused.
     */
    public function withinFocused(window:Window, cx:App):Bool {
        final focused = window.focusId();
        return focused != -1 && window.focusContains(focused, id);
    }

    /**
     * Obtains whether this handle contains the given handle in the most recently rendered frame.
     */
    public function contains(other:FocusHandle, window:Window):Bool {
        return window.focusContains(id, other.id);
    }

    /**
     * Dispatch an action on the element that rendered this focus handle.
     */
    public function dispatchAction(action:Action, window:Window, cx:App):Void {
        window.dispatchActionOnFocusHandle(this, action, cx);
    }

    public function toString():String {
        return 'FocusHandle(' + id + ')';
    }

}
