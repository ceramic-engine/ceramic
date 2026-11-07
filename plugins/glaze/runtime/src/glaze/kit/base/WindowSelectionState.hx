// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.Model;
import glaze.Point;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TouchPhase;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.SelectableTextState;
import glaze.kit.base.TextSelectionRegistration.BoundsPair;
import glaze.kit.base.input.EdgeDrag;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TouchSelectionSnapshot;

import glaze.Prelude.*;

/** Rust `ParticipantRegistration`. */
class ParticipantRegistration {
    public final participant:WeakEntity<SelectableTextState>;
    public final registration:TextSelectionRegistration;
    public var documentOrder:Int;
    public final generation:Int;

    public inline function new(participant:WeakEntity<SelectableTextState>, registration:TextSelectionRegistration, documentOrder:Int, generation:Int) {
        this.participant = participant;
        this.registration = registration;
        this.documentOrder = documentOrder;
        this.generation = generation;
    }
}

/** Rust `(ContentKeyResolver, Point<Pixels>)`. */
class PendingContentKey {
    public final resolver:ContentKeyResolver;
    public final point:Point;

    public inline function new(resolver:ContentKeyResolver, point:Point) {
        this.resolver = resolver;
        this.point = point;
    }
}

/** Rust `SelectionEndpoint`. Immutable: the Rust clones are shared values here. */
class SelectionEndpoint {
    public final participant:Null<WeakEntity<SelectableTextState>>;
    public final point:Point;
    public final inside:Bool;
    public final insideText:Bool;
    public final contentKey:Null<TextSelectionContentKey>;
    public final contentKeyResolver:Null<PendingContentKey>;

    public function new(participant:Null<WeakEntity<SelectableTextState>>, point:Point, inside:Bool, insideText:Bool, contentKey:Null<TextSelectionContentKey>, contentKeyResolver:Null<PendingContentKey>) {
        this.participant = participant;
        this.point = point;
        this.inside = inside;
        this.insideText = insideText;
        this.contentKey = contentKey;
        this.contentKeyResolver = contentKeyResolver;
    }

    public function snapshot():TextSelectionEndpoint {
        final snapshot = new TextSelectionEndpoint(entityId(), point);
        return contentKey != null ? snapshot.withContentKey(contentKey) : snapshot;
    }

    public function resolve(participants:Map<Int, ParticipantRegistration>):Null<Point> {
        final participant = this.participant;
        if (participant == null) return null;
        final registration = participants.get(participant.entityId());
        if (registration == null) return null;
        if (participant.upgrade() == null) return null;
        return point.add(registration.registration._scrollOffset).add(registration.registration._bounds.origin);
    }

    public function entityId():Null<Int> {
        return participant != null ? participant.entityId() : null;
    }

    /** This endpoint moved by `delta` within its participant, its content key to be resolved again. */
    public function moved(delta:Point):SelectionEndpoint {
        final point = this.point.add(delta);
        return new SelectionEndpoint(participant, point, inside, insideText, null, contentKeyResolver != null ? new PendingContentKey(contentKeyResolver.resolver, point) : null);
    }

    /** The endpoint with its content key resolved. */
    public function withResolvedKey(key:TextSelectionContentKey):SelectionEndpoint {
        return new SelectionEndpoint(participant, point, inside, insideText, key, null);
    }
}

/**
 * The word or line a double or triple click selected. A drag from the click,
 * and a shift-click after it, extend the selection by the same unit, and it
 * stays selected whichever way they go.
 */
class SelectionUnit {
    public final clickCount:Int;
    public final start:SelectionEndpoint;
    public final end:SelectionEndpoint;
    /** The heights of the rows the unit starts and ends on. */
    public final startRowHeight:Float;
    public final endRowHeight:Float;

    public inline function new(clickCount:Int, start:SelectionEndpoint, end:SelectionEndpoint, startRowHeight:Float, endRowHeight:Float) {
        this.clickCount = clickCount;
        this.start = start;
        this.end = end;
        this.startRowHeight = startRowHeight;
        this.endRowHeight = endRowHeight;
    }
}

/** Rust `(Bounds, Bounds, bool, bool)`: the ends as last laid out, with their visibility. */
class TouchEdges {
    public final start:Bounds;
    public final end:Bounds;
    public final startVisible:Bool;
    public final endVisible:Bool;

    public inline function new(start:Bounds, end:Bounds, startVisible:Bool, endVisible:Bool) {
        this.start = start;
        this.end = end;
        this.startVisible = startVisible;
        this.endVisible = endVisible;
    }
}

/**
 * What a long press left behind: the handles and the edit menu (Rust
 * `TouchSelection`, renamed: the input engine has a `TouchSelection`).
 *
 * The presentation layer draws both and reports their bounds each frame, so
 * that a press on a handle or a menu item is not taken for a press on the text
 * underneath, which would clear the very selection they belong to.
 */
class WindowTouchSelection {
    /** The current selection was made by touch and carries handles. */
    public var active:Bool = false;
    public var menuOpen:Bool = false;
    public var drag:Null<EdgeDrag> = null;
    /**
     * Where the menu was painted this frame, and the frame before: a press
     * arrives between frames, and the surfaces may have moved in the one that
     * has not painted yet.
     */
    public var uiBounds:Array<Bounds> = [];
    public var previousUiBounds:Array<Bounds> = [];
    /** Where each participant last painted its handles. */
    public final handleBounds:Map<Int, Array<Bounds>> = new Map();
    /** The ends as last laid out. */
    public var lastEdges:Null<TouchEdges> = null;

    public function new() {}

    public function covers(position:Point):Bool {
        if (!active) return false;
        for (bounds in uiBounds) if (bounds.contains(position)) return true;
        for (bounds in previousUiBounds) if (bounds.contains(position)) return true;
        for (list in handleBounds) for (bounds in list) if (bounds.contains(position)) return true;
        return false;
    }

    /** Whether the handles or the menu were painted in either of the last two frames. */
    public function paintedAny():Bool {
        return uiBounds.length > 0 || previousUiBounds.length > 0;
    }

    /** A new frame begins: what was painted last frame is kept one frame more. */
    public function beginFrame():Void {
        previousUiBounds = uiBounds;
        uiBounds = [];
    }

    /** Drops the handles and the menu; returns whether there were any. */
    public function reset():Bool {
        final had = active;
        handleBounds.clear();
        active = false;
        menuOpen = false;
        drag = null;
        lastEdges = null;
        return had;
    }
}

/**
 * Automatic order is committed only after all live TextViews have painted. A
 * partial frame is a subsequence of that order, not a new document.
 */
class ParticipantPaintOrder {
    public var next:Int = 0;
    public var painted:Array<Int> = [];
    public var last:Null<Int> = null;
    public var dirty:Bool = false;
    public var refreshRequested:Bool = false;

