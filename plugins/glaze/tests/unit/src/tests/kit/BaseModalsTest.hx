// Ported from gpui-kit 0.8.1: crates/base/src/dialog.rs (tests), crates/base/src/alert_dialog.rs (tests),
// crates/base/src/sheet.rs (tests), crates/base/src/toast.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Element;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.LayoutId;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.AlertDialog;
import glaze.kit.base.Base;
import glaze.kit.base.Dialog;
import glaze.kit.base.Sheet;
import glaze.kit.base.Toast;
import glaze.kit.base.FocusTrap;
import glaze.kit.base.Actions.Cancel;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The tests of gpui-base's `dialog.rs`, `alert_dialog.rs`, `sheet.rs` and
 * `toast.rs`.
 *
 * Rust reads element bounds through `debug_selector` / `debug_bounds`; the
 * port records them with a `BoundsProbe` wrapping the same element. The
 * accessibility test of `DialogClose` reads the button's `a11y` (the port
 * has no accesskit tree).
 */
class BaseModalsTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        BoundsProbe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        BoundsProbe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new RenderView(render));
        contexts.push(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static function debugBounds(selector:String):Null<Bounds> {
        return BoundsProbe.bounds.get(selector);
    }

// dialog.rs

    function testCloseTriggerSuppliesAccessibleButton() {
        var captured:Null<glaze.kit.base.Button> = null;
        final cx = open((window, cx) -> {
            new DialogClose().trigger(button -> {
                button.render(window, cx.app);
                captured = button;
                return button;
            });
            return div();
        });
        draw(cx);
        assertTrue(captured != null);
        assertEquals(glaze.kit.base.A11y.Role.Button, captured.a11y.role);
        assertEquals('Close', captured.a11y.label);
        assertTrue(captured.a11y.clickable);
    }

    function testCloseTriggerActivatesOnceAndRespectsCancelVeto() {
        app.update(cx -> Base.init(cx));
        final handle = new DialogHandle(true);
        var attempts = 0;
        final focus = app.focusHandle();
        final buttonFocus = app.focusHandle();
        final cx = open((_, cx) -> new Dialog(cx.app)
            .handle(handle)
            .focusHandle(focus)
            .onCancel((_, _, _) -> {
                attempts++;
                return attempts > 1;
            })
            .popup(new DialogClose().trigger(button -> button.size(px(100.)).trackFocus(buttonFocus))));
        final viewport = cx.update((window, cx) -> {
            focus.focus(window, cx);
            window.draw();
            return window.viewportSize();
        });
        final popupCenter = new Point(viewport.width / 2., viewport.height / 2.);
        cx.simulateClick(popupCenter);
        cx.runUntilParked();
        assertEquals(1, attempts);
        assertTrue(handle.isOpen(), 'on_cancel can veto pointer dismissal');

        cx.update((window, cx) -> {
            buttonFocus.focus(window, cx);
            window.draw();
        });
        final keystroke = Keystroke.parse('space');
        cx.simulateEvent(new KeyDownEvent(keystroke, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
        cx.runUntilParked();
        assertEquals(2, attempts);
        assertTrue(!handle.isOpen(), 'Space uses the same cancel decision');
    }

    function testTriggerOpensSharedHandleAndReportsReason() {
        final handle = new DialogHandle(false);
        final changes:Array<String> = [];
        @:privateAccess handle.onOpenChange = (open, reason, _, _) -> changes.push('$open ${reason.toString()}');
        final cx = open((_, _) -> new DialogTrigger(div().size(px(100.))).handle(handle));
        draw(cx);
        cx.simulateClick(new Point(20., 20.));

        assertTrue(handle.isOpen());
        assertEquals('true TriggerPress', changes.join(','));
    }

    /**
     * The backdrop is the dimming surface every caller hands over as an
     * `absolute()` element, so it has to have the host's box to resolve
     * against.
     */
    function testTheBackdropFillsTheHost() {
        app.update(cx -> Base.init(cx));
        final focus = app.focusHandle();
        final backdrop = new BoundsCell();
        final cx = open((_, cx) -> new Dialog(cx.app)
            .open(true)
            .focusHandle(focus)
            .backdrop(canvas((bounds, _, _) -> {
                backdrop.bounds = bounds;
                return null;
            }, (_, _, _, _) -> {}).absolute().sizeFull())
            .popup(div().size(px(100.))));
        final viewport = cx.update((window, _) -> {
            final viewport = window.viewportSize();
            window.draw();
            return viewport;
        });
        assertTrue(backdrop.bounds.size.equals(viewport), 'a zero-sized backdrop paints no overlay behind the dialog');
    }

    /**
     * The backdrop sits under the popup, so a press on the popup must not
     * reach it and dismiss the dialog.
     */
    function testPressingThePopupDoesNotDismiss() {
        app.update(cx -> Base.init(cx));
        final handle = new DialogHandle(true);
        final cx = open((_, cx) -> new Dialog(cx.app)
            .handle(handle)
            .backdrop(div().absolute().sizeFull())
            .popup(new DialogPopup().size(px(100.))));
        final viewport = cx.update((window, _) -> {
            window.draw();
            return window.viewportSize();
        });

        cx.simulateClick(new Point(viewport.width / 2., viewport.height / 2.));
        assertTrue(handle.isOpen(), 'a press on the popup keeps the dialog open');

        cx.simulateClick(new Point(5., 5.));
        assertTrue(!handle.isOpen(), 'a press on the backdrop still dismisses');
    }

    function testThePopupIsCenteredByDefault() {
        app.update(cx -> Base.init(cx));
        final popup = new BoundsCell();
        final cx = open((_, cx) -> new Dialog(cx.app).popup(canvas((bounds, _, _) -> {
            popup.bounds = bounds;
            return null;
        }, (_, _, _, _) -> {}).size(px(100.))));
        final viewport = cx.update((window, _) -> {
            final viewport = window.viewportSize();
            window.draw();
            return viewport;
        });
        assertTrue(popup.bounds.center().equals(new Point(viewport.width / 2., viewport.height / 2.)));
    }

// alert_dialog.rs

    function testBackdropIsNotClosableByDefault() {
        app.update(cx -> Base.init(cx));
        var closeRequested = false;
        final cx = open((_, cx) -> new AlertDialog(cx.app)
            .requestClose((_, _, _) -> closeRequested = true)
            .backdrop(div().size(px(200.))));
        draw(cx);

        cx.simulateClick(new Point(20., 20.));

        assertTrue(!closeRequested);
    }

    /**
     * The host centers its popup by default; styling the alert dialog
     * replaces that layout just as it does for a plain dialog.
     */
    function testHostStylePositionsThePopup() {
        app.update(cx -> Base.init(cx));
        final popup = new BoundsCell();
        final cx = open((_, cx) -> new AlertDialog(cx.app).itemsStart().justifyStart().popup(canvas((bounds, _, _) -> {
            popup.bounds = bounds;
            return null;
        }, (_, _, _, _) -> {}).size(px(100.))));
        draw(cx);

        assertTrue(popup.bounds.origin.equals(new Point(0., 0.)));
    }

// sheet.rs

    function sheetHarness(closable:Bool, ?cutoff:Float, focusFirst:Bool = true):{cx:VisualTestContext, events:Array<String>} {
        app.update(cx -> Base.init(cx));
        final focus = app.focusHandle();
        final events:Array<String> = [];
        final cx = open((_, cx) -> {
            final sheet = new Sheet(cx.app)
                .focusHandle(focus)
                .overlayClosable(closable)
                .requestClose((_, _) -> events.push('request'))
                .onClose((_, _, _) -> events.push('closed'))
                .overlay(div().absolute().inset0().occlude())
                .surface(div()
                    .absolute()
                    .right0()
                    .top0()
                    .hFull()
                    .w(px(80.))
                    .occlude());
            return cutoff != null ? sheet.dismissBeforeY(cutoff) : sheet;
        });
        if (focusFirst) {
            cx.update((window, cx) -> focus.focus(window, cx));
        }
        draw(cx);
        return {cx: cx, events: events};
    }

    function testOverlayCloseRequestsThenNotifies() {
        final h = sheetHarness(true);
        h.cx.simulateClick(new Point(20., 20.));
        assertEquals('request,closed', h.events.join(','));
    }

    function testNonClosableOverlayDoesNotRequestClose() {
        final h = sheetHarness(false);
        h.cx.simulateClick(new Point(20., 20.));
        assertEquals(0, h.events.length);
    }

    function testEscapeUsesTheSameCloseOrderAndRegistersFocusTrap() {
        final h = sheetHarness(true);
        assertTrue(h.cx.update((window, cx) -> FocusTrap.activeFocusTrap(window, cx) != null));
        h.cx.update((window, cx) -> window.dispatchAction(new Cancel(), cx));
        h.cx.runUntilParked();
        assertEquals('request,closed', h.events.join(','));
    }

    function testPointerAboveTheDismissCutoffIsIgnored() {
        final h = sheetHarness(true, 50., false);
        h.cx.simulateClick(new Point(20., 20.));
        assertEquals(0, h.events.length);
        h.cx.simulateClick(new Point(20., 80.));
        assertEquals('request,closed', h.events.join(','));
    }

// toast.rs

    function testManagerPausesTimeoutAndRemovesOnlyAfterExit() {
        final motion = ToastMotion.sonner();
        final start = 0.;
        final manager = new ToastManager<String, Int>(motion);
        manager.push('a', 1, new ToastOptions(5.), start);
        manager.advance(start + motion.duration, false);
        manager.advance(start + motion.duration + 4., true);
        assertEquals(Present, manager.iter()[0].status);
        final ending = manager.advance(start + motion.duration + 9., false);
        assertEquals('a', ending.ending.join(','));
        assertEquals(0, ending.removed.length);
        final removed = manager.advance(start + motion.duration + motion.exitDuration + 9., false);
        assertEquals(1, removed.removed.length);
        assertEquals('a', removed.removed[0].id);
        assertEquals(1, removed.removed[0].value);
    }

    function testManagerLimitKeepsEndingToastsMounted() {
        final now = 0.;
        final manager = new ToastManager<String, String>(ToastMotion.sonner());
        for (id in ['a', 'b', 'c']) {
            manager.push(id, id, new ToastOptions(), now);
        }
        manager.dismiss('a', now);
        assertEquals('a,c', [for (entry in manager.visible(1)) entry.id].join(','));
    }

    function testManagerReplacesDuplicateIdsAsTheNewestToast() {
        final now = 0.;
        final manager = new ToastManager<String, Int>(ToastMotion.sonner());
        manager.push('a', 1, new ToastOptions(), now);
        manager.push('b', 2, new ToastOptions(), now);
        assertEquals(1, manager.push('a', 3, new ToastOptions(), now));
        assertEquals('b2,a3', [for (entry in manager.iter()) entry.id + entry.value].join(','));
    }

    function testManagerResetsClockWhenReusedAfterBecomingEmpty() {
        final motion = ToastMotion.sonner();
        final start = 0.;
        final manager = new ToastManager<String, Int>(motion);
        manager.push('old', 1, new ToastOptions(), start);
        manager.dismiss('old', start);
        manager.advance(start + motion.exitDuration, false);
        final later = start + 60.;
        manager.push('new', 2, new ToastOptions(), later);
        manager.advance(later + 0.05, false);
        assertEquals(Starting, manager.iter()[0].status);
    }

    function testNewlyPushedToastDoesNotInheritExistingEntryClock() {
        final motion = ToastMotion.sonner();
        final start = 0.;
        final manager = new ToastManager<String, Int>(motion);
        manager.push('old', 1, new ToastOptions(), start);
        final later = start + 60.;
        manager.push('new', 2, new ToastOptions(), later);
        manager.advance(later + 0.05, false);
        assertEquals(Starting, [for (entry in manager.iter()) if (entry.id == 'new') entry.status][0]);
    }

    function testStackGeometryAnchorsNewestItemAndSupportsVariableHeights() {
        final heights = [40., 60., 80.];
        final top = @:privateAccess ToastStackGeometry.compute(heights, 12., 12., false);
        assertEquals(104., top.collapsedHeight);
        assertEquals(204., top.expandedHeight);
        assertEquals('24/164,12/92,0/0', [for (o in top.offsets) '${(o.collapsed:Float)}/${(o.expanded:Float)}'].join(','));

        final bottom = @:privateAccess ToastStackGeometry.compute(heights, 12., 12., true);
        assertEquals('40/0,32/52,24/124', [for (o in bottom.offsets) '${(o.collapsed:Float)}/${(o.expanded:Float)}'].join(','));

        final tallBehind = [180., 60.];
        final top = @:privateAccess ToastStackGeometry.compute(tallBehind, 14., 14., false);
        assertEquals(194., top.collapsedHeight);
        assertEquals(14., top.offsets[0].collapsed);
        assertTrue(top.offsets[0].collapsed + tallBehind[0] <= top.collapsedHeight);
        assertEquals(14., top.offsets[0].collapsed - top.offsets[1].collapsed);

        final bottom = @:privateAccess ToastStackGeometry.compute(tallBehind, 14., 14., true);
        assertTrue(bottom.offsets[0].collapsed >= 0.);
        assertTrue(bottom.offsets[0].collapsed + tallBehind[0] <= top.collapsedHeight);
        assertEquals(14., (bottom.offsets[1].collapsed + tallBehind[1]) - (bottom.offsets[0].collapsed + tallBehind[0]));
    }

    function testToastExposesAlertSemantics() {
        final toast = new Toast('toast');
        assertEquals(glaze.kit.base.A11y.Role.Alert, toast.a11y.role);
    }

    function testStackBootstrapsMeasurementWithoutZeroHeightClipping() {
        final state = new ToastStackState();
        final cx = open((_, _) -> new ToastStack('stack', state)
            .w(px(300.))
            .item('first', div().h(px(80.)).child('Visible')));
        draw(cx);
        assertEquals(80., state.heights.get(Std.string(glaze.ElementId.Name('first'))));
    }

    function testStackExpandsForHoverAndFocus() {
        final state = new ToastStackState();
        final focus = app.focusHandle().tabStop(true);
        final cx = open((_, _) -> new ToastStack('stack', state)
            .focusHandle(focus)
            .w(px(300.))
            .item('first', div().h(px(80.))));
        draw(cx);

        cx.simulateMouseMove(new Point(10., 10.));
        draw(cx);
        assertTrue(state.isExpanded());

        cx.simulateMouseMove(new Point(400., 400.));
        draw(cx);
        assertTrue(!state.isExpanded());

        cx.simulateMouseMove(new Point(10., 10.));
        draw(cx);
        assertTrue(state.isExpanded());

        cx.simulateMouseMove(new Point(400., 400.));
        draw(cx);
        assertTrue(!state.isExpanded());

        cx.update((window, cx) -> {
            focus.focus(window, cx);
            window.draw();
        });
        assertTrue(state.isExpanded());
    }

    function testKeyedStackReflowMovesFromTheCurrentVisualPosition() {
        final state = new ToastStackState();
        final view = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ReflowHarness(state, false, false));
        final cx = view.cx;
        contexts.push(cx);
        cx.update((window, _) -> {
            window.draw();
            window.draw();
        });
        final initialY = debugBounds('first-toast').origin.y;

        view.view.update(app, (harness, hcx) -> {
            harness.showSecond = true;
            hcx.notify();
        });
        cx.runUntilParked();
        final firstReflowY = debugBounds('first-toast').origin.y;
        assertEquals(initialY, firstReflowY);

        cx.advanceClock(0.2);
        draw(cx);
        final middleY = debugBounds('first-toast').origin.y;
        assertTrue(middleY > initialY);
        assertTrue(middleY < initialY + 14.);

        cx.advanceClock(0.2);
        draw(cx);
        assertEquals(initialY + 14., debugBounds('first-toast').origin.y);
        assertTrue(debugBounds('first-toast').size.width < debugBounds('second-toast').size.width);
    }

    function testBottomStackReflowMovesUpWithoutAnOppositeDirectionJump() {
        final state = new ToastStackState();
        final view = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ReflowHarness(state, false, true));
        final cx = view.cx;
        contexts.push(cx);
        cx.update((window, _) -> {
            window.draw();
            window.draw();
        });
        // Both the baseline and the final reading are taken settled.
        cx.advanceClock(1.);
        draw(cx);
        final initialY = debugBounds('bottom-first-toast').origin.y;

        view.view.update(app, (harness, hcx) -> {
            harness.showSecond = true;
            hcx.notify();
        });
        cx.runUntilParked();
        assertEquals(initialY, debugBounds('bottom-first-toast').origin.y);

        cx.advanceClock(0.2);
        draw(cx);
        final middleY = debugBounds('bottom-first-toast').origin.y;
        assertTrue(middleY < initialY);
        assertTrue(middleY >= initialY - 14., 'middle=$middleY, initial=$initialY');

        cx.advanceClock(1.);
        draw(cx);
        assertEquals(initialY - 14., debugBounds('bottom-first-toast').origin.y);
    }

}

