// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/indent.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.base.input.TabSize;
import ropey.RopeSlice;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.TabSize` (Rust `indent.rs`).
 */
class InputIndentTest extends TestCase {

    function testTabSize() {
        var tab = new TabSize(2, false);
        assertEquals("  ", tab.toString());
        tab = new TabSize(4, false);
        assertEquals("    ", tab.toString());

        tab = new TabSize(2, true);
        assertEquals("\t", tab.toString());
        tab = new TabSize(4, true);
        assertEquals("\t", tab.toString());
    }

    function testTabSizeIndentCount() {
        final tab = new TabSize(4, false);
        assertEquals(0, tab.indentCount(RopeSlice.fromStr("abc")));
        assertEquals(2, tab.indentCount(RopeSlice.fromStr("  abc")));
        assertEquals(4, tab.indentCount(RopeSlice.fromStr("    abc")));
        assertEquals(4, tab.indentCount(RopeSlice.fromStr("\tabc")));
        assertEquals(4, tab.indentCount(RopeSlice.fromStr("  \tabc")));
        assertEquals(5, tab.indentCount(RopeSlice.fromStr(" \t abc  ")));
        assertEquals(8, tab.indentCount(RopeSlice.fromStr(" \t \tabc")));
        assertEquals(8, tab.indentCount(RopeSlice.fromStr("    \tabc")));
        assertEquals(0, tab.indentCount(RopeSlice.fromStr("abc")));
    }

}
