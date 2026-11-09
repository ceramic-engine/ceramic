// Ported from vscode src/vs/editor/test/common/controller/cursorAtomicMoveOperations.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.controller;

import cityscape.common.cursor.CursorAtomicMoveOperations;
import testing.TestCase;

/**
 * suite('Cursor move command test') of cursorAtomicMoveOperations.test.ts
 */
class CursorAtomicMoveOperationsTest extends TestCase {

    function testTestWhitespaceVisibleColumn() {
        final testCases:Array<{lineContent:String, tabSize:Int, expectedPrevTabStopPosition:Array<Int>, expectedPrevTabStopVisibleColumn:Array<Int>, expectedVisibleColumn:Array<Int>}> = [
            {
                lineContent: '        ',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, 0, 0, 0, 4, 4, 4, 4, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, 0, 0, 0, 4, 4, 4, 4, -1],
                expectedVisibleColumn: [0, 1, 2, 3, 4, 5, 6, 7, 8, -1],
            },
            {
                lineContent: '  ',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, 0, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, 0, -1],
                expectedVisibleColumn: [0, 1, 2, -1],
            },
            {
                lineContent: '\t',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, -1],
                expectedVisibleColumn: [0, 4, -1],
            },
            {
                lineContent: '\t ',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, 1, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, 4, -1],
                expectedVisibleColumn: [0, 4, 5, -1],
            },
            {
                lineContent: ' \t\t ',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, 0, 2, 3, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, 0, 4, 8, -1],
                expectedVisibleColumn: [0, 1, 4, 8, 9, -1],
            },
            {
                lineContent: ' \tA',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, 0, 0, -1, -1],
                expectedPrevTabStopVisibleColumn: [-1, 0, 0, -1, -1],
                expectedVisibleColumn: [0, 1, 4, -1, -1],
            },
            {
                lineContent: 'A',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, -1, -1],
                expectedPrevTabStopVisibleColumn: [-1, -1, -1],
                expectedVisibleColumn: [0, -1, -1],
            },
            {
                lineContent: '',
                tabSize: 4,
                expectedPrevTabStopPosition: [-1, -1],
                expectedPrevTabStopVisibleColumn: [-1, -1],
                expectedVisibleColumn: [0, -1],
            },
        ];

        for (testCase in testCases) {
            final maxPosition = testCase.expectedVisibleColumn.length;
            for (position in 0...maxPosition) {
                final actual = AtomicTabMoveOperations.whitespaceVisibleColumn(testCase.lineContent, position, testCase.tabSize);
                final expected = [
                    testCase.expectedPrevTabStopPosition[position],
                    testCase.expectedPrevTabStopVisibleColumn[position],
                    testCase.expectedVisibleColumn[position]
                ];
                assertDeepEquals(expected, actual);
            }
        }
    }

    function testTestAtomicPosition() {
        final testCases:Array<{lineContent:String, tabSize:Int, expectedLeft:Array<Int>, expectedRight:Array<Int>, expectedNearest:Array<Int>}> = [
            {
                lineContent: '        ',
                tabSize: 4,
                expectedLeft: [-1, 0, 0, 0, 0, 4, 4, 4, 4, -1],
                expectedRight: [4, 4, 4, 4, 8, 8, 8, 8, -1, -1],
                expectedNearest: [0, 0, 0, 4, 4, 4, 4, 8, 8, -1],
            },
            {
                lineContent: ' \t',
                tabSize: 4,
                expectedLeft: [-1, 0, 0, -1],
                expectedRight: [2, 2, -1, -1],
                expectedNearest: [0, 0, 2, -1],
            },
            {
                lineContent: '\t ',
                tabSize: 4,
                expectedLeft: [-1, 0, -1, -1],
                expectedRight: [1, -1, -1, -1],
                expectedNearest: [0, 1, -1, -1],
            },
            {
                lineContent: ' \t ',
                tabSize: 4,
                expectedLeft: [-1, 0, 0, -1, -1],
                expectedRight: [2, 2, -1, -1, -1],
                expectedNearest: [0, 0, 2, -1, -1],
            },
            {
                lineContent: '        A',
                tabSize: 4,
                expectedLeft: [-1, 0, 0, 0, 0, 4, 4, 4, 4, -1, -1],
                expectedRight: [4, 4, 4, 4, 8, 8, 8, 8, -1, -1, -1],
                expectedNearest: [0, 0, 0, 4, 4, 4, 4, 8, 8, -1, -1],
            },
            {
                lineContent: '      foo',
                tabSize: 4,
                expectedLeft: [-1, 0, 0, 0, 0, -1, -1, -1, -1, -1, -1],
                expectedRight: [4, 4, 4, 4, -1, -1, -1, -1, -1, -1, -1],
                expectedNearest: [0, 0, 0, 4, 4, -1, -1, -1, -1, -1, -1],
            },
        ];

        for (testCase in testCases) {
            for (item in [
                {
                    direction: Direction.Left,
                    expected: testCase.expectedLeft,
                },
                {
                    direction: Direction.Right,
                    expected: testCase.expectedRight,
                },
                {
                    direction: Direction.Nearest,
                    expected: testCase.expectedNearest,
                },
            ]) {
                final direction = item.direction;
                final expected = item.expected;
                final actual = [for (i in 0...expected.length) AtomicTabMoveOperations.atomicPosition(testCase.lineContent, i, testCase.tabSize, direction)];
                assertDeepEquals(expected, actual);
            }
        }
    }

}
