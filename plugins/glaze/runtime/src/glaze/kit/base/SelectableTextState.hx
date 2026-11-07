// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.Context;
import gpui.Model;
import gpui.Point;
import gpui.WeakEntity;
import gpui.Window;
import gpui.util.Utf8;

typedef FocusCallback = (Window, App) -> Void;
typedef ClearHandler = (App) -> Void;
typedef CopyCallback = (App) -> String;
typedef ContentKeyResolver = (Point, App) -> Null<TextSelectionContentKey>;

/** Rust `CopyItem`. */
class CopyItem {
    public final documentOrder:Int;
    public final callback:Null<CopyCallback>;
    public final fallback:String;

    public inline function new(documentOrder:Int, callback:Null<CopyCallback>, fallback:String) {
        this.documentOrder = documentOrder;
        this.callback = callback;
        this.fallback = fallback;
    }
}

/**
 * The entity behind a `TextSelectionHandle` (crate-private in Rust).
 * Emits `TextSelectionEvent`.
 */
@:allow(gpui.base)
class SelectableTextState extends Model {

    var fallbackCopyText:String;
    var windowSelection:Null<WeakEntity<WindowSelectionState>> = null;
    /**
     * The selected text as the participant last painted it. Painting projects
     * it, which is not a change of the participant.
     */
    var projectedCopyText:Null<String> = null;
    /** The participant's text as it last painted it, for hit testing. */
    var runs:Array<TextSelectionRun> = [];
    var localSelection:Bool = false;
    var _snapshot:Null<TextSelectionSnapshot> = null;
    var onFocus:Null<FocusCallback> = null;
    var clear:Null<ClearHandler> = null;
    var copy:Null<CopyCallback> = null;
    var contentKeyResolver:Null<ContentKeyResolver> = null;

    public function new(fallbackCopyText:String) {
        super();
        this.fallbackCopyText = fallbackCopyText;
    }

    /** The current geometry selection snapshot for this participant. */
    function snapshot():Null<TextSelectionSnapshot> {
        return _snapshot;
    }

    /** Sets the text copied by this participant when it participates in selection. */
    function setFallbackCopyText(text:String):Void {
        fallbackCopyText = text;
        projectedCopyText = null;
    }

    /** Marks participant-local selection (for example select-all) as active. */
    function setLocalSelection(active:Bool):Void {
        localSelection = active;
    }

    /**
     * Projects this participant's current snapshot onto plain-text runs and
     * caches their selected substrings for the window selection query.
     */
    function updateRuns(runs:Array<TextSelectionRun>):TextSelectionProjection {
        this.runs = runs.copy();
        final states = TextSelection.projectRanges(_snapshot, runs);
        final selectedRuns:Array<{order:Int, index:Int, text:String}> = [];
        for (index in 0...runs.length) {
            final range = states.ranges()[index];
            if (range != null) {
                final run = runs[index];
                selectedRuns.push({order: run._documentOrder, index: index, text: Utf8.substring(run._text, range.start, range.end)});
            }
        }
        haxe.ds.ArraySort.sort(selectedRuns, (a, b) -> a.order != b.order ? (a.order < b.order ? -1 : 1) : (a.index < b.index ? -1 : (a.index > b.index ? 1 : 0)));
        final buf = new StringBuf();
        for (run in selectedRuns) buf.add(run.text);
        projectedCopyText = buf.toString();
        return states;
    }

    /** Installs the callback which focuses the participant when a drag begins in it. */
    function setFocusHandler(callback:FocusCallback):Void {
        onFocus = callback;
    }

    function clearWith(callback:ClearHandler):Void {
        clear = callback;
    }

    /** Installs a participant-specific copy projection. */
    function copyWith(callback:CopyCallback):Void {
        copy = callback;
    }

    /** Installs a participant-specific lookup for stable virtualized content keys. */
    function resolveContentKeyWith(callback:ContentKeyResolver):Void {
        contentKeyResolver = callback;
    }

    function setSnapshotQuietly(snapshot:Null<TextSelectionSnapshot>):Bool {
        if (TextSelectionSnapshot.eq(_snapshot, snapshot)) {
            return false;
        }
        _snapshot = snapshot;
        projectedCopyText = null;
        return true;
    }

    function setSnapshot(snapshot:Null<TextSelectionSnapshot>, cx:Context<SelectableTextState>):Void {
        if (setSnapshotQuietly(snapshot)) {
            cx.emit(TextSelectionEvent.SelectionChanged(snapshot));
        }
    }

    /**
     * Whether clearing the participant would change anything: it is part of
     * the window selection, or selected on its own.
     */
    function hasSelectionToClear():Bool {
        return _snapshot != null || localSelection;
    }

    function clearState(cx:Context<SelectableTextState>):Null<ClearHandler> {
        _snapshot = null;
        projectedCopyText = null;
        localSelection = false;
        cx.emit(TextSelectionEvent.Cleared);
        cx.emit(TextSelectionEvent.SelectionChanged(null));
        return clear;
    }

    function setAutoScroll(delta:Null<Float>, cx:Context<SelectableTextState>):Void {
        cx.emit(TextSelectionEvent.AutoScroll(delta));
    }

    function focus(window:Window, cx:App):Void {
        final callback = onFocus;
        if (callback != null) {
            window.defer(cx, (window, cx) -> callback(window, cx));
        }
    }

    function copyItem(documentOrder:Int):Null<CopyItem> {
        return (_snapshot != null || localSelection)
            ? new CopyItem(documentOrder, copy, projectedCopyText != null ? projectedCopyText : fallbackCopyText)
            : null;
    }

}
