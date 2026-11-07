// Ported from gpui-pre 0.3.10: src/text_system/line_wrapper.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Utf8;
import haxe.ds.IntMap;

/**
 * The GPUI line wrapper, used to wrap lines of text to a given width.
 *
 * Differences with GPUI: `wrapLine()` returns every boundary at once (an
 * array) instead of a lazy iterator, and `truncateLine()` returns a
 * `TruncatedLine` instead of a tuple. Wrappers are pooled by the
 * `TextSystem` (`lineWrapper()`), there is no `LineWrapperHandle`.
 */
class LineWrapper {

    /** The maximum indent that can be applied to a line. */
    public static inline final MAX_INDENT:Int = 256;

    final textSystem:TextSystem;

    public var fontId(default, null):FontId;

    public var fontSize(default, null):Pixels;

    /** Cached widths of ASCII characters (NaN when not computed yet) */
    final cachedAsciiCharWidths:Array<Float> = [for (_ in 0...128) Math.NaN];

    final cachedOtherCharWidths:IntMap<Float> = new IntMap();

    final decoded:Utf8Text = new Utf8Text();

    @:allow(gpui.TextSystem)
    function new(fontId:FontId, fontSize:Pixels, textSystem:TextSystem) {
        this.textSystem = textSystem;
        this.fontId = fontId;
        this.fontSize = fontSize;
    }

    /**
     * Wrap a line of text to the given width with this wrapper's font and font size.
     */
    public function wrapLine(fragments:Array<LineFragment>, wrapWidth:Pixels, ?indentAdjustment:IndentAdjustment):Array<Boundary> {
        if (indentAdjustment == null)
            indentAdjustment = SameIndent;

        final boundaries:Array<Boundary> = [];
        var width:Float = 0.0;
        var firstNonWhitespaceIx:Int = -1;
        var baseIndent:Int = -1;
        var lastCandidateIx = 0;
        var lastCandidateWidth:Float = 0.0;
        var lastWrapIx = 0;
        var prevC = 0;
        var index = 0;

        for (fragment in fragments) {
            switch fragment {
                case Text(text):
                    final d = decoded.reset(text);
                    for (k in 0...d.count) {
                        final c = d.codePoints[k];
                        final ix = index;
                        index += Utf8.codePointLength(c);
                        var newPrevC = prevC;

                        if (c == '\n'.code) {
                            continue;
                        }

                        if (isWordChar(c)) {
                            if (prevC == ' '.code && c != ' '.code && firstNonWhitespaceIx >= 0) {
                                lastCandidateIx = ix;
                                lastCandidateWidth = width;
                            }
                        }
                        else {
                            // CJK may not be space separated, e.g.: `Hello world你好世界`
                            if (c != ' '.code && firstNonWhitespaceIx >= 0) {
                                lastCandidateIx = ix;
                                lastCandidateWidth = width;
                            }
                        }

                        if (c != ' '.code && firstNonWhitespaceIx < 0) {
                            firstNonWhitespaceIx = ix;
                        }

                        newPrevC = c;

                        final itemWidth = widthForChar(c);
                        final result = step(ix, itemWidth, wrapWidth, indentAdjustment, width, firstNonWhitespaceIx, baseIndent, lastCandidateIx, lastCandidateWidth, lastWrapIx);
                        if (result != null) {
                            boundaries.push(result);
                            width = stepWidth;
                            baseIndent = stepBaseIndent;
                            lastWrapIx = result.ix;
                            lastCandidateIx = 0;
                            // Rust returns before updating prev_c
                            continue;
                        }
                        width = stepWidth;
                        prevC = newPrevC;
                    }

                case Element(elementWidth, lenUtf8):
                    final ix = index;
                    index += lenUtf8;
                    if (prevC == ' '.code && firstNonWhitespaceIx >= 0) {
                        lastCandidateIx = ix;
                        lastCandidateWidth = width;
                    }

                    if (firstNonWhitespaceIx < 0) {
                        firstNonWhitespaceIx = ix;
                    }

                    final result = step(ix, elementWidth, wrapWidth, indentAdjustment, width, firstNonWhitespaceIx, baseIndent, lastCandidateIx, lastCandidateWidth, lastWrapIx);
                    if (result != null) {
                        boundaries.push(result);
                        width = stepWidth;
                        baseIndent = stepBaseIndent;
                        lastWrapIx = result.ix;
                        lastCandidateIx = 0;
                        continue;
                    }
                    width = stepWidth;
                    // Elements keep prev_c unchanged (new_prev_c = prev_c)
            }
        }

        return boundaries;
    }

