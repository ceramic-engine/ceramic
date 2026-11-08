// Ported from gpui-kit 0.8.1: crates/base/src/root.rs (tests), crates/base/src/styled.rs (tests),
// crates/kit/tests/integration/root.rs (Base parts)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.Root;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.FocusTrap;
using glaze.kit.base.StyledExt;

/**
 * The tests of gpui-base's `root.rs` (focus trap navigation, plugins) and
 * `styled.rs` (h_flex / v_flex cross axis), and the Base parts of
 * `kit/tests/integration/root.rs`.
 *
 * Not ported: `focus_trap.rs`'s accessibility test (no accesskit in the
 * port), the root tests that open dialogs, sheets and notifications (they
 * come with those components).
 */
class BaseRootTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    var extra:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        for (other in extra) other.destroy();
        extra = [];
        ceramic.App.app.flushImmediate();
    }

    function trapHarness(controlCount:Int):TrapHarness {
        app.update(cx -> Base.init(cx));
        final container = app.focusHandle();
        final controls = [for (_ in 0...controlCount) app.focusHandle().tabStop(true)];
        // Regression: traversing past the modal must cross more than the
        // former 100-attempt limit before reaching its other end.
        final background = [for (_ in 0...256) app.focusHandle().tabStop(true)];
        final harness = new TrapHarness(container, controls, background);
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
            final content:Entity<TrapContent> = rootCx.newEntity((contentCx:Context<TrapContent>) -> {
                for (handle in background) {
                    contentCx.onFocus(handle, window, (_, _, _) -> harness.backgroundFocuses++).detach();
                }
                return new TrapContent(background, container, controls);
            });
            return content;
        });
        cx = opened.cx;
        cx.update((window, _) -> window.setActive(true));
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        return harness;
    }

    function dispatch(action:glaze.Action):Void {
        cx.update((window, app) -> window.dispatchAction(action, app));
        cx.runUntilParked();
    }

    function assertTrappedFocus(container:FocusHandle, expected:FocusHandle, ?pos:haxe.PosInfos):Void {
        cx.update((window, app) -> {
            window.draw();
            assertTrue(window.focused(app) == expected, 'focused', pos);
            assertTrue(container.containsFocused(window, app), 'contained', pos);
        });
    }

    function testFocusTrapWrapsForwardPastMoreThan100BackgroundStops() {
        final h = trapHarness(2);
        cx.update((window, app) -> {
            h.controls[1].focus(window, app);
            window.draw();
        });
        dispatch(new Tab());
        assertTrappedFocus(h.container, h.controls[0]);
        dispatch(new Tab());
        assertTrappedFocus(h.container, h.controls[1]);
        assertEquals(0, h.backgroundFocuses);
    }

    function testFocusTrapWrapsBackwardPastMoreThan100BackgroundStops() {
        final h = trapHarness(2);
        cx.update((window, app) -> {
            h.controls[0].focus(window, app);
            window.draw();
        });
        dispatch(new TabPrev());
        assertTrappedFocus(h.container, h.controls[1]);
        dispatch(new TabPrev());
        assertTrappedFocus(h.container, h.controls[0]);
        assertEquals(0, h.backgroundFocuses);
    }

    function testFocusTrapWithoutTabStopsKeepsItsContainerFocused() {
        final h = trapHarness(0);
        cx.update((window, app) -> {
            h.container.focus(window, app);
            window.draw();
        });
        dispatch(new Tab());
        assertTrappedFocus(h.container, h.container);
        dispatch(new TabPrev());
        assertTrappedFocus(h.container, h.container);
        assertEquals(0, h.backgroundFocuses);
    }

    function testFocusTrapSearchEndsAtAShortCycleOnItsContainer() {
        final h = trapHarness(2);
        cx.update((window, app) -> {
            h.controls[0].focus(window, app);
            window.draw();
        });
        // A tab order in which the second stop is its own neighbor never
        // returns to the first. Popped from the end: first, second, second.
        final first = h.background[0];
        final second = h.background[1];
        final scripted = [second, second, first];
        cx.update((window, app) -> Root.advanceFocus(window, app, (window, app) -> {
            final next = scripted.pop();
            if (next == null)
                throw 'the search kept advancing after a stop repeated';
            next.focus(window, app);
        }));
        assertTrappedFocus(h.container, h.container);
        assertEquals(0, scripted.length);
    }

    function testInactiveFocusTrapDoesNotCaptureBackgroundNavigation() {
        final h = trapHarness(2);
        cx.update((window, app) -> {
            h.background[0].focus(window, app);
            window.draw();
        });
        cx.runUntilParked();
        // The observers used by the containment regressions really receive
        // focus notifications when a background control is used.
        assertEquals(1, h.backgroundFocuses);

        dispatch(new Tab());
        cx.update((window, app) -> {
            window.draw();
            assertTrue(window.focused(app) == h.background[1]);
        });
        dispatch(new TabPrev());
        cx.update((window, app) -> {
            window.draw();
            assertTrue(window.focused(app) == h.background[0]);
        });
        cx.runUntilParked();
        assertEquals(3, h.backgroundFocuses);
    }

    function testPluginRegistrationIsIdempotentAndStateIsPerWindow() {
        app.update(cx -> {
            Base.init(cx);
            Root.registerPlugin(cx, Layer, (_, _) -> new Layer());
            Root.registerPlugin(cx, Layer, (_, _) -> new Layer());
        });
        final ids:Array<Int> = [];
        for (_ in 0...2) {
            final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
                final content:Entity<Content> = rootCx.newEntity((_:Context<Content>) -> new Content());
                return content;
            });
            extra.push(opened.cx);
            final root = Root.read(opened.cx.window, app);
            // The kit, initialized by the root, adds its own plugin
            assertEquals(1, root.plugins.filter(p -> Std.isOfType(p, Layer)).length);
            ids.push(root.plugin(Layer).entityId);
        }
        assertTrue(ids[0] != ids[1]);
    }

    function testNestedTrapsKeepTheInnermostScopeAcrossCloseAndReopen() {
        app.update(cx -> Base.init(cx));
        final containers = [for (_ in 0...6) app.focusHandle()];
        final controls = [for (_ in 0...6) [app.focusHandle().tabStop(true), app.focusHandle().tabStop(true)]];
        var nested:Null<Entity<NestedTraps>> = null;
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
            nested = rootCx.newEntity((_:Context<NestedTraps>) -> new NestedTraps(containers, controls, 6));
            return nested;
        });
        cx = opened.cx;
        // Retain every container handle while inner scopes disappear and
        // return. Rendered containment, not registration order or ownership
        // lifetime, must decide which remaining scope handles Tab.
        for (depth in [6, 5, 4, 3, 2, 1, 2, 3, 4, 5, 6]) {
            nested.update(app, (view, viewCx) -> {
                view.depth = depth;
                viewCx.notify();
            });
            final index = depth - 1;
            cx.update((window, app) -> {
                controls[index][1].focus(window, app);
                window.draw();
            });
            dispatch(new Tab());
            assertTrappedFocus(containers[index], controls[index][0]);
            dispatch(new TabPrev());
            assertTrappedFocus(containers[index], controls[index][1]);
        }
    }

    /**
     * `h_flex` centers on the cross axis while `v_flex` leaves the default
     * stretch.
     */
    function testHFlexCentersAndVFlexStretchesOnTheCrossAxis() {
        final bounds = new Map<String, Bounds>();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<CrossAxisTest>) -> new CrossAxisTest(bounds));
        cx = opened.cx;
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());

        // A shorter child of a 100px row sits at (100 - 40) / 2, not at the top,
        // and a height-less child keeps its content height instead of filling.
        assertEquals(30., bounds.get('row-child').top());
        assertEquals(0., bounds.get('row-stretch').size.height);
        // A child taller than the row is centered too.
        assertEquals(-20., bounds.get('row-overflowing-child').top());
        // A width-less child of a column does fill the cross axis.
        assertEquals(200., bounds.get('col-stretch').size.width);
    }

    /**
     * kit/tests/integration/root.rs: `initialization_leaves_quit_and_close_shortcuts_to_the_application`
     * (Base part).
     */
    function testInitializationLeavesQuitAndCloseShortcutsToTheApplication() {
        app.update(cx -> {
            Base.init(cx);
            for (shortcut in ['cmd-q', 'cmd-w', 'alt-f4']) {
                assertEquals(0, cx.allBindingsForInput([Keystroke.parse(shortcut)]).length, shortcut);
            }
        });
    }

    /**
     * kit/tests/integration/root.rs: `base_startup_keeps_the_same_root_even_when_component_is_compiled`.
     */
    function testBaseStartupKeepsTheContentViewOfItsRoot() {
        app.update(cx -> Base.init(cx));
        var content:Null<Entity<Content>> = null;
        final opened = VisualTestContext.addWindowRoot(app, dispatcher, (window, rootCx) -> {
            content = rootCx.newEntity((_:Context<Content>) -> new Content());
            return content;
        });
        cx = opened.cx;
        final root = Root.read(cx.window, app);
        assertEquals(content.entityId(), root.contentView().entityId());
    }

}

