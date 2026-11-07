// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * Participant-relative selection endpoints with an optional rendering
 * projection. Immutable: the builders return a new value.
 */
class TextSelectionSnapshot {

    final _anchor:TextSelectionEndpoint;

    final _cursor:TextSelectionEndpoint;

    final _isSelecting:Bool;

    final _windowPoints:Null<TextSelectionWindowPoints>;

    final _coverage:TextSelectionCoverage;

    function new(anchor:TextSelectionEndpoint, cursor:TextSelectionEndpoint, isSelecting:Bool, windowPoints:Null<TextSelectionWindowPoints>, coverage:TextSelectionCoverage) {
        _anchor = anchor;
        _cursor = cursor;
        _isSelecting = isSelecting;
        _windowPoints = windowPoints;
        _coverage = coverage;
    }

    /** Creates a snapshot from stable participant-relative endpoints (Rust `new`). */
    @:allow(gpui.base, tests)
    static function create(anchor:TextSelectionEndpoint, cursor:TextSelectionEndpoint):TextSelectionSnapshot {
        return new TextSelectionSnapshot(anchor, cursor, false, null, Bounded);
    }

    /** Sets whether the pointer gesture is still active. */
    @:allow(gpui.base, tests)
    function withSelecting(isSelecting:Bool):TextSelectionSnapshot {
        return new TextSelectionSnapshot(_anchor, _cursor, isSelecting, _windowPoints, _coverage);
    }

    /** Sets the current window-coordinate rendering projection. */
    @:allow(gpui.base, tests)
    function withWindowPoints(windowPoints:Null<TextSelectionWindowPoints>):TextSelectionSnapshot {
        return new TextSelectionSnapshot(_anchor, _cursor, _isSelecting, windowPoints, _coverage);
    }

    /** Sets the portion of the receiving participant covered by this selection. */
    @:allow(gpui.base, tests)
    function withCoverage(coverage:TextSelectionCoverage):TextSelectionSnapshot {
        return new TextSelectionSnapshot(_anchor, _cursor, _isSelecting, _windowPoints, coverage);
    }

    /** Returns the stable anchor endpoint. */
    public inline function anchor():TextSelectionEndpoint {
        return _anchor;
    }

    /** Returns the moving cursor endpoint. */
    public inline function cursor():TextSelectionEndpoint {
        return _cursor;
    }

    /** Returns whether the pointer gesture is still active. */
    public inline function isSelecting():Bool {
        return _isSelecting;
    }

    /** Returns the window-coordinate endpoints for participants that need them. */
    public inline function windowPoints():Null<TextSelectionWindowPoints> {
        return _windowPoints;
    }

    /** Returns the portion of the receiving participant covered by this selection. */
    public inline function coverage():TextSelectionCoverage {
        return _coverage;
    }

    public function equals(other:Null<TextSelectionSnapshot>):Bool {
        return other != null
            && _anchor.equals(other._anchor)
            && _cursor.equals(other._cursor)
            && _isSelecting == other._isSelecting
            && TextSelectionWindowPoints.eq(_windowPoints, other._windowPoints)
            && _coverage == other._coverage;
    }

    /** `Option<TextSelectionSnapshot>` equality. */
    public static function eq(a:Null<TextSelectionSnapshot>, b:Null<TextSelectionSnapshot>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}
