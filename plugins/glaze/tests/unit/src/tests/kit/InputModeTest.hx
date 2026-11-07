// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mode.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Range;
import gpui.base.input.AutoClosedPairs;
import gpui.base.input.DiagnosticSet;
import gpui.base.input.EditorLanguage;
import gpui.base.input.HighlighterCell;
import gpui.base.input.LayoutMode;
import gpui.base.input.RopePoint;
import gpui.base.input.TabSize;
import ropey.Rope;

/**
 * Tests of `LayoutMode` (Rust `mode.rs`). `LayoutMode` names the input
 * state types, so this test can only be registered once `InputBaseState`
 * is ported.
 */
class InputModeTest extends KitTestCase {

    function testReplacementInputEditBackspaceAtEndUsesOldRange() {
        final oldText = Rope.fromStr("-=");
        final text = Rope.fromStr("-");
        final edit = LayoutMode.replacementInputEdit(oldText, text, new Range(1, 2), "");

        assertEquals(1, edit.startByte);
        assertEquals(2, edit.oldEndByte);
        assertEquals(1, edit.newEndByte);
        assertTrue(new RopePoint(0, 1).equals(edit.startPosition));
        assertTrue(new RopePoint(0, 2).equals(edit.oldEndPosition));
        assertTrue(new RopePoint(0, 1).equals(edit.newEndPosition));
    }

    function testCodeEditor() {
        final language = app.update(cx -> EditorLanguage.create(cx));
        var mode = LayoutMode.codeEditor(language);
        assertEquals(true, mode.lineNumber());
        assertEquals(true, mode.hasIndentGuides());
        assertEquals(0x7FFFFFFF, mode.maxRows());
        assertEquals(1, mode.minRows());
        assertEquals(true, mode.isFolding());

        mode = LayoutMode.codeEditorWith(TabSize.defaultValue(), 0, false, language, false, false, new HighlighterCell(), null,
            new DiagnosticSet(Rope.fromStr("")), new AutoClosedPairs(), false, false);
        assertEquals(false, mode.lineNumber());
        assertEquals(false, mode.hasIndentGuides());
        assertEquals(1, mode.minRows());
        assertEquals(false, mode.isFolding());
        assertEquals(false, mode.isAutoClose());
        assertEquals(false, mode.isSmartIndent());
    }

    function testPlain() {
        var mode = LayoutMode.plainTextWith(TabSize.defaultValue(), 5);
        assertEquals(false, mode.lineNumber());
        assertEquals(5, mode.rows());
        assertEquals(0x7FFFFFFF, mode.maxRows());
        assertEquals(1, mode.minRows());

        mode = LayoutMode.plainText();
        assertEquals(false, mode.lineNumber());
        assertEquals(1, mode.rows());
        assertEquals(1, mode.minRows());
    }

    function testAutoGrow() {
        final mode = LayoutMode.autoGrow(2, 5);
        assertEquals(false, mode.lineNumber());
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
