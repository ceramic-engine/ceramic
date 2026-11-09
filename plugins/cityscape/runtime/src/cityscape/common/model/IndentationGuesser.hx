// Ported from vscode src/vs/editor/common/model/indentationGuesser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.CharCode;
import cityscape.common.Model.ITextBuffer;

class SpacesDiffResult {

    public var spacesDiff:Int = 0;

    public var looksLikeAlignment:Bool = false;

    public function new() {}

}

/**
 * Result for a guessIndentation
 */
typedef IGuessedIndentation = {
    /**
     * If indentation is based on spaces (`insertSpaces` = true), then what is the number of spaces that make an indent?
     */
    var tabSize:Int;
    /**
     * Is indentation based on spaces?
     */
    var insertSpaces:Bool;
}

class IndentationGuesser {

    /**
     * Compute the diff in spaces between two line's indentation.
     */
    static function spacesDiff(a:String, aLength:Int, b:String, bLength:Int, result:SpacesDiffResult):Void {

        result.spacesDiff = 0;
        result.looksLikeAlignment = false;

        // This can go both ways (e.g.):
        //  - a: "\t"
        //  - b: "\t    "
        //  => This should count 1 tab and 4 spaces

        var i = 0;

        while (i < aLength && i < bLength) {
            final aCharCode = StringTools.fastCodeAt(a, i);
            final bCharCode = StringTools.fastCodeAt(b, i);

            if (aCharCode != bCharCode) {
                break;
            }
            i++;
        }

        var aSpacesCnt = 0, aTabsCount = 0;
        for (j in i...aLength) {
            final aCharCode = StringTools.fastCodeAt(a, j);
            if (aCharCode == CharCode.Space) {
                aSpacesCnt++;
            }
            else {
                aTabsCount++;
            }
        }

        var bSpacesCnt = 0, bTabsCount = 0;
        for (j in i...bLength) {
            final bCharCode = StringTools.fastCodeAt(b, j);
            if (bCharCode == CharCode.Space) {
                bSpacesCnt++;
            }
            else {
                bTabsCount++;
            }
        }

        if (aSpacesCnt > 0 && aTabsCount > 0) {
            return;
        }
        if (bSpacesCnt > 0 && bTabsCount > 0) {
            return;
        }

        final tabsDiff = Std.int(Math.abs(aTabsCount - bTabsCount));
        final spacesDiff = Std.int(Math.abs(aSpacesCnt - bSpacesCnt));

        if (tabsDiff == 0) {
            // check if the indentation difference might be caused by alignment reasons
            // sometime folks like to align their code, but this should not be used as a hint
            result.spacesDiff = spacesDiff;

            if (spacesDiff > 0 && 0 <= bSpacesCnt - 1 && bSpacesCnt - 1 < a.length && bSpacesCnt < b.length) {
                if (StringTools.fastCodeAt(b, bSpacesCnt) != CharCode.Space && StringTools.fastCodeAt(a, bSpacesCnt - 1) == CharCode.Space) {
                    if (a.length > 0 && StringTools.fastCodeAt(a, a.length - 1) == CharCode.Comma) {
                        // This looks like an alignment desire: e.g.
                        // const a = b + c,
                        //       d = b - c;
                        result.looksLikeAlignment = true;
                    }
                }
            }
            return;
        }
        if (spacesDiff % tabsDiff == 0) {
            result.spacesDiff = Std.int(spacesDiff / tabsDiff);
            return;
        }
    }

