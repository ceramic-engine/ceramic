// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mod.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.StyleRefinement;
import gpui.base.input.InputBase;
import gpui.base.input.InputContextMenuCapabilities;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests of `InputBase` and `InputContextMenuCapabilities` (Rust
 * `input/base/mod.rs`, with its doc example).
 */
class InputBaseTest extends TestCase {

    static function opacityOf(style:StyleRefinement):Null<Float> {
        return style.has(StyleRefinement.OPACITY) ? style.opacity : null;
    }

    function testFrameAcceptsApplicationOwnedContentAndStyle() {
        final frame = new InputBase('input')
            .focused(true)
            .disabled(false)
            .styles(styles -> styles
                .focused(style -> style.border1())
                .disabled(style -> style.opacity(0.5)))
            .child('value')
            .opacity(0.8);
        assertNotNull(frame);
    }

    function testSemanticStateStylesOverrideTheNormalStyle() {
        final focused = new InputBase('focused')
            .focused(true)
            .borderColor(red())
            .styles(styles -> styles.focused(style -> style.borderColor(blue())));
        assertTrue(blue().equals(focused.resolvedStyle().borderColor));

        final disabled = new InputBase('disabled')
            .focused(true)
            .disabled(true)
            .opacity(1.)
            .styles(styles -> styles
                .focused(style -> style.opacity(0.8))
                .disabled(style -> style.opacity(0.5)));
        assertFloatEquals(0.5, opacityOf(disabled.resolvedStyle()));
    }

    function testContextMenuCapabilitiesDocExample() {
        final capabilities = new InputContextMenuCapabilities()
            .codeEditor(true)
            .selection(true);

        assertTrue(capabilities.isEditable());
        assertTrue(capabilities.hasSelection());
    }

}
