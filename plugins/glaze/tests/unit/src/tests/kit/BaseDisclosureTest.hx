// Ported from gpui-kit 0.8.1: crates/base/src/accordion.rs and collapsible.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Point;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Accordion.AccordionHeader;
import gpui.base.Accordion.AccordionPanel;
import gpui.base.Accordion.AccordionTrigger;
import gpui.base.BaseCollapsible;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The tests of gpui-base's `accordion.rs` and `collapsible.rs`.
 *
 * The accessibility tests read the `A11y` data the parts export (the port
 * has no accesskit tree). `debug_bounds` lookups use `DebugProbe`.
 */
class BaseDisclosureTest extends TestCase {

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

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    /// accordion.rs

    function testTriggerProjectsExpandedAccessibilityState() {
        final requested:Array<Bool> = [];
        final trigger = new AccordionTrigger('trigger')
            .open(true)
            .onChange((open, _, _, _) -> requested.push(open));
        open((_, _) -> div().child(trigger));

        assertEquals(Role.Button, trigger.a11y.role);
        assertEquals(true, trigger.a11y.expanded);

        assertEquals(0, requested.length);
    }

    function harness(open:Bool, disabled:Bool):{cx:VisualTestContext, requested:Array<Bool>} {
        final requested:Array<Bool> = [];
        final cx = this.open((_, _) -> new AccordionTrigger('trigger')
            .open(open)
            .disabled(disabled)
            .size(px(100.))
            .onChange((open, _, _, _) -> requested.push(open)));
        return {cx: cx, requested: requested};
    }

    function testPointerRequestsNextControlledStateAndRespectsDisabled() {
        final h = harness(false, false);
        h.cx.simulateClick(new Point(10., 10.));
        assertEquals('true', h.requested.join(','));

        final h = harness(true, true);
        h.cx.simulateClick(new Point(10., 10.));
        assertEquals(0, h.requested.length);
    }

    function testHeaderAndPanelProjectStructuralRoles() {
        final header = new AccordionHeader(new AccordionTrigger('trigger'))
            .id('header')
            .level(2);
        final panel = new AccordionPanel()
            .id('panel')
            .open(true);
        open((_, _) -> div().child(header).child(panel));

        assertEquals(Role.Heading, header.a11y.role);
        assertEquals(2, header.a11y.level);
        assertEquals(Role.Region, panel.a11y.role);
    }

    /// collapsible.rs

    function collapsibleHarness(isOpen:Bool):VisualTestContext {
        return open((_, _) -> new BaseCollapsible()
            .open(isOpen)
            .child(new DebugProbe('trigger', div().size(px(10.))))
            .content(new DebugProbe('content', div().size(px(10.)))));
    }

    function testContentIsOnlyRenderedWhileOpen() {
        collapsibleHarness(false);
        assertNotNull(DebugProbe.bounds('trigger'));
        assertNull(DebugProbe.bounds('content'));

        DebugProbe.clear();
        collapsibleHarness(true);
        assertNotNull(DebugProbe.bounds('trigger'));
        assertNotNull(DebugProbe.bounds('content'));
    }

}