    // Outputs of `step()` (avoids allocating a result object)
    var stepWidth:Float = 0;
    var stepBaseIndent:Int = -1;

    /**
     * Adds an item to the current line and returns a boundary if the line
     * must wrap before it (the body of the loop of Rust's `wrap_line`).
     */
    function step(ix:Int, itemWidth:Float, wrapWidth:Float, indentAdjustment:IndentAdjustment, width:Float, firstNonWhitespaceIx:Int, baseIndent:Int, lastCandidateIx:Int, lastCandidateWidth:Float, lastWrapIx:Int):Null<Boundary> {
        width += itemWidth;
        stepBaseIndent = baseIndent;
        if (width > wrapWidth && ix > lastWrapIx) {
            final wrapAtCandidate = lastCandidateIx > 0 && width - lastCandidateWidth <= wrapWidth;

            final carriedWidth = wrapAtCandidate ? width - lastCandidateWidth : itemWidth;

            // Compute base indentation from the first non-whitespace character on the line
            // and retain it for all subsequent wrap rows. If the line begins with leading
            // whitespace that wraps before any non-whitespace character (or is all whitespace),
            // base_indent remains None so continuation rows within the leading whitespace
            // do not receive ExtraColumns indentation and degrade into cascading short rows.
            if (baseIndent < 0) {
                if (firstNonWhitespaceIx >= 0) {
                    baseIndent = Std.int(Math.min(MAX_INDENT, Math.max(0, firstNonWhitespaceIx - lastWrapIx)));
                }
            }

            final nextIndent:Int = switch indentAdjustment {
                case NoIndent: 0;
                case SameIndent: baseIndent >= 0 ? baseIndent : 0;
                case ExtraColumns(extra):
                    if (baseIndent >= 0) {
                        // saturating_add on u32
                        final candidate:Float = Math.min((baseIndent:Float) + uintValue(extra), 4294967295.0);
                        final candidateIndentWidth = widthForChar(' '.code) * candidate;
                        // Reserve headroom for any carried suffix from an earlier word boundary
                        // (and at least 2 columns for a full-width character) so the continuation
                        // line does not immediately exceed wrap width.
                        final minHeadroom = Math.max(carriedWidth, widthForChar(' '.code) * 2.0);
                        if (candidateIndentWidth + minHeadroom > wrapWidth) {
                            0;
                        }
                        else {
                            Std.int(Math.min(MAX_INDENT, candidate));
                        }
                    }
                    else {
                        0;
                    }
            }

            var wrapIx:Int;
            if (wrapAtCandidate) {
                wrapIx = lastCandidateIx;
                width -= lastCandidateWidth;
            }
            else {
                wrapIx = ix;
                width = itemWidth;
            }

            width += widthForChar(' '.code) * nextIndent;

            stepWidth = width;
            stepBaseIndent = baseIndent;
            return new Boundary(wrapIx, nextIndent);
        }
        stepWidth = width;
        return null;
    }

    /** `u32` value of an Int that may hold `u32::MAX` (stored as -1). */
    static inline function uintValue(value:Int):Float {
        return value < 0 ? value + 4294967296.0 : value;
    }

    /**
     * Determines if a line should be truncated based on its width.
     *
     * Returns the truncation index in `line`, or -1 (Rust `None`).
     */
    public function shouldTruncateLine(line:String, truncateWidth:Pixels, truncationAffix:String, truncateFrom:TruncateFrom):Int {
        var width:Float = 0.0;
        final suffixWidth = affixWidth(truncationAffix);
        var truncateIx = 0;

        final d = decoded.reset(line);
        switch truncateFrom {
            case Start:
                var k = d.count - 1;
                while (k >= 0) {
                    final ix = d.byteOffsets[k];
                    final c = d.codePoints[k];
                    if (width + suffixWidth < truncateWidth) {
                        truncateIx = ix;
                    }

                    final charWidth = widthForChar(c);
                    width += charWidth;

                    if (Math.ffloor(width) > truncateWidth) {
                        return truncateIx;
                    }
                    k--;
                }
            case End:
                for (k in 0...d.count) {
                    final ix = d.byteOffsets[k];
                    final c = d.codePoints[k];
                    if (width + suffixWidth < truncateWidth) {
                        truncateIx = ix;
                    }

                    final charWidth = widthForChar(c);
                    width += charWidth;

                    if (Math.ffloor(width) > truncateWidth) {
                        return truncateIx;
                    }
                }
            case Middle:
        }

        return -1;
    }

