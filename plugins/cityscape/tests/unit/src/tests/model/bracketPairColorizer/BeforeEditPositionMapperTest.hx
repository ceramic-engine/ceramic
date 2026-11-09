// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/beforeEditPositionMapper.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.base.common.Strings;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BeforeEditPositionMapper;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import testing.TestCase;

/**
 * suite('Bracket Pair Colorizer - BeforeEditPositionMapper')
 */
class BeforeEditPositionMapperTest extends TestCase {

    function testSingleLine1() {
        assertDeepEquals(
            compute(
                [
                    '0123456789',
                ],
                [
                    new TextEdit(Length.toLength(0, 4), Length.toLength(0, 7), 'xy')
                ]
            ),
            [
                '0  1  2  3  x  y  7  8  9  ', // The line

                '0  0  0  0  0  0  0  0  0  0  ', // the old line numbers
                '0  1  2  3  4  5  7  8  9  10 ', // the old columns

                '0  0  0  0  0  0  ∞  ∞  ∞  ∞  ', // line count until next change
                '4  3  2  1  0  0  ∞  ∞  ∞  ∞  ', // column count until next change
            ]
        );
    }

    function testSingleLine2() {
        assertDeepEquals(
            compute(
                [
                    '0123456789',
                ],
                [
                    new TextEdit(Length.toLength(0, 2), Length.toLength(0, 4), 'xxxx'),
                    new TextEdit(Length.toLength(0, 6), Length.toLength(0, 6), 'yy')
                ]
            ),
            [
                '0  1  x  x  x  x  4  5  y  y  6  7  8  9  ',

                '0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  ',
                '0  1  2  3  4  5  4  5  6  7  6  7  8  9  10 ',

                '0  0  0  0  0  0  0  0  0  0  ∞  ∞  ∞  ∞  ∞  ',
                '2  1  0  0  0  0  2  1  0  0  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineReplace1() {
        assertDeepEquals(
            compute(
                [
                    '₀₁₂₃₄₅₆₇₈₉',
                    '0123456789',
                    '⁰¹²³⁴⁵⁶⁷⁸⁹',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(1, 3), 'xy'),
                ]
            ),
            [
                '₀  ₁  ₂  x  y  3  4  5  6  7  8  9  ',

                '0  0  0  0  0  1  1  1  1  1  1  1  1  ',
                '0  1  2  3  4  3  4  5  6  7  8  9  10 ',

                "0  0  0  0  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ",
                '3  2  1  0  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                // ------------------
                '⁰  ¹  ²  ³  ⁴  ⁵  ⁶  ⁷  ⁸  ⁹  ',

                '2  2  2  2  2  2  2  2  2  2  2  ',
                '0  1  2  3  4  5  6  7  8  9  10 ',

                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineReplace2() {
        assertDeepEquals(
            compute(
                [
                    '₀₁₂₃₄₅₆₇₈₉',
                    '012345678',
                    '⁰¹²³⁴⁵⁶⁷⁸⁹',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(1, 0), 'ab'),
                    new TextEdit(Length.toLength(1, 5), Length.toLength(1, 7), 'c'),
                ]
            ),
            [
                '₀  ₁  ₂  a  b  0  1  2  3  4  c  7  8  ',

                '0  0  0  0  0  1  1  1  1  1  1  1  1  1  ',
                '0  1  2  3  4  0  1  2  3  4  5  7  8  9  ',

                '0  0  0  0  0  0  0  0  0  0  0  ∞  ∞  ∞  ',
                '3  2  1  0  0  5  4  3  2  1  0  ∞  ∞  ∞  ',
                // ------------------
                '⁰  ¹  ²  ³  ⁴  ⁵  ⁶  ⁷  ⁸  ⁹  ',

                '2  2  2  2  2  2  2  2  2  2  2  ',
                '0  1  2  3  4  5  6  7  8  9  10 ',

                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineReplace3() {
        assertDeepEquals(
            compute(
                [
                    '₀₁₂₃₄₅₆₇₈₉',
                    '012345678',
                    '⁰¹²³⁴⁵⁶⁷⁸⁹',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(1, 0), 'ab'),
                    new TextEdit(Length.toLength(1, 5), Length.toLength(1, 7), 'c'),
                    new TextEdit(Length.toLength(1, 8), Length.toLength(2, 4), 'd'),
                ]
            ),
            [
                '₀  ₁  ₂  a  b  0  1  2  3  4  c  7  d  ⁴  ⁵  ⁶  ⁷  ⁸  ⁹  ',

                '0  0  0  0  0  1  1  1  1  1  1  1  1  2  2  2  2  2  2  2  ',
                '0  1  2  3  4  0  1  2  3  4  5  7  8  4  5  6  7  8  9  10 ',

                '0  0  0  0  0  0  0  0  0  0  0  0  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '3  2  1  0  0  5  4  3  2  1  0  1  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineInsert1() {
        assertDeepEquals(
            compute(
                [
                    '012345678',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(0, 5), 'a\nb'),
                ]
            ),
            [
                '0  1  2  a  ',

                '0  0  0  0  0  ',
                '0  1  2  3  4  ',

                '0  0  0  0  0  ',
                '3  2  1  0  0  ',
                // ------------------
                'b  5  6  7  8  ',

                '1  0  0  0  0  0  ',
                '0  5  6  7  8  9  ',

                '0  ∞  ∞  ∞  ∞  ∞  ',
                '0  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineInsert2() {
        assertDeepEquals(
            compute(
                [
                    '012345678',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(0, 5), 'a\nb'),
                    new TextEdit(Length.toLength(0, 7), Length.toLength(0, 8), 'x\ny'),
                ]
            ),
            [
                '0  1  2  a  ',

                '0  0  0  0  0  ',
                '0  1  2  3  4  ',

                '0  0  0  0  0  ',
                '3  2  1  0  0  ',
                // ------------------
                'b  5  6  x  ',

                '1  0  0  0  0  ',
                '0  5  6  7  8  ',

                '0  0  0  0  0  ',
                '0  2  1  0  0  ',
                // ------------------
                'y  8  ',

                '1  0  0  ',
                '0  8  9  ',

                '0  ∞  ∞  ',
                '0  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineReplaceInsert1() {
        assertDeepEquals(
            compute(
                [
                    '₀₁₂₃₄₅₆₇₈₉',
                    '012345678',
                    '⁰¹²³⁴⁵⁶⁷⁸⁹',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(1, 1), 'aaa\nbbb'),
                ]
            ),
            [
                '₀  ₁  ₂  a  a  a  ',
                '0  0  0  0  0  0  0  ',
                '0  1  2  3  4  5  6  ',

                '0  0  0  0  0  0  0  ',
                '3  2  1  0  0  0  0  ',
                // ------------------
                'b  b  b  1  2  3  4  5  6  7  8  ',

                '1  1  1  1  1  1  1  1  1  1  1  1  ',
                '0  1  2  1  2  3  4  5  6  7  8  9  ',

                '0  0  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '0  0  0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                // ------------------
                '⁰  ¹  ²  ³  ⁴  ⁵  ⁶  ⁷  ⁸  ⁹  ',

                '2  2  2  2  2  2  2  2  2  2  2  ',
                '0  1  2  3  4  5  6  7  8  9  10 ',

                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    function testMultiLineReplaceInsert2() {
        assertDeepEquals(
            compute(
                [
                    '₀₁₂₃₄₅₆₇₈₉',
                    '012345678',
                    '⁰¹²³⁴⁵⁶⁷⁸⁹',

                ],
                [
                    new TextEdit(Length.toLength(0, 3), Length.toLength(1, 1), 'aaa\nbbb'),
                    new TextEdit(Length.toLength(1, 5), Length.toLength(1, 5), 'x\ny'),
                    new TextEdit(Length.toLength(1, 7), Length.toLength(2, 4), 'k\nl'),
                ]
            ),
            [
                '₀  ₁  ₂  a  a  a  ',

                '0  0  0  0  0  0  0  ',
                '0  1  2  3  4  5  6  ',

                '0  0  0  0  0  0  0  ',
                '3  2  1  0  0  0  0  ',
                // ------------------
                'b  b  b  1  2  3  4  x  ',

                '1  1  1  1  1  1  1  1  1  ',
                '0  1  2  1  2  3  4  5  6  ',

                '0  0  0  0  0  0  0  0  0  ',
                '0  0  0  4  3  2  1  0  0  ',
                // ------------------
                'y  5  6  k  ',

                '2  1  1  1  1  ',
                '0  5  6  7  8  ',

                '0  0  0  0  0  ',
                '0  2  1  0  0  ',
                // ------------------
                'l  ⁴  ⁵  ⁶  ⁷  ⁸  ⁹  ',

                '2  2  2  2  2  2  2  2  ',
                '0  4  5  6  7  8  9  10 ',

                '0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
                '0  ∞  ∞  ∞  ∞  ∞  ∞  ∞  ',
            ]
        );
    }

    /** @pure */
    static function compute(inputArr:Array<String>, edits:Array<TextEdit>):Array<String> {
        final newLines = Strings.splitLines(applyLineColumnEdits(inputArr.join('\n'), [for (e in edits) {
            text: e.newText,
            range: Range.fromPositions(Length.lengthToPosition(e.startOffset), Length.lengthToPosition(e.endOffset))
        }]));

        final mapper = new BeforeEditPositionMapper(cast edits);

        final result = new Array<String>();

        var lineIdx = 0;
        for (line in newLines) {
            var lineLine = '';
            var colLine = '';
            var lineStr = '';

            var colDist = '';
            var lineDist = '';

            for (colIdx in 0...line.length + 1) {
                final before = mapper.getOffsetBeforeChange(Length.toLength(lineIdx, colIdx));
                final beforeObj = Length.lengthToObj(before);
                if (colIdx < line.length) {
                    lineStr += rightPad(line.charAt(colIdx), 3);
                }
                lineLine += rightPad('' + beforeObj.lineCount, 3);
                colLine += rightPad('' + beforeObj.columnCount, 3);

                final distLen = mapper.getDistanceToNextChange(Length.toLength(lineIdx, colIdx));
                if (distLen == null) {
                    lineDist += '\u221E  ';
                    colDist += '\u221E  ';
                }
                else {
                    final dist = Length.lengthToObj(distLen);
                    lineDist += rightPad('' + dist.lineCount, 3);
                    colDist += rightPad('' + dist.columnCount, 3);
                }
            }
            result.push(lineStr);

            result.push(lineLine);
            result.push(colLine);

            result.push(lineDist);
            result.push(colDist);

            lineIdx++;
        }

        return result;
    }

    static function applyLineColumnEdits(text:String, edits:Array<{range:Range, text:String}>):String {
        final transformer = new PositionOffsetTransformer(text);
        final offsetEdits = [for (e in edits) {
            final range = e.range;
            {
                startOffset: transformer.getOffset(range.getStartPosition()),
                endOffset: transformer.getOffset(range.getEndPosition()),
                text: e.text
            };
        }];

        haxe.ds.ArraySort.sort(offsetEdits, (a, b) -> b.startOffset - a.startOffset);

        for (edit in offsetEdits) {
            text = text.substring(0, edit.startOffset) + edit.text + text.substring(edit.endOffset);
        }

        return text;
    }

    static function rightPad(str:String, len:Int):String {
        while (str.length < len) {
            str += ' ';
        }
        return str;
    }

}

class TextEdit extends TextEditInfo {

    public final newText:String;

    public function new(startOffset:Length, endOffset:Length, newText:String) {
        super(
            startOffset,
            endOffset,
            Length.lengthOfString(newText)
        );
        this.newText = newText;
    }

}

private class PositionOffsetTransformer {

    final lineStartOffsetByLineIdx:Array<Int>;

    public function new(text:String) {
        lineStartOffsetByLineIdx = [];
        lineStartOffsetByLineIdx.push(0);
        for (i in 0...text.length) {
            if (text.charAt(i) == '\n') {
                lineStartOffsetByLineIdx.push(i + 1);
            }
        }
    }

    public function getOffset(position:Position):Int {
        return lineStartOffsetByLineIdx[position.lineNumber - 1] + position.column - 1;
    }

}
