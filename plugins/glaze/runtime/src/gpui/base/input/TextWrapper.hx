// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// (`measured_wrap`, `measured_wrap_boundaries`, `TextWrapper`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Font;
import gpui.Hsla;
import gpui.LineWrapper.Boundary;
import gpui.LineWrapper.IndentAdjustment;
import gpui.LineWrapper.LineFragment;
import gpui.Range;
import gpui.TextRun;
import gpui.WindowTextSystem;
import gpui.util.Utf8;
import haxe.io.Bytes;
import ropey.Rope;
import unicode_linebreak.UnicodeLinebreak;
import unicode_segmentation.UnicodeSegmentation;

using gpui.base.input.RopeExt;

/**
 * Used to prepare the text with soft wrap to be get lines to displayed in the Editor.
 *
 * After use lines to calculate the scroll size of the Editor.
 *
 * The fields Rust keeps private are public here for the tests of the module
 * (Rust tests live inside it); other code should not write them.
 */
class TextWrapper {

    /**
     * Rust `#[cfg(test)] MEASURED_LINES`: actual glyph-measurement passes,
     * distinguishing cache reuse from visually identical recomputation.
     */
    public static var measuredLines:Int = 0;

    public var text:Rope;

    public var font:Font;

    public var fontSize:Float;

    /** If is null, it means the text is not wrapped */
    public var wrapWidth:Null<Float>;

    public var wrappingIndent:WrappingIndent;

    /** Spaces per tab stop, so tabs are measured as they are drawn. */
    public var tabSize:Int;

    /** The lines by split \n */
    public var lines:LineItems;

    public var inlineMetrics:Array<InlineMetric>;

    /** Exact native widths avoid reshaping the same prefix when a drag crosses wrap thresholds. */
    final widthMeasurements:WidthMeasurements;

    var _initialized:Bool;

    public function new(font:Font, fontSize:Float, wrapWidth:Null<Float>) {
        this.text = new Rope();
        this.font = font;
        this.fontSize = fontSize;
        this.wrapWidth = wrapWidth;
        this.wrappingIndent = WrappingIndent.defaultValue();
        this.tabSize = TabSize.defaultValue().tabSize;
        this.lines = new LineItems();
        this.inlineMetrics = [];
        this.widthMeasurements = new WidthMeasurements();
        this._initialized = false;
    }

    public inline function setDefaultText(text:Rope):Void {
        this.text = text.clone();
    }

    /** Get reference to the rope text. */
    public inline function getText():Rope {
        return text;
    }

    /** Get the total number of lines including wrapped lines. */
    public inline function len():Int {
        return lines.summary().wrapRows;
    }

    /** Get the total number of buffer lines. */
    public inline function linesCount():Int {
        return lines.summary().bufferRows;
    }

    /** Get the 0-based row index of the longest line (by byte length). */
    public inline function longestRow():Int {
        return lines.summary().longestRow;
    }

    /** Get the line item by buffer row index. */
    public inline function line(row:Int):Null<LineItem> {
        return lines.get(row);
    }

    /** Iterate buffer lines in order. */
    public inline function iterLines():Iterator<LineItem> {
        return lines.iterator();
    }

    /**
     * First wrap row of buffer line `row`. Returns the total wrap row count if `row` is
     * out of range.
     */
    public function bufferLineToFirstWrapRow(row:Int):Int {
        return lines.wrapRowsBefore(row);
    }

    /** Wrap row range of buffer line `row`. */
    public function bufferLineToWrapRowRange(row:Int):Range {
        final start = lines.wrapRowsBefore(row);
        final item = lines.get(row);
        final len = item != null ? item.linesLen() : 0;
        return new Range(start, start + len);
    }

    /** Buffer line containing wrap row `wrapRow`, clamped to the last line. */
    public function wrapRowToBufferLine(wrapRow:Int):Int {
        final index = lines.itemIndexForWrapRow(wrapRow);
        if (index < lines.length())
            return index;
        final count = linesCount();
        return count > 0 ? count - 1 : 0;
    }

    public function setWrapWidth(wrapWidth:Null<Float>, cx:App):Void {
        if (wrapWidth == this.wrapWidth)
            return;

        final widthOnly = this.wrapWidth != null && wrapWidth != null;
        this.wrapWidth = wrapWidth;
        if (widthOnly && lines.summary().validWidths.contains(wrapWidth))
            return;
        final text = this.text.clone();
        updateWrapped(text, new Range(0, text.len()), text, widthOnly, cx);
    }

