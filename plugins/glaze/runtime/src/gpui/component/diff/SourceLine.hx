// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`SourceLine`, `source_line`, `display_chunks`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.Range;
import gpui.util.Utf8;
import unicode_segmentation.UnicodeSegmentation;

/**
 * One supplied source line and its display form.
 *
 * Offsets are UTF-8 byte offsets like the original. The line also keeps the
 * UTF-16 indices of its source range (`sourceUnitStart`, `sourceUnitEnd`) so
 * that slicing the side's source is constant time.
 */
@:allow(gpui.component.diff)
class SourceLine {

    var _lineNumber:Int;

    var _text:String;

    var _textLen:Int;

    var _display:String;

    var _displayLen:Int;

    var chunks:Array<DisplayChunk>;

    var _counterpart:Null<Int> = null;

    // Only expanded tabs need an entry; ordinary UTF-8 bytes map by identity
    // plus the cumulative expansion of earlier tabs.
    var displayTabs:Array<DisplayTab>;

    var _source:Range;

    var _contentEnd:Int;

    var sourceUnitStart:Int;

    var sourceUnitEnd:Int;

    function new() {}

    /** The one-based line number in the source file. */
    public inline function lineNumber():Int {
        return _lineNumber;
    }

    /** The source content, without its line ending. */
    public inline function text():String {
        return _text;
    }

    /** The length of `text()` in UTF-8 bytes. */
    public inline function textLen():Int {
        return _textLen;
    }

    /** The content with tabs expanded, as painted. */
    public inline function display():String {
        return _display;
    }

    /** The length of `display()` in UTF-8 bytes. */
    public inline function displayLen():Int {
        return _displayLen;
    }

    /** Display ranges painted as separate text runs, bounding shaping cost. */
    public function chunkRanges():Array<Range> {
        return [for (chunk in chunks) chunk.range];
    }

    /** The index of the paired line on the other side, if any. */
    public inline function counterpart():Null<Int> {
        return _counterpart;
    }

    /** The byte range in the side's source, including the line ending. */
    public inline function source():Range {
        return _source;
    }

    /** The source offset where the line ending begins. */
    public inline function contentEnd():Int {
        return _contentEnd;
    }

    /** The whole line in `source`, its ending included (Rust `&source[line.source()]`). */
    public inline function sourceText(source:String):String {
        return source.substring(sourceUnitStart, sourceUnitEnd);
    }

    /**
     * Reuses the retained text for a projected chunk. The fallback supports
     * valid partial ranges.
     */
    public function chunkText(range:Range):String {
        if (range.start == 0 && range.end == _displayLen)
            return _display;
        // `partition_point(|chunk| chunk.range.start < range.start)`
        var ix = 0;
        while (ix < chunks.length && chunks[ix].range.start < range.start)
            ix++;
        if (ix < chunks.length && chunks[ix].range.equals(range))
            return chunks[ix].text;
        if (range.start > range.end || range.end > _displayLen || !Utf8.isCharBoundary(_display, range.start)
            || !Utf8.isCharBoundary(_display, range.end))
            return '';
        return Utf8.substring(_display, range.start, range.end);
    }

    public function sourceOffset(displayOffset:Int):Int {
        if (displayOffset > _displayLen)
            displayOffset = _displayLen;
        // `partition_point(|tab| tab.display_offset <= display_offset)`
        var preceding = 0;
        while (preceding < displayTabs.length && displayTabs[preceding].displayOffset <= displayOffset)
            preceding++;
        if (preceding == 0)
            return displayOffset;
        final tab = displayTabs[preceding - 1];
        if (displayOffset < tab.displayOffset + tab.width)
            return tab.sourceOffset;
        return displayOffset - (tab.displayOffset + tab.width - tab.sourceOffset - 1);
    }

    public function displayRange(source:Range):Range {
        return new Range(displayOffset(source.start), displayOffset(source.end));
    }

    function displayOffset(sourceOffset:Int):Int {
        if (sourceOffset > _textLen)
            sourceOffset = _textLen;
        // `partition_point(|tab| tab.source_offset < source_offset)`
        var preceding = 0;
        while (preceding < displayTabs.length && displayTabs[preceding].sourceOffset < sourceOffset)
            preceding++;
        final expansion = if (preceding == 0) {
            0;
        }
        else {
            final tab = displayTabs[preceding - 1];
            tab.displayOffset + tab.width - tab.sourceOffset - 1;
        }
        return sourceOffset + expansion;
    }

