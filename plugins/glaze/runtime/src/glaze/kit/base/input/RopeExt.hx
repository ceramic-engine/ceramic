// Ported from gpui-kit 0.8.1: crates/base/src/input/base/rope_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;
import ropey.LineType;
import ropey.Rope;
import ropey.RopeSlice;
import unicode_segmentation.Tables;

/**
 * Extra utility methods for `Rope` (Rust trait `RopeExt`), used with
 * `using glaze.kit.base.input.RopeExt;`.
 *
 * Offsets are UTF-8 byte offsets, rows are 0-based.
 */
class RopeExt {

    /**
     * Start offset of the line at the given row (0-based) index.
     */
    public static function lineStartOffset(self:Rope, row:Int):Int {
        return pointToOffset(self, new RopePoint(row, 0));
    }

    /**
     * End offset (excluding `\n`) of the line at the given row (0-based)
     * index. Returns the end of the rope if the row is out of bounds.
     */
    public static function lineEndOffset(self:Rope, row:Int):Int {
        if (row > linesLen(self)) {
            return self.len();
        }

        return lineStartOffset(self, row) + lineLen(self, row);
    }

    /**
     * A line slice at the given row (0-based) index, including `\r` if
     * present, but not `\n`. Empty when the row is out of bounds.
     */
    public static function sliceLine(self:Rope, row:Int):RopeSlice {
        final totalLines = linesLen(self);
        if (row >= totalLines) {
            return self.slice(0, 0);
        }

        final line = self.line(row, LineType.LF);
        if (line.len() > 0) {
            final lineEnd = line.len() - 1;
            if (line.isCharBoundary(lineEnd) && line.char(lineEnd) == '\n'.code) {
                return line.slice(0, lineEnd);
            }
        }

        return line;
    }

    /**
     * A slice of the rows in the given range (0-based, end exclusive),
     * clamped to the valid range.
     */
    public static function sliceLines(self:Rope, rowsRange:Range):RopeSlice {
        final start = lineStartOffset(self, rowsRange.start);
        final end = lineEndOffset(self, saturatingSub(rowsRange.end, 1));
        return self.slice(start, end);
    }

    /**
     * An iterator over all lines in the rope. Each line slice includes `\r`
     * if present, but not `\n`.
     */
    public static function iterLines(self:Rope):RopeLines {
        return new RopeLines(self);
    }

    /**
     * The number of lines in the rope.
     */
    public static function linesLen(self:Rope):Int {
        return self.lenLines(LineType.LF);
    }

    /**
     * Length of the row (0-based) in bytes, including `\r` if present, but
     * not `\n`. 0 when the row is out of bounds.
     */
    public static function lineLen(self:Rope, row:Int):Int {
        return sliceLine(self, row).len();
    }

    /**
     * Replace the text in the given byte range with new text. The range is
     * clipped to char boundaries (start to the left, end to the right).
     */
    public static function replace(self:Rope, range:Range, newText:String):Void {
        final start = clipOffset(self, range.start, Bias.Left);
        final end = clipOffset(self, range.end, Bias.Right);
        self.remove(start, end);
        self.insert(start, newText);
    }

    /**
     * The char (code point) at the given byte offset, or null when out of
     * bounds or not on a char boundary.
     */
    public static function charAt(self:Rope, offset:Int):Null<Int> {
        if (offset > self.len()) {
            return null;
        }

        return self.getChar(offset);
    }

    /**
     * The byte offset of the given line, column `LspPosition` (0-based). The
     * column is in characters.
     */
    public static function positionToOffset(self:Rope, pos:LspPosition):Int {
        final line = sliceLine(self, pos.line);
        // Clamp out-of-range columns, then use Ropey's index to avoid rescanning long lines.
        return lineStartOffset(self, pos.line) + line.charToByteIdx(minInt(pos.character, line.lenChars()));
    }

    /**
     * The line, column `LspPosition` (0-based) of the given byte offset. The
     * column is in characters.
     */
    public static function offsetToPosition(self:Rope, offset:Int):LspPosition {
        final point = offsetToPoint(self, offset);
        final line = sliceLine(self, point.row);
        final offset = line.utf16ToByteIdx(line.byteToUtf16Idx(point.column));
        final character = line.slice(0, offset).lenChars();
        return new LspPosition(point.row, character);
    }

