// Ported from gpui-kit 0.8.1: crates/base/src/reduce_motion.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.base.ReduceMotion;

/**
 * Tests of `glaze.kit.base.ReduceMotion` (Rust `reduce_motion.rs`).
 */
class ReduceMotionTest extends KitTestCase {

    function testASystemPreferenceForReducedMotionSetsTheFlag() {
        app.update(cx -> {
            ReduceMotion.applyPreference(true, cx);
            assertTrue(cx.reduceMotion());
        });
    }

    function testAnUnknownSystemPreferenceLeavesTheFlagAlone() {
        app.update(cx -> {
            ReduceMotion.applyPreference(null, cx);
            assertFalse(cx.reduceMotion());

            cx.setReduceMotion(true);
            ReduceMotion.applyPreference(null, cx);
            assertTrue(cx.reduceMotion());
        });
    }

    function testTheSystemDrivesTheFlagUntilTheApplicationSetsIt() {
        app.update(cx -> {
            ReduceMotion.applyPreference(true, cx);
            ReduceMotion.applyPreference(false, cx);
            assertFalse(cx.reduceMotion());
            ReduceMotion.applyPreference(true, cx);
            assertTrue(cx.reduceMotion());

            cx.setReduceMotion(false);
            ReduceMotion.applyPreference(true, cx);
            assertFalse(cx.reduceMotion());
        });
    }

    function testTheTestSchedulerIsNeverAskedForThePlatformPreference() {
        final previous = ReduceMotion.systemPreference;
        var asked = false;
        ReduceMotion.systemPreference = () -> {
            asked = true;
            return true;
        };
        app.update(cx -> {
            ReduceMotion.applySystemReduceMotion(cx);
            assertFalse(cx.reduceMotion());
        });
        runUntilParked();
        app.update(cx -> assertFalse(cx.reduceMotion()));
        assertFalse(asked);
        ReduceMotion.systemPreference = previous;
    }

    function testAFlagTheApplicationSetBeforeTheFirstReadingIsKept() {
        app.update(cx -> {
            cx.setReduceMotion(true);
            ReduceMotion.applyPreference(false, cx);
            assertTrue(cx.reduceMotion());
        });
    }

}
