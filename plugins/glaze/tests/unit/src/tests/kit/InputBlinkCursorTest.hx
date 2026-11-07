// Ported from gpui-kit 0.8.1: crates/base/src/input/base/blink_cursor.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Entity;
import glaze.kit.base.input.BlinkCursor;
import glaze.kit.base.input.CursorBlink;
import glaze.kit.base.theme.Theme as BaseTheme;

/**
 * Tests of `BlinkCursor` and `CursorBlink` (Rust `blink_cursor.rs`), on the
 * test clock. Durations are in milliseconds here, seconds in the API.
 */
class InputBlinkCursorTest extends KitTestCase {

    static inline final INTERVAL = BlinkCursor.INTERVAL;

    static inline final PAUSE_DELAY = BlinkCursor.PAUSE_DELAY;

    /** `Theme::global_mut(cx).cursor_blink = policy`. */
    function setCursorBlink(policy:CursorBlink, cx:App):Void {
        BaseTheme.globalMut(cx).cursorBlink = policy;
    }

    function newCursor():Entity<BlinkCursor> {
        return app.update(cx -> cx.newEntity(cx -> new BlinkCursor(cx)));
    }

    function visible(cursor:Entity<BlinkCursor>):Bool {
        return cursor.readWith(app, (cursor, _) -> cursor.visible());
    }

    function taskReady(cursor:Entity<BlinkCursor>):Bool {
        return cursor.readWith(app, (cursor, _) -> @:privateAccess cursor._task.isReady);
    }

    function start(cursor:Entity<BlinkCursor>):Void {
        cursor.update(app, (cursor, cx) -> cursor.start(cx));
    }

    function stop(cursor:Entity<BlinkCursor>):Void {
        cursor.update(app, (cursor, cx) -> cursor.stop(cx));
    }

    function pause(cursor:Entity<BlinkCursor>):Void {
        cursor.update(app, (cursor, cx) -> cursor.pause(cx));
    }

    /**
     * The test clock counts seconds in a Float, Rust's in whole nanoseconds:
     * a chain of timers can drift a few ulps past the target of an advance
     * that Rust reaches exactly. Every advance goes 1 ns further, far below
     * the millisecond steps of these tests.
     */
    static inline final CLOCK_SLACK = 1e-9;

    /** Advance the test clock by `seconds`. */
    function advanceBy(seconds:Float):Void {
        runUntilParked();
        dispatcher.advanceClock(seconds + CLOCK_SLACK);
        runUntilParked();
    }

    /** `cx.executor().advance_clock(d)` then `run_until_parked()`. */
    function clock(seconds:Float):Void {
        dispatcher.advanceClock(seconds + CLOCK_SLACK);
        runUntilParked();
    }

    function assertIdle(cursor:Entity<BlinkCursor>, expectedVisible:Bool, ?pos:haxe.PosInfos):Void {
        runUntilParked();
        var notifications = 0;
        final observer = app.update(cx -> cx.observe(cursor, (_, _) -> notifications++));

        advanceBy(3);

        assertEquals(expectedVisible, visible(cursor), null, pos);
        assertTrue(taskReady(cursor), null, pos);
        assertEquals(0, notifications, null, pos);
        observer.dispose();
    }

    function testCursorBlinkBuilder() {
        final policy = CursorBlink.blinking(INTERVAL).withIdleTimeout(5);
        assertEquals(INTERVAL, policy.interval());
        assertEquals(5., policy.idleTimeout());
        assertFalse(policy.isSteady());
        assertTrue(CursorBlink.defaultValue().equals(CursorBlink.blinking(INTERVAL)));

        final steady = CursorBlink.blinking(0).withIdleTimeout(INTERVAL);
        assertTrue(steady.isSteady());
        assertNull(steady.interval());
        assertNull(steady.idleTimeout());
        assertTrue(steady.normalized().equals(CursorBlink.steady()));
    }

    function testRepeatedPausesKeepCursorVisibleUntilIdle() {
        final cursor = newCursor();
        assertFalse(visible(cursor));
        // Only a focused input blinks, and only a blinking cursor pauses.
        start(cursor);
        runUntilParked();
        for (_ in 0...5) {
            pause(cursor);
            runUntilParked();
            clock(0.2);
            assertTrue(visible(cursor));
        }
        clock(0.1);
        assertFalse(visible(cursor));
        clock(INTERVAL);
        assertTrue(visible(cursor));
    }

