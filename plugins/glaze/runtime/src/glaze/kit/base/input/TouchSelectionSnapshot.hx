// Ported from gpui-kit 0.8.1: crates/base/src/touch_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Hsla;
import glaze.Pixels;
import glaze.Point;
import glaze.Size;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Where a touch selection's ends are laid out this frame, and what the
 * gesture is doing to them (Rust `crate::touch_selection`, the geometry
 * shared by the input engine and window text selection, kept here with its
 * first user).
 *
 * Each end is the caret line box at that end in window coordinates: zero
 * width, one line tall, at the character boundary. An empty selection has
 * both ends at the caret. Built only by Base; a presentation layer reads it
 * to draw the handles and place the edit menu. The builders return a new
 * value.
 */
class TouchSelectionSnapshot {

    final _start:Bounds;
    final _end:Bounds;
    final startVisible:Bool;
    final endVisible:Bool;
    final menuOpen:Bool;
    final _dragging:Null<SelectionEdge>;

    function new(start:Bounds, end:Bounds, startVisible:Bool, endVisible:Bool, menuOpen:Bool, dragging:Null<SelectionEdge>) {
        _start = start;
        _end = end;
        this.startVisible = startVisible;
        this.endVisible = endVisible;
        this.menuOpen = menuOpen;
        _dragging = dragging;
    }

    @:allow(glaze.kit.base, tests)
    static function create(start:Bounds, end:Bounds):TouchSelectionSnapshot {
        return new TouchSelectionSnapshot(start, end, true, true, false, null);
    }

    @:allow(glaze.kit.base, tests)
    function withEdgeVisible(edge:SelectionEdge, visible:Bool):TouchSelectionSnapshot {
        return switch edge {
            case Start: new TouchSelectionSnapshot(_start, _end, visible, endVisible, menuOpen, _dragging);
            case End: new TouchSelectionSnapshot(_start, _end, startVisible, visible, menuOpen, _dragging);
        }
    }

    @:allow(glaze.kit.base, tests)
    function withMenuOpen(menuOpen:Bool):TouchSelectionSnapshot {
        return new TouchSelectionSnapshot(_start, _end, startVisible, endVisible, menuOpen, _dragging);
    }

    @:allow(glaze.kit.base, tests)
    function withDragging(dragging:Null<SelectionEdge>):TouchSelectionSnapshot {
        return new TouchSelectionSnapshot(_start, _end, startVisible, endVisible, menuOpen, dragging);
    }

    /** The caret line box before the first selected character. */
    public inline function start():Bounds {
        return _start;
    }

    /** The caret line box after the last selected character. */
    public inline function end():Bounds {
        return _end;
    }

    /** The caret line box at the given end. */
    public function edge(edge:SelectionEdge):Bounds {
        return edge == Start ? _start : _end;
    }

    /**
     * Whether the given end is in view. A handle is drawn only for an end
     * that is; the menu anchors to the ends that are.
     */
    public function isEdgeVisible(edge:SelectionEdge):Bool {
        return edge == Start ? startVisible : endVisible;
    }

    /** Whether the selection is a bare caret, which gets a menu but no handles. */
    public function isEmpty():Bool {
        return _start.equals(_end);
    }

    /**
     * The smallest box holding the ends in view, for anchoring the edit
     * menu. Null when the whole selection is scrolled away.
     */
    public function bounds():Null<Bounds> {
        return if (startVisible && endVisible) _start.union(_end) else if (startVisible) _start else if (endVisible) _end else null;
    }

    /**
     * Whether the edit menu is open. It closes while a handle is dragged and
     * reopens when the drag ends.
     */
    public inline function isMenuOpen():Bool {
        return menuOpen;
    }

    /** The end currently being dragged by its handle. */
    public inline function dragging():Null<SelectionEdge> {
        return _dragging;
    }

    /** The caret line box at `position`, for reporting a selection end. */
    public static function caretLineBox(position:Point, lineHeight:Pixels):Bounds {
        return new Bounds(position, new Size(0., lineHeight));
    }

    /**
     * Whether a caret line box shows inside `viewport`: its line overlaps the
     * viewport vertically and its x lies within it. A zero-width box never
     * intersects anything, so this is not `Bounds.intersects`.
     */
    public static function caretInView(caret:Bounds, viewport:Bounds):Bool {
        return caret.bottom() > viewport.top() && caret.top() < viewport.bottom() && caret.left() >= viewport.left()
            && caret.left() <= viewport.right();
    }

}