    /**
     * The point (row, column) of the given byte offset. The column is in bytes.
     */
    public static function offsetToPoint(self:Rope, offset:Int):RopePoint {
        final offset = clipOffset(self, offset, Bias.Left);
        final row = self.byteToLineIdx(offset, LineType.LF);
        final lineStart = self.lineToByteIdx(row, LineType.LF);
        final column = saturatingSub(offset, lineStart);
        return new RopePoint(row, column);
    }

    /**
     * The byte offset of the given point (row, column). The column is 0-based
     * in bytes.
     */
    public static function pointToOffset(self:Rope, point:RopePoint):Int {
        if (point.row >= linesLen(self)) {
            return self.len();
        }

        final lineStart = self.lineToByteIdx(point.row, LineType.LF);
        return lineStart + point.column;
    }

    /**
     * The word byte range at the given byte offset (0-based).
     */
    public static function wordRange(self:Rope, offset:Int):Null<Range> {
        if (offset >= self.len()) {
            return null;
        }

        var leftLen = 0;
        final offset = clipOffset(self, offset, Bias.Left);
        final backward = self.charsAt(offset).reversed();
        while (true) {
            final c = backward.next();
            if (c == -1) break;
            if (Tables.isAlphanumeric(c) || c == '_'.code) {
                leftLen += utf8Len(c);
            }
            else {
                break;
            }
        }
        final start = saturatingSub(offset, leftLen);

        var rightLen = 0;
        final forward = self.charsAt(offset);
        while (true) {
            final c = forward.next();
            if (c == -1) break;
            if (Tables.isAlphanumeric(c) || c == '_'.code) {
                rightLen += utf8Len(c);
            }
            else {
                break;
            }
        }

        final end = offset + rightLen;

        return start == end ? null : new Range(start, end);
    }

    /**
     * The word at the given byte offset (0-based), or an empty string.
     */
    public static function wordAt(self:Rope, offset:Int):String {
        final range = wordRange(self, offset);
        if (range != null) {
            return self.slice(range.start, range.end).toString();
        }
        else {
            return '';
        }
    }

    /**
     * Convert an offset in UTF-16 to a byte offset (0-based). O(log N).
     */
    public static function offsetUtf16ToOffset(self:Rope, offsetUtf16:Int):Int {
        if (offsetUtf16 > self.lenUtf16()) {
            return self.len();
        }

        return self.utf16ToByteIdx(offsetUtf16);
    }

    /**
     * Convert a byte offset (0-based) to an offset in UTF-16. O(log N).
     */
    public static function offsetToOffsetUtf16(self:Rope, offset:Int):Int {
        if (offset > self.len()) {
            return self.lenUtf16();
        }

        return self.byteToUtf16Idx(offset);
    }

    /**
     * A clipped offset (never inside a char).
     *
     * - `Bias.Left` inside a char: the start of that char;
     * - `Bias.Right` inside a char: the end of that char;
     * - otherwise the offset (clamped to the length).
     */
    public static function clipOffset(self:Rope, offset:Int, bias:Bias):Int {
        if (offset > self.len()) {
            return self.len();
        }

        if (self.isCharBoundary(offset)) {
            return offset;
        }

        if (bias == Bias.Left) {
            return self.floorCharBoundary(offset);
        }
        else {
            return self.ceilCharBoundary(offset);
        }
    }

    /**
     * Convert an offset in characters to a byte offset (0-based). Rust sums
     * the UTF-8 lengths of the first `charIndex` chars; ropey's index gives
     * the same result (the whole length past the end).
     */
    public static function charIndexToOffset(self:Rope, charIndex:Int):Int {
        return self.charToByteIdx(minInt(charIndex, self.lenChars()));
    }

    /**
     * Convert a byte offset (0-based) to an offset in characters. An offset
     * inside a char counts that char.
     */
    public static function offsetToCharIndex(self:Rope, offset:Int):Int {
        final offset = clipOffset(self, offset, Bias.Right);
        return self.slice(0, offset).lenChars();
    }

    static inline function saturatingSub(a:Int, b:Int):Int {
        return a > b ? a - b : 0;
    }

    static inline function minInt(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    static inline function utf8Len(c:Int):Int {
        return c < 0x80 ? 1 : (c < 0x800 ? 2 : (c < 0x10000 ? 3 : 4));
    }

}
