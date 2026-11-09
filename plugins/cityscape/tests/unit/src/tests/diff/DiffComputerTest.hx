// Ported from vscode src/vs/editor/test/common/diff/diffComputer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.diff;

import cityscape.common.Model.IIdentifiedSingleEditOperation;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.diff.LegacyLinesDiffComputer.DiffComputer;
import cityscape.common.diff.LegacyLinesDiffComputer.ICharChange;
import cityscape.common.diff.LegacyLinesDiffComputer.ILineChange;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

/**
 * vscode's suite 'Editor Diff - DiffComputer' (the legacy diff computer).
 */
class DiffComputerTest extends TestCase {

    static inline final MAX_SAFE_SMALL_INTEGER:Int = 1 << 30;

    function assertDiff(originalLines:Array<String>, modifiedLines:Array<String>, expectedChanges:Array<ILineChange>, shouldComputeCharChanges:Bool = true, shouldPostProcessCharChanges:Bool = false, shouldIgnoreTrimWhitespace:Bool = false, ?pos:haxe.PosInfos):Void {
        final diffComputer = new DiffComputer(originalLines, modifiedLines, {
            shouldComputeCharChanges: shouldComputeCharChanges,
            shouldPostProcessCharChanges: shouldPostProcessCharChanges,
            shouldIgnoreTrimWhitespace: shouldIgnoreTrimWhitespace,
            shouldMakePrettyDiff: true,
            maxComputationTime: 0
        });
        final changes = diffComputer.computeDiff().changes;

        final mapCharChange = (charChange:ICharChange) -> {
            return ({
                originalStartLineNumber: charChange.originalStartLineNumber,
                originalStartColumn: charChange.originalStartColumn,
                originalEndLineNumber: charChange.originalEndLineNumber,
                originalEndColumn: charChange.originalEndColumn,
                modifiedStartLineNumber: charChange.modifiedStartLineNumber,
                modifiedStartColumn: charChange.modifiedStartColumn,
                modifiedEndLineNumber: charChange.modifiedEndLineNumber,
                modifiedEndColumn: charChange.modifiedEndColumn,
            } : ICharChange);
        };

        final actual:Array<ILineChange> = changes.map((lineChange) -> {
            return ({
                originalStartLineNumber: lineChange.originalStartLineNumber,
                originalEndLineNumber: lineChange.originalEndLineNumber,
                modifiedStartLineNumber: lineChange.modifiedStartLineNumber,
                modifiedEndLineNumber: lineChange.modifiedEndLineNumber,
                charChanges: (lineChange.charChanges != null ? lineChange.charChanges.map(c -> mapCharChange(cast c)) : null)
            } : ILineChange);
        });

        assertDeepEquals(expectedChanges, actual, null, pos);

        if (!shouldIgnoreTrimWhitespace) {
            // The diffs should describe how to apply edits to the original text model to get to the modified text model.

            final modifiedTextModel = createTextModel(modifiedLines.join('\n'));
            final expectedValue = modifiedTextModel.getValue();

            {
                // Line changes:
                final originalTextModel = createTextModel(originalLines.join('\n'));
                originalTextModel.applyEdits(actual.map(c -> getLineEdit(c, modifiedTextModel)));
                assertEquals(expectedValue, originalTextModel.getValue(), null, pos);
                originalTextModel.dispose();
            }

            if (shouldComputeCharChanges) {
                // Char changes:
                final originalTextModel = createTextModel(originalLines.join('\n'));
                final edits:Array<IIdentifiedSingleEditOperation> = [];
                for (c in actual) {
                    for (e in getCharEdits(c, modifiedTextModel)) {
                        edits.push(e);
                    }
                }
                originalTextModel.applyEdits(edits);
                assertEquals(expectedValue, originalTextModel.getValue(), null, pos);
                originalTextModel.dispose();
            }

            modifiedTextModel.dispose();
        }
    }

    static function getCharEdits(lineChange:ILineChange, modifiedTextModel:ITextModel):Array<IIdentifiedSingleEditOperation> {
        if (lineChange.charChanges == null) {
            return [getLineEdit(lineChange, modifiedTextModel)];
        }
        return lineChange.charChanges.map(c -> {
            final originalRange = new Range(c.originalStartLineNumber, c.originalStartColumn, c.originalEndLineNumber, c.originalEndColumn);
            final modifiedRange = new Range(c.modifiedStartLineNumber, c.modifiedStartColumn, c.modifiedEndLineNumber, c.modifiedEndColumn);
            return ({
                range: originalRange,
                text: modifiedTextModel.getValueInRange(modifiedRange)
            } : IIdentifiedSingleEditOperation);
        });
    }

