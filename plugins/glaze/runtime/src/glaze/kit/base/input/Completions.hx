// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/completions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import glaze.util.Utf8;

/**
 * The completion label highlighters (Rust free functions `highlight_prefix`,
 * `highlight_contains` and `highlight_characters`).
 */
class Completions {

    /** Default debounce duration for inline completions, in milliseconds. */
    public static inline final DEFAULT_INLINE_COMPLETION_DEBOUNCE:Float = 300;

    /**
     * Highlight a prefix of the completion label, matching today's menu.
     *
     * The painted length is `CompletionItem.filterText` when the item sets
     * one, otherwise the query. It is shortened so the range never splits a
     * character. An empty length paints nothing.
     */
    public static function highlightPrefix(query:String, item:CompletionItem):Array<Range> {
        final labelLen = Utf8.byteLength(item.label);
        var matchedLen = item.filterText != null ? Utf8.byteLength(item.filterText) : Utf8.byteLength(query);
        if (matchedLen > labelLen)
            matchedLen = labelLen;
        final end = floorCharBoundary(item.label, matchedLen);
        return end == 0 ? [] : [new Range(0, end)];
    }

    /**
     * Highlight the first case-insensitive occurrence of `query` in the label.
     *
     * An empty query, or a query that does not occur as a contiguous span,
     * paints nothing.
     */
    public static function highlightContains(query:String, item:CompletionItem):Array<Range> {
        final queryChars = new Utf8Text(query);
        if (queryChars.count == 0)
            return [];

        final label = new Utf8Text(item.label);
        if (label.count < queryChars.count)
            return [];
        final lastStart = label.count - queryChars.count;

        for (start in 0...lastStart + 1) {
            var matched = true;
            for (k in 0...queryChars.count) {
                if (!charsEqIgnoreCase(queryChars.codePoints[k], label.codePoints[start + k])) {
                    matched = false;
                    break;
                }
            }
            if (!matched)
                continue;

            final byteStart = label.byteOffsets[start];
            final last = start + queryChars.count - 1;
            return [new Range(byteStart, label.byteOffsets[last] + Utf8.codePointLength(label.codePoints[last]))];
        }
        return [];
    }

    /**
     * Highlight each character of `query` in order, skipping characters in between.
     *
     * Matching is case-insensitive. Adjacent hits merge into one range, so a
     * contiguous match still paints as a single span. A query that cannot be
     * matched in full paints nothing.
     */
    public static function highlightCharacters(query:String, item:CompletionItem):Array<Range> {
        final queryChars = new Utf8Text(query);
        if (queryChars.count == 0)
            return [];

        final label = new Utf8Text(item.label);
        final ranges:Array<Range> = [];
        var next = 0;
        for (q in 0...queryChars.count) {
            final queryChar = queryChars.codePoints[q];
            var found = -1;
            for (k in next...label.count) {
                if (charsEqIgnoreCase(queryChar, label.codePoints[k])) {
                    found = k;
                    break;
                }
            }
            if (found < 0)
                return [];

            final start = label.byteOffsets[found];
            final end = start + Utf8.codePointLength(label.codePoints[found]);
            next = found + 1;
            if (ranges.length > 0 && ranges[ranges.length - 1].end == start) {
                ranges[ranges.length - 1] = new Range(ranges[ranges.length - 1].start, end);
                continue;
            }
            ranges.push(new Range(start, end));
        }
        return ranges;
    }

    /**
     * Rust `left == right || left.eq_ignore_ascii_case(&right) ||
     * left.to_lowercase().eq(right.to_lowercase())`. The Unicode lowercase
     * mapping is the target's `toLowerCase`.
     */
    static function charsEqIgnoreCase(left:Int, right:Int):Bool {
        if (left == right)
            return true;
        inline function asciiLower(c:Int):Int {
            return (c >= 'A'.code && c <= 'Z'.code) ? c + 32 : c;
        }
        if (asciiLower(left) == asciiLower(right))
            return true;
        return String.fromCharCode(left).toLowerCase() == String.fromCharCode(right).toLowerCase();
    }

    /** Rust `str::floor_char_boundary` */
    static function floorCharBoundary(s:String, index:Int):Int {
        final decoded = new Utf8Text(s);
        if (index >= decoded.byteLength)
            return decoded.byteLength;
        var result = 0;
        for (k in 0...decoded.count) {
            if (decoded.byteOffsets[k] <= index)
                result = decoded.byteOffsets[k];
            else
                break;
        }
        return result;
    }

}