    public function new() {}
}

/** Rust `(TextSelectionEndpoint, Bounds<Pixels>)`. */
class TableCellAnchor {
    public final endpoint:TextSelectionEndpoint;
    public final bounds:Bounds;

    public inline function new(endpoint:TextSelectionEndpoint, bounds:Bounds) {
        this.endpoint = endpoint;
        this.bounds = bounds;
    }
}

/** Rust `(SelectionEdge, Bounds<Pixels>)`. */
class EdgeCaret {
    public final edge:SelectionEdge;
    public final caret:Bounds;

    public inline function new(edge:SelectionEdge, caret:Bounds) {
        this.edge = edge;
        this.caret = caret;
    }
}

/** Rust `(EntityId, WeakEntity<SelectableTextState>)`. */
class StaleParticipant {
    public final id:Int;
    public final participant:WeakEntity<SelectableTextState>;

    public inline function new(id:Int, participant:WeakEntity<SelectableTextState>) {
        this.id = id;
        this.participant = participant;
    }
}

/** Rust `(Option<(Bounds, Point)>, u8)`: where the anchor's text was at the last synthetic wheel. */
class AutoScrollStall {
    public var bounds:Null<Bounds> = null;
    public var scrollOffset:Null<Point> = null;
    public var stalled:Int = 0;

    public function new() {}
}

/** Rust `(Entity<SelectableTextState>, Rc<TextSelectionRegistration>)`. */
class AnchorRegistration {
    public final participant:Entity<SelectableTextState>;
    public final registration:TextSelectionRegistration;

    public inline function new(participant:Entity<SelectableTextState>, registration:TextSelectionRegistration) {
        this.participant = participant;
        this.registration = registration;
    }
}

/** Non-owning window locator; retained `TextSelectionLayer` element state owns each live selection entity. */
class SelectionStateRegistry {
    public final map:Map<Int, WeakEntity<WindowSelectionState>> = new Map();

    public function new() {}
}

class PendingTextSelectionScopes {
    public final map:Map<Int, TextSelectionScopeId> = new Map();

    public function new() {}
}

class TextSelectionScopeStacks {
    public final map:Map<Int, Array<TextSelectionScopeId>> = new Map();

    public function new() {}
}

/**
 * Window-local generic text-selection state.
 */
@:allow(glaze.kit.base)
class WindowSelectionState extends Model {

    /**
     * What each participant painted this frame, or last painted. Painting
     * reports it without changing the selection: see `registerQuietly`.
     */
    var participants:Map<Int, ParticipantRegistration> = new Map();
    var activeScope:TextSelectionScopeId = TextSelectionScopeId.DEFAULT;
    /** A prepaint projection owned by this window and reset with its selection. */
    var tableCellAnchor:Null<TableCellAnchor> = null;
    var touchSelectAll:Bool = false;
    var anchor:Null<SelectionEndpoint> = null;
    var cursor:Null<SelectionEndpoint> = null;
    var pendingExtensionAnchor:Null<SelectionEndpoint> = null;
    var unit:Null<SelectionUnit> = null;
    var isSelecting:Bool = false;
    var didHitText:Bool = false;
    var frameGeneration:Int = 0;
    var finishFrameScheduled:Bool = false;
    var layerPainted:Bool = false;
    var paintOrder:ParticipantPaintOrder = new ParticipantPaintOrder();
    /**
     * Participants given an updated snapshot while drawing. Their observers
     * run after the frame, including adapters which registered after paint.
     */
    var drawChanged:Map<Int, WeakEntity<SelectableTextState>> = new Map();
    var refreshHeldCursor:Bool = false;
    var touchEdgesMoved:Bool = false;
    /** Test counter (Rust `#[cfg(test)] snapshot_visits`). */
    var snapshotVisits:Int = 0;
    var mouseDownPrepared:Bool = false;
    var autoScroll:AutoScroll = new AutoScroll();
    /**
     * Where the anchor's text was when the last synthetic wheel went out, and
     * how many went out without moving it.
     */
    var autoScrollStall:AutoScrollStall = new AutoScrollStall();
    var touch:WindowTouchSelection = new WindowTouchSelection();
    /** This entity, so that touch changes can notify observers from paths that only hold an `App`. */
    var stateEntityId:Null<Int> = null;

    public function new() {
        super();
    }

    /**
     * The global of `type`, untracked: views do not react to the selection
     * registries (Rust views only react to globals they observe), and they are
     * mutated in place, without notifying (none of them has observers).
     */
    static function globalOf<G>(cx:App, type:Class<G>):Null<G> {
        tracker.Autorun.unobserve();
        final value = cx.tryGlobal(type);
        tracker.Autorun.reobserve();
        return value;
    }

    static function resolveContentKeys(state:Entity<WindowSelectionState>, cx:App):Void {
        final current = state.read(cx);
        final pending = [
            current.anchor != null ? current.anchor.contentKeyResolver : null,
            current.cursor != null ? current.cursor.contentKeyResolver : null,
        ];
        // Nothing to resolve and no selection to publish: an event that
        // changed nothing does not change the state either.
        if (pending[0] == null && pending[1] == null && !current.isActive()) {
            return;
        }
        final resolved:Array<Null<TextSelectionContentKey>> = [
            for (p in pending) p != null ? p.resolver(p.point, cx) : null
        ];
        state.update(cx, (state, cx) -> {
            if (state.anchor != null && resolved[0] != null) {
                state.anchor = state.anchor.withResolvedKey(resolved[0]);
            }
            if (state.cursor != null && resolved[1] != null) {
                state.cursor = state.cursor.withResolvedKey(resolved[1]);
            }
            state.publishSnapshots(cx.app);
        });
    }

