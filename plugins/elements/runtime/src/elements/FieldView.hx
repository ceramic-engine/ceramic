package elements;

import ceramic.LinearLayout;
import ceramic.Point;
import ceramic.Shortcuts.*;
import ceramic.View;
import elements.FieldSystem;

class FieldView extends LinearLayout {

    static var _point = new Point();

/// Public properties

    public var focused(get,never):Bool;
    inline function get_focused():Bool {
        FieldSystem.shared.updateFocusedField();
        return FieldSystem.shared.focusedField == this;
    }

/// Lifecycle

    public function new() {

        super();

        transparent = true;
        direction = HORIZONTAL;

        bindPointerEvents();

    }

/// Public API

    public function focus():Void {

        screen.focusedVisual = this;

        makeVisibleInForm();

    }

    public function makeVisibleInForm():Void {

        var scrollingLayout = getScrollingLayout();
        if (scrollingLayout == null) {
            // Nothing to do if there is no scrolling layout
            return;
        }

        var scroller = scrollingLayout.scroller;

        scroller.content.visualToScreen(0, 0, _point);
        var formY = _point.y;

        this.visualToScreen(0, 0, _point);
        var fieldStart = _point.y;
        this.visualToScreen(0, height, _point);
        var fieldEnd = _point.y;

        var targetStart = fieldStart - formY;
        var targetEnd = fieldEnd - formY;

        // Tweak values a bit to make it look nicer
        targetStart -= 8;
        targetEnd += 8;

        var startVisible = scroller.isContentPositionInBounds(0, targetStart);
        var endVisible = scroller.isContentPositionInBounds(0, targetEnd);

        scroller.ensureContentPositionIsInBounds(0, targetStart);
        scroller.ensureContentPositionIsInBounds(0, targetEnd);

    }

/// Internal

    function getScrollingLayout():ScrollingLayout<View> {

        var parent = this.parent;

        while (parent != null) {
            if (Std.isOfType(parent, ScrollingLayout)) {
                var scrollingLayout:ScrollingLayout<View> = cast parent;
                return scrollingLayout;
            }
            parent = parent.parent;
        }

        return null;

    }

    @:allow(elements.FieldSystem)
    function didLostFocus():Void {

        // Override in subclasses

    }

    function bindPointerEvents() {

        // To make it focusable
        onPointerDown(this, function(_) {});

    }

}