    public function setWrappingIndent(wrappingIndent:WrappingIndent, cx:App):Void {
        if (wrappingIndent == this.wrappingIndent)
            return;

        this.wrappingIndent = wrappingIndent;
        updateAll(text.clone(), cx);
    }

    /** Returns whether the tab size changed, and so the wrapping. */
    public function setTabSize(tabSize:Int, cx:App):Bool {
        if (tabSize == this.tabSize)
            return false;

        this.tabSize = tabSize;
        updateAll(text.clone(), cx);
        return true;
    }

    public function setFont(font:Font, fontSize:Float, cx:App):Void {
        if (this.font.equals(font) && this.fontSize == fontSize)
            return;

        this.font = font;
        this.fontSize = fontSize;
        updateAll(text.clone(), cx);
    }

    public function prepareIfNeed(text:Rope, cx:App):Bool {
        if (_initialized)
            return false;
        _initialized = true;
        updateAll(text, cx);
        return true;
    }

    /**
     * Update the text wrapper and recalculate the wrapped lines.
     *
     * - `changedText`: The text `Rope` that has changed.
     * - `range`: The `selected_range` before change.
     * - `newText`: The inserted text.
     */
    public function update(changedText:Rope, range:Range, newText:Rope, cx:App):Void {
        updateWrapped(changedText, range, newText, false, cx);
    }

    /** Only width changes reuse rows and measurements; edits, fonts, tab stops and inline metrics remeasure. */
    function updateWrapped(changedText:Rope, range:Range, newText:Rope, reuseWidths:Bool, cx:App):Void {
        final lineWrapper = cx.textSystem().lineWrapper(font, fontSize);
        final metrics = inlineMetrics;
        final measurements = widthMeasurements;
        if (!reuseWidths)
            measurements.clear();
        final textSystem = new WindowTextSystem(cx.textSystem());
        final font = this.font;
        final fontSize = this.fontSize;
        final wrappingIndent = this.wrappingIndent;
        final tabStop = TabStops.tabStopWidth(textSystem, font, fontSize, tabSize);
        updateLines(changedText, range, newText, reuseWidths, (lineStr:String, wrapWidth:Float, lineStart:Int) -> {
            final lineBytes = Bytes.ofString(lineStr);
            final lineLen = lineBytes.length;
            final fragments:Array<LineFragment> = [];
            var offset = 0;
            var first = 0;
            {
                // metrics.partition_point(|(r, _)| r.end <= line_start)
                var lo = 0;
                var hi = metrics.length;
                while (lo < hi) {
                    final mid = (lo + hi) >> 1;
                    if (metrics[mid].range.end <= lineStart)
                        lo = mid + 1;
                    else
                        hi = mid;
                }
                first = lo;
            }
            for (i in first...metrics.length) {
                final metric = metrics[i];
                if (metric.range.start >= lineStart + lineLen)
                    break;
                if (metric.range.start < lineStart || metric.range.end > lineStart + lineLen)
                    continue;
                final start = metric.range.start - lineStart;
                final end = metric.range.end - lineStart;
                if (!isCharBoundary(lineBytes, start) || !isCharBoundary(lineBytes, end))
                    continue;
                if (offset < start)
                    fragments.push(LineFragment.Text(lineBytes.getString(offset, start - offset)));
                fragments.push(LineFragment.Element(metric.width, end - start));
                offset = end;
            }
            if (fragments.length == 0) {
                return measuredWrap(lineStr, wrapWidth, wrappingIndent, text -> {
                    final textLen = Utf8.byteLength(text);
                    return measurements.measure(text, textLen, () -> {
                        final layout = textSystem.layoutLine(text, fontSize, [new TextRun(textLen, font, Hsla.black())]);
                        return TabStops.expandedWidth(layout, text, tabStop);
                    });
                });
            }
            if (offset < lineLen)
                fragments.push(LineFragment.Text(lineBytes.getString(offset, lineLen - offset)));
            // Inline element widths retain the original wrapper; no safe interval is inferred.
            return MeasuredWrap.uncached(lineWrapper.wrapLine(fragments, wrapWidth, IndentAdjustment.SameIndent));
        });
    }