    static function getLineEdit(lineChange:ILineChange, modifiedTextModel:ITextModel):IIdentifiedSingleEditOperation {
        var originalRange:TestLineRange;
        if (lineChange.originalEndLineNumber == 0) {
            // Insertion
            originalRange = new TestLineRange(lineChange.originalStartLineNumber + 1, 0);
        }
        else {
            originalRange = new TestLineRange(lineChange.originalStartLineNumber, lineChange.originalEndLineNumber - lineChange.originalStartLineNumber + 1);
        }

        var modifiedRange:TestLineRange;
        if (lineChange.modifiedEndLineNumber == 0) {
            // Deletion
            modifiedRange = new TestLineRange(lineChange.modifiedStartLineNumber + 1, 0);
        }
        else {
            modifiedRange = new TestLineRange(lineChange.modifiedStartLineNumber, lineChange.modifiedEndLineNumber - lineChange.modifiedStartLineNumber + 1);
        }

        final r = diffFromLineRanges(originalRange, modifiedRange);
        return {
            range: r[0],
            text: modifiedTextModel.getValueInRange(r[1]),
        };
    }

    static function diffFromLineRanges(originalRange:TestLineRange, modifiedRange:TestLineRange):Array<Range> {
        if (originalRange.startLineNumber == 1 || modifiedRange.startLineNumber == 1) {
            if (!originalRange.isEmpty && !modifiedRange.isEmpty) {
                return [
                    new Range(
                        originalRange.startLineNumber,
                        1,
                        originalRange.endLineNumberExclusive - 1,
                        MAX_SAFE_SMALL_INTEGER
                    ),
                    new Range(
                        modifiedRange.startLineNumber,
                        1,
                        modifiedRange.endLineNumberExclusive - 1,
                        MAX_SAFE_SMALL_INTEGER
                    )
                ];
            }

            // When one of them is one and one of them is empty, the other cannot be the last line of the document
            return [
                new Range(
                    originalRange.startLineNumber,
                    1,
                    originalRange.endLineNumberExclusive,
                    1
                ),
                new Range(
                    modifiedRange.startLineNumber,
                    1,
                    modifiedRange.endLineNumberExclusive,
                    1
                )
            ];
        }

        return [
            new Range(
                originalRange.startLineNumber - 1,
                MAX_SAFE_SMALL_INTEGER,
                originalRange.endLineNumberExclusive - 1,
                MAX_SAFE_SMALL_INTEGER
            ),
            new Range(
                modifiedRange.startLineNumber - 1,
                MAX_SAFE_SMALL_INTEGER,
                modifiedRange.endLineNumberExclusive - 1,
                MAX_SAFE_SMALL_INTEGER
            )
        ];
    }

    static function createLineDeletion(startLineNumber:Int, endLineNumber:Int, modifiedLineNumber:Int):ILineChange {
        return {
            originalStartLineNumber: startLineNumber,
            originalEndLineNumber: endLineNumber,
            modifiedStartLineNumber: modifiedLineNumber,
            modifiedEndLineNumber: 0,
            charChanges: null
        };
    }

    static function createLineInsertion(startLineNumber:Int, endLineNumber:Int, originalLineNumber:Int):ILineChange {
        return {
            originalStartLineNumber: originalLineNumber,
            originalEndLineNumber: 0,
            modifiedStartLineNumber: startLineNumber,
            modifiedEndLineNumber: endLineNumber,
            charChanges: null
        };
    }

    static function createLineChange(originalStartLineNumber:Int, originalEndLineNumber:Int, modifiedStartLineNumber:Int, modifiedEndLineNumber:Int, ?charChanges:Array<ICharChange>):ILineChange {
        return {
            originalStartLineNumber: originalStartLineNumber,
            originalEndLineNumber: originalEndLineNumber,
            modifiedStartLineNumber: modifiedStartLineNumber,
            modifiedEndLineNumber: modifiedEndLineNumber,
            charChanges: charChanges
        };
    }

    static function createCharChange(
        originalStartLineNumber:Int, originalStartColumn:Int, originalEndLineNumber:Int, originalEndColumn:Int,
        modifiedStartLineNumber:Int, modifiedStartColumn:Int, modifiedEndLineNumber:Int, modifiedEndColumn:Int
    ):ICharChange {
        return {
            originalStartLineNumber: originalStartLineNumber,
            originalStartColumn: originalStartColumn,
            originalEndLineNumber: originalEndLineNumber,
            originalEndColumn: originalEndColumn,
            modifiedStartLineNumber: modifiedStartLineNumber,
            modifiedStartColumn: modifiedStartColumn,
            modifiedEndLineNumber: modifiedEndLineNumber,
            modifiedEndColumn: modifiedEndColumn
        };
    }