    function affixWidth(truncationAffix:String):Float {
        var result:Float = 0.0;
        final d = decoded.reset(truncationAffix);
        for (k in 0...d.count)
            result += widthForChar(d.codePoints[k]);
        return result;
    }

    /**
     * Returns `[frontEndIx, backStartIx]`, or null when the line fits.
     */
    function shouldTruncateLineMiddle(line:String, truncateWidth:Pixels, truncationAffix:String):Null<Array<Int>> {
        final suffixWidth = affixWidth(truncationAffix);

        final d = decoded.reset(line);
        var totalWidth:Float = 0.0;
        for (k in 0...d.count)
            totalWidth += widthForChar(d.codePoints[k]);

        if (totalWidth <= truncateWidth) {
            return null;
        }

        final lineLen = d.byteLength;
        final contentBudget = truncateWidth - suffixWidth;
        if (contentBudget <= 0.0) {
            return [0, lineLen];
        }

        final frontBudget = contentBudget * (2.0 / 3.0);
        final backBudget = contentBudget - frontBudget;

        var frontWidth:Float = 0.0;
        var frontEndIx = 0;
        for (k in 0...d.count) {
            final c = d.codePoints[k];
            final charWidth = widthForChar(c);
            if (frontWidth + charWidth > frontBudget) {
                break;
            }
            frontWidth += charWidth;
            frontEndIx = d.byteOffsets[k] + Utf8.codePointLength(c);
        }

        var backWidth:Float = 0.0;
        var backStartIx = lineLen;
        var k = d.count - 1;
        while (k >= 0) {
            final c = d.codePoints[k];
            final charWidth = widthForChar(c);
            if (backWidth + charWidth > backBudget) {
                break;
            }
            backWidth += charWidth;
            backStartIx = d.byteOffsets[k];
            k--;
        }

        if (frontEndIx >= backStartIx) {
            return [0, lineLen];
        }

        return [frontEndIx, backStartIx];
    }

    /**
     * Truncate a line of text to the given width with this wrapper's font and font size.
     */
    public function truncateLine(line:String, truncateWidth:Pixels, truncationAffix:String, runs:Array<TextRun>, truncateFrom:TruncateFrom):TruncatedLine {
        if (truncateFrom == Middle) {
            final middle = shouldTruncateLineMiddle(line, truncateWidth, truncationAffix);
            if (middle != null) {
                final frontEndIx = middle[0];
                final backStartIx = middle[1];
                final result = Utf8.substring(line, 0, frontEndIx) + truncationAffix + Utf8.substringFrom(line, backStartIx);
                final newRuns = cloneRuns(runs);
                updateRunsAfterMiddleTruncation(truncationAffix, newRuns, frontEndIx, backStartIx);
                return new TruncatedLine(result, newRuns);
            }
            else {
                return new TruncatedLine(line, runs);
            }
        }

        final truncateIx = shouldTruncateLine(line, truncateWidth, truncationAffix, truncateFrom);
        if (truncateIx >= 0) {
            final result = switch truncateFrom {
                case Start:
                    truncationAffix + Utf8.substringFrom(line, Utf8.ceilCharBoundary(line, truncateIx + 1));
                case End:
                    trimEndWhitespaceAndPunctuation(Utf8.substring(line, 0, truncateIx)) + truncationAffix;
                case Middle:
                    throw 'Middle truncation is handled above';
            }
            final newRuns = cloneRuns(runs);
            updateRunsAfterTruncation(result, truncationAffix, newRuns, truncateFrom);
            return new TruncatedLine(result, newRuns);
        }
        else {
            return new TruncatedLine(line, runs);
        }
    }

