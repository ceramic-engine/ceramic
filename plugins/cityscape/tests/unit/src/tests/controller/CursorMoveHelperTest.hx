// Ported from vscode src/vs/editor/test/common/controller/cursorMoveHelper.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.controller;

import cityscape.common.core.CursorColumns;
import testing.TestCase;

/**
 * suite('CursorMove')
 */
class CursorMoveHelperTest extends TestCase {

    function testNextRenderTabStop() {
        assertEquals(CursorColumns.nextRenderTabStop(0, 4), 4);
        assertEquals(CursorColumns.nextRenderTabStop(1, 4), 4);
        assertEquals(CursorColumns.nextRenderTabStop(2, 4), 4);
        assertEquals(CursorColumns.nextRenderTabStop(3, 4), 4);
        assertEquals(CursorColumns.nextRenderTabStop(4, 4), 8);
        assertEquals(CursorColumns.nextRenderTabStop(5, 4), 8);
        assertEquals(CursorColumns.nextRenderTabStop(6, 4), 8);
        assertEquals(CursorColumns.nextRenderTabStop(7, 4), 8);
        assertEquals(CursorColumns.nextRenderTabStop(8, 4), 12);

        assertEquals(CursorColumns.nextRenderTabStop(0, 2), 2);
        assertEquals(CursorColumns.nextRenderTabStop(1, 2), 2);
        assertEquals(CursorColumns.nextRenderTabStop(2, 2), 4);
        assertEquals(CursorColumns.nextRenderTabStop(3, 2), 4);
        assertEquals(CursorColumns.nextRenderTabStop(4, 2), 6);
        assertEquals(CursorColumns.nextRenderTabStop(5, 2), 6);
        assertEquals(CursorColumns.nextRenderTabStop(6, 2), 8);
        assertEquals(CursorColumns.nextRenderTabStop(7, 2), 8);
        assertEquals(CursorColumns.nextRenderTabStop(8, 2), 10);

        assertEquals(CursorColumns.nextRenderTabStop(0, 1), 1);
        assertEquals(CursorColumns.nextRenderTabStop(1, 1), 2);
        assertEquals(CursorColumns.nextRenderTabStop(2, 1), 3);
        assertEquals(CursorColumns.nextRenderTabStop(3, 1), 4);
        assertEquals(CursorColumns.nextRenderTabStop(4, 1), 5);
        assertEquals(CursorColumns.nextRenderTabStop(5, 1), 6);
        assertEquals(CursorColumns.nextRenderTabStop(6, 1), 7);
        assertEquals(CursorColumns.nextRenderTabStop(7, 1), 8);
        assertEquals(CursorColumns.nextRenderTabStop(8, 1), 9);
    }