private class BoundsCell {

    public var bounds:Bounds = new Bounds();

    public function new() {}

}

/**
 * A view rendering what its function returns.
 */
@:allow(tests.kit)
class RenderView extends Model implements Render {

    final build:(Window, Context<Dynamic>) -> IntoElement;

    public function new(build:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return build(window, cx);
    }

}

/**
 * Records the bounds of its child in prepaint, under a selector (Rust
 * `debug_selector` / `debug_bounds`).
 */
class BoundsProbe extends Element {

    public static final bounds:Map<String, Bounds> = new Map();

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        BoundsProbe.bounds.set(selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

private class ReflowHarness extends Model implements Render {

    final state:ToastStackState;

    public var showSecond:Bool;

    final bottom:Bool;

    public function new(state:ToastStackState, showSecond:Bool, bottom:Bool) {
        super();
        this.state = state;
        this.showSecond = showSecond;
        this.bottom = bottom;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (bottom) {
            final stack = new ToastStack('bottom-stack', state)
                .placement(Anchor.BottomRight)
                .absolute()
                .bottom0()
                .w(px(300.))
                .item('bottom-first', new BoundsProbe('bottom-first-toast', div().h(px(40.))));
            if (showSecond) stack.item('bottom-second', div().h(px(80.)));
            return div().relative().size(px(300.)).child(stack);
        }
        final stack = new ToastStack('stack', state)
            .w(px(300.))
            .item('first', new BoundsProbe('first-toast', div().h(px(40.))));
        if (showSecond) stack.item('second', new BoundsProbe('second-toast', div().h(px(80.))));
        return stack;
    }

}