    /**
     * Truncate text to fit within a given number of wrapped lines.
     *
     * Unlike `truncateLine` which treats the text as a flat width budget
     * (`width * maxLines`), this method accounts for word-boundary wrapping:
     * it walks through characters once, tracking wrap boundaries and the
     * truncation point simultaneously. When text overflows on the last
     * allowed line, it truncates there and appends the affix.
     *
     * For `maxLines == 1`, this delegates to `truncateLine`.
     */
    public function truncateWrappedLine(text:String, wrapWidth:Pixels, maxLines:Int, truncationAffix:String, runs:Array<TextRun>, truncateFrom:TruncateFrom):TruncatedLine {
        if (maxLines <= 1 || truncateFrom == Start) {
            return truncateLine(text, wrapWidth * maxLines, truncationAffix, runs, truncateFrom);
        }
        if (truncateFrom == Middle) {
            return truncateLine(text, wrapWidth, truncationAffix, runs, truncateFrom);
        }

        final affixW = affixWidth(truncationAffix);

        var width:Float = 0.0;
        var line = 0;
        var firstNonWhitespaceIx = -1;
        var lastCandidateIx = 0;
        var lastCandidateWidth:Float = 0.0;
        var lastWrapIx = 0;
        var prevC = 0;
        var indent:Int = -1;
        var truncateIx = 0;

        final d = new Utf8Text(text);
        for (k in 0...d.count) {
            final ix = d.byteOffsets[k];
            final c = d.codePoints[k];
            if (c == '\n'.code) {
                if (line >= maxLines - 1 && !isAllWhitespace(Utf8.substringFrom(text, ix + 1))) {
                    // Newline on the last allowed line with real content
                    // below. Truncate here.
                    final truncated = trimEndWhitespaceAndPunctuation(Utf8.substring(text, 0, truncateIx));
                    final result = truncated + truncationAffix;
                    final newRuns = cloneRuns(runs);
                    updateRunsAfterTruncation(result, truncationAffix, newRuns, End);
                    return new TruncatedLine(result, newRuns);
                }

                // Newline before the last line: it consumes a line.
                line += 1;
                width = 0.0;
                firstNonWhitespaceIx = -1;
                lastCandidateIx = 0;
                lastCandidateWidth = 0.0;
                lastWrapIx = ix + 1;
                prevC = 0;
                indent = -1;
                truncateIx = ix + 1;
                continue;
            }

            final charWidth = widthForChar(c);

            if (isWordChar(c)) {
                if (prevC == ' '.code && firstNonWhitespaceIx >= 0) {
                    lastCandidateIx = ix;
                    lastCandidateWidth = width;
                }
            }
            else if (c != ' '.code && firstNonWhitespaceIx >= 0) {
                lastCandidateIx = ix;
                lastCandidateWidth = width;
            }

            if (c != ' '.code && firstNonWhitespaceIx < 0) {
                firstNonWhitespaceIx = ix;
            }

            width += charWidth;

            if (line < maxLines - 1) {
                // Before the last line: replicate wrap_line's boundary logic.
                if (width > wrapWidth && ix > lastWrapIx) {
                    if (indent < 0 && firstNonWhitespaceIx >= 0) {
                        indent = Std.int(Math.min(MAX_INDENT, firstNonWhitespaceIx - lastWrapIx));
                    }

                    if (lastCandidateIx > lastWrapIx) {
                        lastWrapIx = lastCandidateIx;
                        width -= lastCandidateWidth;
                        lastCandidateIx = 0;
                    }
                    else {
                        lastWrapIx = ix;
                        width = charWidth;
                    }

                    if (indent >= 0) {
                        width += widthForChar(' '.code) * indent;
                    }

                    line += 1;
                    truncateIx = lastWrapIx;
                }
            }
            else {
                // On the last line: track the furthest point where the affix
                // still fits, and stop as soon as the line overflows.
                if (width + affixW <= wrapWidth) {
                    truncateIx = ix + Utf8.codePointLength(c);
                }

                if (width > wrapWidth) {
                    final truncated = trimEndWhitespaceAndPunctuation(Utf8.substring(text, 0, truncateIx));
                    final result = truncated + truncationAffix;
                    final newRuns = cloneRuns(runs);
                    updateRunsAfterTruncation(result, truncationAffix, newRuns, End);
                    return new TruncatedLine(result, newRuns);
                }
            }

            prevC = c;
        }

        // Text fits within max_lines without truncation.
        return new TruncatedLine(text, runs);
    }

    /** Rust `str::trim().is_empty()` is false: the text has a non whitespace character */
    static function isAllWhitespace(s:String):Bool {
        final d = new Utf8Text(s);
        for (k in 0...d.count) {
            if (!Utf8.isWhitespace(d.codePoints[k]))
                return false;
        }
        return true;
    }

