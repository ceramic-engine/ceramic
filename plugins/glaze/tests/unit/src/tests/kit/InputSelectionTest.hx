// Ported from gpui-kit 0.8.1: crates/base/src/input/base/selection.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.base.input.TextSelector;
import ropey.Rope;
import testing.TestCase;

using glaze.kit.base.input.RopeExt;

/**
 * Tests of `TextSelector` (Rust `selection.rs`). Columns are byte offsets
 * in the line.
 */
class InputSelectionTest extends TestCase {

    function testWordRange() {
        // indoc! strips the common indentation and keeps the final newline.
        final rope = Rope.fromStr("test text:\nabcde 中文🎉 test\nhello[()]\ntest_connector ____\nRope\nrök\ngrande île\n");

        final tests:Array<Array<Dynamic>> = [
            [0, 0, "test"],
            [0, 4, " "],
            [1, 0, "abcde"],
            [1, 4, "abcde"],
            [1, 5, " "],
            [1, 6, "中"],
            [1, 9, "文"],
            [1, 13, "🎉"],
            [1, 20, "test"],
            [2, 5, "["],
            [2, 6, "("],
            [2, 7, ")"],
            [2, 8, "]"],
            [3, 5, "test_connector"],
            [3, 14, " "],
            [3, 16, "____"],
            [4, 0, "Rope"],
            [5, 0, "rök"],
            [6, 8, "île"],
        ];

        for (test in tests) {
            final line:Int = test[0];
            final column:Int = test[1];
            final expected:Null<String> = test[2];
            final offset = rope.lineStartOffset(line) + column;
            final range = TextSelector.wordRange(rope, offset);

            final actual = range == null ? null : rope.slice(range.start, range.end).toString();
            assertEquals(expected, actual, 'line $line, column $column');
        }
    }

    function testLineRange() {
        final rope = Rope.fromStr("first line\nsecond line\nthird");
        final tests:Array<Array<Dynamic>> = [
            [0, 0, "first line"],
            [0, 5, "first line"],
            [1, 3, "second line"],
            [2, 1, "third"],
        ];

        for (test in tests) {
            final line:Int = test[0];
            final column:Int = test[1];
            final expected:String = test[2];
            final offset = rope.lineStartOffset(line) + column;
            final range = TextSelector.lineRange(rope, offset);

            assertEquals(expected, rope.slice(range.start, range.end).toString(), 'line $line, column $column');
        }
    }

}
