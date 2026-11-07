// Ported from gpui-pre 0.3.10: src/elements/text.rs (StyledText)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.HighlightStyle.TextHighlight;
import glaze.util.Utf8;

/**
 * Renders text with runs of different styles.
 *
 * Callers are responsible for setting the correct style for each run.
 * For text with a uniform style, you can usually avoid calling this constructor
 * and just pass text directly. Ranges are UTF-8 byte ranges.
 */
class StyledText extends Element {

    final textValue:String;

    var runs:Null<Array<TextRun>> = null;

    var delayedHighlights:Null<Array<TextHighlight>> = null;

    var delayedFontFamilyOverrides:Null<Array<FontFamilyOverride>> = null;

    final textLayout:TextLayout = new TextLayout();

    /**
     * Construct a new styled text element from the given string.
     */
    public function new(text:String) {
        this.textValue = text;
    }

    /** The text of this element. */
    public inline function text():String {
        return textValue;
    }

    /**
     * Get the layout for this element. This can be used to map indices to pixels and vice versa.
     */
    public inline function layout():TextLayout {
        return textLayout;
    }

    /**
     * Set the styling attributes for the given text, as well as
     * as any ranges of text that have had their style customized.
     */
    public function withDefaultHighlights(defaultStyle:TextStyle, highlights:Array<TextHighlight>):StyledText {
        return withRuns(computeRuns(textValue, defaultStyle, highlights));
    }

    /**
     * Set the styling attributes for the given text, as well as
     * as any ranges of text that have had their style customized
     * (applied on top of the text style of the window, at layout time).
     */
    public function withHighlights(highlights:Array<TextHighlight>):StyledText {
        for (highlight in highlights) {
            if (!Utf8.isCharBoundary(textValue, highlight.start) || !Utf8.isCharBoundary(textValue, highlight.end))
                throw 'highlight range is not on character boundaries';
        }
        delayedHighlights = highlights;
        return this;
    }

    static function computeRuns(text:String, defaultStyle:TextStyle, highlights:Array<TextHighlight>):Array<TextRun> {
        final runs:Array<TextRun> = [];
        var ix = 0;
        for (highlight in highlights) {
            if (ix < highlight.start) {
                runs.push(defaultStyle.toRun(highlight.start - ix));
            }
            runs.push(defaultStyle.clone().highlight(highlight.style).toRun(highlight.end - highlight.start));
            ix = highlight.end;
        }
        final len = Utf8.byteLength(text);
        if (ix < len) {
            runs.push(defaultStyle.toRun(len - ix));
        }
        return runs;
    }

    /**
     * Override the font family for specific byte ranges of the text.
     *
     * This is resolved lazily at layout time, so the overrides are applied
     * on top of the inherited text style from the parent element.
     * The overrides must be sorted by range start and non-overlapping.
     */
    public function withFontFamilyOverrides(overrides:Array<FontFamilyOverride>):StyledText {
        delayedFontFamilyOverrides = overrides;
        return this;
    }

    static function applyFontFamilyOverrides(runs:Array<TextRun>, overrides:Array<FontFamilyOverride>):Void {
        var byteOffset = 0;
        var overrideIdx = 0;
        for (i in 0...runs.length) {
            final run = runs[i];
            final runEnd = byteOffset + run.len;
            while (overrideIdx < overrides.length && overrides[overrideIdx].end <= byteOffset) {
                overrideIdx++;
            }
            if (overrideIdx < overrides.length) {
                final o = overrides[overrideIdx];
                if (byteOffset >= o.start && runEnd <= o.end) {
                    final font = run.font.clone();
                    font.family = o.family;
                    final updated = run.clone();
                    updated.font = font;
                    runs[i] = updated;
                }
            }
            byteOffset = runEnd;
        }
    }

    /**
     * Set the text runs for this piece of text.
     */
    public function withRuns(runs:Array<TextRun>):StyledText {
        var offset = 0;
        final len = Utf8.byteLength(textValue);
        for (run in runs) {
            offset += run.len;
            if (offset > len || !Utf8.isCharBoundary(textValue, offset))
                throw 'invalid text run. Text: \'$textValue\', run: $run';
        }
        if (offset != len)
            throw 'invalid text run';
        this.runs = runs;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final fontFamilyOverrides = delayedFontFamilyOverrides;
        delayedFontFamilyOverrides = null;
        var runs = this.runs;
        this.runs = null;
        if (runs == null && delayedHighlights != null) {
            runs = computeRuns(textValue, window.currentTextStyle(), delayedHighlights);
            delayedHighlights = null;
        }

        if (fontFamilyOverrides != null) {
            if (runs == null)
                runs = [window.currentTextStyle().toRun(Utf8.byteLength(textValue))];
            else
                runs = runs.copy();
            applyFontFamilyOverrides(runs, fontFamilyOverrides);
        }

        return textLayout.layout(textValue, runs, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        textLayout.prepaint(bounds, textValue);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        textLayout.paint(textValue, window, cx);
    }

}

/**
 * A font family override for a byte range `[start, end)` of a `StyledText`.
 */
class FontFamilyOverride {

    public final start:Int;

    public final end:Int;

    public final family:String;

    public function new(start:Int, end:Int, family:String) {
        this.start = start;
        this.end = end;
        this.family = family;
    }

}
