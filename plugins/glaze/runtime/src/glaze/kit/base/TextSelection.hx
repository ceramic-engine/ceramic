// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;
import glaze.Bounds;
import glaze.Entity;
import glaze.IntoElement;
import glaze.LongPressEvent;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.Point;
import glaze.Range;
import glaze.ScrollEvent;
import glaze.Subscription;
import glaze.TextLayout;
import glaze.TouchDragEvent;
import glaze.Window;
import glaze.kit.base.SelectableTextState;
import glaze.kit.base.TextSelectionRegistration.BoundsPair;
import glaze.kit.base.WindowSelectionState;
import glaze.kit.base.TextSelectionLayer.TextSelectionScopeMarker;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TextBoundary;
import glaze.kit.base.input.TouchSelectionSnapshot;
import glaze.util.Utf8;

/**
 * Window-level operations for text selection, and the helpers of Rust's
 * `text_selection` module.
 */
class TextSelection {

    /**
     * Returns whether `position` hits selectable text in the active scope.
     *
     * Uses the current frame's registered text geometry and hitboxes without
     * starting or changing a selection.
     */
    public static function isSelectableAt(position:Point, window:Window, cx:App):Bool {
        final state = liveTextSelectionState(window, cx);
        if (state == null) return false;
        return state.update(cx, (state, cx) -> !state.touch.covers(position) && state.endpoint(position, window, cx.app).insideText);
    }

    /** Returns the currently selected text in logical document order. */
    public static function selectedText(window:Window, cx:App):String {
        final state = liveTextSelectionState(window, cx);
        if (state == null) {
            return '';
        }
        final items = state.read(cx).copyItems(cx);
        return resolveCopyItems(items, cx);
    }

    /**
     * Returns whether the window has a geometry selection or any participant
     * has an active participant-local selection such as select-all.
     */
    public static function hasSelection(window:Window, cx:App):Bool {
        final state = liveTextSelectionState(window, cx);
        return state != null && state.read(cx).hasSelection(cx);
    }

