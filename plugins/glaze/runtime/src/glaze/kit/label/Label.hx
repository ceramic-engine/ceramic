// Ported from gpui-kit 0.8.1: crates/component/src/label.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.label;

import glaze.App;
import glaze.Component;
import glaze.HighlightStyle;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.StyledText;
import glaze.Window;
import glaze.kit.theme.Theme;
import haxe.io.Bytes;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Represents the type of match for highlighting text in a label.
 */
enum HighlightsMatch {
    Prefix(text:String);
    Full(text:String);
}

/**
 * Rust `impl Into<HighlightsMatch>`: a `HighlightsMatch`, or a string for a
 * full match.
 */
abstract IntoHighlightsMatch(HighlightsMatch) from HighlightsMatch to HighlightsMatch {

    @:from static inline function fromString(text:String):IntoHighlightsMatch {
        return Full(text);
    }

}

/**
 * A text label element with optional secondary text, masking, and
 * highlighting capabilities.
 *
 * Ranges are UTF-8 byte ranges (`[start, end]` pairs), like the Rust code.
 */
class Label extends Component implements Styled {

    static inline final MASKED = '•';

    final labelStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final label:String;

    /**
     * Set the secondary text for the label, displayed after the label text
     * with the `mutedForeground` color.
     */
    @:allow(tests)
    @prop var secondary:Null<String> = null;

    /**
     * Set whether to mask the label text.
     */
    @:allow(tests)
    @prop var masked:Bool = false;

    @:allow(tests)
    @prop var highlights:Null<HighlightsMatch> = null;

    /**
     * Create a new label with the main label.
     */
    public function new(label:String) {
        super();
        this.label = label;
    }

    public inline function style():StyleRefinement {
        return labelStyle;
    }

    /**
     * Set for matching text to highlight in the label.
     */
    public function highlights(text:IntoHighlightsMatch):Label {
        this.highlights = text;
        return this;
    }

    function fullText():String {
        return secondary != null ? '$label $secondary' : label;
    }

    /**
     * The highlighted UTF-8 byte ranges, as `[start, end]` pairs.
     */
    @:allow(tests)
    function highlightRanges(totalLength:Int):Array<Array<Int>> {
        final ranges:Array<Array<Int>> = [];
        final fullText = this.fullText();
        final labelLength = byteLength(label);

        if (secondary != null) {
            ranges.push([0, labelLength]);
            ranges.push([labelLength, totalLength]);
        }

        if (highlights != null) {
            final matchedStr = switch highlights {
                case Prefix(text) | Full(text): text;
            };
            final isPrefix = highlights.match(Prefix(_));
            if (matchedStr.length > 0) {
                final searchLower = Bytes.ofString(matchedStr.toLowerCase());
                final fullTextLower = Bytes.ofString(fullText.toLowerCase());
                final fullTextBytes = Bytes.ofString(fullText);
                final matchedLength = byteLength(matchedStr);

                if (isPrefix) {
                    // For prefix matching, only check if the text starts with the search term
                    if (indexOf(fullTextLower, searchLower, 0) == 0) {
                        ranges.push([0, matchedLength]);
                    }
                }
                else {
                    // For full matching, find all occurrences
                    var searchStart = 0;
                    while (true) {
                        final matchStart = indexOf(fullTextLower, searchLower, searchStart);
                        if (matchStart < 0)
                            break;
                        final matchEnd = matchStart + matchedLength;
                        if (matchEnd <= fullTextBytes.length) {
                            ranges.push([matchStart, matchEnd]);
                        }

                        searchStart = matchStart + 1;
                        while (searchStart < fullTextBytes.length && !isCharBoundary(fullTextBytes, searchStart)) {
                            searchStart++;
                        }

                        if (searchStart >= fullTextBytes.length) {
                            break;
                        }
                    }
                }
            }
        }

        return ranges;
    }

    static function byteLength(text:String):Int {
        return Bytes.ofString(text).length;
    }

    static inline function isCharBoundary(bytes:Bytes, index:Int):Bool {
        return index >= bytes.length || (bytes.get(index) & 0xC0) != 0x80;
    }

    static function indexOf(haystack:Bytes, needle:Bytes, from:Int):Int {
        final last = haystack.length - needle.length;
        var i = from;
        while (i <= last) {
            var found = true;
            for (j in 0...needle.length) {
                if (haystack.get(i + j) != needle.get(j)) {
                    found = false;
                    break;
                }
            }
            if (found)
                return i;
            i++;
        }
        return -1;
    }

    @:allow(tests)
    function measureHighlights(length:Int, cx:App):Null<Array<TextHighlight>> {
        if (masked) {
            return null;
        }

        final ranges = highlightRanges(length);
        if (ranges.length == 0) {
            return null;
        }

        final theme = Theme.global(cx);
        final highlights:Array<TextHighlight> = [];
        var highlightRangesAdded = 0;

        if (secondary != null) {
            highlights.push(new TextHighlight(ranges[0][0], ranges[0][1], new HighlightStyle()));
            highlights.push(new TextHighlight(ranges[1][0], ranges[1][1], HighlightStyle.ofColor(theme.mutedForeground)));
            highlightRangesAdded = 2;
        }

        for (i in highlightRangesAdded...ranges.length) {
            highlights.push(new TextHighlight(ranges[i][0], ranges[i][1], HighlightStyle.ofColor(theme.blue)));
        }

        return HighlightStyle.combineHighlights([], highlights);
    }

    public function render(window:Window, cx:App):IntoElement {
        var text = fullText();

        if (masked) {
            var charsCount = 0;
            final bytes = Bytes.ofString(text);
            for (i in 0...bytes.length) {
                if ((bytes.get(i) & 0xC0) != 0x80)
                    charsCount++;
            }
            final buf = new StringBuf();
            for (_ in 0...charsCount) buf.add(MASKED);
            text = buf.toString();
        }

        final highlights = measureHighlights(byteLength(text), cx);

        final styledText = new StyledText(text);
        if (highlights != null) {
            styledText.withHighlights(highlights);
        }
        return div()
            .lineHeight(rems(1.25))
            .textColor(Theme.global(cx).foreground)
            .refineStyle(labelStyle)
            .child(styledText);
    }

}
