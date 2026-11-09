// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mode.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.base.input.LayoutMode;
import glaze.kit.base.input.TabSize;

/**
 * Tests of `LayoutMode` (Rust `mode.rs`). `LayoutMode` names the input
 * state types, so this test can only be registered once `InputBaseState`
 * is ported.
 */
class InputModeTest extends KitTestCase {

    function testPlain() {
        var mode = LayoutMode.plainTextWith(TabSize.defaultValue(), 5);
        assertEquals(5, mode.rows());
        assertEquals(0x7FFFFFFF, mode.maxRows());
        assertEquals(1, mode.minRows());

        mode = LayoutMode.plainText();
        assertEquals(1, mode.rows());
        assertEquals(1, mode.minRows());
    }

    function testAutoGrow() {
        final mode = LayoutMode.autoGrow(2, 5);
        assertEquals(2, mode.rows());
        assertEquals(5, mode.maxRows());
        assertEquals(2, mode.minRows());

        mode.setRows(4);
        assertEquals(4, mode.rows());

        mode.setRows(1);
        assertEquals(2, mode.rows());

        mode.setRows(10);
        assertEquals(5, mode.rows());
    }

}