    static inline function isCharBoundary(bytes:Bytes, index:Int):Bool {
        return index == 0 || index == bytes.length || (index > 0 && index < bytes.length && (bytes.get(index) & 0xC0) != 0x80);
    }

    public function adjustInlineMetrics(range:Range, newLen:Int):Void {
        if (inlineMetrics.length == 0)
            return;
        final shift = newLen - range.len();
        final result:Array<InlineMetric> = [];
        for (metric in inlineMetrics) {
            final token = metric.range;
            if (token.start < range.end && range.start < token.end)
                continue;
            var adjusted = token;
            if (token.start >= range.end) {
                // `checked_add_signed` drops the token when it would go below zero
                final start = token.start + shift;
                final end = token.end + shift;
                if (start < 0 || end < 0)
                    continue;
                adjusted = new Range(start, end);
            }
            result.push(new InlineMetric(adjusted, metric.width));
        }
        inlineMetrics = result;
    }

    public function setInlineMetrics(metrics:Array<InlineMetric>, cx:App):Void {
        if (InlineMetric.arrayEquals(inlineMetrics, metrics))
            return;
        // Only rows whose element geometry changed need another wrap pass.
        final affected:Array<Range> = [];
        final old = inlineMetrics;
        var o = 0;
        var n = 0;
        while (o < old.length || n < metrics.length) {
            final a = o < old.length ? old[o] : null;
            final b = n < metrics.length ? metrics[n] : null;
            if (a != null && b != null && a.equals(b)) {
                o++;
                n++;
            }
            else if (a != null && b != null && a.range.start <= b.range.start) {
                affected.push(a.range);
                o++;
            }
            else if (b != null) {
                affected.push(b.range);
                n++;
            }
            else if (a != null) {
                affected.push(a.range);
                o++;
            }
            else {
                break;
            }
        }
        inlineMetrics = metrics;
        final text = this.text.clone();
        final rows:Array<Int> = [];
        for (r in affected)
            rows.push(text.offsetToPoint(r.start < text.len() ? r.start : text.len()).row);
        rows.sort((a, b) -> a - b);
        var previous = -1;
        for (row in rows) {
            if (row == previous)
                continue;
            previous = row;
            final start = text.lineStartOffset(row);
            final end = text.lineEndOffset(row);
            update(text, new Range(start, end), Rope.fromStr(text.slice(start, end).toString()), cx);
        }
    }

    /**
     * Rust `#[cfg(test)] _update`: keeps the synthetic edit tests independent of
     * native glyph measurement.
     */
    public function _update(changedText:Rope, range:Range, newText:Rope, wrapLine:(String, Float, Int) -> Array<Boundary>):Void {
        updateLines(changedText, range, newText, false, (text, width, start) -> MeasuredWrap.uncached(wrapLine(text, width, start)));
    }

