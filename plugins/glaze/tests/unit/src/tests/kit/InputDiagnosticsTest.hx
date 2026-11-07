// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Range;
import glaze.kit.base.input.Diagnostic;
import glaze.kit.base.input.DiagnosticSet;
import glaze.kit.base.input.DiagnosticSeverity;
import glaze.kit.base.input.LspPosition;
import ropey.Rope;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.DiagnosticSet` (Rust `diagnostics.rs`).
 */
class InputDiagnosticsTest extends TestCase {

    function testDiagnostic() {
        final text = Rope.fromStr("Hello, 你好warld!\nThis is a test.\nGoodbye, world!");
        final diagnostics = new DiagnosticSet(text);

        diagnostics.push(new Diagnostic(new LspPosition(0, 7), new LspPosition(0, 17), "Spelling mistake").withSeverity(DiagnosticSeverity.Warning));
        diagnostics.push(new Diagnostic(new LspPosition(2, 9), new LspPosition(2, 14), "Syntax error").withSeverity(DiagnosticSeverity.Error));

        assertEquals(2, diagnostics.len());
        final items = diagnostics.iter().copy();

        assertEquals("Spelling mistake", items[0].message);
        assertTrue(new Range(7, 19).equals(items[0].range));

        assertEquals("Syntax error", items[1].message);
        assertTrue(new Range(45, 50).equals(items[1].range));

        assertEquals(2, diagnostics.range(new Range(6, 48)).length);

        final item = diagnostics.forOffset(10);
        assertEquals("Spelling mistake", item.message);

        assertNull(diagnostics.forOffset(30));

        final item = diagnostics.forOffset(46);
        assertEquals("Syntax error", item.message);

        diagnostics.push(new Diagnostic(new LspPosition(1, 5), new LspPosition(1, 7), "Info message").withSeverity(DiagnosticSeverity.Info));
        assertEquals(3, diagnostics.len());

        diagnostics.clear();
        assertEquals(0, diagnostics.len());
    }

}
