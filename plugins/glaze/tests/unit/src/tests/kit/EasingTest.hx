// Ported from gpui-kit 0.8.1: crates/base/src/motion/easing.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.motion.Easing;
import testing.TestCase;

/**
 * Tests of `gpui.base.motion.Easing` errors (Rust `motion/easing.rs`).
 */
class EasingTest extends TestCase {

    function testBezierErrorsNameTheInvalidControlPoint() {
        var error:Null<EasingError> = null;
        try {
            Easing.cubicBezier(0.2, Math.NaN, 0.8, 1.0);
        }
        catch (e:EasingError) {
            error = e;
        }

        assertEquals(InvalidBezierControlPoint, error);
        assertEquals('cubic Bézier control points must be finite and x must be within 0..=1', error.message());
    }

}
