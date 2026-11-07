// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/search.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;
import haxe.io.Bytes;
import ropey.Rope;

/**
 * Stateful, presentation-independent search engine used by text inputs.
 *
 * Rust builds an `AhoCorasick` automaton for the query (one pattern,
 * optionally ASCII case insensitive) and collects its non-overlapping
 * matches with `stream_find_iter`. With a single pattern that is a scan for
 * the leftmost occurrence, resuming after each match: the port does that scan
 * on the UTF-8 bytes of the text. `query` is the pattern (null when empty).
 *
 * Rust's `Iterator` / `DoubleEndedIterator` are `next()` / `nextBack()`.
 */
class SearchMatcher {

    var text:Rope;

    public var query(default, null):Null<String>;

    var queryBytes:Null<Bytes>;

    var queryCaseInsensitive:Bool = false;

    var _matchedRanges:Array<Range>;

    var currentMatchIx:Int;

    var replacing:Bool;

    public function new() {
        text = Rope.fromStr('');
        query = null;
        queryBytes = null;
        _matchedRanges = [];
        currentMatchIx = 0;
        replacing = false;
    }

    public static inline function defaultValue():SearchMatcher {
        return new SearchMatcher();
    }

    public function clone():SearchMatcher {
        final result = new SearchMatcher();
        result.text = text.clone();
        result.query = query;
        result.queryBytes = queryBytes;
        result.queryCaseInsensitive = queryCaseInsensitive;
        result._matchedRanges = _matchedRanges;
        result.currentMatchIx = currentMatchIx;
        result.replacing = replacing;
        return result;
    }

    /** Update the source text and recompute matches. */
    public function update(text:Rope):Void {
        if (this.text.equals(text)) {
            replacing = false;
            return;
        }
        this.text = text.clone();
        updateMatches();
    }

    public function updateQuery(query:String, caseInsensitive:Bool):Void {
        if (query.length > 0) {
            this.query = query;
            this.queryBytes = Bytes.ofString(query);
            this.queryCaseInsensitive = caseInsensitive;
        }
        else {
            this.query = null;
            this.queryBytes = null;
        }
        updateMatches();
    }

    /** The matches (shared: do not modify the array). */
    public inline function matchedRanges():Array<Range> {
        return _matchedRanges;
    }

    public inline function currentMatchIndex():Int {
        return currentMatchIx;
    }

    /**
     * The index of the current match into `matchedRanges`, null while there
     * is no match.
     */
    public inline function current():Null<Int> {
        return !isEmpty() ? currentMatchIx : null;
    }

    public inline function len():Int {
        return _matchedRanges.length;
    }

    public inline function isEmpty():Bool {
        return _matchedRanges.length == 0;
    }

    /** `2/5`: the current match and the total, `0/0` without matches. */
    public function label():String {
        final ix = current();
        return ix != null ? '${ix + 1}/${len()}' : '0/0';
    }

    public function peek():Null<Range> {
        final ix = nextIndex();
        return ix != null && ix < _matchedRanges.length ? _matchedRanges[ix] : null;
    }

    public function hasNextWithoutWrap():Bool {
        final last = _matchedRanges.length > 0 ? _matchedRanges.length - 1 : 0;
        return currentMatchIx < last;
    }

    public function updateCursorByOffset(offset:Int):Void {
        for (ix in 0..._matchedRanges.length) {
            final range = _matchedRanges[ix];
            currentMatchIx = ix;
            if (range.contains(offset) || range.end >= offset)
                return;
        }
    }

    /** Preserve the current logical match while a replacement mutates text. */
    public function beginReplacement():Void {
        replacing = true;
    }

    public function setCurrentMatchIndex(index:Int):Void {
        final last = _matchedRanges.length > 0 ? _matchedRanges.length - 1 : 0;
        currentMatchIx = index < last ? index : last;
    }

    function nextIndex():Null<Int> {
        if (isEmpty())
            return null;
        else if (hasNextWithoutWrap())
            return currentMatchIx + 1;
        else
            return 0;
    }

    function updateMatches():Void {
        final ranges:Array<Range> = [];
        if (queryBytes != null) {
            final haystack = Bytes.ofString(text.toString());
            findAll(haystack, queryBytes, queryCaseInsensitive, ranges);
        }
        _matchedRanges = ranges;
        if (!replacing || isEmpty())
            currentMatchIx = 0;
        else
            currentMatchIx = currentMatchIx < len() - 1 ? currentMatchIx : len() - 1;
        replacing = false;
    }

    /** The non-overlapping occurrences of `needle`, leftmost first. */
    static function findAll(haystack:Bytes, needle:Bytes, asciiCaseInsensitive:Bool, ranges:Array<Range>):Void {
        final n = needle.length;
        final limit = haystack.length - n;
        var i = 0;
        while (i <= limit) {
            var j = 0;
            while (j < n) {
                var a = haystack.get(i + j);
                var b = needle.get(j);
                if (asciiCaseInsensitive) {
                    if (a >= 'A'.code && a <= 'Z'.code)
                        a += 32;
                    if (b >= 'A'.code && b <= 'Z'.code)
                        b += 32;
                }
                if (a != b)
                    break;
                j++;
            }
            if (j == n) {
                ranges.push(new Range(i, i + n));
                i += n;
            }
            else {
                i++;
            }
        }
    }

    /** Rust `Iterator::next`: move to the next match (wrapping) and return it. */
    public function next():Null<Range> {
        final ix = nextIndex();
        if (ix == null)
            return null;
        currentMatchIx = ix;
        return ix < _matchedRanges.length ? _matchedRanges[ix] : null;
    }

    /** Rust `DoubleEndedIterator::next_back`: move to the previous match (wrapping). */
    public function nextBack():Null<Range> {
        if (isEmpty())
            return null;
        if (currentMatchIx == 0)
            currentMatchIx = len();
        currentMatchIx -= 1;
        return currentMatchIx < _matchedRanges.length ? _matchedRanges[currentMatchIx] : null;
    }

}
