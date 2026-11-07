// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/search.rs (`impl<M: InputModeKind> InputBaseState<M>`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.Context;
import glaze.Range;
import glaze.Window;

import glaze.kit.base.input.InputActions;

using glaze.kit.base.input.RopeExt;

/**
 * The search methods of `InputBaseState`, written where Rust writes them
 * (`search.rs`). Haxe has no `impl` blocks outside a class: they are static
 * extensions (`using glaze.kit.base.input.InputSearchExt;`), and `InputBaseState`
 * forwards its public API to them.
 *
 * They read the state fields of the Rust struct (`searchable`,
 * `searchActivationRevision`, `searchSession`, `lastLayout`, `replaceable`,
 * `text`) and call its methods (`isEditable`, `selectedText`,
 * `rangeToUtf16`, `scrollTo`, `scrollToWithPadding`,
 * `replaceTextInRangeSilent`), named like the Rust ones.
 */
@:access(glaze.kit.base.input.InputBaseState)
class InputSearchExt {

    /**
     * Open the search session, or re-invoke it if it is already open.
     *
     * This is not idempotent: every call advances
     * `searchActivationRevision`, and the presentation layer answers that by
     * re-focusing the search field and selecting its contents, the same as
     * pressing the shortcut a second time. Call it from an action or another
     * user gesture, never from a render pass or an observer that runs every frame.
     */
    public static function openSearch(self:InputBaseState, replaceMode:Bool, cx:Context<InputBaseState>):Void {
        if (!self.searchable)
            return;
        // `wrapping_add(1)` on a `u64`
        self.searchActivationRevision = self.searchActivationRevision + 1;
        self.searchSession.openPanel(replaceMode, isReplaceable(self));
        final selected = self.selectedText().toString();
        final query = selected.length == 0 ? self.searchSession.query : selected;
        final queryChanged = query != self.searchSession.query;
        // A retained query resumes its previous occurrence. Only a new query
        // is anchored to the current viewport.
        self.searchSession.anchorOffset = queryChanged && self.lastLayout != null ? self.lastLayout.visibleRangeOffset.start : null;
        final caseInsensitive = self.searchSession.caseInsensitive;
        self.searchSession.updateQuery(query, caseInsensitive);
        self.searchSession.matcher.update(self.text);
        final anchor = self.searchSession.anchorOffset;
        if (queryChanged && anchor != null)
            self.searchSession.matcher.updateCursorByOffset(anchor);
        cx.notify();
    }

    public static inline function searchSession(self:InputBaseState):SearchSession {
        return self.searchSession;
    }

    /**
     * A counter that advances every time `openSearch` runs, including while
     * the session is already open.
     */
    public static inline function searchActivationRevision(self:InputBaseState):Int {
        return self.searchActivationRevision;
    }

    public static function setSearchReplaceMode(self:InputBaseState, replaceMode:Bool, cx:Context<InputBaseState>):Void {
        self.searchSession.replaceMode = replaceMode && isReplaceable(self);
        cx.notify();
    }

    /**
     * Returns true if the search panel can replace the matches.
     *
     * This is false when the input is not `replaceable`, or when it is
     * `disabled` or `readonly`.
     */
    public static function isReplaceable(self:InputBaseState):Bool {
        return self.replaceable && self.isEditable();
    }

    /**
     * Set the search query and highlight its matches.
     *
     * This is the entry point for a custom search UI: it needs neither
     * `searchable` nor the built-in panel. A changed query or case mode
     * starts at the current viewport. Setting the same query and case mode
     * again retains the current occurrence.
     */
    public static function setSearchQuery(self:InputBaseState, query:String, caseInsensitive:Bool, cx:Context<InputBaseState>):Void {
        final queryChanged = query != self.searchSession.query || caseInsensitive != self.searchSession.caseInsensitive;
        self.searchSession.anchorOffset = queryChanged && self.lastLayout != null ? self.lastLayout.visibleRangeOffset.start : null;
        self.searchSession.activate();
        self.searchSession.updateQuery(query, caseInsensitive);
        self.searchSession.matcher.update(self.text);
        final anchor = self.searchSession.anchorOffset;
        if (queryChanged && anchor != null)
            self.searchSession.matcher.updateCursorByOffset(anchor);
        cx.notify();
    }

