// Ported from vscode src/vs/editor/common/core/cursorColumns.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

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
 *
 * TODO(steps 2 and 3): `visibleColumnFromColumn`, `toStatusbarColumn` and
 * `columnFromVisibleColumn` come with the grapheme iterator of strings.ts
 * (`GraphemeIterator`, `isFullWidthCharacter`, `isEmojiImprecise`). Only the
 * tab stop functions are ported so far.
 */
class CursorColumns {

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
