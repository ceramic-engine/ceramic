// Ported from vscode src/vs/editor/common/core/cursorColumns.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;

/**
 * A column in a position is the gap between two adjacent characters. The methods here
 * work with a concept called "visible column". A visible column is a very rough approximation
 * of the horizontal screen position of a column. For example, using a tab size of 4:
 * ```txt
 * |<TAB>|<TAB>|T|ext
 * |     |     | \---- column = 4, visible column = 9
 * |     |     \------ column = 3, visible column = 8
 * |     \------------ column = 2, visible column = 4
 * \------------------ column = 1, visible column = 0
 * ```
 *
 * **NOTE**: Visual columns do not work well for RTL text or variable-width fonts or characters.
 *
 * **NOTE**: These methods work and make sense both on the model and on the view model.
 */
class CursorColumns {

    static function _nextVisibleColumn(codePoint:Int, visibleColumn:Int, tabSize:Int):Int {
        if (codePoint == CharCode.Tab) {
            return CursorColumns.nextRenderTabStop(visibleColumn, tabSize);
        }
        if (Strings.isFullWidthCharacter(codePoint) || Strings.isEmojiImprecise(codePoint)) {
            return visibleColumn + 2;
        }
        return visibleColumn + 1;
    }

    /**
     * Returns a visible column from a column.
     * @see {@link CursorColumns}
     */
    public static function visibleColumnFromColumn(lineContent:String, column:Int, tabSize:Int):Int {
        final textLen = Std.int(Math.min(column - 1, lineContent.length));
        final text = lineContent.substring(0, textLen);
        final iterator = new GraphemeIterator(text);

        var result = 0;
        while (!iterator.eol()) {
            final codePoint = Strings.getNextCodePoint(text, textLen, iterator.offset);
            iterator.nextGraphemeLength();

            result = _nextVisibleColumn(codePoint, result, tabSize);
        }

        return result;
    }

    /**
     * Returns the value to display as "Col" in the status bar.
     * @see {@link CursorColumns}
     */
    public static function toStatusbarColumn(lineContent:String, column:Int, tabSize:Int):Int {
        final text = lineContent.substring(0, Std.int(Math.min(column - 1, lineContent.length)));
        final iterator = new CodePointIterator(text);

        var result = 0;
        while (!iterator.eol()) {
            final codePoint = iterator.nextCodePoint();

            if (codePoint == CharCode.Tab) {
                result = CursorColumns.nextRenderTabStop(result, tabSize);
            }
            else {
                result = result + 1;
            }
        }

        return result + 1;
    }

    /**
     * Returns a column from a visible column.
     * @see {@link CursorColumns}
     */
    public static function columnFromVisibleColumn(lineContent:String, visibleColumn:Int, tabSize:Int):Int {
        if (visibleColumn <= 0) {
            return 1;
        }

        final lineContentLength = lineContent.length;
        final iterator = new GraphemeIterator(lineContent);

        var beforeVisibleColumn = 0;
        var beforeColumn = 1;
        while (!iterator.eol()) {
            final codePoint = Strings.getNextCodePoint(lineContent, lineContentLength, iterator.offset);
            iterator.nextGraphemeLength();

            final afterVisibleColumn = _nextVisibleColumn(codePoint, beforeVisibleColumn, tabSize);
            final afterColumn = iterator.offset + 1;

            if (afterVisibleColumn >= visibleColumn) {
                final beforeDelta = visibleColumn - beforeVisibleColumn;
                final afterDelta = afterVisibleColumn - visibleColumn;
                if (afterDelta < beforeDelta) {
                    return afterColumn;
                }
                else {
                    return beforeColumn;
                }
            }

            beforeVisibleColumn = afterVisibleColumn;
            beforeColumn = afterColumn;
        }

        // walked the entire string
        return lineContentLength + 1;
    }

    /**
     * ATTENTION: This works with 0-based columns (as opposed to the regular 1-based columns)
     */
    public static inline function nextRenderTabStop(visibleColumn:Int, tabSize:Int):Int {
        return visibleColumn + tabSize - visibleColumn % tabSize;
    }

    /**
     * ATTENTION: This works with 0-based columns (as opposed to the regular 1-based columns)
     */
    public static inline function nextIndentTabStop(visibleColumn:Int, indentSize:Int):Int {
        return visibleColumn + indentSize - visibleColumn % indentSize;
    }

    /**
     * ATTENTION: This works with 0-based columns (as opposed to the regular 1-based columns)
     */
    public static function prevRenderTabStop(column:Int, tabSize:Int):Int {
        return Std.int(Math.max(0, column - 1 - (column - 1) % tabSize));
    }

    /**
     * ATTENTION: This works with 0-based columns (as opposed to the regular 1-based columns)
     */
    public static function prevIndentTabStop(column:Int, indentSize:Int):Int {
        return Std.int(Math.max(0, column - 1 - (column - 1) % indentSize));
    }

}