    // ---- insertions


    // ---- insertions

    /** one inserted line below */
    function testOneInsertedLineBelow():Void {
        final original = ['line'];
        final modified = ['line', 'new line'];
        final expected = [createLineInsertion(2, 2, 1)];
        assertDiff(original, modified, expected);
    }

    /** two inserted lines below */
    function testTwoInsertedLinesBelow():Void {
        final original = ['line'];
        final modified = ['line', 'new line', 'another new line'];
        final expected = [createLineInsertion(2, 3, 1)];
        assertDiff(original, modified, expected);
    }

    /** one inserted line above */
    function testOneInsertedLineAbove():Void {
        final original = ['line'];
        final modified = ['new line', 'line'];
        final expected = [createLineInsertion(1, 1, 0)];
        assertDiff(original, modified, expected);
    }

    /** two inserted lines above */
    function testTwoInsertedLinesAbove():Void {
        final original = ['line'];
        final modified = ['new line', 'another new line', 'line'];
        final expected = [createLineInsertion(1, 2, 0)];
        assertDiff(original, modified, expected);
    }

    /** one inserted line in middle */
    function testOneInsertedLineInMiddle():Void {
        final original = ['line1', 'line2', 'line3', 'line4'];
        final modified = ['line1', 'line2', 'new line', 'line3', 'line4'];
        final expected = [createLineInsertion(3, 3, 2)];
        assertDiff(original, modified, expected);
    }

    /** two inserted lines in middle */
    function testTwoInsertedLinesInMiddle():Void {
        final original = ['line1', 'line2', 'line3', 'line4'];
        final modified = ['line1', 'line2', 'new line', 'another new line', 'line3', 'line4'];
        final expected = [createLineInsertion(3, 4, 2)];
        assertDiff(original, modified, expected);
    }

    /** two inserted lines in middle interrupted */
    function testTwoInsertedLinesInMiddleInterrupted():Void {
        final original = ['line1', 'line2', 'line3', 'line4'];
        final modified = ['line1', 'line2', 'new line', 'line3', 'another new line', 'line4'];
        final expected = [createLineInsertion(3, 3, 2), createLineInsertion(5, 5, 3)];
        assertDiff(original, modified, expected);
    }

    // ---- deletions

    /** one deleted line below */
    function testOneDeletedLineBelow():Void {
        final original = ['line', 'new line'];
        final modified = ['line'];
        final expected = [createLineDeletion(2, 2, 1)];
        assertDiff(original, modified, expected);
    }

    /** two deleted lines below */
    function testTwoDeletedLinesBelow():Void {
        final original = ['line', 'new line', 'another new line'];
        final modified = ['line'];
        final expected = [createLineDeletion(2, 3, 1)];
        assertDiff(original, modified, expected);
    }

    /** one deleted lines above */
    function testOneDeletedLinesAbove():Void {
        final original = ['new line', 'line'];
        final modified = ['line'];
        final expected = [createLineDeletion(1, 1, 0)];
        assertDiff(original, modified, expected);
    }

    /** two deleted lines above */
    function testTwoDeletedLinesAbove():Void {
        final original = ['new line', 'another new line', 'line'];
        final modified = ['line'];
        final expected = [createLineDeletion(1, 2, 0)];
        assertDiff(original, modified, expected);
    }

    /** one deleted line in middle */
    function testOneDeletedLineInMiddle():Void {
        final original = ['line1', 'line2', 'new line', 'line3', 'line4'];
        final modified = ['line1', 'line2', 'line3', 'line4'];
        final expected = [createLineDeletion(3, 3, 2)];
        assertDiff(original, modified, expected);
    }

    /** two deleted lines in middle */
    function testTwoDeletedLinesInMiddle():Void {
        final original = ['line1', 'line2', 'new line', 'another new line', 'line3', 'line4'];
        final modified = ['line1', 'line2', 'line3', 'line4'];
        final expected = [createLineDeletion(3, 4, 2)];
        assertDiff(original, modified, expected);
    }

    /** two deleted lines in middle interrupted */
    function testTwoDeletedLinesInMiddleInterrupted():Void {
        final original = ['line1', 'line2', 'new line', 'line3', 'another new line', 'line4'];
        final modified = ['line1', 'line2', 'line3', 'line4'];
        final expected = [createLineDeletion(3, 3, 2), createLineDeletion(5, 5, 3)];
        assertDiff(original, modified, expected);
    }