    /** Rust `trim_end_matches(|c| c.is_whitespace() || c.is_ascii_punctuation())` */
    static function trimEndWhitespaceAndPunctuation(s:String):String {
        final d = new Utf8Text(s);
        var end = d.count;
        while (end > 0) {
            final c = d.codePoints[end - 1];
            if (Utf8.isWhitespace(c) || Utf8.isAsciiPunctuation(c))
                end--;
            else
                break;
        }
        if (end == d.count)
            return s;
        return Utf8.substring(s, 0, end > 0 ? d.byteOffsets[end - 1] + Utf8.codePointLength(d.codePoints[end - 1]) : 0);
    }

    static function cloneRuns(runs:Array<TextRun>):Array<TextRun> {
        return [for (run in runs) run.clone()];
    }

    /**
     * Any character in this list should be treated as a word character,
     * meaning it can be part of a word that should not be wrapped.
     */
    public static function isWordChar(c:Int):Bool {
        // ASCII alphanumeric characters, for English, numbers: `Hello123`, etc.
        return Utf8.isAsciiAlphanumeric(c)
            // Latin script in Unicode for French, German, Spanish, etc.
            // Latin-1 Supplement
            || (c >= 0x00C0 && c <= 0x00FF)
            // Latin Extended-A
            || (c >= 0x0100 && c <= 0x017F)
            // Latin Extended-B
            || (c >= 0x0180 && c <= 0x024F)
            // Cyrillic for Russian, Ukrainian, etc.
            || (c >= 0x0400 && c <= 0x04FF)
            // Vietnamese: Latin Extended Additional
            || (c >= 0x1E00 && c <= 0x1EFF)
            // Combining Diacritical Marks
            || (c >= 0x0300 && c <= 0x036F)
            // Bengali
            || (c >= 0x0980 && c <= 0x09FF)
            // Some other known special characters that should be treated as word characters,
            // e.g. `a-b`, `var_name`, `I'm`/`won’t`, '@mention`, `#hashtag`, `100%`, `3.1415`,
            // `2^3`, `a~b`, `a=1`, `Self::new`, etc. Trailing punctuation like `,`, `.`, `:`, `;`
            // is included so it stays attached to the preceding word when wrapping.
            || c == '-'.code || c == '_'.code || c == '.'.code || c == "'".code || c == 0x2019 || c == 0x2018
            || c == '$'.code || c == '%'.code || c == '@'.code || c == '#'.code || c == '^'.code || c == '~'.code
            || c == ','.code || c == '='.code || c == ':'.code || c == ';'.code
            // Closing punctuation never starts a line (UAX #14 LB13: no break
            // before `!`, `)`, `]`, `}`, closing quotes or an ellipsis). `/` and `?`
            // stay break opportunities so long paths and URLs can wrap.
            || c == '!'.code || c == ')'.code || c == ']'.code || c == '}'.code || c == '"'.code
            || c == 0x201D || c == 0x00BB || c == 0x2026
            // `⋯` character is special used in Zed, to keep this at the end of the line.
            || c == 0x22EF
            // Non-breaking glue characters
            || c == 0x202F || c == 0x00A0 || c == 0x2011;
    }

    /**
     * Width of a character (shaped alone), cached.
     */
    public function widthForChar(c:Int):Pixels {
        if (c < 128) {
            final cached = cachedAsciiCharWidths[c];
            if (!Math.isNaN(cached)) {
                return cached;
            }
            final width = textSystem.layoutWidth(fontId, fontSize, c);
            cachedAsciiCharWidths[c] = width;
            return width;
        }
        else {
            final cached = cachedOtherCharWidths.get(c);
            if (cached != null) {
                return cached;
            }
            final width = textSystem.layoutWidth(fontId, fontSize, c);
            cachedOtherCharWidths.set(c, width);
            return width;
        }
    }

    /**
     * Updates run lengths after `truncateLine()` (exposed for tests).
     */
    public static function updateRunsAfterTruncation(result:String, ellipsis:String, runs:Array<TextRun>, truncateFrom:TruncateFrom):Void {
        final ellipsisLen = Utf8.byteLength(ellipsis);
        var truncateAt = Utf8.byteLength(result) - ellipsisLen;
        switch truncateFrom {
            case Start:
                var runIndex = runs.length - 1;
                while (runIndex >= 0) {
                    final run = runs[runIndex];
                    if (run.len <= truncateAt) {
                        truncateAt -= run.len;
                    }
                    else {
                        run.len = truncateAt + ellipsisLen;
                        runs.splice(0, runIndex);
                        break;
                    }
                    runIndex--;
                }
            case End:
                for (runIndex in 0...runs.length) {
                    final run = runs[runIndex];
                    if (run.len <= truncateAt) {
                        truncateAt -= run.len;
                    }
                    else {
                        run.len = truncateAt + ellipsisLen;
                        runs.resize(runIndex + 1);
                        break;
                    }
                }
            case Middle:
                throw 'Middle truncation calls this function with TruncateFrom.End directly';
        }
    }