private class TrapHarness {

    public final container:FocusHandle;

    public final controls:Array<FocusHandle>;

    public final background:Array<FocusHandle>;

    public var backgroundFocuses:Int = 0;

    public function new(container:FocusHandle, controls:Array<FocusHandle>, background:Array<FocusHandle>) {
        this.container = container;
        this.controls = controls;
        this.background = background;
    }

}

private class TrapContent extends Model implements Render {

    final background:Array<FocusHandle>;

    final container:FocusHandle;

    final controls:Array<FocusHandle>;

    public function new(background:Array<FocusHandle>, container:FocusHandle, controls:Array<FocusHandle>) {
        super();
        this.background = background;
        this.container = container;
        this.controls = controls;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .tabGroup()
            .sizeFull()
            .children([for (index in 0...background.length) div()
                .id(glaze.ElementId.NamedInteger('background', index))
                .trackFocus(background[index])
                .tabIndex(0)
                .size(px(1.))
            ])
            .child(
                div()
                    .id('trap')
                    .trackFocus(container)
                    .tabStop(false)
                    .children([for (index in 0...controls.length) div()
                        .id(glaze.ElementId.NamedInteger('control', index))
                        .trackFocus(controls[index])
                        .tabIndex(0)
                        .size(px(1.))
                    ])
                    .focusTrap('modal', container)
            );
    }

}