    // ---- changes

    /** one line changed: chars inserted at the end */
    function testOneLineChangedCharsInsertedAtTheEnd():Void {
        final original = ['line'];
        final modified = ['line changed'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 5, 1, 5, 1, 5, 1, 13)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** one line changed: chars inserted at the beginning */
    function testOneLineChangedCharsInsertedAtTheBeginning():Void {
        final original = ['line'];
        final modified = ['my line'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 1, 1, 1, 1, 1, 1, 4)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** one line changed: chars inserted in the middle */
    function testOneLineChangedCharsInsertedInTheMiddle():Void {
        final original = ['abba'];
        final modified = ['abzzba'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 3, 1, 3, 1, 3, 1, 5)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** one line changed: chars inserted in the middle (two spots) */
    function testOneLineChangedCharsInsertedInTheMiddleTwoSpots():Void {
        final original = ['abba'];
        final modified = ['abzzbzza'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 3, 1, 3, 1, 3, 1, 5),
                createCharChange(1, 4, 1, 4, 1, 6, 1, 8)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** one line changed: chars deleted 1 */
    function testOneLineChangedCharsDeleted1():Void {
        final original = ['abcdefg'];
        final modified = ['abcfg'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 4, 1, 6, 1, 4, 1, 4)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** one line changed: chars deleted 2 */
    function testOneLineChangedCharsDeleted2():Void {
        final original = ['abcdefg'];
        final modified = ['acfg'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 2, 1, 3, 1, 2, 1, 2),
                createCharChange(1, 4, 1, 6, 1, 3, 1, 3)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** two lines changed 1 */
    function testTwoLinesChanged1():Void {
        final original = ['abcd', 'efgh'];
        final modified = ['abcz'];
        final expected = [
            createLineChange(1, 2, 1, 1, [
                createCharChange(1, 4, 2, 5, 1, 4, 1, 5)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** two lines changed 2 */
    function testTwoLinesChanged2():Void {
        final original = ['foo', 'abcd', 'efgh', 'BAR'];
        final modified = ['foo', 'abcz', 'BAR'];
        final expected = [
            createLineChange(2, 3, 2, 2, [
                createCharChange(2, 4, 3, 5, 2, 4, 2, 5)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** two lines changed 3 */
    function testTwoLinesChanged3():Void {
        final original = ['foo', 'abcd', 'efgh', 'BAR'];
        final modified = ['foo', 'abcz', 'zzzzefgh', 'BAR'];
        final expected = [
            createLineChange(2, 3, 2, 3, [
                createCharChange(2, 4, 2, 5, 2, 4, 2, 5),
                createCharChange(3, 1, 3, 1, 3, 1, 3, 5)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** two lines changed 4 */
    function testTwoLinesChanged4():Void {
        final original = ['abc'];
        final modified = ['', '', 'axc', ''];
        final expected = [
            createLineChange(1, 1, 1, 4, [
                createCharChange(1, 1, 1, 1, 1, 1, 3, 1),
                createCharChange(1, 2, 1, 3, 3, 2, 3, 3),
                createCharChange(1, 4, 1, 4, 3, 4, 4, 1)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** empty original sequence in char diff */
    function testEmptyOriginalSequenceInCharDiff():Void {
        final original = ['abc', '', 'xyz'];
        final modified = ['abc', 'qwe', 'rty', 'xyz'];
        final expected = [
            createLineChange(2, 2, 2, 3)
        ];
        assertDiff(original, modified, expected);
    }

    /** three lines changed */
    function testThreeLinesChanged():Void {
        final original = ['foo', 'abcd', 'efgh', 'BAR'];
        final modified = ['foo', 'zzzefgh', 'xxx', 'BAR'];
        final expected = [
            createLineChange(2, 3, 2, 3, [
                createCharChange(2, 1, 3, 1, 2, 1, 2, 4),
                createCharChange(3, 5, 3, 5, 2, 8, 3, 4),
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** big change part 1 */
    function testBigChangePart1():Void {
        final original = ['foo', 'abcd', 'efgh', 'BAR'];
        final modified = ['hello', 'foo', 'zzzefgh', 'xxx', 'BAR'];
        final expected = [
            createLineInsertion(1, 1, 0),
            createLineChange(2, 3, 3, 4, [
                createCharChange(2, 1, 3, 1, 3, 1, 3, 4),
                createCharChange(3, 5, 3, 5, 3, 8, 4, 4)
            ])
        ];
        assertDiff(original, modified, expected);
    }

    /** big change part 2 */
    function testBigChangePart2():Void {
        final original = ['foo', 'abcd', 'efgh', 'BAR', 'RAB'];
        final modified = ['hello', 'foo', 'zzzefgh', 'xxx', 'BAR'];
        final expected = [
            createLineInsertion(1, 1, 0),
            createLineChange(2, 3, 3, 4, [
                createCharChange(2, 1, 3, 1, 3, 1, 3, 4),
                createCharChange(3, 5, 3, 5, 3, 8, 4, 4)
            ]),
            createLineDeletion(5, 5, 5)
        ];
        assertDiff(original, modified, expected);
    }

    /** char change postprocessing merges */
    function testCharChangePostprocessingMerges():Void {
        final original = ['abba'];
        final modified = ['azzzbzzzbzzza'];
        final expected = [
            createLineChange(1, 1, 1, 1, [
                createCharChange(1, 2, 1, 4, 1, 2, 1, 13)
            ])
        ];
        assertDiff(original, modified, expected, true, true);
    }

    /** ignore trim whitespace */
    function testIgnoreTrimWhitespace():Void {
        final original = ['\t\t foo ', 'abcd', 'efgh', '\t\t BAR\t\t'];
        final modified = ['  hello\t', '\t foo   \t', 'zzzefgh', 'xxx', '   BAR   \t'];
        final expected = [
            createLineInsertion(1, 1, 0),
            createLineChange(2, 3, 3, 4, [
                createCharChange(2, 1, 2, 5, 3, 1, 3, 4),
                createCharChange(3, 5, 3, 5, 4, 1, 4, 4)
            ])
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** issue #12122 r.hasOwnProperty is not a function */
    function testIssue12122RHasOwnPropertyIsNotAFunction():Void {
        final original = ['hasOwnProperty'];
        final modified = ['hasOwnProperty', 'and another line'];
        final expected = [
            createLineInsertion(2, 2, 1)
        ];
        assertDiff(original, modified, expected);
    }

    /** empty diff 1 */
    function testEmptyDiff1():Void {
        final original = [''];
        final modified = ['something'];
        final expected = [
            createLineChange(1, 1, 1, 1, null)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** empty diff 2 */
    function testEmptyDiff2():Void {
        final original = [''];
        final modified = ['something', 'something else'];
        final expected = [
            createLineChange(1, 1, 1, 2, null)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** empty diff 3 */
    function testEmptyDiff3():Void {
        final original = ['something', 'something else'];
        final modified = [''];
        final expected = [
            createLineChange(1, 2, 1, 1, null)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** empty diff 4 */
    function testEmptyDiff4():Void {
        final original = ['something'];
        final modified = [''];
        final expected = [
            createLineChange(1, 1, 1, 1, null)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** empty diff 5 */
    function testEmptyDiff5():Void {
        final original = [''];
        final modified = [''];
        final expected:Array<ILineChange> = [];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** pretty diff 1 */
    function testPrettyDiff1():Void {
        final original = [
            'suite(function () {',
            '\ttest1() {',
            '\t\tassert.ok(true);',
            '\t}',
            '',
            '\ttest2() {',
            '\t\tassert.ok(true);',
            '\t}',
            '});',
            '',
        ];
        final modified = [
            '// An insertion',
            'suite(function () {',
            '\ttest1() {',
            '\t\tassert.ok(true);',
            '\t}',
            '',
            '\ttest2() {',
            '\t\tassert.ok(true);',
            '\t}',
            '',
            '\ttest3() {',
            '\t\tassert.ok(true);',
            '\t}',
            '});',
            '',
        ];
        final expected = [
            createLineInsertion(1, 1, 0),
            createLineInsertion(10, 13, 8)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** pretty diff 2 */
    function testPrettyDiff2():Void {
        final original = [
            '// Just a comment',
            '',
            'function compute(a, b, c, d) {',
            '\tif (a) {',
            '\t\tif (b) {',
            '\t\t\tif (c) {',
            '\t\t\t\treturn 5;',
            '\t\t\t}',
            '\t\t}',
            '\t\t// These next lines will be deleted',
            '\t\tif (d) {',
            '\t\t\treturn -1;',
            '\t\t}',
            '\t\treturn 0;',
            '\t}',
            '}',
        ];
        final modified = [
            '// Here is an inserted line',
            '// and another inserted line',
            '// and another one',
            '// Just a comment',
            '',
            'function compute(a, b, c, d) {',
            '\tif (a) {',
            '\t\tif (b) {',
            '\t\t\tif (c) {',
            '\t\t\t\treturn 5;',
            '\t\t\t}',
            '\t\t}',
            '\t\treturn 0;',
            '\t}',
            '}',
        ];
        final expected = [
            createLineInsertion(1, 3, 0),
            createLineDeletion(10, 13, 12),
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** pretty diff 3 */
    function testPrettyDiff3():Void {
        final original = [
            'class A {',
            '\t/**',
            '\t * m1',
            '\t */',
            '\tmethod1() {}',
            '',
            '\t/**',
            '\t * m3',
            '\t */',
            '\tmethod3() {}',
            '}',
        ];
        final modified = [
            'class A {',
            '\t/**',
            '\t * m1',
            '\t */',
            '\tmethod1() {}',
            '',
            '\t/**',
            '\t * m2',
            '\t */',
            '\tmethod2() {}',
            '',
            '\t/**',
            '\t * m3',
            '\t */',
            '\tmethod3() {}',
            '}',
        ];
        final expected = [
            createLineInsertion(7, 11, 6)
        ];
        assertDiff(original, modified, expected, true, false, true);
    }

    /** issue #23636 */
    function testIssue23636():Void {
        final original = [
            'if(!TextDrawLoad[playerid])',
            '{',
            '',
            '\tTextDrawHideForPlayer(playerid,TD_AppleJob[3]);',
            '\tTextDrawHideForPlayer(playerid,TD_AppleJob[4]);',
            '\tif(!AppleJobTreesType[AppleJobTreesPlayerNum[playerid]])',
            '\t{',
            '\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[5+i]);',
            '\t}',
            '\telse',
            '\t{',
            '\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[15+i]);',
            '\t}',
            '}',
            'else',
            '{',
            '\tTextDrawHideForPlayer(playerid,TD_AppleJob[3]);',
            '\tTextDrawHideForPlayer(playerid,TD_AppleJob[27]);',
            '\tif(!AppleJobTreesType[AppleJobTreesPlayerNum[playerid]])',
            '\t{',
            '\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[28+i]);',
            '\t}',
            '\telse',
            '\t{',
            '\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[38+i]);',
            '\t}',
            '}',
        ];
        final modified = [
            '\tif(!TextDrawLoad[playerid])',
            '\t{',
            '\t',
            '\t\tTextDrawHideForPlayer(playerid,TD_AppleJob[3]);',
            '\t\tTextDrawHideForPlayer(playerid,TD_AppleJob[4]);',
            '\t\tif(!AppleJobTreesType[AppleJobTreesPlayerNum[playerid]])',
            '\t\t{',
            '\t\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[5+i]);',
            '\t\t}',
            '\t\telse',
            '\t\t{',
            '\t\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[15+i]);',
            '\t\t}',
            '\t}',
            '\telse',
            '\t{',
            '\t\tTextDrawHideForPlayer(playerid,TD_AppleJob[3]);',
            '\t\tTextDrawHideForPlayer(playerid,TD_AppleJob[27]);',
            '\t\tif(!AppleJobTreesType[AppleJobTreesPlayerNum[playerid]])',
            '\t\t{',
            '\t\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[28+i]);',
            '\t\t}',
            '\t\telse',
            '\t\t{',
            '\t\t\tfor(new i=0;i<10;i++) if(StatusTD_AppleJobApples[playerid][i]) TextDrawHideForPlayer(playerid,TD_AppleJob[38+i]);',
            '\t\t}',
            '\t}',
        ];
        final expected = [
            createLineChange(
                1, 27, 1, 27,
                [
                    createCharChange(1, 1, 1, 1, 1, 1, 1, 2),
                    createCharChange(2, 1, 2, 1, 2, 1, 2, 2),
                    createCharChange(3, 1, 3, 1, 3, 1, 3, 2),
                    createCharChange(4, 1, 4, 1, 4, 1, 4, 2),
                    createCharChange(5, 1, 5, 1, 5, 1, 5, 2),
                    createCharChange(6, 1, 6, 1, 6, 1, 6, 2),
                    createCharChange(7, 1, 7, 1, 7, 1, 7, 2),
                    createCharChange(8, 1, 8, 1, 8, 1, 8, 2),
                    createCharChange(9, 1, 9, 1, 9, 1, 9, 2),
                    createCharChange(10, 1, 10, 1, 10, 1, 10, 2),
                    createCharChange(11, 1, 11, 1, 11, 1, 11, 2),
                    createCharChange(12, 1, 12, 1, 12, 1, 12, 2),
                    createCharChange(13, 1, 13, 1, 13, 1, 13, 2),
                    createCharChange(14, 1, 14, 1, 14, 1, 14, 2),
                    createCharChange(15, 1, 15, 1, 15, 1, 15, 2),
                    createCharChange(16, 1, 16, 1, 16, 1, 16, 2),
                    createCharChange(17, 1, 17, 1, 17, 1, 17, 2),
                    createCharChange(18, 1, 18, 1, 18, 1, 18, 2),
                    createCharChange(19, 1, 19, 1, 19, 1, 19, 2),
                    createCharChange(20, 1, 20, 1, 20, 1, 20, 2),
                    createCharChange(21, 1, 21, 1, 21, 1, 21, 2),
                    createCharChange(22, 1, 22, 1, 22, 1, 22, 2),
                    createCharChange(23, 1, 23, 1, 23, 1, 23, 2),
                    createCharChange(24, 1, 24, 1, 24, 1, 24, 2),
                    createCharChange(25, 1, 25, 1, 25, 1, 25, 2),
                    createCharChange(26, 1, 26, 1, 26, 1, 26, 2),
                    createCharChange(27, 1, 27, 1, 27, 1, 27, 2),
                ]
            )
            // createLineInsertion(7, 11, 6)
        ];
        assertDiff(original, modified, expected, true, true, false);
    }

    /** issue #43922 */
    function testIssue43922():Void {
        final original = [
            ' * `yarn [install]` -- Install project NPM dependencies. This is automatically done when you first create the project. You should only need to run this if you add dependencies in `package.json`.',
        ];
        final modified = [
            ' * `yarn` -- Install project NPM dependencies. You should only need to run this if you add dependencies in `package.json`.',
        ];
        final expected = [
            createLineChange(
                1, 1, 1, 1,
                [
                    createCharChange(1, 9, 1, 19, 1, 9, 1, 9),
                    createCharChange(1, 58, 1, 120, 1, 48, 1, 48),
                ]
            )
        ];
        assertDiff(original, modified, expected, true, true, false);
    }

    /** issue #42751 */
    function testIssue42751():Void {
        final original = [
            '    1',
            '  2',
        ];
        final modified = [
            '    1',
            '   3',
        ];
        final expected = [
            createLineChange(
                2, 2, 2, 2,
                [
                    createCharChange(2, 3, 2, 4, 2, 3, 2, 5)
                ]
            )
        ];
        assertDiff(original, modified, expected, true, true, false);
    }

    /** does not give character changes */
    function testDoesNotGiveCharacterChanges():Void {
        final original = [
            '    1',
            '  2',
            'A',
        ];
        final modified = [
            '    1',
            '   3',
            ' A',
        ];
        final expected = [
            createLineChange(
                2, 3, 2, 3
            )
        ];
        assertDiff(original, modified, expected, false, false, false);
    }

    /** issue #44422: Less than ideal diff results */
    function testIssue44422LessThanIdealDiffResults():Void {
        final original = [
            'export class C {',
            '',
            '\tpublic m1(): void {',
            '\t\t{',
            '\t\t//2',
            '\t\t//3',
            '\t\t//4',
            '\t\t//5',
            '\t\t//6',
            '\t\t//7',
            '\t\t//8',
            '\t\t//9',
            '\t\t//10',
            '\t\t//11',
            '\t\t//12',
            '\t\t//13',
            '\t\t//14',
            '\t\t//15',
            '\t\t//16',
            '\t\t//17',
            '\t\t//18',
            '\t\t}',
            '\t}',
            '',
            '\tpublic m2(): void {',
            '\t\tif (a) {',
            '\t\t\tif (b) {',
            '\t\t\t\t//A1',
            '\t\t\t\t//A2',
            '\t\t\t\t//A3',
            '\t\t\t\t//A4',
            '\t\t\t\t//A5',
            '\t\t\t\t//A6',
            '\t\t\t\t//A7',
            '\t\t\t\t//A8',
            '\t\t\t}',
            '\t\t}',
            '',
            '\t\t//A9',
            '\t\t//A10',
            '\t\t//A11',
            '\t\t//A12',
            '\t\t//A13',
            '\t\t//A14',
            '\t\t//A15',
            '\t}',
            '',
            '\tpublic m3(): void {',
            '\t\tif (a) {',
            '\t\t\t//B1',
            '\t\t}',
            '\t\t//B2',
            '\t\t//B3',
            '\t}',
            '',
            '\tpublic m4(): boolean {',
            '\t\t//1',
            '\t\t//2',
            '\t\t//3',
            '\t\t//4',
            '\t}',
            '',
            '}',
        ];
        final modified = [
            'export class C {',
            '',
            '\tconstructor() {',
            '',
            '',
            '',
            '',
            '\t}',
            '',
            '\tpublic m1(): void {',
            '\t\t{',
            '\t\t//2',
            '\t\t//3',
            '\t\t//4',
            '\t\t//5',
            '\t\t//6',
            '\t\t//7',
            '\t\t//8',
            '\t\t//9',
            '\t\t//10',
            '\t\t//11',
            '\t\t//12',
            '\t\t//13',
            '\t\t//14',
            '\t\t//15',
            '\t\t//16',
            '\t\t//17',
            '\t\t//18',
            '\t\t}',
            '\t}',
            '',
            '\tpublic m4(): boolean {',
            '\t\t//1',
            '\t\t//2',
            '\t\t//3',
            '\t\t//4',
            '\t}',
            '',
            '}',
        ];
        final expected = [
            createLineChange(
                2, 0, 3, 9
            ),
            createLineChange(
                25, 55, 31, 0
            )
        ];
        assertDiff(original, modified, expected, false, false, false);
    }

    /** gives preference to matching longer lines */
    function testGivesPreferenceToMatchingLongerLines():Void {
        final original = [
            'A',
            'A',
            'BB',
            'C',
        ];
        final modified = [
            'A',
            'BB',
            'A',
            'D',
            'E',
            'A',
            'C',
        ];
        final expected = [
            createLineChange(
                2, 2, 1, 0
            ),
            createLineChange(
                3, 0, 3, 6
            )
        ];
        assertDiff(original, modified, expected, false, false, false);
    }

    /** issue #119051: gives preference to fewer diff hunks */
    function testIssue119051GivesPreferenceToFewerDiffHunks():Void {
        final original = [
            '1',
            '',
            '',
            '2',
            '',
        ];
        final modified = [
            '1',
            '',
            '1.5',
            '',
            '',
            '2',
            '',
            '3',
            '',
        ];
        final expected = [
            createLineChange(
                2, 0, 3, 4
            ),
            createLineChange(
                5, 0, 8, 9
            )
        ];
        assertDiff(original, modified, expected, false, false, false);
    }

    /** issue #121436: Diff chunk contains an unchanged line part 1 */
    function testIssue121436DiffChunkContainsAnUnchangedLinePart1():Void {
        final original = [
            'if (cond) {',
            '    cmd',
            '}',
        ];
        final modified = [
            'if (cond) {',
            '    if (other_cond) {',
            '        cmd',
            '    }',
            '}',
        ];
        final expected = [
            createLineChange(
                1, 0, 2, 2
            ),
            createLineChange(
                2, 0, 4, 4
            )
        ];
        assertDiff(original, modified, expected, false, false, true);
    }

    /** issue #121436: Diff chunk contains an unchanged line part 2 */
    function testIssue121436DiffChunkContainsAnUnchangedLinePart2():Void {
        final original = [
            'if (cond) {',
            '    cmd',
            '}',
        ];
        final modified = [
            'if (cond) {',
            '    if (other_cond) {',
            '        cmd',
            '    }',
            '}',
        ];
        final expected = [
            createLineChange(
                1, 0, 2, 2
            ),
            createLineChange(
                2, 2, 3, 3
            ),
            createLineChange(
                2, 0, 4, 4
            )
        ];
        assertDiff(original, modified, expected, false, false, false);
    }

    /** issue #169552: Assertion error when having both leading and trailing whitespace diffs */
    function testIssue169552AssertionErrorWhenHavingBothLeadingAndTrailingWhitespaceDiffs():Void {
        final original = [
            'if True:',
            '    print(2)',
        ];
        final modified = [
            'if True:',
            '\tprint(2) ',
        ];
        final expected = [
            createLineChange(
                2, 2, 2, 2,
                [
                    createCharChange(2, 1, 2, 5, 2, 1, 2, 2),
                    createCharChange(2, 13, 2, 13, 2, 10, 2, 11),
                ]
            ),
        ];
        assertDiff(original, modified, expected, true, false, false);
    }

}

private class TestLineRange {

    public final startLineNumber:Int;
    public final lineCount:Int;

    public function new(startLineNumber:Int, lineCount:Int) {
        this.startLineNumber = startLineNumber;
        this.lineCount = lineCount;
    }

    public var isEmpty(get, never):Bool;
    function get_isEmpty():Bool {
        return this.lineCount == 0;
    }

    public var endLineNumberExclusive(get, never):Int;
    function get_endLineNumberExclusive():Int {
        return this.startLineNumber + this.lineCount;
    }

}
