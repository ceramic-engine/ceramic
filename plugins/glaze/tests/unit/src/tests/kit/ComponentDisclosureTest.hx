// Ported from gpui-kit 0.8.1: crates/component/src/accordion.rs and collapsible.rs (tests),
// crates/kit/tests/integration/disclosure.rs (the accordion and stepper tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.Point;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.accordion.Accordion;
import glaze.kit.collapsible.Collapsible;
import glaze.kit.stepper.Stepper;
import glaze.kit.stepper.StepperItem;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `accordion.rs` and
 * `collapsible.rs`, and the accordion and stepper tests of gpui-kit's
 * `integration/disclosure.rs`.
 *
 * `debug_selector` / `debug_bounds` become `DebugProbe`s around the queried
 * elements. The integration tests find triggers by id and read their
 * accesskit `expanded` state; here the probes wrap the titles and labels
 * (inside the triggers, so clicking their center activates the trigger), and
 * the expanded state is the one the view renders, which the accordion's
 * `onToggleClick` keeps (what `expanded` reflects after the frame).
 */
class ComponentDisclosureTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, width:Float = 1920, height:Float = 1080):{cx:VisualTestContext, view:Entity<ScriptView>} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return {cx: opened.cx, view: opened.view};
    }

    function notify(view:Entity<ScriptView>):Void {
        app.update(cx -> view.update(cx, (_, cx) -> cx.notify()));
    }

    /** Draws the window again and returns the bounds `selector` got (null when not rendered). */
    static function draw(cx:VisualTestContext, selector:String):Null<Bounds> {
        DebugProbe.clear();
        cx.update((window, _) -> window.draw());
        return DebugProbe.bounds(selector);
    }

    static function clickCenter(cx:VisualTestContext, selector:String):Void {
        final bounds = DebugProbe.bounds(selector);
        cx.simulateClick(bounds.center());
    }

    /// accordion.rs

    function testExpandedPanelKeepsContentBetweenItsHeaderAndTheNextItem() {
        final h = open((_, _) -> Accordion.component('accordion-layout')
            .w(px(240.))
            .h(px(100.))
            .item(item -> item.open(true)
                .title(new DebugProbe('first-title', div().child('First')))
                .child(new DebugProbe('first-content', div().h(px(60.)))))
            .item(item -> item.title(new DebugProbe('second-title', div().child('Second')))));
        draw(h.cx, 'first-title');

        final first = DebugProbe.bounds('first-title');
        final content = DebugProbe.bounds('first-content');
        final second = DebugProbe.bounds('second-title');
        assertTrue(first.origin.y < content.origin.y);
        assertTrue(content.origin.y + content.size.height <= second.origin.y);
    }

    function testSettledClosedPanelUnmountsItsContent() {
        final state = {open: false};
        final h = open((_, _) -> Accordion.component('accordion-toggle')
            .w(px(240.))
            .item(item -> item.open(state.open)
                .title('Item')
                .child(new DebugProbe('toggle-content', div().h(px(60.)))))
            .item(item -> item.title('Next')));
        final contentHeight = () -> {
            final bounds = draw(h.cx, 'toggle-content');
            return bounds != null ? bounds.size.height : null;
        };
        assertNull(contentHeight());

        state.open = true;
        notify(h.view);
        assertEquals(60., contentHeight());
        for (_ in 0...100) {
            h.cx.advanceClock(0.016);
            assertEquals(60., contentHeight());
        }

        // The closing reveal keeps the content until the spring settles.
        state.open = false;
        notify(h.view);
        var closingFrames = 0;
        while (contentHeight() != null) {
            closingFrames++;
            assertTrue(closingFrames < 100, 'closed content stayed mounted');
            if (closingFrames >= 100) break;
            h.cx.advanceClock(0.016);
        }
        assertTrue(closingFrames > 1, 'content unmounted before the reveal ran');
    }

    /// collapsible.rs

    function collapsibleHarness(isOpen:Bool):VisualTestContext {
        return open((_, _) -> Collapsible.component()
            .open(isOpen)
            .child(new DebugProbe('collapsible-trigger', div().size(px(10.))))
            .content(new DebugProbe('collapsible-content', div().size(px(10.))))).cx;
    }

    function testFacadePreservesVerticalLayoutAndVisibility() {
        draw(collapsibleHarness(true), 'collapsible-trigger');
        final trigger = DebugProbe.bounds('collapsible-trigger');
        final content = DebugProbe.bounds('collapsible-content');
        assertTrue(trigger.origin.y < content.origin.y);

        draw(collapsibleHarness(false), 'collapsible-trigger');
        assertNotNull(DebugProbe.bounds('collapsible-trigger'));
        assertNull(DebugProbe.bounds('collapsible-content'));
    }

    function testMotionIdKeepsClosedContentMountedForReversibleReveal() {
        final cx = open((_, _) -> Collapsible.component()
            .motionId('details-motion')
            .open(false)
            .content(new DebugProbe('motion-content', div().size(px(10.))))).cx;
        assertNotNull(draw(cx, 'motion-content'));
    }

    /// integration/disclosure.rs (the slider steps are ported with the slider)

    function settings(disabled:Bool, advancedDisabled:Bool):{cx:VisualTestContext, view:Entity<ScriptView>, state:{open:Array<Int>, step:Int, disabled:Bool, advancedDisabled:Bool}} {
        final state = {open: [], step: 0, disabled: disabled, advancedDisabled: advancedDisabled};
        var view:Null<Entity<ScriptView>> = null;
        final h = open((_, _) -> div()
            .sizeFull()
            .flex()
            .flexCol()
            .p4()
            .gap4()
            .child(new DebugProbe('sections', Accordion.component('sections')
                .hAuto()
                .disabled(state.disabled)
                .item(item -> item.title(new DebugProbe('trigger-0', 'General'))
                    .open(state.open.indexOf(0) != -1)
                    .child(div().h12().child('General options')))
                .item(item -> item.title(new DebugProbe('trigger-1', 'Advanced'))
                    .disabled(state.advancedDisabled)
                    .open(state.open.indexOf(1) != -1)
                    .child(new DebugProbe('panel-1', div().h12().child('Advanced options'))))
                .onToggleClick((open, _, cx) -> {
                    state.open = open.copy();
                    view.update(cx, (_, cx) -> cx.notify());
                })))
            .child(Stepper.component('wizard')
                .selectedIndex(state.step)
                .disabled(state.disabled)
                .items([
                    StepperItem.component().child(new DebugProbe('step-0', 'Account')),
                    StepperItem.component().child(new DebugProbe('step-1', 'Review')),
                ])
                .onClick((step, _, cx) -> {
                    state.step = step;
                    view.update(cx, (_, cx) -> cx.notify());
                }))
            .child(div()
                .id('step-content')
                .child(state.step == 0
                    ? new DebugProbe('account', div().id('account').child('Account'))
                    : new DebugProbe('review', div().id('review').child('Review')))),
            640., 600.);
        view = h.view;
        draw(h.cx, 'sections');
        return {cx: h.cx, view: h.view, state: state};
    }

    function testAccordionExpandsOnePanelAndStepperNavigates() {
        app.setReduceMotion(true);
        final s = settings(false, false);
        final closedHeight = DebugProbe.bounds('sections').size.height;
        clickCenter(s.cx, 'trigger-0');
        draw(s.cx, 'sections');
        assertEquals('0', s.state.open.join(','));
        clickCenter(s.cx, 'trigger-1');
        draw(s.cx, 'sections');
        assertEquals('1', s.state.open.join(','));
        assertTrue(DebugProbe.bounds('sections').size.height > closedHeight);
        assertTrue(DebugProbe.bounds('panel-1').size.height > 0.);
        clickCenter(s.cx, 'trigger-1');
        draw(s.cx, 'sections');
        assertEquals(closedHeight, DebugProbe.bounds('sections').size.height);
        clickCenter(s.cx, 'step-1');
        draw(s.cx, 'sections');
        assertNull(DebugProbe.bounds('account'));
        assertNotNull(DebugProbe.bounds('review'));
        clickCenter(s.cx, 'step-0');
        draw(s.cx, 'sections');
        assertNotNull(DebugProbe.bounds('account'));
    }

    function testDisabledDisclosuresAndStepsDoNotChangeContent() {
        final s = settings(true, false);
        clickCenter(s.cx, 'trigger-0');
        draw(s.cx, 'sections');
        assertEquals(0, s.state.open.length);
        clickCenter(s.cx, 'step-1');
        draw(s.cx, 'sections');
        assertNotNull(DebugProbe.bounds('account'));
        assertNull(DebugProbe.bounds('review'));
    }

    function testAccordionPreservesDisabledItemsWhenTheGroupIsEnabled() {
        app.setReduceMotion(true);
        final s = settings(false, true);
        for (groupDisabled in [false, true, false]) {
            s.state.disabled = groupDisabled;
            s.state.open = [];
            notify(s.view);
            draw(s.cx, 'sections');
            clickCenter(s.cx, 'trigger-1');
            draw(s.cx, 'sections');
            assertEquals(-1, s.state.open.indexOf(1));
            assertEquals(0, s.state.open.length);

            clickCenter(s.cx, 'trigger-0');
            draw(s.cx, 'sections');
            assertEquals(!groupDisabled, s.state.open.indexOf(0) != -1);
        }
    }

}
