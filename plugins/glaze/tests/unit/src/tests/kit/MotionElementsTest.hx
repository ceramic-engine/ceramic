// Ported from gpui-kit 0.8.1: crates/base/src/animation.rs, crates/base/src/motion/reveal.rs (sanity tests added by the port)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.animation.EffectTransition;
import glaze.kit.base.motion.MotionReveal;

import glaze.Prelude.*;

class RecordingDiv extends Div {

    public static var recorded:Null<Bounds> = null;

    public function new() {
        super();
    }

    override public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        recorded = bounds;
        super.prepaint(id, bounds, window, cx);
    }

}

class RecordingReveal extends MotionReveal {

    public static var recorded:Null<Bounds> = null;

    override public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        recorded = bounds;
        super.prepaint(id, bounds, window, cx);
    }

}

class EffectTransitionView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().child(new EffectTransition(0.1).ease(t -> t).width(px(0), px(100)).height(px(10), px(10)).apply(new RecordingDiv(), 'grow'));
    }

}

class MotionRevealView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().flex().flexCol().child(new RecordingReveal('reveal', 0.5, div().h(px(40))));
    }

}

/**
 * Sanity tests of the motion elements that Rust does not test on their own:
 * `EffectTransition.apply` and `MotionReveal`.
 */
class MotionElementsTest extends KitTestCase {

    function testEffectTransitionAnimatesItsEffects() {
        RecordingDiv.recorded = null;
        final opened = openWindow(_ -> new EffectTransitionView());
        assertEquals(0.0, RecordingDiv.recorded.size.width);
        assertEquals(10.0, RecordingDiv.recorded.size.height);

        advanceClock(50);
        assertEquals(1, simulateNextFrame(opened.window));
        assertEquals(50.0, RecordingDiv.recorded.size.width);

        advanceClock(100);
        simulateNextFrame(opened.window);
        assertEquals(100.0, RecordingDiv.recorded.size.width);
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testMotionRevealShowsItsProgressOfTheMeasuredHeight() {
        RecordingReveal.recorded = null;
        final opened = openWindow(_ -> new MotionRevealView());
        assertEquals(100.0, RecordingReveal.recorded.size.width);

        // The first frame measures the child and asks for another one.
        assertEquals(1, simulateNextFrame(opened.window));
        assertEquals(20.0, RecordingReveal.recorded.size.height);
        assertEquals(0, simulateNextFrame(opened.window));
    }

}