    static function updateRunsAfterMiddleTruncation(ellipsis:String, runs:Array<TextRun>, frontEndIx:Int, backStartIx:Int):Void {
        final ellipsisLen = Utf8.byteLength(ellipsis);
        final originalRuns = runs.copy();
        final resultRuns:Array<TextRun> = [];

        // Front segment [0, front_end_ix) + ellipsis: walk forward until the run
        // that straddles or ends at front_end_ix, then extend that run's length
        // to include the ellipsis.
        var frontRemaining = frontEndIx;
        var frontDone = false;
        for (run in originalRuns) {
            if (frontDone) {
                break;
            }
            if (run.len <= frontRemaining) {
                resultRuns.push(run.clone());
                frontRemaining -= run.len;
            }
            else {
                final partial = run.clone();
                partial.len = frontRemaining + ellipsisLen;
                resultRuns.push(partial);
                frontDone = true;
            }
        }
        if (!frontDone) {
            // front_end_ix landed exactly on a run boundary; append ellipsis to
            // the last front run (or, if the front is empty, to the first back run).
            if (resultRuns.length > 0) {
                resultRuns[resultRuns.length - 1].len += ellipsisLen;
            }
            else if (originalRuns.length > 0) {
                final affixRun = originalRuns[0].clone();
                affixRun.len = ellipsisLen;
                resultRuns.push(affixRun);
            }
        }

        // Back segment [back_start_ix, original.len()): skip runs entirely in the
        // removed middle, keep the rest.
        var bytePos = 0;
        for (run in originalRuns) {
            final runEnd = bytePos + run.len;
            if (runEnd > backStartIx) {
                if (bytePos < backStartIx) {
                    // Run straddles back_start_ix; keep only the tail.
                    final partial = run.clone();
                    partial.len = runEnd - backStartIx;
                    resultRuns.push(partial);
                }
                else {
                    resultRuns.push(run.clone());
                }
            }
            bytePos = runEnd;
        }

        runs.resize(0);
        for (run in resultRuns)
            runs.push(run);
    }

}

/**
 * Determines whether to truncate text from the start or end.
 */
enum abstract TruncateFrom(Int) {

    /** Truncate text from the start. */
    var Start = 0;

    /** Truncate text from the end. */
    var End = 1;

    /** Truncate text from the middle, preserving the start and end. */
    var Middle = 2;

}

/**
 * Controls how soft-wrapped continuation lines are indented.
 */
enum IndentAdjustment {

    /** No indent - continuation lines start at column 0. */
    NoIndent;

    /** Match the original line's leading whitespace (the default). */
    SameIndent;

    /** Add N extra columns of indent (in space-character widths). `u32::MAX` is -1. */
    ExtraColumns(extra:Int);

}

/**
 * A fragment of a line that can be wrapped.
 */
enum LineFragment {

    /** A text fragment consisting of characters. */
    Text(text:String);

    /** A non-text element with a fixed width and its UTF-8 encoded length. */
    Element(width:Pixels, lenUtf8:Int);

}

/**
 * A boundary between two lines of text.
 */
class Boundary {

    /** The index of the last character in a line */
    public var ix:Int;

    /** The indent of the next line. */
    public var nextIndent:Int;

    public inline function new(ix:Int, nextIndent:Int) {
        this.ix = ix;
        this.nextIndent = nextIndent;
    }

    public inline function equals(other:Boundary):Bool {
        return other != null && ix == other.ix && nextIndent == other.nextIndent;
    }

    public function toString():String {
        return 'Boundary($ix, $nextIndent)';
    }

}

/**
 * Result of `LineWrapper.truncateLine()`: the (possibly) truncated text and
 * its runs. When nothing is truncated, `runs` is the array given as input
 * (Rust `Cow::Borrowed`).
 */
class TruncatedLine {

    public var text:String;

    public var runs:Array<TextRun>;

    public inline function new(text:String, runs:Array<TextRun>) {
        this.text = text;
        this.runs = runs;
    }

}
