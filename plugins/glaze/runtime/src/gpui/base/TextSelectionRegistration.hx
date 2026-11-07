// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.Bounds;
import gpui.ElementId;
import gpui.Entity;
import gpui.Hitbox;
import gpui.Point;
import gpui.WeakEntity;
import gpui.Window;
import gpui.Window.StateModel;

/**
 * Per-frame geometry reported by a `TextSelectionHandle` participant.
 *
 * The builders set the field and return the same registration (Rust's
 * `mut self` builders).
 */
class TextSelectionRegistration {

    @:allow(gpui.base) final _hitbox:Hitbox;
    @:allow(gpui.base) final _bounds:Bounds;
    @:allow(gpui.base) var _scrollOffset:Point;
    @:allow(gpui.base) var _scope:TextSelectionScopeId;
    @:allow(gpui.base) var _documentOrder:Int = 0;
    @:allow(gpui.base) var paintOrder:Bool = false;
    @:allow(gpui.base) var _textBounds:Array<Bounds>;
    @:allow(gpui.base) var selfScroll:Bool = false;
    @:allow(gpui.base) var _selectionEdges:Null<BoundsPair> = null;

    /**
     * Retained element state proving a participant is still in the window
     * (Rust `RenderedMarker`): it outlives the frames a cached view replays,
     * and dies with the frame that drops the element for good.
     */
    @:allow(gpui.base) var rendered:Null<WeakEntity<StateModel<Bool>>> = null;

    /** Creates a registration with default scope, order, and scroll offset. */
    public function new(hitbox:Hitbox, bounds:Bounds) {
        _hitbox = hitbox;
        _bounds = bounds;
        _scrollOffset = new Point(0, 0);
        _scope = TextSelectionScopeId.DEFAULT;
        _textBounds = [];
    }

    /**
     * Ties this registration to the retained state of the element reporting
     * it, so that a frame replayed from that element's cached view keeps it.
     *
     * Call this from the reporting element's `prepaint` or `paint`.
     */
    public function withRenderedElement(participant:TextSelectionHandle, window:Window, cx:App):TextSelectionRegistration {
        final marker:Entity<StateModel<Bool>> = window.useKeyedState(ElementId.NamedInteger('text-selection-participant', participant.entityId()), cx, _ -> true);
        rendered = marker.downgrade();
        return this;
    }

    /**
     * Whether the element that reported this registration is still part of
     * the window, even if it did not paint the frame that just finished.
     */
    @:allow(gpui.base)
    function isRendered():Bool {
        return rendered != null && rendered.upgrade() != null;
    }

    /**
     * Marks a participant that scrolls its own content in response to
     * `TextSelectionEvent.AutoScroll`.
     */
    @:allow(gpui.base)
    function withSelfScroll(selfScroll:Bool):TextSelectionRegistration {
        this.selfScroll = selfScroll;
        return this;
    }

    /** Sets the participant's content scroll offset. */
    public function withScrollOffset(scrollOffset:Point):TextSelectionRegistration {
        _scrollOffset = scrollOffset;
        return this;
    }

    /** Sets the opaque selection scope. */
    public function withScope(scope:TextSelectionScopeId):TextSelectionRegistration {
        _scope = scope;
        return this;
    }

    /** Sets the stable logical document order. */
    public function withDocumentOrder(documentOrder:Int):TextSelectionRegistration {
        _documentOrder = documentOrder;
        return this;
    }

    /**
     * Uses the order of the TextViews in a complete painted frame. A cached
     * view keeps that order while only some of its siblings paint again.
     */
    @:allow(gpui.base)
    function inPaintOrder():TextSelectionRegistration {
        paintOrder = true;
        return this;
    }

    /** Sets the glyph-bearing bounds used to reject blank-only gestures. */
    public function withTextBounds(textBounds:Array<Bounds>):TextSelectionRegistration {
        _textBounds = textBounds;
        return this;
    }

    /**
     * Sets where the participant painted the two ends of its selection: the
     * caret line box before its first selected character and the one after
     * its last, in window coordinates. The touch handles are drawn there.
     */
    public function withSelectionEdges(start:Bounds, end:Bounds):TextSelectionRegistration {
        _selectionEdges = new BoundsPair(start, end);
        return this;
    }

    /** Returns the participant hitbox. */
    public inline function hitbox():Hitbox {
        return _hitbox;
    }

    /** Returns the participant's window-coordinate bounds. */
    public inline function bounds():Bounds {
        return _bounds;
    }

    /** Returns the participant's content scroll offset. */
    public inline function scrollOffset():Point {
        return _scrollOffset;
    }

    /** Returns the opaque selection scope. */
    public inline function scope():TextSelectionScopeId {
        return _scope;
    }

    /** Returns the stable logical document order. */
    public inline function documentOrder():Int {
        return _documentOrder;
    }

    /** Returns the glyph-bearing bounds used to reject blank-only gestures. */
    public inline function textBounds():Array<Bounds> {
        return _textBounds;
    }

    /** Returns the caret line boxes at the participant's selection ends. */
    public inline function selectionEdges():Null<BoundsPair> {
        return _selectionEdges;
    }

}

/** Rust `(Bounds<Pixels>, Bounds<Pixels>)`: a start and an end box. */
class BoundsPair {

    public final start:Bounds;

    public final end:Bounds;

    public inline function new(start:Bounds, end:Bounds) {
        this.start = start;
        this.end = end;
    }

    public function equals(other:Null<BoundsPair>):Bool {
        return other != null && start.equals(other.start) && end.equals(other.end);
    }

    public static function eq(a:Null<BoundsPair>, b:Null<BoundsPair>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}
