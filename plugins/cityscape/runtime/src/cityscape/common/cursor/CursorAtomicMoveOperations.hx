// Ported from vscode src/vs/editor/common/cursor/cursorAtomicMoveOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.CharCode;
import cityscape.common.core.CursorColumns;

enum abstract Direction(Int) from Int to Int {
    var Left = 0;
    var Right = 1;
    var Nearest = 2;
}

class AtomicTabMoveOperations {

    /**
     * Get the visible column at the position. If we get to a non-whitespace character first
     * or past the end of string then return -1.
     *
     * **Note** `position` and the return value are 0-based.
     *
     * Returns Monaco's tuple `[prevTabStopPosition, prevTabStopVisibleColumn, visibleColumn]`.
     */
    public static function whitespaceVisibleColumn(lineContent:String, position:Int, tabSize:Int):Array<Int> {
        final lineLength = lineContent.length;
        var visibleColumn = 0;
        var prevTabStopPosition = -1;
        var prevTabStopVisibleColumn = -1;
        for (i in 0...lineLength) {
            if (i == position) {
                return [prevTabStopPosition, prevTabStopVisibleColumn, visibleColumn];
            }
            if (visibleColumn % tabSize == 0) {
                prevTabStopPosition = i;
                prevTabStopVisibleColumn = visibleColumn;
            }
            final chCode = StringTools.fastCodeAt(lineContent, i);
            switch (chCode) {
                case CharCode.Space:
                    visibleColumn += 1;
                case CharCode.Tab:
                    // Skip to the next multiple of tabSize.
                    visibleColumn = CursorColumns.nextRenderTabStop(visibleColumn, tabSize);
                default:
                    return [-1, -1, -1];
            }
        }
        if (position == lineLength) {
            return [prevTabStopPosition, prevTabStopVisibleColumn, visibleColumn];
        }
        return [-1, -1, -1];
    }

    /**
     * Return the position that should result from a move left, right or to the
     * nearest tab, if atomic tabs are enabled. Left and right are used for the
     * arrow key movements, nearest is used for mouse selection. It returns
     * -1 if atomic tabs are not relevant and you should fall back to normal
     * behaviour.
     *
     * **Note**: `position` and the return value are 0-based.
     */
    public static function atomicPosition(lineContent:String, position:Int, tabSize:Int, direction:Direction):Int {
        final lineLength = lineContent.length;

        // Get the 0-based visible column corresponding to the position, or return
        // -1 if it is not in the initial whitespace.
        final r = AtomicTabMoveOperations.whitespaceVisibleColumn(lineContent, position, tabSize);
        final prevTabStopPosition = r[0];
        final prevTabStopVisibleColumn = r[1];
        final visibleColumn = r[2];

        if (visibleColumn == -1) {
            return -1;
        }

        // Is the output left or right of the current position. The case for nearest
        // where it is the same as the current position is handled in the switch.
        var left:Bool;
        switch (direction) {
            case Direction.Left:
                left = true;
            case Direction.Right:
                left = false;
            case Direction.Nearest:
                // The code below assumes the output position is either left or right
                // of the input position. If it is the same, return immediately.
                if (visibleColumn % tabSize == 0) {
                    return position;
                }
                // Go to the nearest indentation.
                left = visibleColumn % tabSize <= (tabSize / 2);
            default:
                left = false;
        }

        // If going left, we can just use the info about the last tab stop position and
        // last tab stop visible column that we computed in the first walk over the whitespace.
        if (left) {
            if (prevTabStopPosition == -1) {
                return -1;
            }
            // If the direction is left, we need to keep scanning right to ensure
            // that targetVisibleColumn + tabSize is before non-whitespace.
            // This is so that when we press left at the end of a partial
            // indentation it only goes one character. For example '      foo' with
            // tabSize 4, should jump from position 6 to position 5, not 4.
            var currentVisibleColumn = prevTabStopVisibleColumn;
            for (i in prevTabStopPosition...lineLength) {
                if (currentVisibleColumn == prevTabStopVisibleColumn + tabSize) {
                    // It is a full indentation.
                    return prevTabStopPosition;
                }

                final chCode = StringTools.fastCodeAt(lineContent, i);
                switch (chCode) {
                    case CharCode.Space:
                        currentVisibleColumn += 1;
                    case CharCode.Tab:
                        currentVisibleColumn = CursorColumns.nextRenderTabStop(currentVisibleColumn, tabSize);
                    default:
                        return -1;
                }
            }
            if (currentVisibleColumn == prevTabStopVisibleColumn + tabSize) {
                return prevTabStopPosition;
            }
            // It must have been a partial indentation.
            return -1;
        }

        // We are going right.
        final targetVisibleColumn = CursorColumns.nextRenderTabStop(visibleColumn, tabSize);

        // We can just continue from where whitespaceVisibleColumn got to.
        var currentVisibleColumn = visibleColumn;
        for (i in position...lineLength) {
            if (currentVisibleColumn == targetVisibleColumn) {
                return i;
            }

            final chCode = StringTools.fastCodeAt(lineContent, i);
            switch (chCode) {
                case CharCode.Space:
                    currentVisibleColumn += 1;
                case CharCode.Tab:
                    currentVisibleColumn = CursorColumns.nextRenderTabStop(currentVisibleColumn, tabSize);
                default:
                    return -1;
            }
        }
        // This condition handles when the target column is at the end of the line.
        if (currentVisibleColumn == targetVisibleColumn) {
            return lineLength;
        }
        return -1;
    }

}