    static function acquire(window:Window, cx:App):Entity<WindowSelectionState> {
        final windowId = window.id;
        if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) == null) {
            cx.setGlobal(new SelectionStateRegistry(), SelectionStateRegistry);
        }
        final registered = WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.get(windowId);
        if (registered != null) {
            final state = registered.upgrade();
            if (state != null) {
                return state;
            }
        }

        var activeScope = TextSelectionScopeId.DEFAULT;
        if (WindowSelectionState.globalOf(cx, PendingTextSelectionScopes) != null) {
            final pending = WindowSelectionState.globalOf(cx, PendingTextSelectionScopes).map;
            if (pending.exists(windowId)) {
                activeScope = pending.get(windowId);
                pending.remove(windowId);
            }
        }

        final state:Entity<WindowSelectionState> = cx.newEntity((cx:Context<WindowSelectionState>) -> {
            final entityId = cx.entityId();
            cx.onRelease((state, cx) -> {
                final handlers = state.clearState(cx);
                if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) != null) {
                    final registry = WindowSelectionState.globalOf(cx, SelectionStateRegistry).map;
                    final current = registry.get(windowId);
                    if (current != null && current.entityId() == entityId) {
                        registry.remove(windowId);
                    }
                }
                if (handlers.length > 0) {
                    cx.defer(cx -> TextSelection.dispatchClearHandlers(handlers, cx));
                }
            });
            final state = new WindowSelectionState();
            state.activeScope = activeScope;
            state.stateEntityId = entityId;
            return state;
        });
        WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.set(windowId, state.downgrade());
        return state;
    }

    /** Rust `#[cfg(test)] ensure`. */
    @:allow(tests)
    static function ensure(window:Window, cx:App):Entity<WindowSelectionState> {
        return acquire(window, cx);
    }

    static function existing(window:Window, cx:App):Null<Entity<WindowSelectionState>> {
        if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) == null) {
            return null;
        }
        final weak = WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.get(window.id);
        return weak != null ? weak.upgrade() : null;
    }

    /** Updates the active scope. Participants from other scopes cannot participate (test helper). */
    @:allow(tests)
    function setActiveScope(scope:TextSelectionScopeId, cx:App):Void {
        final handlers = setActiveScopeState(scope, cx);
        TextSelection.dispatchClearHandlers(handlers, cx);
    }

    function setActiveScopeState(scope:TextSelectionScopeId, cx:App):Array<ClearHandler> {
        if (activeScope == scope) {
            return [];
        }
        final handlers = clearState(cx);
        activeScope = scope;
        publishSnapshots(cx);
        return handlers;
    }

    /**
     * Sweeps participants after a rendered frame has completed (test helper,
     * the live path is `TextSelection.scheduleSelectionFrame`).
     */
    @:allow(tests)
    function finishFrame(cx:App):Array<ClearHandler> {
        final stale = staleParticipants(true);
        final handlers = endpointDeparted(stale) ? clearState(cx) : [];
        final departed = removeStaleParticipants(stale);
        for (handler in TextSelection.clearDepartedParticipants(departed, cx)) handlers.push(handler);
        finishRegistrations();
        publishSnapshots(cx);
        return handlers;
    }

    function staleParticipants(fullFrame:Bool):Array<StaleParticipant> {
        final generation = frameGeneration;
        final stale:Array<StaleParticipant> = [];
        for (id => participant in participants) {
            final registration = participant.registration;
            final missedFrame = participant.generation != generation
                && !registration.isRendered()
                && (fullFrame || registration.rendered != null);
            if (missedFrame || participant.participant.upgrade() == null) {
                stale.push(new StaleParticipant(id, participant.participant));
            }
        }
        return stale;
    }

    function endpointDeparted(stale:Array<StaleParticipant>):Bool {
        final endpoints:Array<SelectionEndpoint> = [];
        if (anchor != null) endpoints.push(anchor);
        if (cursor != null) endpoints.push(cursor);
        if (pendingExtensionAnchor != null) endpoints.push(pendingExtensionAnchor);
        if (unit != null) {
            endpoints.push(unit.start);
            endpoints.push(unit.end);
        }
        for (entry in stale) {
            for (endpoint in endpoints) {
                if (endpoint.entityId() == entry.id) return true;
            }
        }
        return false;
    }

    function removeStaleParticipants(stale:Array<StaleParticipant>):Array<Entity<SelectableTextState>> {
        final departed:Array<Entity<SelectableTextState>> = [];
        for (entry in stale) {
            participants.remove(entry.id);
            final participant = entry.participant.upgrade();
            if (participant != null) departed.push(participant);
        }
        return departed;
    }

    /**
     * Finishes bookkeeping through a read of the window entity. Updating it
     * would invalidate every retained view that registered a participant.
     * Returns whether one complete frame is needed to recover paint order.
     */
    function finishRegistrations():Bool {
        final generation = frameGeneration;
        final order = paintOrder;
        var complete = true;
        for (participant in participants) {
            if (participant.registration.paintOrder && participant.generation != generation) {
                complete = false;
                break;
            }
        }
        var refresh = false;
        if (complete) {
            var next = 0;
            for (id in order.painted) {
                final participant = participants.get(id);
                if (participant != null && participant.registration.paintOrder) {
                    next += 1;
                    participant.documentOrder = next;
                }
            }
            order.painted = [];
            order.next = next;
            order.dirty = false;
            order.refreshRequested = false;
            refresh = false;
        }
        else {
            refresh = order.dirty && !order.refreshRequested;
            if (refresh) order.refreshRequested = true;
            order.painted = [];
        }
        order.last = null;
        finishFrameScheduled = false;
        layerPainted = false;
        frameGeneration = generation + 1;
        return refresh;
    }

    function scheduleFinishFrame():Bool {
        final scheduled = finishFrameScheduled;
        finishFrameScheduled = true;
        return !scheduled;
    }

    /**
     * Whether there is a selection, or a gesture or touch selection that may
     * make one: what painting the participants reports can change it.
     */
    function isActive():Bool {
        return anchor != null
            || cursor != null
            || pendingExtensionAnchor != null
            || isSelecting
            || refreshHeldCursor
            || touch.active;
    }

    /**
     * Records one participant in constant time, even during a selection. Full
     * publication belongs to input handling or the end of the frame, never to
     * each participant's draw callback.
     */
    function registerQuietly(selection:TextSelectionHandle, registration:TextSelectionRegistration):Void {
        final previous = participants.get(selection.entityId());
        if (isSelecting
            && registration.selfScroll
            && anchor != null && anchor.entityId() == selection.entityId()
            && previous != null
            && (!previous.registration._scrollOffset.equals(registration._scrollOffset)
                || !previous.registration._bounds.equals(registration._bounds))) {
            refreshHeldCursor = true;
        }
        // The handles sit on the painted ends; when those moved (a scroll, a
        // reflow, a select-all), whoever draws the handles needs to know.
        if (touch.active
            && (previous == null || !BoundsPair.eq(previous.registration._selectionEdges, registration._selectionEdges))) {
            touchEdgesMoved = true;
        }
        final generation = frameGeneration;
        final documentOrder = if (registration.paintOrder) {
            final order = paintOrder;
            final previous = previous != null && previous.registration.paintOrder ? previous : null;
            final number = if (previous == null) {
                order.next += 1;
                order.dirty = true;
                order.next;
            }
            else {
                previous.documentOrder;
            }
            // Reparenting an element changes its keyed marker and may move it
            // among retained siblings. Geometry alone is not a topology change:
            // scrolling an ancestor moves its text without changing its order.
            if (previous != null) {
                final previousMarker = previous.registration.rendered != null ? previous.registration.rendered.entityId() : null;
                final marker = registration.rendered != null ? registration.rendered.entityId() : null;
                if (previousMarker != marker) {
                    order.dirty = true;
                }
            }
            final inverted = order.last != null && order.last > number;
            if (inverted) order.dirty = true;
            order.last = number;
            // As with geometry, a handle painted twice takes its last position.
            order.painted.push(selection.entityId());
            number;
        }
        else {
            registration._documentOrder;
        }
        participants.set(selection.entityId(), new ParticipantRegistration(selection.downgrade(), registration, documentOrder, generation));
    }

    /** Test helper. */
    @:allow(tests)
    function registerParticipant(selection:TextSelectionHandle, registration:TextSelectionRegistration, cx:App):Void {
        registerQuietly(selection, registration);
        publishSnapshots(cx);
    }

    /** Starts a selection gesture using bounds hit testing (test helper). */
    @:allow(tests)
    function begin(position:Point, extend:Bool, cx:App):Void {
        beginImpl(position, extend, false, null, cx);
    }

    /** Updates the current gesture using bounds hit testing (test helper). */
    @:allow(tests)
    function updateGesture(position:Point, cx:App):Void {
        updateImpl(position, null, cx);
    }

    /** Ends the current gesture and keeps its selection visible. */
    public function end(cx:App):Void {
        pendingExtensionAnchor = null;
        if (!isSelecting) {
            return;
        }
        isSelecting = false;
        if (!didHitText) {
            anchor = null;
            cursor = null;
        }
        stopAnchorAutoScroll(cx);
        publishSnapshots(cx);
    }

    /** Clears both window selection and every participant's local selection. */
    public function clear(cx:App):Void {
        final handlers = clearState(cx);
        TextSelection.dispatchClearHandlers(handlers, cx);
    }

    function clearState(cx:App):Array<ClearHandler> {
        drawChanged.clear();
        tableCellAnchor = null;
        touchSelectAll = false;
        stopAnchorAutoScroll(cx);
        anchor = null;
        cursor = null;
        pendingExtensionAnchor = null;
        unit = null;
        isSelecting = false;
        didHitText = false;
        if (touch.reset()) {
            touchChanged(cx);
        }
        pruneDeadParticipants();
        final handlers:Array<ClearHandler> = [];
        for (registration in [for (r in participants) r]) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            final handler = participant.update(cx, (state, cx) -> state.clearState(cx));
            if (handler != null) handlers.push(handler);
        }
        return handlers;
    }

    /**
     * Tells whoever draws the handles and the menu that they changed.
     *
     * Deferred, because the change may come from a participant painting its
     * selection ends. The participants in the selection hear it too.
     */
    function touchChanged(cx:App):Void {
        final participants:Array<Entity<SelectableTextState>> = [];
        for (registration in this.participants) {
            final participant = registration.participant.upgrade();
            if (participant != null && participant.read(cx)._snapshot != null) {
                participants.push(participant);
            }
        }
        final entityId = stateEntityId;
        cx.defer(cx -> {
            for (participant in participants) {
                participant.update(cx, (_, cx) -> cx.emit(TextSelectionEvent.TouchSelectionChanged));
            }
            if (entityId != null) {
                cx.notify(entityId);
            }
        });
    }

    function copyItems(cx:App):Array<CopyItem> {
        final items:Array<CopyItem> = [];
        for (registration in participants) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            final item = participant.read(cx).copyItem(registration.documentOrder);
            if (item != null) items.push(item);
        }
        return items;
    }

    /** Test helper. */
    @:allow(tests)
    function selectedText(cx:App):String {
        return TextSelection.resolveCopyItems(copyItems(cx), cx);
    }

    /**
     * Whether the current endpoints take in at least one character of some
     * participant's painted text, as opposed to two points with nothing
     * between them.
     */
    function selectsText(cx:App):Bool {
        if (snapshot() == null) return false;
        for (registration in participants) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            final participant = participant.read(cx);
            for (range in TextSelection.projectRanges(participant._snapshot, participant.runs).ranges()) {
                if (range != null && !range.isEmpty()) return true;
            }
        }
        return false;
    }

    /** Returns whether a drag or a participant-local selection is active. */
    public function hasSelection(cx:App):Bool {
        if (snapshot() != null) return true;
        for (registration in participants) {
            final participant = registration.participant.upgrade();
            if (participant != null && participant.read(cx).localSelection) return true;
        }
        return false;
    }

    /** Returns the current resolved selection endpoints. */
    public function snapshot():Null<TextSelectionSnapshot> {
        if (!didHitText) {
            return null;
        }
        final anchorEndpoint = anchor;
        if (anchorEndpoint == null) return null;
        final cursorEndpoint = cursor;
        if (cursorEndpoint == null) return null;
        final anchor = anchorEndpoint.resolve(participants);
        if (anchor == null) return null;
        final cursor = cursorEndpoint.resolve(participants);
        if (cursor == null) return null;
        if (anchor.equals(cursor)) return null;
        return TextSelectionSnapshot.create(anchorEndpoint.snapshot(), cursorEndpoint.snapshot())
            .withSelecting(isSelecting)
            .withWindowPoints(new TextSelectionWindowPoints(anchor, cursor));
    }

    /** Returns whether a drag is currently in progress (test helper). */
    @:allow(tests)
    function isSelectingNow():Bool {
        return isSelecting;
    }

    function prepareForMouseDown(extend:Bool, cx:App):Array<ClearHandler> {
        final pendingExtensionAnchor = extend ? anchor : null;
        var unit:Null<SelectionUnit> = null;
        if (extend) {
            unit = this.unit;
            this.unit = null;
        }
        if (!extend) {
            tableCellAnchor = null;
            touchSelectAll = false;
        }
        stopAnchorAutoScroll(cx);
        anchor = null;
        cursor = null;
        this.pendingExtensionAnchor = null;
        this.unit = unit;
        isSelecting = false;
        didHitText = false;
        if (touch.reset()) {
            touchChanged(cx);
        }
        pruneDeadParticipants();
        final handlers:Array<ClearHandler> = [];
        for (registration in [for (r in participants) r]) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            final handler = participant.update(cx, (state, cx) -> state.clearState(cx));
            if (handler != null) handlers.push(handler);
        }
        this.pendingExtensionAnchor = pendingExtensionAnchor;
        return handlers;
    }

    /**
     * The touch selection laid out for its handles and edit menu.
     *
     * The ends come from the participants: the first selected character of
     * the earliest participant in document order and the last of the latest.
     */
    function touchSelection():Null<TouchSelectionSnapshot> {
        if (!touch.active) {
            return null;
        }
        var startOrder:Null<Int> = null;
        var start:Null<Bounds> = null;
        var startVisible = false;
        var endOrder:Null<Int> = null;
        var end:Null<Bounds> = null;
        var endVisible = false;
        for (registration in participants) {
            final geometry = registration.registration;
            if (geometry._scope != activeScope || registration.participant.upgrade() == null) {
                continue;
            }
            final edges = geometry._selectionEdges;
            if (edges == null) {
                continue;
            }
            final order = registration.documentOrder;
            final viewport = geometry._hitbox.bounds;
            if (startOrder == null || order < startOrder) {
                startOrder = order;
                start = edges.start;
                startVisible = TouchSelectionSnapshot.caretInView(edges.start, viewport);
            }
            if (endOrder == null || order >= endOrder) {
                endOrder = order;
                end = edges.end;
                endVisible = TouchSelectionSnapshot.caretInView(edges.end, viewport);
            }
        }
        final edges = if (start != null && end != null) {
            final edges = new TouchEdges(start, end, startVisible, endVisible);
            touch.lastEdges = edges;
            edges;
        }
        else if (touch.drag != null) {
            if (touch.lastEdges == null) return null;
            touch.lastEdges;
        }
        else {
            return null;
        }
        return TouchSelectionSnapshot.create(edges.start, edges.end)
            .withEdgeVisible(SelectionEdge.Start, edges.startVisible)
            .withEdgeVisible(SelectionEdge.End, edges.endVisible)
            .withMenuOpen(touch.menuOpen)
            .withDragging(touch.drag != null ? touch.drag.edge() : null);
    }

    /**
     * The handles `participant` paints: the start when no participant earlier
     * in document order has a selection end, the end when none later has.
     */
    function touchHandlesOf(participant:Int):Array<EdgeCaret> {
        if (!touch.active) {
            return [];
        }
        final own = participants.get(participant);
        if (own == null) {
            return [];
        }
        final edges = own.registration._selectionEdges;
        if (edges == null) {
            return [];
        }
        if (edges.start.equals(edges.end)) {
            return [];
        }
        final order = own.documentOrder;
        var earlier = false;
        var later = false;
        for (id => registration in participants) {
            if (id != participant
                && registration.registration._scope == activeScope
                && registration.registration._selectionEdges != null
                && registration.participant.upgrade() != null) {
                final other = registration.documentOrder;
                if (other < order) earlier = true;
                if (other > order) later = true;
            }
        }
        final viewport = own.registration._hitbox.bounds;
        final handles:Array<EdgeCaret> = [];
        if (!earlier && TouchSelectionSnapshot.caretInView(edges.start, viewport)) {
            handles.push(new EdgeCaret(SelectionEdge.Start, edges.start));
        }
        if (!later && TouchSelectionSnapshot.caretInView(edges.end, viewport)) {
            handles.push(new EdgeCaret(SelectionEdge.End, edges.end));
        }
        return handles;
    }

    /** Keeps the selection a long press made, and opens the edit menu over it. */
    function keepTouchSelection(cx:App):Void {
        touch.active = snapshot() != null;
        touch.menuOpen = touch.active;
        touch.drag = null;
        touchChanged(cx);
    }

    /** Records where the menu is painted this frame. */
    function registerTouchUi(bounds:Bounds):Void {
        touch.uiBounds.push(bounds);
    }

    /** Whether `bounds` are where `participant` painted its handles last. */
    function handlesPaintedAt(participant:Int, bounds:Array<Bounds>):Bool {
        final painted = touch.handleBounds.get(participant);
        if (painted == null) return bounds.length == 0;
        if (painted.length != bounds.length) return false;
        for (i in 0...painted.length) if (!painted[i].equals(bounds[i])) return false;
        return true;
    }

    /** Records where `participant` painted its handles, which replace those it painted before. */
    function registerHandles(participant:Int, bounds:Array<Bounds>):Void {
        touch.handleBounds.set(participant, bounds);
    }

    function closeEditMenu(cx:App):Void {
        if (!touch.menuOpen) {
            return;
        }
        touch.menuOpen = false;
        touchChanged(cx);
    }

    /**
     * The handles follow the text, but the menu would sit over whatever
     * scrolls underneath it: it steps aside while a finger scrolls and comes
     * back over the handles once the finger lifts.
     */
    function editMenuOnScroll(phase:TouchPhase, cx:App):Void {
        if (!touch.active || touch.drag != null) {
            return;
        }
        switch phase {
            case Ended | Cancelled:
                if (!touch.menuOpen) {
                    touch.menuOpen = true;
                    touchChanged(cx);
                }
            case _:
                closeEditMenu(cx);
        }
    }

    /**
     * Selects all of the participant the touch selection started in.
     *
     * This stays a point selection, anchored on the participant's first line
     * of text and ending on its last.
     */
    function selectAllTouched(cx:App):Void {
        if (!touch.active) {
            return;
        }
        final anchorRegistration = this.anchorRegistration();
        if (anchorRegistration == null) {
            return;
        }
        final participant = anchorRegistration.participant;
        final registration = anchorRegistration.registration;
        // From the participant's text runs, not its painted line bounds: those
        // are clipped to the viewport.
        final runs = participant.read(cx).runs;
        var first:Null<TextSelectionRun> = null;
        var last:Null<TextSelectionRun> = null;
        for (run in runs) {
            if (first == null || run._documentOrder < first._documentOrder) first = run;
            // Rust `max_by_key` keeps the last of equal maxima.
            if (last == null || run._documentOrder >= last._documentOrder) last = run;
        }
        if (first == null || last == null) {
            return;
        }
        final start = first._layout.positionForIndex(0);
        final end = last._layout.positionForIndex(glaze.util.Utf8.byteLength(last._text));
        if (start == null || end == null) {
            return;
        }
        // Just inside the first and the last glyph, mid-line, so both land on text.
        final inset = 1.0;
        final anchor = new Point(start.x + inset, start.y + first._layout.lineHeight() / 2.);
        final cursor = new Point(end.x - inset, end.y + last._layout.lineHeight() / 2.);
        final contentKeyResolver = participant.read(cx).contentKeyResolver;
        function toEndpoint(windowPoint:Point):SelectionEndpoint {
            final contentPoint = windowPoint.sub(registration._bounds.origin).sub(registration._scrollOffset);
            return new SelectionEndpoint(participant.downgrade(), contentPoint, true, true, null,
                contentKeyResolver != null ? new PendingContentKey(contentKeyResolver, contentPoint) : null);
        }
        tableCellAnchor = null;
        touchSelectAll = true;
        this.anchor = toEndpoint(anchor);
        this.cursor = toEndpoint(cursor);
        didHitText = true;
        isSelecting = false;
        touch.menuOpen = true;
        publishSnapshots(cx);
        touchChanged(cx);
    }

    /**
     * Starts dragging one end of the touch selection from `finger`.
     *
     * The selection is rebuilt from the painted ends, anchored at the end that
     * stays.
     */
    function beginEdgeDrag(edge:SelectionEdge, finger:Point, window:Window, cx:App):Void {
        final snapshot = touchSelection();
        if (snapshot == null) {
            return;
        }
        final handlers = prepareForMouseDown(false, cx);
        TextSelection.dispatchClearHandlers(handlers, cx);
        final held = snapshot.edge(edge.opposite());
        // Just inside the held end, so the anchor lands on the character it
        // marks rather than on the boundary between two participants.
        final nudge = 1.0;
        final anchorPoint = switch edge {
            case Start: new Point(held.left() - nudge, held.center().y);
            case End: new Point(held.left() + nudge, held.center().y);
        }
        final anchor = endpoint(anchorPoint, null, cx);
        final drag = EdgeDrag.begin(edge, snapshot.edge(edge), finger);
        final cursor = endpoint(drag.textPosition(finger), window, cx);
        didHitText = anchor.insideText || cursor.insideText;
        this.anchor = anchor;
        this.cursor = cursor;
        isSelecting = true;
        touch.active = true;
        touch.menuOpen = false;
        touch.drag = drag;
        publishSnapshots(cx);
        touchChanged(cx);
    }

    function updateEdgeDrag(finger:Point, window:Window, cx:Context<WindowSelectionState>):Void {
        final drag = touch.drag;
        if (drag == null) {
            return;
        }
        final before = cursor;
        updateInWindow(drag.textPosition(finger), window, cx);
        // A handle never collapses the selection: at the other end it stops,
        // and the finger has to pass that end, onto text, to swap the two.
        if (!selectsText(cx.app)) {
            cursor = before;
            publishSnapshots(cx.app);
            return;
        }
        // Dragging one end past the other swaps them: the cursor now lies
        // before the anchor, so the finger holds what became the start.
        final snapshot = this.snapshot();
        final points = snapshot != null ? snapshot.windowPoints() : null;
        if (points != null) {
            final anchor = points.anchor();
            final cursor = points.cursor();
            final cursorFirst = cursor.y < anchor.y || (cursor.y == anchor.y && cursor.x < anchor.x);
            final edge = cursorFirst ? SelectionEdge.Start : SelectionEdge.End;
            if (touch.drag != null) {
                touch.drag.setEdge(edge);
            }
        }
        touchChanged(cx.app);
    }

    function endEdgeDrag(cx:App):Void {
        final drag = touch.drag;
        touch.drag = null;
        if (drag == null) {
            return;
        }
        end(cx);
        keepTouchSelection(cx);
    }

    function beginInWindow(position:Point, extend:Bool, window:Window, cx:App):Void {
        beginImpl(position, extend, true, window, cx);
    }

    function updateInWindow(position:Point, window:Window, cx:Context<WindowSelectionState>):Void {
        if (!cx.app.hasActiveDrag()) {
            updateImpl(position, window, cx.app);
            updateAutoScroll(position, window, cx);
        }
    }

    /** Selects the word or line under `position`, and returns it. */
    function selectAt(position:Point, clickCount:Int, window:Window, cx:App):Null<SelectionUnit> {
        GlobalState.init(cx);
        if (GlobalState.isTextSelectionSuppressed(cx)) {
            return null;
        }
        final hit = endpoint(position, window, cx);
        if (!hit.insideText) {
            return null;
        }
        if (hit.participant == null) return null;
        final participant = hit.participant.upgrade();
        if (participant == null) return null;
        final carets = TextSelection.caretsForMultiClick(participant.read(cx).runs, position, clickCount);
        if (carets == null) return null;
        final unit = unitOf(participant, carets.start, carets.end, clickCount, cx);
        if (unit == null) return null;
        anchor = unit.start;
        cursor = unit.end;
        didHitText = true;
        isSelecting = false;
        participant.update(cx, (state, cx) -> state.focus(window, cx.app));
        publishSnapshots(cx);
        return unit;
    }

    /**
     * The word or line of `participant` from the caret `start` to the caret
     * `end`, both in window coordinates, that `clickCount` clicks selected.
     */
    function unitOf(participant:Entity<SelectableTextState>, start:Bounds, end:Bounds, clickCount:Int, cx:App):Null<SelectionUnit> {
        final entry = participants.get(participant.entityId());
        if (entry == null) return null;
        final registration = entry.registration;
        final contentKeyResolver = participant.read(cx).contentKeyResolver;
        function toEndpoint(point:Point):SelectionEndpoint {
            final contentPoint = point.sub(registration._bounds.origin).sub(registration._scrollOffset);
            return new SelectionEndpoint(participant.downgrade(), contentPoint, true, true, null,
                contentKeyResolver != null ? new PendingContentKey(contentKeyResolver, contentPoint) : null);
        }
        return new SelectionUnit(clickCount, toEndpoint(start.origin), toEndpoint(end.origin), start.size.height, end.size.height);
    }

    /**
     * Keeps the gesture of the click that selected `unit` going: a drag from
     * it, until the button is released, and a shift-click after it extend the
     * selection by the same unit.
     */
    function holdUnit(unit:SelectionUnit, cx:App):Void {
        this.unit = unit;
        isSelecting = true;
        publishSnapshots(cx);
    }

    /**
     * Moves the cursor to the edge of the unit at `position`, which `endpoint`
     * hit, and the anchor to the far edge of `unit`. A pointer over no text
     * moves the cursor to itself, as a plain drag does.
     */
    function extendUnit(unit:SelectionUnit, position:Point, endpoint:SelectionEndpoint, cx:App):Void {
        final start = unit.start.resolve(participants);
        final end = unit.end.resolve(participants);
        if (start == null || end == null) {
            if (endpoint.insideText) didHitText = true;
            cursor = endpoint;
            return;
        }
        final startHeight = unit.startRowHeight;
        final endHeight = unit.endRowHeight;
        final before = position.y < start.y || (position.y < start.y + startHeight && position.x < start.x);
        final after = position.y >= end.y + endHeight || (position.y >= end.y && position.x > end.x);
        if (!before && !after) {
            // A participant's own multi-click selection stands until the
            // pointer leaves it.
            if (anchor != null) {
                anchor = unit.start;
                cursor = unit.end;
                didHitText = true;
            }
            return;
        }
        final edge = before ? SelectionEdge.Start : SelectionEdge.End;
        final anchor = before ? unit.end : unit.start;
        final cursor = unitEdgeAt(endpoint, position, unit.clickCount, edge, cx);
        this.anchor = anchor;
        this.cursor = cursor != null ? cursor : endpoint;
        didHitText = true;
    }

    /** `endpoint`, hit at `position`, moved to the `edge` of the word or line under the pointer. */
    static function unitEdgeAt(endpoint:SelectionEndpoint, position:Point, clickCount:Int, edge:SelectionEdge, cx:App):Null<SelectionEndpoint> {
        if (!endpoint.inside) {
            return null;
        }
        if (endpoint.participant == null) return null;
        final participant = endpoint.participant.upgrade();
        if (participant == null) return null;
        final runs = participant.read(cx).runs;
        var run:Null<TextSelectionRun> = null;
        for (candidate in runs) {
            if (candidate._bounds.contains(position)) {
                run = candidate;
                break;
            }
        }
        if (run == null) return null;
        if (glaze.util.Utf8.byteLength(run._text) != run._layout.len()) {
            return null;
        }
        // Past the end of a row, the pointer takes the character closest to it.
        final offset = switch run._layout.indexForPosition(position) {
            case Ok(ix) | Err(ix): ix;
        }
        final carets = TextSelection.unitCarets(run, offset, clickCount);
        if (carets == null) return null;
        final caret = switch edge {
            case Start: carets.start;
            case End: carets.end;
        }
        return endpoint.moved(caret.origin.sub(position));
    }

    /** Test helper. */
    @:allow(tests)
    function updateInWindowWithActiveDrag(position:Point, activeDrag:Bool, window:Window, cx:App):Void {
        if (!activeDrag) {
            updateImpl(position, window, cx);
        }
    }

    function beginImpl(position:Point, extend:Bool, alreadyPrepared:Bool, window:Null<Window>, cx:App):Void {
        GlobalState.init(cx);
        if (GlobalState.isTextSelectionSuppressed(cx)) {
            pendingExtensionAnchor = null;
            return;
        }
        var previousAnchor:Null<SelectionEndpoint> = null;
        if (extend) {
            final pending = pendingExtensionAnchor;
            pendingExtensionAnchor = null;
            previousAnchor = pending != null ? pending : anchor;
            if (previousAnchor != null && previousAnchor.resolve(participants) == null) {
                previousAnchor = null;
            }
        }
        if (!extend && !alreadyPrepared) {
            clear(cx);
        }
        final endpoint = this.endpoint(position, window, cx);
        final focusParticipant = endpoint.inside ? endpoint.participant : null;
        final anchor = previousAnchor != null ? previousAnchor : endpoint;
        this.anchor = anchor;
        this.cursor = endpoint;
        didHitText = anchor.insideText || endpoint.insideText;
        isSelecting = true;
        // A shift-click after a double or triple click extends by its unit.
        final unit = extend ? this.unit : null;
        if (unit != null) {
            extendUnit(unit, position, endpoint, cx);
        }
        final participant = focusParticipant != null ? focusParticipant.upgrade() : null;
        if (participant != null && window != null) {
            participant.update(cx, (state, cx) -> state.focus(window, cx.app));
        }
        publishSnapshots(cx);
    }

    function updateImpl(position:Point, window:Null<Window>, cx:App):Void {
        if (!isSelecting) {
            return;
        }
        final endpoint = this.endpoint(position, window, cx);
        final unit = this.unit;
        if (unit != null) {
            extendUnit(unit, position, endpoint, cx);
        }
        else {
            if (endpoint.insideText) didHitText = true;
            cursor = endpoint;
        }
        if (window == null) {
            updateParticipantAutoScroll(position, cx);
        }
        publishSnapshots(cx);
    }

    function endpoint(position:Point, window:Null<Window>, cx:App):SelectionEndpoint {
        pruneDeadParticipants();
        var hit:Null<ParticipantRegistration> = null;
        var hitArea = 0.0;
        var predecessor:Null<ParticipantRegistration> = null;
        var first:Null<ParticipantRegistration> = null;

        for (registration in participants) {
            if (registration.registration._scope != activeScope || registration.participant.upgrade() == null) {
                continue;
            }
            final geometry = registration.registration;
            final hovered = window == null ? geometry._bounds.contains(position) : geometry._hitbox.isHovered(window);
            if (hovered) {
                final area = glaze.SpringMath.f32(geometry._bounds.size.width * geometry._bounds.size.height);
                if (hit == null || area < hitArea || (area == hitArea && registration.documentOrder < hit.documentOrder)) {
                    hit = registration;
                    hitArea = area;
                }
            }
            if (geometry._bounds.top() <= position.y
                && (predecessor == null
                    || geometry._bounds.top() > predecessor.registration._bounds.top()
                    || (geometry._bounds.top() == predecessor.registration._bounds.top() && registration.documentOrder < predecessor.documentOrder))) {
                predecessor = registration;
            }
            if (first == null
                || geometry._bounds.top() < first.registration._bounds.top()
                || (geometry._bounds.top() == first.registration._bounds.top() && registration.documentOrder < first.documentOrder)) {
                first = registration;
            }
        }

        var selection:Null<ParticipantRegistration> = hit;
        var inside = hit != null;
        if (selection == null) {
            selection = predecessor != null ? predecessor : first;
            inside = false;
        }
        if (selection != null) {
            final registration = selection.registration;
            final participant = selection.participant;
            final point = position.sub(registration._bounds.origin).sub(registration._scrollOffset);
            final live = participant.upgrade();
            final resolver = live != null ? live.read(cx).contentKeyResolver : null;
            var insideText = false;
            if (inside) {
                for (bounds in registration._textBounds) {
                    if (bounds.contains(position)) {
                        insideText = true;
                        break;
                    }
                }
            }
            return new SelectionEndpoint(participant, point, inside, insideText, null, resolver != null ? new PendingContentKey(resolver, point) : null);
        }
        return new SelectionEndpoint(null, position, false, false, null, null);
    }

    function publishSnapshots(cx:App):Void {
        pruneDeadParticipants();
        for (change in changedSnapshots(cx)) {
            drawChanged.remove(change.participant.entityId());
            change.participant.update(cx, (state, cx) -> state.setSnapshot(change.snapshot, cx));
        }
    }

    function participantSnapshot(id:Int):Null<TextSelectionSnapshot> {
        snapshotVisits++;

        final registration = participants.get(id);
        if (registration == null) return null;
        if (registration.registration._scope != activeScope || !participates(id, registration)) return null;
        final single = singleParticipant();
        if (single != null && single != id) return null;
        final snapshot = this.snapshot();
        return snapshot != null ? snapshot.withCoverage(coverageFor(id)) : null;
    }

    function changedSnapshots(cx:App):Array<SnapshotChange> {
        final changes:Array<SnapshotChange> = [];
        for (id => registration in participants) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            final snapshot = participantSnapshot(id);
            if (!TextSelectionSnapshot.eq(participant.read(cx)._snapshot, snapshot)) {
                changes.push(new SnapshotChange(participant, snapshot));
            }
        }
        return changes;
    }

    function coverageFor(id:Int):TextSelectionCoverage {
        final anchor = this.anchor != null ? this.anchor.entityId() : null;
        if (anchor == null) {
            return Bounded;
        }
        final cursor = this.cursor != null ? this.cursor.entityId() : null;
        if (cursor == null) {
            return Bounded;
        }
        if (anchor == cursor) {
            return Bounded;
        }
        final anchorOrder = participants.get(anchor).documentOrder;
        final cursorOrder = participants.get(cursor).documentOrder;
        if (id != anchor && id != cursor) {
            return Full;
        }
        else if ((id == anchor) == (anchorOrder < cursorOrder)) {
            return ToEnd;
        }
        else {
            return FromStart;
        }
    }

    function singleParticipant():Null<Int> {
        if (anchor == null) return null;
        final anchor = anchor.entityId();
        if (anchor == null) return null;
        if (cursor == null) return null;
        final cursor = cursor.entityId();
        if (cursor == null) return null;
        return anchor == cursor ? anchor : null;
    }

    function participates(id:Int, registration:ParticipantRegistration):Bool {
        final anchor = this.anchor != null ? this.anchor.entityId() : null;
        if (anchor == null) return false;
        final cursor = this.cursor != null ? this.cursor.entityId() : null;
        if (cursor == null) return false;
        final anchorRegistration = participants.get(anchor);
        if (anchorRegistration == null) return false;
        final cursorRegistration = participants.get(cursor);
        if (cursorRegistration == null) return false;
        final start = anchorRegistration.documentOrder < cursorRegistration.documentOrder ? anchorRegistration.documentOrder : cursorRegistration.documentOrder;
        final end = anchorRegistration.documentOrder > cursorRegistration.documentOrder ? anchorRegistration.documentOrder : cursorRegistration.documentOrder;
        return (registration.documentOrder >= start && registration.documentOrder <= end) || id == anchor || id == cursor;
    }

    function updateAutoScroll(position:Point, window:Window, cx:Context<WindowSelectionState>):Void {
        // A finished gesture keeps its anchor for shift-click extension; only
        // a live drag may scroll.
        if (!isSelecting) {
            return;
        }
        final anchorRegistration = this.anchorRegistration();
        if (anchorRegistration == null) {
            return;
        }
        final registration = anchorRegistration.registration;
        // Exactly one writer per drag: a participant that scrolls its own
        // content is notified directly; anything else gets a synthetic wheel.
        if (registration.selfScroll) {
            autoScroll.stop();
            updateParticipantAutoScroll(position, cx.app);
            return;
        }
        // The content mask is the nearest clipping viewport established by a
        // scrollable ancestor.
        final visibleBounds = registration._hitbox.contentMask.bounds;
        // Keeps the synthesized wheel event hit-testing inside the mask.
        final HIT_TEST_INSET = 1.0;
        // A collapsed mask leaves an empty clamp range below: stop.
        if (visibleBounds.size.width < HIT_TEST_INSET * 2. || visibleBounds.size.height < HIT_TEST_INSET * 2.) {
            stopAnchorAutoScroll(cx.app);
            return;
        }
        final delta = AutoScroll.computeDelta(position.y, visibleBounds);
        final eventPosition = new Point(
            clamp(position.x, visibleBounds.left() + HIT_TEST_INSET, visibleBounds.right() - HIT_TEST_INSET),
            clamp(position.y, visibleBounds.top() + HIT_TEST_INSET, visibleBounds.bottom() - HIT_TEST_INSET)
        );
        autoScroll.lastDragPosition = eventPosition;
        autoScrollStall = new AutoScrollStall();
        autoScroll.set(delta, cx, (delta, state, cx) -> {
            final position = state.autoScroll.lastDragPosition;
            if (position == null) {
                return;
            }
            // Hold off once the container has shown, over a few ticks, that
            // it has nowhere left to go; the next move of the finger asks
            // again.
            final STALLED_TICKS = 3;
            final anchor = state.anchorRegistration();
            final bounds = anchor != null ? anchor.registration._bounds : null;
            final scrollOffset = anchor != null ? anchor.registration._scrollOffset : null;
            final stall = state.autoScrollStall;
            final same = (bounds == null ? stall.bounds == null : bounds.equals(stall.bounds))
                && (scrollOffset == null ? stall.scrollOffset == null : scrollOffset.equals(stall.scrollOffset));
            if (same) {
                if (stall.stalled < 255) stall.stalled += 1;
                if (stall.stalled >= STALLED_TICKS) {
                    return;
                }
            }
            else {
                stall.bounds = bounds;
                stall.scrollOffset = scrollOffset;
                stall.stalled = 0;
            }
            cx.defer(cx -> {
                if (!Window.windows.contains(window)) return;
                window.dispatchEvent(new ScrollEvent(position, ScrollDelta.Pixels(new Point(0, -delta))).toPlatformInput(), cx);
            });
        });
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /**
     * Drives the anchor participant's own scrolling, measured against the
     * visible portion of the participant's element bounds.
     */
    function updateParticipantAutoScroll(position:Point, cx:App):Void {
        final anchorRegistration = this.anchorRegistration();
        if (anchorRegistration == null) {
            return;
        }
        final registration = anchorRegistration.registration;
        final visibleBounds = registration._bounds.intersect(registration._hitbox.contentMask.bounds);
        final delta = visibleBounds.size.width > 0 && visibleBounds.size.height > 0
            ? AutoScroll.computeDelta(position.y, visibleBounds)
            : null;
        anchorRegistration.participant.update(cx, (state, cx) -> state.setAutoScroll(delta, cx));
    }

    function stopAnchorAutoScroll(cx:App):Void {
        autoScroll.stop();
        final participant = anchorParticipant();
        if (participant == null) {
            return;
        }
        participant.update(cx, (state, cx) -> state.setAutoScroll(null, cx));
    }

    /** The live participant owning the anchor of the current gesture. */
    function anchorParticipant():Null<Entity<SelectableTextState>> {
        final anchor = this.anchor;
        if (anchor == null || !anchor.inside || anchor.participant == null) return null;
        return anchor.participant.upgrade();
    }

    /** The anchor participant together with its current frame registration. */
    function anchorRegistration():Null<AnchorRegistration> {
        final participant = anchorParticipant();
        if (participant == null) return null;
        final registration = participants.get(participant.entityId());
        if (registration == null) return null;
        return new AnchorRegistration(participant, registration.registration);
    }

    function pruneDeadParticipants():Void {
        for (id in [for (id in participants.keys()) id]) {
            if (participants.get(id).participant.upgrade() == null) {
                participants.remove(id);
            }
        }
    }

}

/** Rust `(Entity<SelectableTextState>, Option<TextSelectionSnapshot>)`. */
class SnapshotChange {
    public final participant:Entity<SelectableTextState>;
    public final snapshot:Null<TextSelectionSnapshot>;

    public inline function new(participant:Entity<SelectableTextState>, snapshot:Null<TextSelectionSnapshot>) {
        this.participant = participant;
        this.snapshot = snapshot;
    }
}