    public static function guessIndentation(source:ITextBuffer, defaultTabSize:Int, defaultInsertSpaces:Bool):IGuessedIndentation {
        // Look at most at the first 10k lines
        final linesCount = Std.int(Math.min(source.getLineCount(), 10000));

        var linesIndentedWithTabsCount = 0; // number of lines that contain at least one tab in indentation
        var linesIndentedWithSpacesCount = 0; // number of lines that contain only spaces in indentation

        var previousLineText = ''; // content of latest line that contained non-whitespace chars
        var previousLineIndentation = 0; // index at which latest line contained the first non-whitespace char

        final ALLOWED_TAB_SIZE_GUESSES = [2, 4, 6, 8, 3, 5, 7]; // prefer even guesses for `tabSize`, limit to [2, 8].
        final MAX_ALLOWED_TAB_SIZE_GUESS = 8; // max(ALLOWED_TAB_SIZE_GUESSES) = 8

        final spacesDiffCount = [0, 0, 0, 0, 0, 0, 0, 0, 0]; // `tabSize` scores
        final tmp = new SpacesDiffResult();

        for (lineNumber in 1...linesCount + 1) {
            final currentLineLength = source.getLineLength(lineNumber);
            final currentLineText = source.getLineContent(lineNumber);

            // if the text buffer is chunk based, so long lines are cons-string, v8 will flattern the string when we check charCode.
            // checking charCode on chunks directly is cheaper.
            final useCurrentLineText = (currentLineLength <= 65536);

            var currentLineHasContent = false; // does `currentLineText` contain non-whitespace chars
            var currentLineIndentation = 0; // index at which `currentLineText` contains the first non-whitespace char
            var currentLineSpacesCount = 0; // count of spaces found in `currentLineText` indentation
            var currentLineTabsCount = 0; // count of tabs found in `currentLineText` indentation
            for (j in 0...currentLineLength) {
                final charCode = (useCurrentLineText ? StringTools.fastCodeAt(currentLineText, j) : source.getLineCharCode(lineNumber, j));

                if (charCode == CharCode.Tab) {
                    currentLineTabsCount++;
                }
                else if (charCode == CharCode.Space) {
                    currentLineSpacesCount++;
                }
                else {
                    // Hit non whitespace character on this line
                    currentLineHasContent = true;
                    currentLineIndentation = j;
                    break;
                }
            }

            // Ignore empty or only whitespace lines
            if (!currentLineHasContent) {
                continue;
            }

            if (currentLineTabsCount > 0) {
                linesIndentedWithTabsCount++;
            }
            else if (currentLineSpacesCount > 1) {
                linesIndentedWithSpacesCount++;
            }

            spacesDiff(previousLineText, previousLineIndentation, currentLineText, currentLineIndentation, tmp);

            if (tmp.looksLikeAlignment) {
                // if defaultInsertSpaces === true && the spaces count == tabSize, we may want to count it as valid indentation
                //
                // - item1
                //   - item2
                //
                // otherwise skip this line entirely
                //
                // const a = 1,
                //       b = 2;

                if (!(defaultInsertSpaces && defaultTabSize == tmp.spacesDiff)) {
                    continue;
                }
            }

            final currentSpacesDiff = tmp.spacesDiff;
            if (currentSpacesDiff <= MAX_ALLOWED_TAB_SIZE_GUESS) {
                spacesDiffCount[currentSpacesDiff]++;
            }

            previousLineText = currentLineText;
            previousLineIndentation = currentLineIndentation;
        }

        var insertSpaces = defaultInsertSpaces;
        if (linesIndentedWithTabsCount != linesIndentedWithSpacesCount) {
            insertSpaces = (linesIndentedWithTabsCount < linesIndentedWithSpacesCount);
        }

        var tabSize = defaultTabSize;

        // Guess tabSize only if inserting spaces...
        if (insertSpaces) {
            var tabSizeScore:Float = (insertSpaces ? 0 : 0.1 * linesCount);

            for (possibleTabSize in ALLOWED_TAB_SIZE_GUESSES) {
                final possibleTabSizeScore = spacesDiffCount[possibleTabSize];
                if (possibleTabSizeScore > tabSizeScore) {
                    tabSizeScore = possibleTabSizeScore;
                    tabSize = possibleTabSize;
                }
            }

            // Let a tabSize of 2 win even if it is not the maximum
            // (only in case 4 was guessed)
            if (tabSize == 4 && spacesDiffCount[4] > 0 && spacesDiffCount[2] > 0 && spacesDiffCount[2] >= spacesDiffCount[4] / 2) {
                tabSize = 2;
            }
        }

        return {
            insertSpaces: insertSpaces,
            tabSize: tabSize
        };
    }

}