    function testStartingABlinkingCursorKeepsItVisible() {
        final cursor = newCursor();

        // Clicking into an input starts the cursor from `focus` and again from
        // the focus observer; the second start must not hide the new cursor.
        start(cursor);
        start(cursor);
        runUntilParked();
        assertTrue(visible(cursor));

        // The restart drops the first cycle's timer, so the cursor stays
        // visible for a full interval before it blinks off.
        clock(INTERVAL - 0.001);
        assertTrue(visible(cursor));
        clock(0.001);
        assertFalse(visible(cursor));
    }

    function testPausingACursorThatIsNotBlinkingDoesNotStartIt() {
        // Never focused, so `start` was never called: the epoch is still zero.
        final cursor = newCursor();

        // What a programmatic `set_value` on an unfocused input does.
        pause(cursor);
        runUntilParked();
        clock(PAUSE_DELAY);
        assertFalse(visible(cursor));

        var notifies = 0;
        final observer = app.update(cx -> cx.observe(cursor, (_, _) -> notifies++));
        runUntilParked();

        clock(INTERVAL * 6);

        assertEquals(0, notifies, "a cursor that was never started is blinking, and every blink repaints the view");
        observer.dispose();
    }

    function testBlurringAPausedCursorLeavesTheNextFocusBlinking() {
        final cursor = newCursor();
        start(cursor);
        runUntilParked();

        // Typing pauses the blink, then the input is blurred before the pause
        // elapses: tabbing away right after a keystroke does exactly this.
        pause(cursor);
        runUntilParked();
        stop(cursor);
        runUntilParked();
        assertFalse(visible(cursor));

        // Focusing again shows the cursor and blinks it, rather than leaving a
        // stale pause to swallow the start.
        start(cursor);
        runUntilParked();
        assertTrue(visible(cursor));
        clock(INTERVAL);
        assertFalse(visible(cursor));
    }

    function testStoppingAPausedCursorEndsTheBlinkLoop() {
        final cursor = newCursor();
        start(cursor);
        runUntilParked();
        pause(cursor);
        runUntilParked();
        stop(cursor);
        runUntilParked();

        var notifications = 0;
        final observer = app.update(cx -> cx.observe(cursor, (_, _) -> notifications++));
        runUntilParked();

        clock(3);

        assertFalse(visible(cursor));
        assertEquals(0, notifications, "a stopped cursor kept blinking");
        observer.dispose();

        start(cursor);
        runUntilParked();
        assertTrue(visible(cursor));
    }

    function testStoppingABlinkingCursorEndsTheBlinkLoop() {
        final cursor = newCursor();
        start(cursor);
        runUntilParked();
        stop(cursor);
        runUntilParked();

        var notifications = 0;
        final observer = app.update(cx -> cx.observe(cursor, (_, _) -> notifications++));
        runUntilParked();

        clock(3);

        assertFalse(visible(cursor));
        assertEquals(0, notifications, "a stopped cursor kept blinking");
        observer.dispose();
    }

    function testIdleTimeoutStopsBetweenBlinksAndActivityRestartsIt() {
        app.update(cx -> setCursorBlink(CursorBlink.blinking(INTERVAL).withIdleTimeout(0.75), cx));
        final cursor = newCursor();
        start(cursor);

        advanceBy(INTERVAL);
        assertFalse(visible(cursor));
        advanceBy(0.249);
        assertFalse(visible(cursor));
        advanceBy(0.001);
        assertIdle(cursor, true);

        pause(cursor);
        advanceBy(PAUSE_DELAY);
        assertFalse(visible(cursor));
        advanceBy(0.45);
        assertIdle(cursor, true);

        start(cursor);
        advanceBy(INTERVAL);
        assertFalse(visible(cursor));
    }

    function testIdleTimeoutIncludesTheTypingPause() {
        app.update(cx -> setCursorBlink(CursorBlink.blinking(INTERVAL).withIdleTimeout(0.2), cx));
        final cursor = newCursor();
        start(cursor);
        advanceBy(0.1);
        pause(cursor);
        advanceBy(0.199);
        assertTrue(visible(cursor));
        assertFalse(taskReady(cursor));
        advanceBy(0.001);
        assertIdle(cursor, true);
    }

    function testSteadyAndZeroDurationsNeverScheduleBlinks() {
        for (policy in [CursorBlink.steady(), CursorBlink.blinking(0), CursorBlink.blinking(INTERVAL).withIdleTimeout(0)]) {
            app.update(cx -> setCursorBlink(policy, cx));
            final cursor = newCursor();
            start(cursor);
            assertIdle(cursor, true);
            pause(cursor);
            assertIdle(cursor, true);
        }
    }

