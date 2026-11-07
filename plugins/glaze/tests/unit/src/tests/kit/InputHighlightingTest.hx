// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Hsla;
import glaze.kit.base.input.InputEditorStyle;
import glaze.kit.base.theme.SemanticThemeTokens;
import testing.TestCase;

/**
 * Tests of `glaze.kit.base.input.InputEditorStyle` (Rust `highlighting.rs`).
 */
class InputHighlightingTest extends TestCase {

    static function dark():SemanticThemeTokens {
        final tokens = new SemanticThemeTokens();
        tokens.colors.foreground = new Hsla(0., 0., 0.98, 1.0);
        tokens.colors.mutedForeground = new Hsla(0., 0., 0.64, 1.0);
        tokens.colors.surface = new Hsla(0., 0., 0.04, 1.0);
        tokens.colors.border = new Hsla(0., 0., 0.15, 1.0);
        tokens.colors.accent = new Hsla(0.6, 0.5, 0.5, 1.0);
        return tokens;
    }

    function testAnUnprojectedStyleTakesItsInkFromThePalette() {
        final tokens = dark();
        final resolved = InputEditorStyle.defaultValue().resolved(tokens);

        assertTrue(tokens.colors.foreground.equals(resolved.foreground));
        assertTrue(tokens.colors.foreground.equals(resolved.caret));
        assertTrue(tokens.colors.mutedForeground.equals(resolved.mutedForeground));
        assertTrue(tokens.colors.surface.equals(resolved.background));
        assertTrue(tokens.colors.border.equals(resolved.border));
        // The point of the change: every one of these was transparent, so an
        // input nothing projected onto painted its text in nothing at all.
        for (colour in [resolved.foreground, resolved.caret, resolved.mutedForeground, resolved.selection]) {
            assertTrue(colour.a > 0., '$colour is still invisible');
        }
    }

    function testASelectionStaysTranslucentEnoughToReadThrough() {
        final resolved = InputEditorStyle.defaultValue().resolved(dark());
        assertEquals(0.4, resolved.selection.a);
    }

    function testProjectedColoursAreKeptVerbatim() {
        final chosen = new Hsla(0.3, 0.4, 0.5, 1.0);
        final style = new InputEditorStyle(chosen, null, null, null, null, chosen);
        final resolved = style.resolved(dark());

        assertTrue(chosen.equals(resolved.foreground));
        assertTrue(chosen.equals(resolved.caret));
        // And what was not projected still comes from the palette.
        assertTrue(dark().colors.border.equals(resolved.border));
    }

    function testResolutionNeverConsumesItsOwnOutput() {
        // The projected style is kept verbatim precisely so that this holds:
        // resolving against a second palette must follow it, not stay on the
        // first. Resolving in place would have frozen after one pass.
        final projected = InputEditorStyle.defaultValue();
        final first = projected.resolved(dark());

        final light = new SemanticThemeTokens();
        light.colors.foreground = new Hsla(0., 0., 0.04, 1.0);
        final second = projected.resolved(light);

        assertFalse(first.foreground.equals(second.foreground));
        assertTrue(light.colors.foreground.equals(second.foreground));
    }

}