    /**
     * End the search: hide the built-in panel and the match highlights. The
     * query is kept so the next `openSearch` resumes it.
     */
    public static function closeSearch(self:InputBaseState, cx:Context<InputBaseState>):Void {
        self.searchSession.close();
        cx.notify();
    }

    public static function nextSearchMatch(self:InputBaseState, cx:Context<InputBaseState>):Null<Range> {
        syncSearchMatcher(self);
        final range = self.searchSession.matcher.next();
        if (range == null)
            return null;
        // Match order does not describe viewport direction after a manual
        // scroll. Always allow search navigation to reveal the active match.
        self.scrollToWithPadding(range.end, null, ScrollPadding.SurroundingLines, cx);
        return range;
    }

    public static function previousSearchMatch(self:InputBaseState, cx:Context<InputBaseState>):Null<Range> {
        syncSearchMatcher(self);
        final range = self.searchSession.matcher.nextBack();
        if (range == null)
            return null;
        // Match order does not describe viewport direction after a manual
        // scroll. Always allow search navigation to reveal the active match.
        self.scrollToWithPadding(range.start, null, ScrollPadding.SurroundingLines, cx);
        return range;
    }

    /**
     * Replace the current match and move on to the next one. Returns whether
     * there was a match to replace.
     */
    public static function replaceCurrentSearchMatch(self:InputBaseState, replacement:String, window:Window, cx:Context<InputBaseState>):Bool {
        if (!isReplaceable(self))
            return false;
        syncSearchMatcher(self);
        final matcher = self.searchSession.matcher;
        final ranges = matcher.matchedRanges();
        final index = matcher.currentMatchIndex();
        if (index >= ranges.length)
            return false;
        final range = ranges[index];
        final peeked = matcher.peek();
        final next = peeked != null ? peeked : range;
        final direction:Null<MoveDirection> = matcher.hasNextWithoutWrap() ? MoveDirection.Down : null;
        if (direction == null)
            matcher.setCurrentMatchIndex(0);
        matcher.beginReplacement();
        final rangeUtf16 = self.rangeToUtf16(range);
        self.scrollTo(next.end, direction, cx);
        self.replaceTextInRangeSilent(rangeUtf16, replacement, window, cx);
        return true;
    }

    /** Replace every match. Returns how many were replaced. */
    public static function replaceAllSearchMatches(self:InputBaseState, replacement:String, window:Window, cx:Context<InputBaseState>):Int {
        if (!isReplaceable(self))
            return 0;
        syncSearchMatcher(self);
        final ranges = self.searchSession.matcher.matchedRanges();
        if (ranges.length == 0)
            return 0;
        final text = self.text.clone();
        var i = ranges.length - 1;
        while (i >= 0) {
            text.replace(ranges[i], replacement);
            i--;
        }
        self.searchSession.matcher.beginReplacement();
        final count = ranges.length;
        self.replaceTextInRangeSilent(new Range(0, self.text.len()), text.toString(), window, cx);
        self.scrollTo(0, MoveDirection.Down, cx);
        return count;
    }

    /**
     * Keep the matches in step with an edit. A closed search skips the scan:
     * it copies and searches the whole document, and nothing reads the
     * matches until the search is resumed or navigated, which sync first.
     */
    public static function updateSearch(self:InputBaseState, cx:App):Void {
        if (!self.searchSession.isActive())
            return;
        syncSearchMatcher(self);
    }

    /** Recompute the matches if the text changed since the last scan. */
    static function syncSearchMatcher(self:InputBaseState):Void {
        self.searchSession.matcher.update(self.text);
    }

    /**
     * An input that is not `searchable` leaves the shortcut to its
     * ancestors, so a custom search UI can take it.
     */
    public static function onActionSearch(self:InputBaseState, action:Search, window:Window, cx:Context<InputBaseState>):Void {
        if (!self.searchable) {
            cx.propagate();
            return;
        }
        openSearch(self, false, cx);
    }

    public static function onActionReplace(self:InputBaseState, action:Replace, window:Window, cx:Context<InputBaseState>):Void {
        if (!self.searchable) {
            cx.propagate();
            return;
        }
        openSearch(self, true, cx);
    }

}