    function testPolicyChangesResumeIdleCursorsWithoutResettingActivity() {
        final cursor = newCursor();
        start(cursor);
        advanceBy(INTERVAL);
        assertFalse(visible(cursor));

        app.update(cx -> setCursorBlink(CursorBlink.steady(), cx));
        assertTrue(visible(cursor));
        advanceBy(1);

        app.update(cx -> setCursorBlink(CursorBlink.blinking(0.1).withIdleTimeout(1), cx));
        assertTrue(taskReady(cursor));

        app.update(cx -> setCursorBlink(CursorBlink.blinking(0.1).withIdleTimeout(2), cx));
        advanceBy(0.1);
        assertFalse(visible(cursor));
        advanceBy(0.4);
        assertTrue(visible(cursor));
        assertTrue(taskReady(cursor));

        app.update(cx -> setCursorBlink(CursorBlink.blinking(0.1), cx));
        advanceBy(0.1);
        assertFalse(visible(cursor));
    }

    function testChangingTheIntervalRestartsTheVisiblePhaseAndCancelsOldBlinks() {
        final cursor = newCursor();
        start(cursor);
        advanceBy(0.25);

        app.update(cx -> setCursorBlink(CursorBlink.blinking(1), cx));
        advanceBy(0.25);
        assertTrue(visible(cursor));
        advanceBy(0.749);
        assertTrue(visible(cursor));
        advanceBy(0.001);
        assertFalse(visible(cursor));

        app.update(cx -> setCursorBlink(CursorBlink.steady(), cx));
        assertIdle(cursor, true);
    }

    function testUnchangedPolicyPreservesThePhaseAndIdleDeadline() {
        final policy = CursorBlink.blinking(INTERVAL).withIdleTimeout(0.75);
        app.update(cx -> setCursorBlink(policy, cx));
        final cursor = newCursor();
        start(cursor);
        advanceBy(INTERVAL);
        assertFalse(visible(cursor));

        app.update(cx -> setCursorBlink(policy, cx));
        assertFalse(visible(cursor));
        advanceBy(0.249);
        assertFalse(visible(cursor));
        advanceBy(0.001);
        assertIdle(cursor, true);
    }

    function testUnrelatedThemeChangesPreserveTheBlinkPhaseAndIdleDeadline() {
        app.update(cx -> setCursorBlink(CursorBlink.blinking(INTERVAL).withIdleTimeout(0.75), cx));
        final cursor = newCursor();
        start(cursor);
        advanceBy(INTERVAL);
        assertFalse(visible(cursor));

        app.update(cx -> BaseTheme.globalMut(cx).appearance = Dark);
        assertFalse(visible(cursor));
        advanceBy(0.249);
        assertFalse(visible(cursor));
        advanceBy(0.001);
        assertIdle(cursor, true);
    }

    function testPolicyChangesPreserveTheRemainingTypingPause() {
        final cursor = newCursor();
        start(cursor);
        pause(cursor);
        advanceBy(0.1);

        app.update(cx -> setCursorBlink(CursorBlink.blinking(0.2).withIdleTimeout(0.4), cx));
        advanceBy(0.199);
        assertTrue(visible(cursor));
        advanceBy(0.001);
        assertFalse(visible(cursor));
        advanceBy(0.1);
        assertIdle(cursor, true);
    }

    function testSteadyPolicyCancelsTheTypingPause() {
        final cursor = newCursor();
        start(cursor);
        pause(cursor);
        advanceBy(0.1);
        app.update(cx -> setCursorBlink(CursorBlink.steady(), cx));
        assertIdle(cursor, true);
    }

    function testUnfocusedCursorsIgnorePolicyChanges() {
        final neverFocused = newCursor();
        final blurred = newCursor();
        start(blurred);
        pause(blurred);
        stop(blurred);

        for (policy in [CursorBlink.steady(), CursorBlink.defaultValue()]) {
            app.update(cx -> setCursorBlink(policy, cx));
            assertIdle(neverFocused, false);
            assertIdle(blurred, false);
        }

        start(blurred);
        advanceBy(INTERVAL);
        assertFalse(visible(blurred));
    }

    function testShorteningTheTimeoutStopsAHiddenCursorImmediately() {
        final cursor = newCursor();
        start(cursor);
        advanceBy(INTERVAL);
        assertFalse(visible(cursor));

        app.update(cx -> setCursorBlink(CursorBlink.blinking(INTERVAL).withIdleTimeout(0.4), cx));
        assertIdle(cursor, true);
    }

    function testInitializationPreservesAnApplicationPolicy() {
        app.update(cx -> setCursorBlink(CursorBlink.steady(), cx));
        // `cx.update(crate::init)`: the Base init does not reset the policy.
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final cursor = newCursor();
        start(cursor);
        assertIdle(cursor, true);
    }

}