    function testVisibleColumnFromColumn() {

        final testVisibleColumnFromColumn = (text:String, tabSize:Int, column:Int, expected:Int) -> {
            assertEquals(CursorColumns.visibleColumnFromColumn(text, column, tabSize), expected);
        };

        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 1, 0);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 2, 4);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 3, 8);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 4, 9);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 5, 10);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 6, 11);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 7, 12);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 8, 13);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 9, 14);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 10, 15);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 11, 16);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 12, 17);
        testVisibleColumnFromColumn('\t\tvar x = 3;', 4, 13, 18);

        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 1, 0);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 2, 4);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 3, 5);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 4, 8);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 5, 9);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 6, 10);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 7, 11);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 8, 12);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 9, 13);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 10, 14);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 11, 15);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 12, 16);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 13, 17);
        testVisibleColumnFromColumn('\t \tvar x = 3;', 4, 14, 18);

        testVisibleColumnFromColumn('\t  \tx\t', 4, -1, 0);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 0, 0);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 1, 0);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 2, 4);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 3, 5);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 4, 6);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 5, 8);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 6, 9);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 7, 12);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 8, 12);
        testVisibleColumnFromColumn('\t  \tx\t', 4, 9, 12);

        testVisibleColumnFromColumn('baz', 4, 1, 0);
        testVisibleColumnFromColumn('baz', 4, 2, 1);
        testVisibleColumnFromColumn('baz', 4, 3, 2);
        testVisibleColumnFromColumn('baz', 4, 4, 3);

        testVisibleColumnFromColumn('📚az', 4, 1, 0);
        testVisibleColumnFromColumn('📚az', 4, 2, 1);
        testVisibleColumnFromColumn('📚az', 4, 3, 2);
        testVisibleColumnFromColumn('📚az', 4, 4, 3);
        testVisibleColumnFromColumn('📚az', 4, 5, 4);
    }

    function testColumnFromVisibleColumn() {

        final testColumnFromVisibleColumn = (text:String, tabSize:Int, visibleColumn:Int, expected:Int) -> {
            assertEquals(CursorColumns.columnFromVisibleColumn(text, visibleColumn, tabSize), expected);
        };

        // testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 0, 1);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 1, 1);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 2, 1);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 3, 2);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 4, 2);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 5, 2);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 6, 2);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 7, 3);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 8, 3);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 9, 4);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 10, 5);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 11, 6);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 12, 7);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 13, 8);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 14, 9);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 15, 10);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 16, 11);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 17, 12);
        testColumnFromVisibleColumn('\t\tvar x = 3;', 4, 18, 13);

        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 0, 1);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 1, 1);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 2, 1);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 3, 2);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 4, 2);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 5, 3);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 6, 3);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 7, 4);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 8, 4);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 9, 5);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 10, 6);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 11, 7);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 12, 8);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 13, 9);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 14, 10);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 15, 11);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 16, 12);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 17, 13);
        testColumnFromVisibleColumn('\t \tvar x = 3;', 4, 18, 14);

        testColumnFromVisibleColumn('\t  \tx\t', 4, -2, 1);
        testColumnFromVisibleColumn('\t  \tx\t', 4, -1, 1);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 0, 1);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 1, 1);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 2, 1);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 3, 2);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 4, 2);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 5, 3);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 6, 4);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 7, 4);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 8, 5);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 9, 6);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 10, 6);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 11, 7);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 12, 7);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 13, 7);
        testColumnFromVisibleColumn('\t  \tx\t', 4, 14, 7);

        testColumnFromVisibleColumn('baz', 4, 0, 1);
        testColumnFromVisibleColumn('baz', 4, 1, 2);
        testColumnFromVisibleColumn('baz', 4, 2, 3);
        testColumnFromVisibleColumn('baz', 4, 3, 4);

        testColumnFromVisibleColumn('📚az', 4, 0, 1);
        testColumnFromVisibleColumn('📚az', 4, 1, 1);
        testColumnFromVisibleColumn('📚az', 4, 2, 3);
        testColumnFromVisibleColumn('📚az', 4, 3, 4);
        testColumnFromVisibleColumn('📚az', 4, 4, 5);
    }

    function testToStatusbarColumn() {

        final t = (text:String, tabSize:Int, column:Int, expected:Int) -> {
            assertEquals(CursorColumns.toStatusbarColumn(text, column, tabSize), expected, '<<t(\'${text}\', ${tabSize}, ${column}, ${expected})>>');
        };

        t('    spaces', 4, 1, 1);
        t('    spaces', 4, 2, 2);
        t('    spaces', 4, 3, 3);
        t('    spaces', 4, 4, 4);
        t('    spaces', 4, 5, 5);
        t('    spaces', 4, 6, 6);
        t('    spaces', 4, 7, 7);
        t('    spaces', 4, 8, 8);
        t('    spaces', 4, 9, 9);
        t('    spaces', 4, 10, 10);
        t('    spaces', 4, 11, 11);

        t('\ttab', 4, 1, 1);
        t('\ttab', 4, 2, 5);
        t('\ttab', 4, 3, 6);
        t('\ttab', 4, 4, 7);
        t('\ttab', 4, 5, 8);

        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 1, 1);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 2, 2);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 3, 2);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 4, 3);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 5, 3);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 6, 4);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 7, 4);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 8, 5);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 9, 5);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 10, 6);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 11, 6);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 12, 7);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 13, 7);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 14, 8);
        t('𐌀𐌁𐌂𐌃𐌄𐌅𐌆', 4, 15, 8);

        t('🎈🎈🎈🎈', 4, 1, 1);
        t('🎈🎈🎈🎈', 4, 2, 2);
        t('🎈🎈🎈🎈', 4, 3, 2);
        t('🎈🎈🎈🎈', 4, 4, 3);
        t('🎈🎈🎈🎈', 4, 5, 3);
        t('🎈🎈🎈🎈', 4, 6, 4);
        t('🎈🎈🎈🎈', 4, 7, 4);
        t('🎈🎈🎈🎈', 4, 8, 5);
        t('🎈🎈🎈🎈', 4, 9, 5);

        t('何何何何', 4, 1, 1);
        t('何何何何', 4, 2, 2);
        t('何何何何', 4, 3, 3);
        t('何何何何', 4, 4, 4);
    }

}
