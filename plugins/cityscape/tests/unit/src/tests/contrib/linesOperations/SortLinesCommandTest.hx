// Ported from vscode src/vs/editor/contrib/linesOperations/test/browser/sortLinesCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.linesOperations;

import cityscape.common.core.Selection;
import cityscape.contrib.linesOperations.view.SortLinesCommand;
import testing.TestCase;
import testing.TestCommand;

/**
 * suite('Editor Contrib - Sort Lines Command')
 */
class SortLinesCommandTest extends TestCase {

    function doTestSortLinesAscendingCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new SortLinesCommand(sel, false), expectedLines, expectedSelection, null, null, pos);
    }

    function doTestSortLinesDescendingCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?pos:haxe.PosInfos):Void {
        TestCommand.testCommand(this, lines, null, selection, (accessor, sel) -> new SortLinesCommand(sel, true), expectedLines, expectedSelection, null, null, pos);
    }

    /**
     * test('no op unless at least two lines selected 1')
     */
    function testNoOpUnlessAtLeastTwoLinesSelected1() {
        doTestSortLinesAscendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 1, 1)
        );
    }

    /**
     * test('no op unless at least two lines selected 2')
     */
    function testNoOpUnlessAtLeastTwoLinesSelected2() {
        doTestSortLinesAscendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 2, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 3, 2, 1)
        );
    }

    /**
     * test('sorting two lines ascending')
     */
    function testSortingTwoLinesAscending() {
        doTestSortLinesAscendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 3, 4, 2),
            [
                'first',
                'second line',
                'fourth line',
                'third line',
                'fifth'
            ],
            new Selection(3, 3, 4, 1)
        );
    }

    /**
     * test('sorting first 4 lines ascending')
     */
    function testSortingFirst4LinesAscending() {
        doTestSortLinesAscendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 5, 1),
            [
                'first',
                'fourth line',
                'second line',
                'third line',
                'fifth'
            ],
            new Selection(1, 1, 5, 1)
        );
    }

    /**
     * test('sorting all lines ascending')
     */
    function testSortingAllLinesAscending() {
        doTestSortLinesAscendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 5, 6),
            [
                'fifth',
                'first',
                'fourth line',
                'second line',
                'third line',
            ],
            new Selection(1, 1, 5, 11)
        );
    }

    /**
     * test('sorting first 4 lines descending')
     */
    function testSortingFirst4LinesDescending() {
        doTestSortLinesDescendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 5, 1),
            [
                'third line',
                'second line',
                'fourth line',
                'first',
                'fifth'
            ],
            new Selection(1, 1, 5, 1)
        );
    }

    /**
     * test('sorting all lines descending')
     */
    function testSortingAllLinesDescending() {
        doTestSortLinesDescendingCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 5, 6),
            [
                'third line',
                'second line',
                'fourth line',
                'first',
                'fifth',
            ],
            new Selection(1, 1, 5, 6)
        );
    }

}