    /** Splice changed rows into the sole display map, retaining valid rows on full width passes. */
    public function updateLines(changedText:Rope, range:Range, newText:Rope, reuseWidths:Bool, wrapLine:(String, Float, Int) -> MeasuredWrap):Void {
        // Remove the old changed lines.
        final bufferLineCount = linesCount();
        final lastRow = bufferLineCount > 0 ? bufferLineCount - 1 : 0;
        var startRow = text.offsetToPoint(range.start).row;
        if (startRow > lastRow)
            startRow = lastRow;
        var endRow = text.offsetToPoint(range.end).row;
        if (endRow > lastRow)
            endRow = lastRow;

        // To add the new lines.
        final newStartRow = changedText.offsetToPoint(range.start).row;
        final newEndRow = changedText.offsetToPoint(range.start + newText.len()).row;

        final newLines:Array<LineItem> = [];
        final wrapWidth = this.wrapWidth;
        var previousIndex = 0;

        // line not contains `\n`.
        for (row in newStartRow...newEndRow + 1) {
            if (reuseWidths) {
                final previous = lines.get(previousIndex++);
                if (previous != null && wrapWidth != null && previous.validWidths.contains(wrapWidth)) {
                    newLines.push(previous.clone());
                    continue;
                }
            }
            final line = changedText.sliceLine(row);
            final lineLen = line.len();
            final wrappedLines:Array<Range> = [];
            var prevBoundaryIx = 0;
            var indentChars = 0;
            final validWidths = WidthRange.all();

            // If wrap_width is null, skip wrapping to disable word wrap
            if (wrapWidth != null) {
                final lineStr = line.toString();
                switch wrappingIndent {
                    case Same:
                        // Here only have wrapped line, if there is no wrap meet, the `line_wraps`
                        // result will empty.
                        final measured = wrapLine(lineStr, wrapWidth, changedText.lineStartOffset(row));
                        validWidths.intersect(measured.validWidths);
                        for (boundary in measured.boundaries) {
                            wrappedLines.push(new Range(prevBoundaryIx, boundary.ix));
                            prevBoundaryIx = boundary.ix;
                            indentChars = boundary.nextIndent;
                        }
                    case None:
                        // The first visual line keeps the line's leading indentation, so it is
                        // wrapped as is.
                        final boundaries = wrapLine(lineStr, wrapWidth, changedText.lineStartOffset(row));
                        validWidths.intersect(boundaries.validWidths);
                        if (boundaries.boundaries.length > 0) {
                            final firstIx = boundaries.boundaries[0].ix;
                            wrappedLines.push(new Range(prevBoundaryIx, firstIx));
                            prevBoundaryIx = firstIx;

                            final continuation = wrapLine(Utf8.substringFrom(lineStr, firstIx), wrapWidth, changedText.lineStartOffset(row) + firstIx);
                            validWidths.intersect(continuation.validWidths);
                            for (boundary in continuation.boundaries) {
                                final ix = firstIx + boundary.ix;
                                wrappedLines.push(new Range(prevBoundaryIx, ix));
                                prevBoundaryIx = ix;
                            }
                        }
                }
            }

            // Reset of the line
            if (prevBoundaryIx < lineLen || prevBoundaryIx == 0)
                wrappedLines.push(new Range(prevBoundaryIx, lineLen));

            newLines.push(new LineItem(lineLen, indentChars, wrappedLines, validWidths));
        }

        if (lines.isEmpty()) {
            lines = LineItems.fromArray(newLines);
        }
        else {
            // Keep the rows before the edit, skip the replaced rows, keep the untouched rows after
            lines.splice(startRow, endRow + 1, newLines);
        }

        text = changedText.clone();
    }

    /** Update the text wrapper and recalculate the wrapped lines. */
    function updateAll(text:Rope, cx:App):Void {
        update(text, new Range(0, text.len()), text, cx);
    }

    /**
     * Return display point (with soft wrap) from the given byte offset in the text.
     */
    public function offsetToDisplayPoint(offset:Int):WrapDisplayPoint {
        return offsetToDisplayPointWithAffinity(offset, false);
    }

    /**
     * Like `offsetToDisplayPoint`, but honours the caret's line-end affinity.
     *
     * A soft wrap boundary is one offset shared by two visual rows. Without affinity it always
     * resolves to the start of the second row, which is wrong for a caret that is being drawn at
     * the end of the first one: vertical movement would then step from the row below the one
     * the user can see.
     */
    public function offsetToDisplayPointWithAffinity(offset:Int, lineEndAffinity:Bool):WrapDisplayPoint {
        final row = text.offsetToPoint(offset).row;
        final start = text.lineStartOffset(row);

        // Seek to buffer row
        final wrappedRow = lines.wrapRowsBefore(row);
        final line = lines.get(row);
        if (line == null)
            return new WrapDisplayPoint(wrappedRow, 0, 0);

        final localOffset = offset > start ? offset - start : 0;
        for (ix in 0...line.wrappedLines.length) {
            final range = line.wrappedLines[ix];
            // With affinity the boundary offset closes the current row instead of opening the
            // next one, so the range is matched inclusively.
            final matches = range.contains(localOffset) || (lineEndAffinity && localOffset == range.end);
            if (matches)
                return new WrapDisplayPoint(wrappedRow + ix, ix, localOffset > range.start ? localOffset - range.start : 0);
        }

        // Otherwise return the eof of the line.
        final count = line.linesLen();
        final lastLen = count > 0 ? line.wrappedLines[count - 1].len() : 0;
        final ix = count > 0 ? count - 1 : 0;
        return new WrapDisplayPoint(wrappedRow + ix, ix, lastLen);
    }