    /**
     * Builds the display form of one source line from its range in `source`.
     * `unitStart` and `unitEnd` are the UTF-16 indices of the range.
     */
    static function build(source:String, range:Range, unitStart:Int, unitEnd:Int, lineNumber:Int):SourceLine {
        final raw = source.substring(unitStart, unitEnd);
        var content = raw;
        if (StringTools.endsWith(content, '\n')) {
            content = content.substr(0, content.length - 1);
            if (StringTools.endsWith(content, '\r'))
                content = content.substr(0, content.length - 1);
        }
        final contentLen = range.end - range.start - (raw.length - content.length);
        final line = new SourceLine();
        line._lineNumber = lineNumber;
        line._text = content;
        line._textLen = contentLen;
        if (content.indexOf('\t') != -1) {
            final display = new StringBuf();
            var displayLen = 0;
            final displayTabs = [];
            var column = 0;
            var byteIx = 0;
            var i = 0;
            while (i < content.length) {
                final c = ttf.Utf8.codePointAt(content, i);
                final units = c >= 0x10000 ? 2 : 1;
                if (c == '\t'.code) {
                    final spaces = 4 - column % 4;
                    displayTabs.push(new DisplayTab(byteIx, displayLen, spaces));
                    for (_ in 0...spaces)
                        display.addChar(' '.code);
                    displayLen += spaces;
                    column += spaces;
                }
                else {
                    display.add(content.substr(i, units));
                    displayLen += Utf8.codePointLength(c);
                    column += 1;
                }
                byteIx += Utf8.codePointLength(c);
                i += units;
            }
            line._display = display.toString();
            line._displayLen = displayLen;
            line.displayTabs = displayTabs;
        }
        else {
            line._display = content;
            line._displayLen = contentLen;
            line.displayTabs = [];
        }
        final display = line._display;
        line.chunks = [
            for (range in displayChunks(display)) {
                final text = range.start == 0 && range.end == line._displayLen ? display : Utf8.substring(display, range.start, range.end);
                new DisplayChunk(range, text);
            }
        ];
        line._contentEnd = range.start + contentLen;
        line._source = range;
        line.sourceUnitStart = unitStart;
        line.sourceUnitEnd = unitEnd;
        return line;
    }

    /** `source_lines`: every line of `text`, numbered from one (test helper of the original). */
    public static function sourceLines(text:String):Array<SourceLine> {
        final rv = [];
        var offset = 0;
        var unit = 0;
        var index = 0;
        while (unit < text.length) {
            var next = text.indexOf('\n', unit);
            final unitEnd = next == -1 ? text.length : next + 1;
            final bytes = Utf8.byteLength(text.substring(unit, unitEnd));
            rv.push(build(text, new Range(offset, offset + bytes), unit, unitEnd, index + 1));
            offset += bytes;
            unit = unitEnd;
            index++;
        }
        return rv;
    }

    /**
     * Bound native selection projection while preserving grapheme boundaries.
     * Exceptionally large clusters split only at UTF-8 boundaries.
     */
    public static function displayChunks(text:String):Array<Range> {
        final MAX_BYTES = 512;
        final len = Utf8.byteLength(text);
        if (len <= MAX_BYTES)
            return [new Range(0, len)];
        final chunks = [];
        var start = 0;
        var end = 0;
        final graphemes = UnicodeSegmentation.graphemeIndices(text, true);
        while (true) {
            final grapheme = graphemes.next();
            if (grapheme == null)
                break;
            final ix = graphemes.index;
            final graphemeLen = Utf8.byteLength(grapheme);
            if (ix + graphemeLen - start > MAX_BYTES && start < ix) {
                chunks.push(new Range(start, ix));
                start = ix;
            }
            if (graphemeLen > MAX_BYTES) {
                var relative = 0;
                var i = 0;
                while (i < grapheme.length) {
                    final c = ttf.Utf8.codePointAt(grapheme, i);
                    final offset = ix + relative;
                    final charLen = Utf8.codePointLength(c);
                    if (offset + charLen - start > MAX_BYTES) {
                        chunks.push(new Range(start, offset));
                        start = offset;
                    }
                    relative += charLen;
                    i += c >= 0x10000 ? 2 : 1;
                }
            }
            end = ix + graphemeLen;
        }
        if (start < end)
            chunks.push(new Range(start, end));
        return chunks;
    }

}

@:allow(gpui.component.diff)
class DisplayChunk {

    final range:Range;

    final text:String;

    function new(range:Range, text:String) {
        this.range = range;
        this.text = text;
    }

}

@:allow(gpui.component.diff)
class DisplayTab {

    final sourceOffset:Int;

    final displayOffset:Int;

    final width:Int;

    function new(sourceOffset:Int, displayOffset:Int, width:Int) {
        this.sourceOffset = sourceOffset;
        this.displayOffset = displayOffset;
        this.width = width;
    }

}