private class Content extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

private class Layer extends glaze.kit.base.Root.RootPlugin {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

private class NestedTraps extends Model implements Render {

    final containers:Array<FocusHandle>;

    final controls:Array<Array<FocusHandle>>;

    public var depth:Int;

    public function new(containers:Array<FocusHandle>, controls:Array<Array<FocusHandle>>, depth:Int) {
        super();
        this.containers = containers;
        this.controls = controls;
        this.depth = depth;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var child:AnyElement = div().intoAnyElement();
        var index = depth - 1;
        while (index >= 0) {
            final control = (side:Int) -> div()
                .id(glaze.ElementId.NamedInteger('nested-control', index * 2 + side))
                .trackFocus(controls[index][side])
                .tabIndex(0)
                .size(px(10.));
            child = div()
                .tabStop(false)
                .child(control(0))
                .child(child)
                .child(control(1))
                .focusTrap(glaze.ElementId.NamedInteger('nested-trap', index), containers[index])
                .intoAnyElement();
            index--;
        }
        return div().tabGroup().sizeFull().child(child);
    }

}

private class CrossAxisTest extends Model implements Render {

    final bounds:Map<String, Bounds>;

    public function new(bounds:Map<String, Bounds>) {
        super();
        this.bounds = bounds;
    }

    function column(selector:String, height:Float):glaze.Div {
        return div()
            .w(px(20.))
            .h(px(height))
            .flexShrink0()
            .onPrepaint((b, _, _) -> bounds.set(selector, b));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .w(px(200.))
            .h(px(100.))
            .child(
                glaze.kit.base.Prelude.hFlex()
                    .sizeFull()
                    .child(column('row-child', 40.))
                    .child(column('row-overflowing-child', 140.))
                    .child(div().w(px(20.)).onPrepaint((b, _, _) -> bounds.set('row-stretch', b)))
            )
            .child(
                glaze.kit.base.Prelude.vFlex().sizeFull().child(div().h(px(20.)).onPrepaint((b, _, _) -> bounds.set('col-stretch', b)))
            );
    }

}