    /**
     * Return byte offset in the text from the given display point (with soft wrap).
     */
    public function displayPointToOffset(point:WrapDisplayPoint):Int {
        // Seek to wrap row `point.row`
        final index = lines.itemIndexForWrapRow(point.row);
        final line = lines.get(index);
        if (line == null)
            return text.len();
        final wrappedRow = lines.wrapRowsBefore(index);
        final row = index;

        final lineStart = text.lineStartOffset(row);
        final localRow = point.row > wrappedRow ? point.row - wrappedRow : 0;
        if (localRow < line.wrappedLines.length) {
            final range = line.wrappedLines[localRow];
            final column = range.start + point.column;
            return lineStart + (column < range.end ? column : range.end);
        }
        else {
            // If not found, return the end of the line.
            return lineStart + line.len();
        }
    }

    public function displayPointToPoint(point:WrapDisplayPoint):RopePoint {
        final offset = displayPointToOffset(point);
        return text.offsetToPoint(offset);
    }

    public function pointToDisplayPoint(point:RopePoint):WrapDisplayPoint {
        final offset = text.pointToOffset(point);
        return offsetToDisplayPoint(offset);
    }

/// Wrapping

    /** Leading spaces kept as the continuation indent (`WrappingIndent.Same`). */
    static function leadingIndent(bytes:Bytes, wrappingIndent:WrappingIndent):Int {
        if (wrappingIndent != Same)
            return 0;
        var count = 0;
        while (count < bytes.length && bytes.get(count) == ' '.code)
            count++;
        return count < LineWrapper.MAX_INDENT ? count : LineWrapper.MAX_INDENT;
    }

    /** Grapheme ends and the line break opportunities that fall on one of them. */
    static function graphemeEnds(bytes:Bytes):Array<Int> {
        final ends:Array<Int> = [];
        final graphemes = UnicodeSegmentation.graphemeIndicesBytes(bytes, 0, bytes.length, true);
        while (graphemes.nextRange())
            ends.push(graphemes.rangeEnd);
        return ends;
    }

    static function breakOpportunities(bytes:Bytes, ends:Array<Int>):Array<Int> {
        final opportunities:Array<Int> = [];
        final breaks = UnicodeLinebreak.linebreaksBytes(bytes, 0, bytes.length);
        while (breaks.nextBreak()) {
            if (binarySearch(ends, breaks.index))
                opportunities.push(breaks.index);
        }
        return opportunities;
    }