    /** Clears window selection and every participant's local selection. */
    public static function clear(window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            final handlers = state.update(cx, (state, cx) -> state.clearState(cx.app));
            dispatchClearHandlers(handlers, cx);
        }
    }

    /** Clears selection for a known window identifier. */
    public static function clearForWindow(windowId:Int, cx:App):Void {
        clearWindowTextSelection(windowId, cx);
    }

    /** Ends the current drag while leaving its selection visible. */
    public static function end(window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.end(cx.app));
        }
    }

    /**
     * Calls `callback` whenever the touch selection changes: it appears, its
     * handles move, its menu opens or closes, or it goes away.
     */
    public static function observeTouchSelection(window:Window, cx:App, callback:(App) -> Void):Subscription {
        final state = WindowSelectionState.acquire(window, cx);
        return cx.observe(state, (_, cx) -> callback(cx));
    }

    /**
     * Returns the selection a long press made, laid out for its handles and
     * edit menu, or `null` when the selection was made with a pointer.
     */
    public static function touchSelection(window:Window, cx:App):Null<TouchSelectionSnapshot> {
        final state = WindowSelectionState.existing(window, cx);
        return state != null ? state.read(cx).touchSelection() : null;
    }

    /**
     * Records where a touch handle or the edit menu is painted this frame, so
     * that pressing it does not clear the selection it belongs to.
     */
    public static function registerTouchUi(bounds:Bounds, window:Window, cx:App):Void {
        final state = WindowSelectionState.existing(window, cx);
        if (state != null) {
            state.update(cx, (state, _) -> state.registerTouchUi(bounds));
        }
    }

    /** Closes the edit menu and keeps the selection with its handles. */
    public static function closeEditMenu(window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.closeEditMenu(cx.app));
        }
    }

    /**
     * Selects all of the text the touch selection started in, keeping the
     * handles and the edit menu over the result.
     */
    public static function selectAll(window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.selectAllTouched(cx.app));
        }
    }

    /** Starts dragging one end of the touch selection from `finger`. */
    public static function beginEdgeDrag(edge:SelectionEdge, finger:Point, window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.beginEdgeDrag(edge, finger, window, cx.app));
            WindowSelectionState.resolveContentKeys(state, cx);
        }
    }

    /** Moves the dragged end to the text under `finger`. */
    public static function updateEdgeDrag(finger:Point, window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.updateEdgeDrag(finger, window, cx));
            WindowSelectionState.resolveContentKeys(state, cx);
        }
    }

    /** Ends the handle drag and reopens the edit menu over the result. */
    public static function endEdgeDrag(window:Window, cx:App):Void {
        final state = liveTextSelectionState(window, cx);
        if (state != null) {
            state.update(cx, (state, cx) -> state.endEdgeDrag(cx.app));
        }
    }

    /** Activates the opaque selection scope for this window. */
    public static function activateScope(scope:TextSelectionScopeId, window:Window, cx:App):Void {
        final state = WindowSelectionState.existing(window, cx);
        if (state == null) {
            if (WindowSelectionState.globalOf(cx, PendingTextSelectionScopes) == null) {
                cx.setGlobal(new PendingTextSelectionScopes(), PendingTextSelectionScopes);
            }
            WindowSelectionState.globalOf(cx, PendingTextSelectionScopes).map.set(window.id, scope);
            return;
        }
        if (state.read(cx).activeScope == scope) {
            return;
        }
        final handlers = state.update(cx, (state, cx) -> state.setActiveScopeState(scope, cx.app));
        dispatchClearHandlers(handlers, cx);
    }

    // Module helpers

    /**
     * Projects a participant selection snapshot onto laid-out plain-text runs.
     *
     * The returned states retain the input order so callers can pair every
     * state with its run. The ranges are always character boundaries.
     */
    @:allow(glaze.kit.base)
    static function projectRanges(snapshot:Null<TextSelectionSnapshot>, runs:Array<TextSelectionRun>):TextSelectionProjection {
        if (snapshot == null) {
            return new TextSelectionProjection([for (_ in runs) null], false);
        }
        final windowPoints = snapshot.windowPoints();
        if (windowPoints == null) {
            return new TextSelectionProjection([for (_ in runs) null], true);
        }
        return new TextSelectionProjection([for (run in runs) selectionRangeForRun(run, windowPoints.anchor(), windowPoints.cursor())], true);
    }

    static function selectionRangeForRun(run:TextSelectionRun, selectionStart:Point, selectionEnd:Point):Null<Range> {
        final textLen = Utf8.byteLength(run._text);
        if (textLen != run._layout.len()) {
            return null;
        }

        if (textLen == 0) {
            return null;
        }

        final lineHeight = run._layout.lineHeight();
        // Each character is tested with its row's top and height, so a run
        // whose rows all miss the band, or all lie strictly inside it with no
        // endpoint on any row, has the same answer for every character.
        final extent = textRowsExtent(run._layout, lineHeight);
        final rowsTop = extent.top;
        final rowsBottom = extent.bottom;
        final bandTop = Math.min(selectionStart.y, selectionEnd.y);
        final bandBottom = Math.max(selectionStart.y, selectionEnd.y);
        if (rowsBottom <= bandTop || rowsTop > bandBottom) {
            return null;
        }
        if (bandTop < rowsTop && bandBottom >= rowsBottom) {
            return new Range(0, textLen);
        }

        var rangeStart = -1;
        var rangeEnd = -1;
        var offset = 0;
        for (character in new haxe.iterators.StringIteratorUnicode(run._text)) {
            final nextOffset = offset + Utf8.codePointLength(character);
            final position = run._layout.positionForIndex(offset);
            if (position != null) {
                final next = run._layout.positionForIndex(nextOffset);
                final charWidth = next != null && next.y == position.y ? f32(next.x - position.x) : f32(lineHeight / 2);

                if (pointInSelectionBand(position, charWidth, selectionStart, selectionEnd, lineHeight)) {
                    if (rangeStart == -1) rangeStart = offset;
                    rangeEnd = nextOffset;
                }
            }
            offset = nextOffset;
        }
        return rangeStart == -1 ? null : new Range(rangeStart, rangeEnd);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    /**
     * The top of the first laid-out row of `textLayout` and the bottom of its
     * last one, each row `lineHeight` tall as a selection band test sees it.
     */
    public static function textRowsExtent(textLayout:TextLayout, lineHeight:Float):RowsExtent {
        final top = textLayout.bounds().top();
        final layoutLineHeight = textLayout.lineHeight();
        final lines = textLayout.lineLayouts();
        var lastLineTop = top;
        for (i in 0...(lines.length > 0 ? lines.length - 1 : 0)) {
            lastLineTop = f32(lastLineTop + lines[i].size(layoutLineHeight).height);
        }
        final lineHeightValue:Float = layoutLineHeight;
        final lastRowTop = lines.length == 0 ? top : f32(lastLineTop + f32(lines[lines.length - 1].wrapBoundaries.length * lineHeightValue));
        return new RowsExtent(top, f32(lastRowTop + lineHeight));
    }

    /**
     * The carets at the two ends of what `clickCount` clicks at `position`
     * select: the word under it for two, its line or paragraph for three.
     */
    @:allow(glaze.kit.base)
    static function caretsForMultiClick(runs:Array<TextSelectionRun>, position:Point, clickCount:Int):Null<BoundsPair> {
        var run:Null<TextSelectionRun> = null;
        for (candidate in runs) {
            if (candidate._bounds.contains(position)) {
                run = candidate;
                break;
            }
        }
        if (run == null) return null;
        if (Utf8.byteLength(run._text) != run._layout.len()) {
            return null;
        }
        final offset = switch run._layout.indexForPosition(position) {
            case Ok(ix): ix;
            case Err(_): return null;
        }
        return unitCarets(run, offset, clickCount);
    }

    /**
     * The carets at the two ends of the word (`clickCount` 2) or the run's
     * triple-click boundary (3 or more) at the byte `offset` of `run`.
     */
    @:allow(glaze.kit.base)
    static function unitCarets(run:TextSelectionRun, offset:Int, clickCount:Int):Null<BoundsPair> {
        final range = if (clickCount == 2) {
            final range = TextBoundary.wordRangeAt(run._text, offset);
            if (range == null) return null;
            range;
        }
        else if (clickCount >= 3) {
            switch run.tripleClick {
                case LogicalLine: TextBoundary.lineRangeAt(run._text, offset);
                case Paragraph: new Range(0, Utf8.byteLength(run._text));
                case Row(row):
                    return new BoundsPair(
                        TouchSelectionSnapshot.caretLineBox(row.origin, row.size.height),
                        TouchSelectionSnapshot.caretLineBox(row.topRight(), row.size.height)
                    );
            }
        }
        else {
            return null;
        }
        if (range.isEmpty()) {
            return null;
        }
        final lineHeight = run._layout.lineHeight();
        final start = run._layout.positionForIndex(range.start);
        if (start == null) return null;
        final end = run._layout.positionForIndex(range.end);
        if (end == null) return null;
        return new BoundsPair(TouchSelectionSnapshot.caretLineBox(start, lineHeight), TouchSelectionSnapshot.caretLineBox(end, lineHeight));
    }

    static function pointInSelectionBand(position:Point, charWidth:Float, selectionStart:Point, selectionEnd:Point, lineHeight:Float):Bool {
        inline function pointInLine(point:Point):Bool {
            return point.y >= position.y && point.y < f32(position.y + lineHeight);
        }
        final top = Math.min(selectionStart.y, selectionEnd.y);
        final bottom = Math.max(selectionStart.y, selectionEnd.y);
        final x = f32(position.x + f32(charWidth / 2));

        if (f32(position.y + lineHeight) <= top || position.y > bottom) {
            return false;
        }

        if (pointInLine(selectionStart) && pointInLine(selectionEnd)) {
            final left = Math.min(selectionStart.x, selectionEnd.x);
            final right = Math.max(selectionStart.x, selectionEnd.x);
            return x >= left && x <= right;
        }

        final topPoint = selectionStart.y < selectionEnd.y ? selectionStart : selectionEnd;
        final bottomPoint = selectionStart.y < selectionEnd.y ? selectionEnd : selectionStart;
        if (pointInLine(topPoint)) {
            return x >= topPoint.x;
        }
        else if (pointInLine(bottomPoint)) {
            return x <= bottomPoint.x;
        }
        else {
            return true;
        }
    }

    @:allow(glaze.kit.base)
    static function resolveCopyItems(items:Array<CopyItem>, cx:App):String {
        // Stable, like Rust's `sort_by_key`.
        haxe.ds.ArraySort.sort(items, (a, b) -> a.documentOrder < b.documentOrder ? -1 : (a.documentOrder > b.documentOrder ? 1 : 0));
        final texts:Array<String> = [];
        for (item in items) {
            final text = item.callback != null ? item.callback(cx) : item.fallback;
            if (StringTools.trim(text).length > 0) {
                texts.push(text);
            }
        }
        return texts.join('\n');
    }

    @:allow(glaze.kit.base)
    static function dispatchClearHandlers(handlers:Array<ClearHandler>, cx:App):Void {
        for (handler in handlers) {
            handler(cx);
        }
    }

    @:allow(glaze.kit.base)
    static function clearDepartedParticipants(participants:Array<Entity<SelectableTextState>>, cx:App):Array<ClearHandler> {
        final handlers:Array<ClearHandler> = [];
        for (participant in participants) {
            if (participant.read(cx).hasSelectionToClear()) {
                final handler = participant.update(cx, (state, cx) -> state.clearState(cx));
                if (handler != null) handlers.push(handler);
            }
        }
        return handlers;
    }

    static function pushTextSelectionScope(windowId:Int, scope:TextSelectionScopeId, cx:App):Void {
        if (WindowSelectionState.globalOf(cx, TextSelectionScopeStacks) == null) {
            cx.setGlobal(new TextSelectionScopeStacks(), TextSelectionScopeStacks);
        }
        final stacks = WindowSelectionState.globalOf(cx, TextSelectionScopeStacks).map;
        var stack = stacks.get(windowId);
        if (stack == null) {
            stack = [];
            stacks.set(windowId, stack);
        }
        stack.push(scope);
        // The views drawn inside read it: see `Window.enterSharedContext`
        glaze.Window.enterSharedContext();
    }

    static function popTextSelectionScope(windowId:Int, cx:App):Void {
        final stacks = WindowSelectionState.globalOf(cx, TextSelectionScopeStacks).map;
        final stack = stacks.get(windowId);
        glaze.Window.exitSharedContext();
        if (stack != null) {
            glaze.util.Stacks.drop(stack);
            if (stack.length == 0) {
                stacks.remove(windowId);
            }
        }
    }

    @:allow(glaze.kit.base)
    static function currentTextSelectionScope(windowId:Int, cx:App):Null<TextSelectionScopeId> {
        if (WindowSelectionState.globalOf(cx, TextSelectionScopeStacks) == null) return null;
        final stack = WindowSelectionState.globalOf(cx, TextSelectionScopeStacks).map.get(windowId);
        return stack != null && stack.length > 0 ? stack[stack.length - 1] : null;
    }

    @:allow(glaze.kit.base)
    static function withTextSelectionScope<T>(windowId:Int, scope:TextSelectionScopeId, cx:App, callback:(App) -> T):T {
        pushTextSelectionScope(windowId, scope, cx);
        try {
            final result = callback(cx);
            popTextSelectionScope(windowId, cx);
            return result;
        }
        catch (e:Dynamic) {
            popTextSelectionScope(windowId, cx);
            throw glaze.util.Exceptions.rethrow(e);
        }
    }

    /** Rust `text_selection_scope(scope, element)`: see `ElementExt.textSelectionScope`. */
    public static function textSelectionScope(scope:TextSelectionScopeId, element:IntoElement):IntoElement {
        return new TextSelectionScopeMarker(scope, element.intoAnyElement());
    }

    @:allow(glaze.kit.base)
    static function retainTextSelectionState(globalId:Null<glaze.GlobalElementId>, window:Window, cx:App):Entity<WindowSelectionState> {
        if (globalId == null) throw 'TextSelection has a stable element id';
        final windowId = window.id;
        final state:Entity<WindowSelectionState> = window.withElementState(globalId, WindowSelectionState, (retained, window) -> {
            if (retained.value == null) {
                retained.value = WindowSelectionState.acquire(window, cx);
            }
            return (retained.value : Entity<WindowSelectionState>);
        });
        // Registered once: writing the global again every frame would change
        // it, and every view that reads it, on every frame.
        var registered = false;
        if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) != null) {
            final current = WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.get(windowId);
            registered = current != null && current.entityId() == state.entityId();
        }
        if (!registered) {
            if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) == null) {
                cx.setGlobal(new SelectionStateRegistry(), SelectionStateRegistry);
            }
            WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.set(windowId, state.downgrade());
        }
        return state;
    }

    @:allow(glaze.kit.base)
    static function scheduleSelectionFrame(state:Entity<WindowSelectionState>, window:Window, cx:App):Void {
        if (state.read(cx).scheduleFinishFrame()) {
            final weak = state.downgrade();
            window.defer(cx, (window, cx) -> {
                final state = weak.upgrade();
                if (state == null) {
                    return;
                }
                final stale = state.read(cx).staleParticipants(state.read(cx).layerPainted);
                // Retiring an endpoint is a real selection change. Ordinary
                // frame publication does not write the shared window entity.
                final handlers = state.read(cx).endpointDeparted(stale)
                    ? state.update(cx, (state, cx) -> state.clearState(cx.app))
                    : [];
                final departed = state.read(cx).removeStaleParticipants(stale);
                for (handler in clearDepartedParticipants(departed, cx)) handlers.push(handler);
                final refreshOrder = state.read(cx).finishRegistrations();
                final changes:Map<Int, SnapshotChange> = new Map();
                final order:Array<Int> = [];
                for (change in state.read(cx).changedSnapshots(cx)) {
                    final id = change.participant.entityId();
                    if (!changes.exists(id)) order.push(id);
                    changes.set(id, change);
                }
                final drawn = state.read(cx).drawChanged;
                state.read(cx).drawChanged = new Map();
                for (id => participant in drawn) {
                    final participant = participant.upgrade();
                    if (participant != null && !changes.exists(id)) {
                        changes.set(id, new SnapshotChange(participant, participant.read(cx)._snapshot));
                        order.push(id);
                    }
                }
                for (id in order) {
                    final change = changes.get(id);
                    change.participant.update(cx, (participant, cx) -> {
                        participant.setSnapshotQuietly(change.snapshot);
                        cx.emit(TextSelectionEvent.SelectionChanged(change.snapshot));
                    });
                }
                dispatchClearHandlers(handlers, cx);
                if (refreshOrder) {
                    // GPUI does not expose the position of a replayed subtree
                    // in paint order. Recover it once after an incomplete
                    // topology change, not on ordinary partial selection redraws.
                    window.refresh();
                }
                if (state.read(cx).touchEdgesMoved) {
                    state.read(cx).touchEdgesMoved = false;
                    state.update(cx, (state, cx) -> state.touchChanged(cx.app));
                }
                // Direct participant scrolling produces no wheel event. Refresh
                // the held cursor after paint registers the new scroll geometry.
                final refreshHeldCursor = state.read(cx).refreshHeldCursor;
                state.read(cx).refreshHeldCursor = false;
                if (refreshHeldCursor && state.read(cx).isSelecting) {
                    state.update(cx, (state, cx) -> {
                        // A handle drag holds the finger off the text; keep the
                        // same offset, or the cursor would hop between the two.
                        var position = window.mousePosition();
                        if (state.touch.drag != null) position = state.touch.drag.textPosition(position);
                        state.updateInWindow(position, window, cx);
                    });
                    WindowSelectionState.resolveContentKeys(state, cx);
                }
            });
        }
    }

    @:allow(glaze.kit.base)
    static function paintTextSelection(state:Entity<WindowSelectionState>, window:Window, cx:App):Void {
        scheduleSelectionFrame(state, window, cx);

        final mouseDownState = state.downgrade();
        window.onMouseEvent(MouseDown, (event, phase, window, cx) -> {
            final event:MouseDownEvent = cast event;
            if (event.button != MouseButton.Left) {
                return;
            }
            final state = mouseDownState.upgrade();
            if (state == null) {
                return;
            }
            // A press on a handle or on the edit menu acts on the selection;
            // it must not clear it.
            if (state.read(cx).touch.covers(event.position)) {
                return;
            }
            if (phase.capture()) {
                GlobalState.init(cx);
                GlobalState.resetTextSelectionSuppression(cx);
                final handlers = state.update(cx, (state, cx) -> {
                    if (state.mouseDownPrepared) {
                        return [];
                    }
                    state.mouseDownPrepared = true;
                    return state.prepareForMouseDown(event.clickCount == 1 && event.modifiers.shift, cx.app);
                });
                dispatchClearHandlers(handlers, cx);
            }
            else if (event.clickCount == 1) {
                if (GlobalState.isTextSelectionSuppressed(cx)) {
                    state.update(cx, (state, _) -> state.pendingExtensionAnchor = null);
                    return;
                }
                state.update(cx, (state, cx) -> {
                    if (!state.isSelecting) {
                        state.beginInWindow(event.position, event.modifiers.shift, window, cx.app);
                    }
                });
                WindowSelectionState.resolveContentKeys(state, cx);
            }
            else if (event.clickCount >= 2) {
                if (GlobalState.isTextSelectionSuppressed(cx)) {
                    return;
                }
                final touch = GlobalState.isTouchPress(cx);
                state.update(cx, (state, cx) -> {
                    final unit = state.selectAt(event.position, event.clickCount, window, cx.app);
                    // A double tap is touch's other way to select a word, and
                    // it gets the handles and the menu like a long press does.
                    if (touch) {
                        state.keepTouchSelection(cx.app);
                    }
                    else if (unit != null) {
                        state.holdUnit(unit, cx.app);
                    }
                });
                WindowSelectionState.resolveContentKeys(state, cx);
            }
        });

        // Every touch is offered as a drag first; that is how a tap's mouse
        // events are later told apart from a mouse's.
        window.onMouseEvent(TouchDrag, (event, phase, _, cx) -> {
            final event:TouchDragEvent = cast event;
            if (phase.capture() && event.phase == Started) {
                GlobalState.noteTouch(cx);
            }
        });

        // Touch panning remains scrolling until a long press actually hits
        // text. Claiming the gesture keeps subsequent moves out of the pan
        // recognizer.
        final longPressState = state.downgrade();
        window.onMouseEvent(LongPress, (event, phase, window, cx) -> {
            final event:LongPressEvent = cast event;
            if (!phase.bubble()) {
                return;
            }
            final state = longPressState.upgrade();
            if (state == null) {
                return;
            }
            if (event.phase == Started) {
                if (window.defaultPrevented()
                    || state.read(cx).touch.covers(event.startPosition)
                    || !state.update(cx, (state, cx) -> state.endpoint(event.startPosition, window, cx.app).insideText)) {
                    return;
                }
                GlobalState.init(cx);
                GlobalState.resetTextSelectionSuppression(cx);
                final handlers = state.update(cx, (state, cx) -> state.prepareForMouseDown(false, cx.app));
                dispatchClearHandlers(handlers, cx);
                final selected = state.update(cx, (state, cx) -> {
                    state.selectAt(event.startPosition, 2, window, cx.app);
                    return state.anchor != null;
                });
                if (!selected) {
                    return;
                }
                window.captureLongPress(state);
            }
            else if (!window.hasLongPressCapture(state)) {
                return;
            }
            else {
                state.update(cx, (state, cx) -> {
                    switch event.phase {
                        case Moved:
                            state.isSelecting = true;
                            state.updateInWindow(event.position, window, cx);
                        case Ended | Cancelled:
                            state.end(cx.app);
                            // The finger is up; the selection it made gets
                            // its handles and the edit menu.
                            state.keepTouchSelection(cx.app);
                        case _:
                    }
                });
            }
            window.preventDefault();
            cx.stopPropagation();
            WindowSelectionState.resolveContentKeys(state, cx);
        });

        // A handle drag in progress follows the finger or the pointer
        // wherever it goes, whether or not the handle it took is laid out
        // this frame.
        final touchDragState = state.downgrade();
        window.onMouseEvent(TouchDrag, (event, phase, window, cx) -> {
            final event:TouchDragEvent = cast event;
            if (!phase.bubble() || event.phase == Started) {
                return;
            }
            final state = touchDragState.upgrade();
            if (state == null || state.read(cx).touch.drag == null) {
                return;
            }
            cx.stopPropagation();
            state.update(cx, (state, cx) -> {
                switch event.phase {
                    case Moved: state.updateEdgeDrag(event.position, window, cx);
                    case _: state.endEdgeDrag(cx.app);
                }
            });
            WindowSelectionState.resolveContentKeys(state, cx);
        });

        // A handle drag in progress follows the pointer wherever it goes,
        // whether or not the handle it took is laid out this frame.
        final dragState = state.downgrade();
        window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
            final event:MouseMoveEvent = cast event;
            if (phase.bubble() && event.pressedButton == MouseButton.Left) {
                final state = dragState.upgrade();
                if (state != null && state.read(cx).touch.drag != null) {
                    state.update(cx, (state, cx) -> state.updateEdgeDrag(event.position, window, cx));
                    WindowSelectionState.resolveContentKeys(state, cx);
                }
            }
        });
        final dragUpState = state.downgrade();
        window.onMouseEvent(MouseUp, (event, phase, _, cx) -> {
            final event:glaze.MouseUpEvent = cast event;
            if (phase.bubble() && event.button == MouseButton.Left) {
                final state = dragUpState.upgrade();
                if (state != null) {
                    state.update(cx, (state, cx) -> state.endEdgeDrag(cx.app));
                }
            }
        });

        final mouseMoveState = state.downgrade();
        window.onMouseEvent(MouseMove, (event, phase, window, cx) -> {
            final event:MouseMoveEvent = cast event;
            if (phase.bubble()) {
                final state = mouseMoveState.upgrade();
                // Moving the pointer only moves a selection being made.
                if (state != null && state.read(cx).isSelecting) {
                    state.update(cx, (state, cx) -> {
                        // A handle drag maps the pointer through the handle's
                        // offset; the raw pointer must not fight it.
                        if (state.touch.drag != null) {
                            return;
                        }
                        state.updateInWindow(event.position, window, cx);
                    });
                    WindowSelectionState.resolveContentKeys(state, cx);
                }
            }
        });

        final mouseUpState = state.downgrade();
        window.onMouseEvent(MouseUp, (_, phase, _, cx) -> {
            if (phase.bubble()) {
                final state = mouseUpState.upgrade();
                if (state != null) {
                    state.update(cx, (state, cx) -> {
                        state.mouseDownPrepared = false;
                        state.end(cx.app);
                    });
                }
            }
        });

        final scrollState = state.downgrade();
        window.onMouseEvent(Scroll, (event, phase, window, cx) -> {
            final event:ScrollEvent = cast event;
            final state = scrollState.upgrade();
            if (state == null) {
                return;
            }
            // On capture, before a scroll container can stop the event: one
            // stretched past its end swallows the whole stream, the lift
            // included, and the menu would never come back.
            if (phase.capture()) {
                if (state.read(cx).touch.active) {
                    state.update(cx, (state, cx) -> state.editMenuOnScroll(event.touchPhase, cx.app));
                }
                return;
            }
            // A scroll only moves a selection being made under the pointer.
            if (phase.bubble() && state.read(cx).isSelecting) {
                var position = window.mousePosition();
                state.update(cx, (state, cx) -> {
                    // A handle drag holds the finger off the text; keep its offset.
                    if (state.touch.drag != null) position = state.touch.drag.textPosition(position);
                    state.updateInWindow(position, window, cx);
                });
                WindowSelectionState.resolveContentKeys(state, cx);
            }
        });
    }

    static function liveTextSelectionState(window:Window, cx:App):Null<Entity<WindowSelectionState>> {
        return WindowSelectionState.existing(window, cx);
    }

    @:allow(glaze)
    static function clearWindowTextSelection(windowId:Int, cx:App):Void {
        if (WindowSelectionState.globalOf(cx, SelectionStateRegistry) == null) {
            return;
        }
        final weak = WindowSelectionState.globalOf(cx, SelectionStateRegistry).map.get(windowId);
        final state = weak != null ? weak.upgrade() : null;
        if (state == null) {
            return;
        }
        final handlers = state.update(cx, (state, cx) -> state.clearState(cx.app));
        dispatchClearHandlers(handlers, cx);
    }

}

/** Rust `(Pixels, Pixels)` of `text_rows_extent`. */
class RowsExtent {
    public final top:Float;
    public final bottom:Float;

    public inline function new(top:Float, bottom:Float) {
        this.top = top;
        this.bottom = bottom;
    }
}