    static function binarySearch(values:Array<Int>, value:Int):Bool {
        var lo = 0;
        var hi = values.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            final v = values[mid];
            if (v == value)
                return true;
            if (v < value)
                lo = mid + 1;
            else
                hi = mid;
        }
        return false;
    }

    /** `values[from..].partition_point(|&ix| ix <= limit)` (relative to `from`) */
    static function partitionPointLe(values:Array<Int>, from:Int, limit:Int):Int {
        var lo = from;
        var hi = values.length;
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (values[mid] <= limit)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo - from;
    }

    static inline function sub(bytes:Bytes, start:Int, end:Int):String {
        return end > start ? bytes.getString(start, end - start) : '';
    }

    /**
     * Rust `#[cfg(test)] measured_wrap_boundaries`: the unmodified upstream
     * character-first algorithm, the independent differential-test oracle.
     */
    public static function measuredWrapBoundaries(text:String, width:Float, wrappingIndent:WrappingIndent, measure:(String) -> Float):Array<Boundary> {
        final bytes = Bytes.ofString(text);
        final textLen = bytes.length;
        final indent = leadingIndent(bytes, wrappingIndent);
        final indentWidth = measure(sub(bytes, 0, indent));
        final ends = graphemeEnds(bytes);
        final opportunities = breakOpportunities(bytes, ends);
        final result:Array<Boundary> = [];
        var first = 0;
        var start = 0;
        while (first < ends.length) {
            final available = start == 0 ? width : width - indentWidth;
            // Find the fitting prefix locally. Exponential probing avoids shaping
            // the entire remaining logical line for every visual row of a long paste.
            final remaining = ends.length - first;
            var low = 0;
            var high = 1;
            while (measure(sub(bytes, start, ends[first + high - 1])) <= available) {
                low = high;
                if (high == remaining)
                    break;
                high = high * 2 < remaining ? high * 2 : remaining;
            }
            while (low + 1 < high) {
                final mid = Std.int((low + high) / 2);
                if (measure(sub(bytes, start, ends[first + mid - 1])) <= available)
                    low = mid;
                else
                    high = mid;
            }
            // An indivisible grapheme wider than the viewport still consumes a row.
            final fittingEnd = ends[first + (low > 1 ? low : 1) - 1];
            if (fittingEnd == textLen)
                break;
            final candidate = partitionPointLe(opportunities, 0, fittingEnd);
            var end = fittingEnd;
            if (candidate > 0) {
                final ix = opportunities[candidate - 1];
                if (ix > start && (start != 0 || ix > indent))
                    end = ix;
            }
            result.push(new Boundary(end, indent));
            first = partitionPointLe(ends, 0, end);
            start = end;
        }
        return result;
    }

    /** Preserve the measured comparisons that make these breaks valid at nearby widths. */
    public static function measuredWrap(text:String, width:Float, wrappingIndent:WrappingIndent, measure:(String) -> Float):MeasuredWrap {
        measuredLines++;
        final validWidths = WidthRange.all();
        final bytes = Bytes.ofString(text);
        final textLen = bytes.length;
        final indent = leadingIndent(bytes, wrappingIndent);
        final indentWidth = measure(sub(bytes, 0, indent));
        final ends = graphemeEnds(bytes);
        final opportunities = breakOpportunities(bytes, ends);
        final result:Array<Boundary> = [];
        var first = 0;
        var start = 0;
        while (first < ends.length) {
            final available = start == 0 ? width : width - indentWidth;
            final indentArg = start == 0 ? 0.0 : indentWidth;
            // Probe legal word breaks first. Character-fit changes inside the same word do not
            // change the result, so they must not invalidate a cached line during a divider drag.
            // Bound word probes before shaping: a single word can span the entire remaining line.
            // Beyond this local window, use the original exponential grapheme search instead.
            final wordProbeEnd = first + MAX_WORD_PROBE_GRAPHEMES - 1 < ends.length ? ends[first + MAX_WORD_PROBE_GRAPHEMES - 1] : textLen;

            // `fitting(candidates, limit)` over `candidates[from..]`: the number of
            // candidates that fit, or -1 (Rust `None`) when a probe passes `limit`
            // (-1 for no limit).
            function fitting(candidates:Array<Int>, from:Int, limit:Int):Int {
                final count = candidates.length - from;
                // `fits(end)`: 1 fits, 0 does not, -1 past the limit
                function fits(end:Int):Int {
                    if (limit >= 0 && end > limit)
                        return -1;
                    return validWidths.fits(measure(sub(bytes, start, end)), available, indentArg) ? 1 : 0;
                }
                var low = 0;
                var high = 1;
                while (high <= count) {
                    final f = fits(candidates[from + high - 1]);
                    if (f < 0)
                        return -1;
                    if (f == 0)
                        break;
                    low = high;
                    if (high == count)
                        break;
                    high = high * 2 < count ? high * 2 : count;
                }
                while (low + 1 < high) {
                    final mid = Std.int((low + high) / 2);
                    final f = fits(candidates[from + mid - 1]);
                    if (f < 0)
                        return -1;
                    if (f == 1)
                        low = mid;
                    else
                        high = mid;
                }
                return low;
            }

            // opportunities.partition_point(|&ix| ix <= start || (start == 0 && ix <= indent))
            final firstWord = partitionPointLe(opportunities, 0, start == 0 && indent > start ? indent : start);
            final wordsCount = opportunities.length - firstWord;
            final wordCount = fitting(opportunities, firstWord, wordProbeEnd);
            var end:Int;
            if (wordCount > 0) {
                end = opportunities[firstWord + wordCount - 1];
            }
            else {
                // An oversized word retains the original complete-grapheme fallback. At least one
                // grapheme is consumed even when it is wider than the available viewport.
                final count = fitting(ends, first, -1);
                final fittingEnd = ends[first + (count > 1 ? count : 1) - 1];
                if (fittingEnd == textLen)
                    break;
                final fittingWords = wordsCount > 0 ? partitionPointLe(opportunities, firstWord, fittingEnd) : 0;
                end = fittingWords > 0 ? opportunities[firstWord + fittingWords - 1] : fittingEnd;
            }
            if (end == textLen)
                break;
            result.push(new Boundary(end, indent));
            first = partitionPointLe(ends, 0, end);
            start = end;
        }
        return new MeasuredWrap(result, validWidths);
    }

    static inline final MAX_WORD_PROBE_GRAPHEMES:Int = 256;

}
