// Ported from gpui-kit 0.8.1: crates/component/src/dialog/dialog.rs (tests), crates/component/src/dialog/alert_dialog.rs (tests),
// crates/component/src/dialog/entrance.rs (tests), crates/component/src/notification.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.SystemNotificationResponse;
import glaze.TestDispatcher;
import glaze.TestPlatformOperations;
import glaze.Window;
import glaze.App;
import glaze.kit.base.Root;
import glaze.kit.WindowState;
import glaze.kit.dialog.AlertDialog;
import glaze.kit.dialog.Dialog;
import glaze.kit.dialog.Dialog.DialogButtonProps;
import glaze.kit.dialog.DialogEntrance.EntranceSurface;
import glaze.kit.notification.Notification;
import glaze.kit.notification.Notification.NotificationDelivery;
import glaze.kit.notification.Notification.NotificationId;
import glaze.kit.notification.Notification.NotificationIdTools;
import glaze.kit.notification.Notification.NotificationList;
import glaze.FocusHandle;
import glaze.kit.base.Positioner;
import glaze.kit.dialog.DialogEntrance;
import glaze.kit.theme.Theme;
import tests.kit.BaseModalsTest.BoundsProbe;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/**
 * The tests of gpui-component's `dialog` module (`dialog.rs`,
 * `alert_dialog.rs`, `entrance.rs`) and `notification.rs`.
 *
 * Rust reads the dialog surface bounds through `debug_selector("dialog-N")`;
 * the port finds the surface quad in the rendered scene (rounded with the
 * theme's large radius, bordered, in paint order), like Rust's
 * `surface_alpha` reads the painted quads.
 */
class ComponentModalsTest extends TestCase {

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

    /**
     * A window of `size` whose root renders the dialog layer, with motion
     * reduced so the entrance animation settles on its first frame.
     */
    function window(width:Float, height:Float):{cx:VisualTestContext, clicks:Counter} {
        app.update(cx -> {
            cx.setReduceMotion(true);
        });
        final clicks = new Counter();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final view = rootCx.newEntity((_:Context<DialogHost>) -> new DialogHost(clicks));
            return new Root(view, window, rootCx);
        }, width, height);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return {cx: opened.cx, clicks: clicks};
    }

    static function open(cx:VisualTestContext, build:(Dialog, Window, App) -> Dialog):Void {
        cx.update((window, app) -> window.openDialog(app, build));
        cx.runUntilParked();
        // Mount the layer and paint the current animation sample.
        cx.update((window, _) -> window.draw());
        cx.update((window, _) -> window.draw());
    }

    /** Draws one frame, so an exit transition samples the clock at its current value. */
    static function frame(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.refresh());
        cx.runUntilParked();
    }

    /**
     * The bounds of the dialog surfaces painted, in paint order (Rust
     * `debug_bounds("dialog-N")`).
     */
    function surfaces(cx:VisualTestContext):Array<Bounds> {
        return cx.update((window, app) -> {
            final scale = window.scaleFactor();
            final radius = Theme.global(app).radiusLg * scale;
            final result:Array<Bounds> = [];
            final quads = window.renderedScene().quads.copy();
            quads.sort((a, b) -> a.order - b.order);
            for (quad in quads) {
                if (quad.cornerRadiusTopLeft == radius && quad.borderWidthTop == scale && quad.backgroundTag == 0 && quad.borderWidthLeft == scale) {
                    // GPUI paints a border as four quads (one per side, each
                    // under its own content mask): keep one per surface.
                    final last = result.length > 0 ? result[result.length - 1] : null;
                    if (last != null && last.origin.x == quad.boundsX / scale && last.origin.y == quad.boundsY / scale
                        && last.size.width == quad.boundsWidth / scale && last.size.height == quad.boundsHeight / scale) {
                        continue;
                    }
                    result.push(new Bounds(new Point(quad.boundsX / scale, quad.boundsY / scale), new Size(quad.boundsWidth / scale, quad.boundsHeight / scale)));
                }
            }
            return result;
        });
    }

    function surface(cx:VisualTestContext, layerIx:Int):Bounds {
        final all = surfaces(cx);
        if (layerIx >= all.length) throw 'dialog layer $layerIx was not painted';
        return all[layerIx];
    }

    /**
     * The clamp must not touch a dialog that already fits: the default width
     * and the tenth-of-the-viewport top offset are the documented contract.
     */
    function testADialogThatFitsKeepsItsDefaultWidthAndTopOffset() {
        final cx = window(1000, 800).cx;
        open(cx, (dialog, _, _) -> dialog.title('Fits').child('body'));

        final bounds = surface(cx, 0);
        assertEquals(448., bounds.size.width);
        assertEquals(276., bounds.origin.x);
        assertEquals(80., bounds.origin.y);
    }

    /**
     * A dialog wider and taller than the window must shrink to the viewport
     * instead of running off both edges. It also gives up the usual top
     * offset so that space is available to its content, while its footer
     * remains inside the surface rather than clipped below it.
     */
    function testADialogLargerThanTheWindowStaysInsideIt() {
        final cx = window(400, 300).cx;
        open(cx, (dialog, _, _) -> dialog
            .w(px(800.))
            .title('Too big')
            .child(div().h(px(1000.)).child('tall body'))
            .footer(new BoundsProbe('footer-probe', div().h(px(32.)))));

        final bounds = surface(cx, 0);
        final footer = BoundsProbe.bounds.get('footer-probe');
        final margin = 16.;
        assertTrue(bounds.origin.x >= margin && bounds.right() <= 400 - margin, 'the dialog ran off the sides: $bounds');
        assertTrue(bounds.bottom() <= 300 - margin, 'the dialog ran off the bottom: $bounds');
        assertEquals(margin, bounds.origin.y);
        assertTrue(footer.bottom() <= bounds.bottom(), 'the footer was clipped below the dialog: footer $footer, dialog $bounds');
    }

    /** `Dialog.buttonProps` overrides only the fields it sets. */
    function testDialogButtonPropsMergeWithWhatTheDialogAlreadyCarries() {
        final cx = window(400, 300).cx;
        cx.update((_, cx) -> {
            final dialog = Dialog.component(cx)
                .buttonProps(new DialogButtonProps().cancelText('Keep'))
                .buttonProps(new DialogButtonProps().okText('Delete'))
                .buttonProps(new DialogButtonProps().okVariant(Danger));

            assertEquals('Delete', dialog.buttonPropsValue.okTextValue);
            assertEquals('Keep', dialog.buttonPropsValue.cancelTextValue);
            assertTrue(dialog.buttonPropsValue.okVariantValue.match(Danger));
        });
    }

    /**
     * Each stacked dialog steps down 16px; the deepest one must still end
     * above the bottom margin.
     */
    function testStackedDialogsEachFitTheWindow() {
        final cx = window(400, 300).cx;
        open(cx, (dialog, _, _) -> dialog.title('First').child(div().h(px(1000.))));
        open(cx, (dialog, _, _) -> dialog.title('Second').child(div().h(px(1000.))));

        final first = surface(cx, 0);
        final second = surface(cx, 1);
        assertEquals(first.origin.y + 16., second.origin.y);
        assertTrue(first.bottom() <= 300 - 16., '$first');
        assertTrue(second.bottom() <= 300 - 16., '$second');
        assertTrue(second.size.height < first.size.height);
    }

    function testDialogEntranceBuilder() {
        app.update(cx -> {
            assertEquals(SlideDown, Dialog.component(cx).props.entrance);
            for (entrance in [SlideDown, Fade, FadeSlide, None]) {
                assertEquals(entrance, Dialog.component(cx).entrance(entrance).props.entrance);
            }
        });
    }

    function testReducedMotionDisplaysEveryEntranceAtRest() {
        for (entrance in [SlideDown, Fade, FadeSlide, None]) {
            final cx = window(1000, 800).cx;
            open(cx, (dialog, _, _) -> dialog
                .title('Entrance')
                .child('body')
                .entrance(entrance)
                .marginTop(px(300.)));
            assertEquals(300., surface(cx, 0).top(), entrance.toString());
        }
    }

    function testNoEntranceDisplaysImmediatelyAndKeepsKeyboardDismissal() {
        final cx = window(1000, 800).cx;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog
            .title('Immediate')
            .child('body')
            .entrance(None)
            .marginTop(px(300.)));
        assertEquals(300., surface(cx, 0).top());
        cx.simulateKeystrokes('escape');
        cx.update((window, cx) -> assertEquals(0, WindowState.read(window).activeDialogs.length));
    }

    /**
     * Closing keeps the dialog mounted until the entrance plays back out, and
     * the dialog stops counting as active before it leaves the screen.
     */
    function testClosingPlaysTheEntranceBackwardsBeforeTheDialogUnmounts() {
        final cx = window(1000, 800).cx;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog.title('Closing').child('body').marginTop(px(300.)));

        advance(cx, Dialog.ANIMATION_DURATION);
        frame(cx);
        cx.update((window, cx) -> window.closeDialog(cx));
        frame(cx);
        // The exit starts from the resting position and the dialog is already
        // logically inactive, though it still paints.
        cx.update((window, cx) -> {
            assertEquals(1, WindowState.read(window).activeDialogs.length);
            assertTrue(!window.hasActiveDialog(cx));
        });
        assertEquals(300., surface(cx, 0).top());

        // Halfway through, the surface has slid up between rest and the top.
        advance(cx, Dialog.ANIMATION_DURATION / 2);
        frame(cx);
        cx.update((window, _) -> assertEquals(1, WindowState.read(window).activeDialogs.length));
        final halfway = surface(cx, 0).top();
        assertTrue(halfway > 0. && halfway < 300., 'the closing dialog should slide back up: $halfway');

        // Once the transition finishes the dialog leaves the window state.
        advance(cx, Dialog.ANIMATION_DURATION / 2 + 0.001);
        frame(cx);
        cx.update((window, cx) -> {
            assertEquals(0, WindowState.read(window).activeDialogs.length);
            assertTrue(!window.hasActiveDialog(cx));
        });
        assertEquals(0, surfaces(cx).length);
    }

    function testReducedMotionClosesInASingleFrame() {
        final cx = window(1000, 800).cx;
        open(cx, (dialog, _, _) -> dialog.title('Reduced').child('body'));
        cx.update((window, cx) -> window.closeDialog(cx));
        cx.update((window, cx) -> {
            assertEquals(0, WindowState.read(window).activeDialogs.length);
            assertTrue(!window.hasActiveDialog(cx));
        });
    }

    function testZeroThemeDurationClosesFadeEntrancesImmediately() {
        for (entrance in [Fade, FadeSlide]) {
            final cx = window(1000, 800).cx;
            cx.update((_, cx) -> {
                cx.setReduceMotion(false);
                Theme.update(cx, theme -> theme.motion.durationNormal = 0.);
            });
            open(cx, (dialog, _, _) -> dialog.title('Immediate').child('body').entrance(entrance));
            cx.update((window, cx) -> window.closeDialog(cx));
            cx.update((window, cx) -> {
                assertEquals(0, WindowState.read(window).activeDialogs.length);
                assertTrue(!window.hasActiveDialog(cx));
            });
        }
    }

    /**
     * Opening a new dialog while the previous one is leaving keeps both
     * mounted for the exit: the new dialog owns focus and survives it.
     */
    function testReopeningDuringTheExitKeepsTheNewDialog() {
        final cx = window(1000, 800).cx;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog.title('First').child('body'));
        advance(cx, Dialog.ANIMATION_DURATION);
        frame(cx);
        cx.update((window, cx) -> window.closeDialog(cx));
        frame(cx);

        open(cx, (dialog, _, _) -> dialog.title('Second').child('body'));
        cx.update((window, _) -> {
            final state = WindowState.read(window);
            assertEquals(2, state.activeDialogs.length);
            assertTrue(state.activeDialogs[0].closing);
            assertTrue(!state.activeDialogs[1].closing);
            assertTrue(state.activeDialogs[1].focusHandle.isFocused(window), 'the reopened dialog owns focus while the old one leaves');
        });

        advance(cx, Dialog.ANIMATION_DURATION + 0.001);
        frame(cx);
        // The old dialog is gone and the new one moves up to its layer.
        frame(cx);
        cx.update((window, cx) -> {
            final state = WindowState.read(window);
            assertEquals(1, state.activeDialogs.length);
            assertTrue(!state.activeDialogs[0].closing);
            assertTrue(state.activeDialogs[0].focusHandle.isFocused(window));
            assertTrue(window.hasActiveDialog(cx));
        });
        assertEquals(80., surface(cx, 0).top());
        assertEquals(1, surfaces(cx).length);
    }

    /**
     * Closing the top of a stack only removes that dialog: the one below stays
     * mounted and becomes the active dialog for the duration of the exit.
     */
    function testClosingTheTopDialogLeavesTheOneBelowMounted() {
        final cx = window(1000, 800).cx;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog.title('First').child('body'));
        open(cx, (dialog, _, _) -> dialog.title('Second').child('body'));

        advance(cx, Dialog.ANIMATION_DURATION);
        frame(cx);
        cx.update((window, cx) -> window.closeDialog(cx));
        frame(cx);
        cx.update((window, cx) -> {
            assertEquals(2, WindowState.read(window).activeDialogs.length);
            assertTrue(window.hasActiveDialog(cx));
        });
        assertEquals(2, surfaces(cx).length, 'the lower dialog stays and the closing dialog still paints its exit');

        advance(cx, Dialog.ANIMATION_DURATION + 0.001);
        frame(cx);
        cx.update((window, cx) -> {
            assertEquals(1, WindowState.read(window).activeDialogs.length);
            assertTrue(window.hasActiveDialog(cx));
        });
        assertEquals(1, surfaces(cx).length);
    }

    /**
     * A leaving dialog releases input: a press that the open backdrop used to
     * swallow now reaches the application beneath it.
     */
    function testClosingDialogDoesNotBlockInputBeneathIt() {
        final opened = window(1000, 800);
        final cx = opened.cx;
        final clicks = opened.clicks;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog
            .title('Closing')
            .child('body')
            .marginTop(px(300.))
            .overlayClosable(false));

        // The open dialog covers the window: the backdrop stops the press
        // before it can reach the target underneath.
        final backdropPoint = new Point(100., 60.);
        cx.simulateClick(backdropPoint);
        assertEquals(0, clicks.value, 'an open dialog blocked the application');

        advance(cx, Dialog.ANIMATION_DURATION);
        frame(cx);
        cx.update((window, cx) -> window.closeDialog(cx));
        frame(cx);
        cx.simulateClick(backdropPoint);
        assertEquals(1, clicks.value, 'the closing dialog swallowed a press meant for the application');
    }

    function testZeroThemeDurationDisplaysFadeEntrancesImmediately() {
        for (entrance in [Fade, FadeSlide]) {
            final cx = window(1000, 800).cx;
            cx.update((_, cx) -> {
                cx.setReduceMotion(false);
                Theme.update(cx, theme -> theme.motion.durationNormal = 0.);
            });
            open(cx, (dialog, _, _) -> dialog
                .title('Immediate')
                .child('body')
                .entrance(entrance)
                .marginTop(px(300.)));
            assertEquals(300., surface(cx, 0).top());
        }
    }

    function testAlertDialogUsesTheSameEntrance() {
        for (entrance in [SlideDown, Fade, FadeSlide, None]) {
            final cx = window(1000, 800).cx;
            cx.update((window, cx) -> {
                final alert = AlertDialog.component(cx)
                    .title('Alert')
                    .entrance(entrance);
                assertEquals(entrance, alert.buildSurface(window, cx).props.entrance);
                window.openAlertDialog(cx, (alert, _, _) -> alert.title('Alert').entrance(entrance));
            });
            cx.runUntilParked();
            cx.update((window, _) -> window.draw());
            cx.update((window, _) -> window.draw());
            assertEquals(80., surface(cx, 0).top());
        }
    }

    /**
     * Closing fades the surface itself, not only the layer: the base host
     * paints in a deferred pass, where ancestor opacity no longer applies.
     */
    function testClosingFadesTheDialogSurface() {
        final cx = window(1000, 800).cx;
        cx.update((_, cx) -> cx.setReduceMotion(false));
        open(cx, (dialog, _, _) -> dialog
            .title('Fading')
            .child('body')
            .marginTop(px(300.))
            .entrance(Fade));
        advance(cx, Dialog.ANIMATION_DURATION);
        frame(cx);
        cx.update((window, cx) -> window.closeDialog(cx));
        frame(cx);
        assertEquals(1.0, surfaceAlpha(cx), 'the exit should start fully visible');

        advance(cx, 0.09);
        frame(cx);
        final alpha = surfaceAlpha(cx);
        assertTrue(alpha > 0.0 && alpha < 1.0, 'the closing surface should fade, but its background is $alpha');
    }

    function testClosingDuringEntranceReversesFromTheCurrentSample() {
        for (entrance in [SlideDown, Fade, FadeSlide]) {
            final cx = window(1000, 800).cx;
            cx.update((_, cx) -> cx.setReduceMotion(false));
            open(cx, (dialog, _, _) -> dialog
                .title('Interrupted')
                .child('body')
                .marginTop(px(300.))
                .entrance(entrance));
            advance(cx, 0.04);
            frame(cx);
            final before = surface(cx, 0);
            final alpha = surfaceAlpha(cx);
            assertTrue(alpha > 0. && alpha < 1., '$alpha');
            cx.update((window, cx) -> window.closeDialog(cx));
            frame(cx);
            assertTrue(surface(cx, 0).equals(before), '${entrance.toString()} jumped on close');
            assertTrue(Math.abs(surfaceAlpha(cx) - alpha) < 0.001);
            advance(cx, 0.02);
            frame(cx);
            assertTrue(surfaceAlpha(cx) < alpha);
            assertTrue(surface(cx, 0).top() <= before.top());
        }
    }

// alert_dialog.rs

    /**
     * `buttonProps` overrides only the fields it sets, so the Cancel button
     * `confirm` asked for survives a later props value that never mentions it.
     */
    function testButtonPropsAfterConfirmKeepsTheCancelButton() {
        final cx = window(800, 600).cx;
        cx.update((_, cx) -> {
            final alert = AlertDialog.component(cx)
                .confirm()
                .buttonProps(new DialogButtonProps().okText('Delete'));

            assertTrue(alert.base.buttonPropsValue.isCancelShown());
            assertEquals('Delete', alert.base.buttonPropsValue.okTextValue);
        });
    }

    /** The call order does not matter either way round. */
    function testConfirmAfterButtonPropsKeepsTheOkText() {
        final cx = window(800, 600).cx;
        cx.update((_, cx) -> {
            final alert = AlertDialog.component(cx)
                .buttonProps(new DialogButtonProps().okText('Delete'))
                .confirm();

            assertTrue(alert.base.buttonPropsValue.isCancelShown());
            assertEquals('Delete', alert.base.buttonPropsValue.okTextValue);
        });
    }

    /**
     * A callback installed with `onOk` survives a later props value that
     * carries no callback of its own.
     */
    function testButtonPropsAfterOnOkKeepsTheCallback() {
        final cx = window(800, 600).cx;
        final confirmed = new Counter();
        cx.update((window, cx) -> {
            final alert = AlertDialog.component(cx)
                .onOk((_, _, _) -> {
                    confirmed.value++;
                    return true;
                })
                .buttonProps(new DialogButtonProps().okText('Delete'));

            assertTrue(alert.base.buttonPropsValue.okHandler()(@:privateAccess glaze.kit.base.Dialog.DialogKeys.defaultClickEvent(), window, cx));
        });

        assertEquals(1, confirmed.value);
    }

    /** The direct builders resolve to the same buttons as a props value. */
    function testTheDirectBuildersMatchButtonProps() {
        final cx = window(800, 600).cx;
        cx.update((_, cx) -> {
            final direct = AlertDialog.component(cx)
                .confirm()
                .okText('Delete')
                .okVariant(Danger)
                .cancelText('Keep')
                .cancelVariant(Ghost);
            final bundled = AlertDialog.component(cx).buttonProps(new DialogButtonProps()
                .showCancel(true)
                .okText('Delete')
                .okVariant(Danger)
                .cancelText('Keep')
                .cancelVariant(Ghost));

            for (props in [direct.base.buttonPropsValue, bundled.base.buttonPropsValue]) {
                assertTrue(props.isCancelShown());
                assertEquals('Delete', props.okTextValue);
                assertTrue(props.okVariantValue.match(Danger));
                assertEquals('Keep', props.cancelTextValue);
                assertTrue(props.cancelVariantValue.match(Ghost));
            }
        });
    }

    /**
     * `marginTop` overrides the tenth-of-the-viewport default offset, which
     * seats a short alert near the top of a tall window.
     */
    function testMarginTopMovesTheAlertSurfaceOffTheDefaultOffset() {
        final cx = window(800, 600).cx;
        cx.update((window, cx) -> window.openAlertDialog(cx, (alert, _, _) -> alert
            .title('Unsaved changes')
            .description('Discard the draft?')
            .confirm()
            .marginTop(px(100.))));
        cx.runUntilParked();
        // One frame mounts the layer, the next paints it at rest.
        cx.update((window, _) -> window.draw());
        cx.update((window, _) -> window.draw());

        final bounds = surface(cx, 0);
        // The alert chrome carries fractional text metrics, so the painted
        // origin lands within a subpixel of the requested offset.
        assertTrue(Math.abs(bounds.origin.y - 100.) <= 0.5, 'expected the surface within 0.5px of y=100, got $bounds');
    }

    /**
     * `centered` seats the surface in the vertical middle of the window,
     * whatever its height.
     */
    function testCenteredSeatsTheAlertSurfaceInTheMiddle() {
        final cx = window(800, 600).cx;
        cx.update((window, cx) -> window.openAlertDialog(cx, (alert, _, _) -> alert
            .title('Unsaved changes')
            .description('Discard the draft?')
            .confirm()
            .centered()));
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        cx.update((window, _) -> window.draw());

        final bounds = surface(cx, 0);
        assertTrue(Math.abs(bounds.center().y - 300.) <= 0.5, 'expected the surface centered on y=300, got $bounds');
    }

// entrance.rs

    function testFadeSlideUsesResolvedBoundsAndKeepsTheSurfaceInsideTheWindow() {
        final probe = new SurfaceProbe();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> probe, 400, 400);
        contexts.push(opened.cx);
        final cx = opened.cx;
        // Requested y=200 resolves to y=84 because the surface is 300px tall.
        for (row in [
            {requestedY: 200., positions: [76., 80., 84.]},
            {requestedY: 20., positions: [16., 18., 20.]},
            {requestedY: 0., positions: [16., 16., 16.]}
        ]) {
            for (index in 0...3) {
                final progress = [0., 0.5, 1.][index];
                final expectedY = row.positions[index];
                cx.update((window, cx) -> {
                    opened.view.update(cx, (probe, probeCx) -> {
                        probe.progress = progress;
                        probe.requestedY = row.requestedY;
                        probeCx.notify();
                    });
                    window.draw();
                });
                final bounds = BoundsProbe.bounds.get('entrance-surface');
                assertEquals(expectedY, bounds.top());
                assertTrue(bounds.top() >= 16. && bounds.bottom() <= 384.);
                // At the beginning of the clamped entrance this point is
                // above the resting surface, so the hitbox must travel too.
                cx.simulateClick(new Point(bounds.origin.x + 10., bounds.origin.y + 2.));
            }
        }
        assertEquals(9, probe.clicks);
    }

// notification.rs

    function notificationRoot(activate:Bool):{cx:VisualTestContext, root:Entity<NotificationRoot>} {
        app.update(cx -> cx.setGlobal(new Theme(), Theme));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<NotificationRoot>) -> new NotificationRoot(cx.newEntity((listCx:Context<NotificationList>) -> new NotificationList(window, listCx)), cx.focusHandle()));
        contexts.push(opened.cx);
        if (activate) {
            opened.cx.update((window, _) -> window.setActive(true));
        }
        return {cx: opened.cx, root: opened.view};
    }

    static function ids(list:Entity<NotificationList>, cx:VisualTestContext):Array<NotificationId> {
        return cx.update((_, app) -> [for (entry in list.read(app).notificationsManager.iter()) entry.value.read(app).idValue]);
    }

    static function idsString(list:Entity<NotificationList>, cx:VisualTestContext):String {
        return [for (id in ids(list, cx)) Std.string(id)].join(',');
    }

    static function updateList(cx:VisualTestContext, list:Entity<NotificationList>, f:(NotificationList, Window, Context<NotificationList>) -> Void):Void {
        cx.update((window, app) -> list.update(app, (list, listCx) -> f(list, window, listCx)));
    }

    /**
     * Drive the dismiss animation timer and propagate the resulting
     * `DismissEvent`, so that closed notifications are removed from the list.
     */
    static function flushDismiss(cx:VisualTestContext):Void {
        advance(cx, NotificationList.NOTIFICATION_EXIT_DURATION + 0.05);
        cx.runUntilParked();
    }

    static inline function typeId(type:Class<Dynamic>):String {
        return NotificationIdTools.typeIdOf(type);
    }

    function testNotificationBuilder() {
        final note = new Notification()
            .title('title')
            .message('message')
            .withType(Success)
            .placement(BottomLeft)
            .delivery(System)
            .autohide(false);
        assertEquals('title', note.titleValue);
        assertEquals('message', note.messageValue);
        assertTrue(note.typeValue == Success);
        assertTrue(note.placementValue == BottomLeft);
        assertTrue(note.deliveryValue == System);
        assertTrue(!note.autohideValue);

        assertEquals(null, new Notification().deliveryValue);
        assertTrue(new Notification().system().deliveryValue == System);
        assertTrue(new Notification().inAppAndSystem().deliveryValue == InAppAndSystem);
    }

    function testNotificationDeliveryIncludes() {
        assertTrue(NotificationDelivery.InApp.includesInApp());
        assertTrue(!NotificationDelivery.InApp.includesSystem());
        assertTrue(!NotificationDelivery.System.includesInApp());
        assertTrue(NotificationDelivery.System.includesSystem());
        assertTrue(NotificationDelivery.InAppAndSystem.includesInApp());
        assertTrue(NotificationDelivery.InAppAndSystem.includesSystem());
    }

    function testSystemTagIsStableAndNamespaced() {
        final byType = NotificationId.Id(typeId(FooKind));
        assertEquals(NotificationIdTools.systemTag(byType), NotificationIdTools.systemTag(NotificationId.Id(typeId(FooKind))));
        assertTrue(StringTools.startsWith(NotificationIdTools.systemTag(byType), 'gpui-component/notification/'));

        final key1 = NotificationId.IdAndElementId(typeId(FooKind), glaze.ElementId.Integer(1));
        final key2 = NotificationId.IdAndElementId(typeId(FooKind), glaze.ElementId.Integer(2));
        assertTrue(NotificationIdTools.systemTag(key1) != NotificationIdTools.systemTag(key2));
        assertTrue(NotificationIdTools.systemTag(byType) != NotificationIdTools.systemTag(key1));

        // Default ids never collide, so they never replace each other.
        assertTrue(NotificationIdTools.systemTag(new Notification().idValue) != NotificationIdTools.systemTag(new Notification().idValue));
    }

    /**
     * A stack's element id must not depend on how many other placements are
     * mounted: a changing id drops the element state of the whole subtree,
     * which replays each notification's enter animation.
     */
    function testStackElementIdSurvivesOtherPlacementsDisappearing() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        // The left stack is pushed first, so it owns the lower group index.
        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('left').withId(FooKind).placement(BottomLeft).autohide(false), window, cx);
            list.push(Notification.info('right').withId(BarKind).autohide(false), window, cx);
        });

        final rightId = () -> cx.update((_, app) -> {
            for (group in list.read(app).grouped(app)) {
                if (group.anchor == TopRight) return group.stackId;
            }
            throw 'the right stack is mounted';
        });
        final before = rightId();

        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(FooKind)), window, cx));
        flushDismiss(cx);

        assertTrue(Type.enumEq(before, rightId()));
    }

    /**
     * A second notification stacks onto the first one without replaying the
     * first one's enter animation: the first stays where its slide ended
     * (only the stack reflow moves it, by at most the collapsed peek) while
     * the second one slides in. A regression test of the port (no Rust
     * counterpart): the story's "Show Notification" pressed twice replayed
     * the first slide-in, because the notification view, clean but moved by
     * the stack reflow, lost the animation state it accessed while
     * rendering again in prepaint (see `ViewCacheTest`). Frames are drawn
     * like the platform draws them (next frame callbacks, then dirty
     * windows only): an explicit draw of a clean window renders every view
     * and hides the bug.
     */
    function testSecondNotificationDoesNotReplayTheFirstOnesEnterAnimation() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        final probed = (selector:String) -> Notification.info(selector)
            .autohide(false)
            .content((_, _, _) -> new BoundsProbe(selector, div().h(px(4.))).intoAnyElement());
        final y = (selector:String) -> BoundsProbe.bounds.get(selector).origin.y;
        final frame = () -> {
            cx.advanceClock(1. / 60.);
            cx.runUntilParked();
            cx.update((window, _) -> {
                window.simulateNextFrame();
                window.drawIfDirty();
            });
        };

        updateList(cx, list, (list, window, cx) -> list.push(probed('first'), window, cx));
        final firstStart = y('first');
        for (_ in 0...60) frame();
        final firstRest = y('first');
        // The first notification slid down from its offset to its place.
        assertTrue(firstRest - firstStart > NotificationList.NOTIFICATION_TRANSITION_OFFSET / 2, 'the first notification slid from $firstStart to $firstRest');

        updateList(cx, list, (list, window, cx) -> list.push(probed('second'), window, cx));
        final secondStart = y('second');
        final peek = 14.;
        for (index in 0...60) {
            final firstY = y('first');
            assertTrue(firstY >= firstRest - 0.5 && firstY <= firstRest + peek + 0.5, 'frame $index: the first notification is at $firstY, it rested at $firstRest');
            frame();
        }
        // Meanwhile the second one slid in.
        assertTrue(y('second') - secondStart > NotificationList.NOTIFICATION_TRANSITION_OFFSET / 2, 'the second notification slid from $secondStart to ${y('second')}');
    }

    function testPerNotificationPlacementStacksByAnchor() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('default').withId(FooKind).autohide(false), window, cx);
            list.push(Notification.info('bottom').withId(BarKind).placement(BottomLeft).autohide(false), window, cx);
        });
        cx.update((window, _) -> window.draw());

        final anchors = () -> cx.update((_, app) -> [for (entry in list.read(app).stacks) Std.string(entry.anchor)].join(','));
        assertEquals([Std.string(glaze.Anchor.TopRight), Std.string(glaze.Anchor.BottomLeft)].join(','), anchors());

        // Dismissing the overridden notification prunes its stack.
        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(BarKind)), window, cx));
        flushDismiss(cx);
        cx.update((window, _) -> window.draw());
        assertEquals(Std.string(glaze.Anchor.TopRight), anchors());
    }

    function testClosingToastStaysMountedUntilItsTransitionFinishes() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('closing').withId(FooKind).autohide(false), window, cx);
            list.close(Id(typeId(FooKind)), window, cx);
        });

        advance(cx, NotificationList.NOTIFICATION_EXIT_DURATION - 0.001);
        cx.runUntilParked();
        assertEquals(1, ids(list, cx).length);

        advance(cx, 0.001);
        cx.runUntilParked();
        assertEquals(0, ids(list, cx).length);
    }

    function testLifecycleClockRunsOnlyWhileANotificationIsMounted() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        final advancing = () -> cx.update((_, app) -> list.read(app).isAdvancing);

        // A list that has never shown anything arms no timer.
        advance(cx, 1.);
        cx.runUntilParked();
        assertTrue(!advancing());

        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('tick').withId(FooKind), window, cx));
        assertTrue(advancing());

        // Autohide expiry plus the exit transition stops the clock with it.
        advance(cx, NotificationList.NOTIFICATION_TRANSITION_DURATION + 5.);
        cx.runUntilParked();
        flushDismiss(cx);
        assertEquals(0, ids(list, cx).length);
        assertTrue(!advancing());

        // A later notification restarts it.
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('again').withId(BarKind), window, cx));
        assertTrue(advancing());
        advance(cx, NotificationList.NOTIFICATION_TRANSITION_DURATION + 5.);
        cx.runUntilParked();
        flushDismiss(cx);
        assertEquals(0, ids(list, cx).length);
        assertTrue(!advancing());
    }

    function testLifecycleClockRestsWhileOnlyPersistentNotificationsAreShown() {
        final opened = notificationRoot(true);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        final advancing = () -> cx.update((_, app) -> list.read(app).isAdvancing);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('first').withId(FooKind).autohide(false), window, cx);
            list.push(Notification.info('second').withId(BarKind).autohide(false), window, cx);
        });
        assertTrue(advancing());

        // Once both have entered, nothing is left to time.
        advance(cx, NotificationList.NOTIFICATION_TRANSITION_DURATION + NotificationList.NOTIFICATION_ADVANCE_INTERVAL);
        cx.runUntilParked();
        assertTrue(!advancing());
        assertEquals(2, ids(list, cx).length);

        // A programmatic close restarts the clock to finish the exit.
        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(FooKind)), window, cx));
        assertTrue(advancing());
        flushDismiss(cx);
        assertEquals(Std.string(NotificationId.Id(typeId(BarKind))), idsString(list, cx));
        assertTrue(!advancing());

        // So does a dismiss requested by the notification itself.
        final note = cx.update((_, app) -> list.read(app).notifications()[0]);
        cx.update((window, app) -> note.update(app, (note, noteCx) -> note.dismiss(window, noteCx)));
        cx.runUntilParked();
        assertTrue(advancing());
        flushDismiss(cx);
        assertEquals(0, ids(list, cx).length);
        assertTrue(!advancing());
    }

    function testInactiveWindowDoesNotPauseAutohide() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        updateList(cx, list, (list, window, cx) -> {
            assertTrue(!window.isWindowActive());
            list.push(Notification.info('background').withId(FooKind), window, cx);
        });

        advance(cx, NotificationList.NOTIFICATION_TRANSITION_DURATION);
        cx.runUntilParked();
        final note = cx.update((_, app) -> list.read(app).notificationsManager.get(Id(typeId(FooKind))));
        assertEquals(glaze.kit.base.Toast.ToastTransitionStatus.Present, cx.update((_, app) -> note.read(app).transitionStatus));

        advance(cx, 5. + 0.05);
        cx.runUntilParked();
        assertEquals(glaze.kit.base.Toast.ToastTransitionStatus.Ending, cx.update((_, app) -> note.read(app).transitionStatus));
    }

    function testFocusPausesAutohideAndPresentPhaseIsProjected() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('paused').withId(FooKind), window, cx));

        advance(cx, NotificationList.NOTIFICATION_TRANSITION_DURATION);
        cx.runUntilParked();
        final note = cx.update((_, app) -> list.read(app).notificationsManager.get(Id(typeId(FooKind))));
        assertEquals(glaze.kit.base.Toast.ToastTransitionStatus.Present, cx.update((_, app) -> note.read(app).transitionStatus));

        final listFocus = cx.update((_, app) -> list.read(app).focusHandle);
        cx.update((window, app) -> {
            listFocus.focus(window, app);
            window.draw();
        });
        advance(cx, 5.);
        cx.runUntilParked();
        assertEquals(glaze.kit.base.Toast.ToastTransitionStatus.Present, cx.update((_, app) -> note.read(app).transitionStatus));

        final otherFocus = cx.update((_, app) -> opened.root.read(app).otherFocus);
        cx.update((window, app) -> {
            otherFocus.focus(window, app);
            window.draw();
        });
        assertTrue(!cx.update((_, app) -> list.read(app).isExpanded()));
        advance(cx, 5. + 0.05);
        cx.runUntilParked();
        assertEquals(glaze.kit.base.Toast.ToastTransitionStatus.Ending, cx.update((_, app) -> note.read(app).transitionStatus));
    }

    function testCloseByTypeRemovesIdAndAllId1OfSameType() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('plain').withId(FooKind).autohide(false), window, cx);
            list.push(Notification.info('a').id1(FooKind, 1).autohide(false), window, cx);
            list.push(Notification.info('b').id1(FooKind, 2).autohide(false), window, cx);
            list.push(Notification.info('bar').withId(BarKind).autohide(false), window, cx);
        });
        cx.runUntilParked();
        assertEquals(4, ids(list, cx).length);

        updateList(cx, list, (list, window, cx) -> list.closeByType(typeId(FooKind), window, cx));
        flushDismiss(cx);

        assertEquals(Std.string(NotificationId.Id(typeId(BarKind))), idsString(list, cx), 'only the BarKind notification should survive');
    }

    function testCloseWithIdAndElementIdRemovesOnlyMatchingKey() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('a').id1(FooKind, 1).autohide(false), window, cx);
            list.push(Notification.info('b').id1(FooKind, 2).autohide(false), window, cx);
            list.push(Notification.info('plain').withId(FooKind).autohide(false), window, cx);
        });

        updateList(cx, list, (list, window, cx) -> list.close(IdAndElementId(typeId(FooKind), glaze.ElementId.Integer(1)), window, cx));
        flushDismiss(cx);

        final remaining = ids(list, cx);
        assertEquals(2, remaining.length);
        assertTrue(Lambda.exists(remaining, id -> Type.enumEq(id, NotificationId.IdAndElementId(typeId(FooKind), glaze.ElementId.Integer(2)))));
        assertTrue(Lambda.exists(remaining, id -> Type.enumEq(id, NotificationId.Id(typeId(FooKind)))));
    }

    /**
     * The plain `close(Id)` form keeps its narrow semantics: it only matches
     * `NotificationId.Id`, not `NotificationId.IdAndElementId`.
     */
    function testCloseWithOnlyTypeIdDoesNotMatchId1Entries() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('a').id1(FooKind, 1).autohide(false), window, cx));
        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(FooKind)), window, cx));
        flushDismiss(cx);

        assertEquals(1, ids(list, cx).length, 'id1 entry should remain untouched');
    }

    function testCloseByTypeWithNoMatchIsNoop() {
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('bar').withId(BarKind).autohide(false), window, cx));
        updateList(cx, list, (list, window, cx) -> list.closeByType(typeId(FooKind), window, cx));
        flushDismiss(cx);

        assertEquals(1, ids(list, cx).length);
    }

    /** Rust `init(cx)` on GPUI's test platform: the port's test double of it. */
    function initSystemNotifications():TestPlatformOperations {
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        app.update(cx -> NotificationList.init(cx));
        return platform;
    }

    /**
     * Applications may post their own system notifications; a response for
     * one of those must not be retracted or dispatched by the library.
     */
    function testResponseForAForeignTagIsIgnored() {
        final platform = initSystemNotifications();
        app.update(cx -> cx.setAppIdentity('com.example.test', 'Test'));
        platform.simulateSystemNotificationResponse(new SystemNotificationResponse('com.example.app/own-tag'));
        dispatcher.runUntilParked();
        assertEquals(0, platform.dismissedSystemNotifications.length);
        assertEquals(0, platform.activations.length);
    }

    function testSystemDeliveryPostsToCenterWithoutInAppToast() {
        final platform = initSystemNotifications();
        // The test platform drops posts until an identity is set, mirroring Windows.
        app.update(cx -> cx.setAppIdentity('com.example.test', 'Test'));
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        updateList(cx, list, (list, window, cx) -> {
            list.push(Notification.info('body text').title('Title').withId(FooKind).delivery(System), window, cx);
            // Message-only: the message becomes the system title.
            list.push(Notification.info('message only').withId(BarKind).delivery(System), window, cx);
        });
        cx.runUntilParked();

        final shown = platform.shownSystemNotifications;
        assertEquals(2, shown.length);
        assertEquals(NotificationIdTools.systemTag(Id(typeId(FooKind))), shown[0].tag);
        assertEquals('Title', shown[0].title);
        assertEquals('body text', shown[0].body);
        assertEquals('message only', shown[1].title);
        assertEquals('', shown[1].body);
        assertEquals(0, ids(list, cx).length, 'no in-app toast should exist');

        // System-only notifications are still retractable through the
        // regular close path even though no toast entity exists.
        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(FooKind)), window, cx));
        assertEquals(NotificationIdTools.systemTag(Id(typeId(FooKind))), platform.dismissedSystemNotifications.join(','));
    }

    function testSystemClickActivatesWindowClosesToastAndFiresOnClick() {
        final platform = initSystemNotifications();
        app.update(cx -> cx.setAppIdentity('com.example.test', 'Test'));
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);

        var clicked = false;
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('message')
            .title('Title')
            .withId(FooKind)
            .delivery(InAppAndSystem)
            .autohide(false)
            .onClick((_, _, _) -> clicked = true), window, cx));
        cx.runUntilParked();
        assertEquals(1, ids(list, cx).length);
        assertEquals(1, platform.shownSystemNotifications.length);

        platform.simulateSystemNotificationResponse(new SystemNotificationResponse(NotificationIdTools.systemTag(Id(typeId(FooKind)))));
        cx.runUntilParked();

        assertTrue(clicked, 'on_click should fire on system response');
        // The response retracts the notification and brings the app forward
        assertEquals(NotificationIdTools.systemTag(Id(typeId(FooKind))), platform.dismissedSystemNotifications.join(','));
        assertEquals('true', platform.activations.join(','));
        flushDismiss(cx);
        assertEquals(0, ids(list, cx).length, 'the in-app counterpart should be closed');
    }

    function testExplicitCloseRetractsSystemNotificationButAutohideDoesNot() {
        final platform = initSystemNotifications();
        app.update(cx -> cx.setAppIdentity('com.example.test', 'Test'));
        final opened = notificationRoot(false);
        final cx = opened.cx;
        cx.update((window, _) -> window.activateWindow());
        final list = cx.update((_, app) -> opened.root.read(app).list);

        // Autohide expiry leaves the system notification in the center.
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('auto').withId(FooKind).delivery(InAppAndSystem), window, cx));
        cx.runUntilParked();
        advance(cx, 6.);
        flushDismiss(cx);
        assertEquals(0, ids(list, cx).length, 'the toast should have autohidden');
        assertEquals(0, platform.dismissedSystemNotifications.length, 'autohide must not retract the system notification');

        // An explicit close retracts it.
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('manual').withId(BarKind).delivery(InAppAndSystem).autohide(false), window, cx));
        cx.runUntilParked();
        updateList(cx, list, (list, window, cx) -> list.close(Id(typeId(BarKind)), window, cx));
        flushDismiss(cx);
        assertEquals(NotificationIdTools.systemTag(Id(typeId(BarKind))), platform.dismissedSystemNotifications.join(','));
    }

    /**
     * A response for a window that closed meanwhile still retracts the
     * notification and activates the app, without dispatching (Rust: the
     * window handle update errs). A port check, no Rust counterpart.
     */
    function testSystemResponseAfterTheWindowClosedOnlyActivates() {
        final platform = initSystemNotifications();
        app.update(cx -> cx.setAppIdentity('com.example.test', 'Test'));
        final opened = notificationRoot(false);
        final cx = opened.cx;
        final list = cx.update((_, app) -> opened.root.read(app).list);
        var clicked = false;
        updateList(cx, list, (list, window, cx) -> list.push(Notification.info('message').withId(FooKind).system().onClick((_, _, _) -> clicked = true), window, cx));
        contexts.remove(cx);
        cx.destroy();

        platform.simulateSystemNotificationResponse(new SystemNotificationResponse(NotificationIdTools.systemTag(Id(typeId(FooKind)))));
        dispatcher.runUntilParked();
        assertFalse(clicked);
        assertEquals(NotificationIdTools.systemTag(Id(typeId(FooKind))), platform.dismissedSystemNotifications.join(','));
        assertEquals('true', platform.activations.join(','));
    }

// kit/tests/integration/root.rs (component parts)

    /** The painted notification cards (bordered, `radiusLg`, the notification width). */
    function notificationCards(cx:VisualTestContext):Array<Bounds> {
        return [for (bounds in surfaces(cx)) if (bounds.size.width == 382.) bounds];
    }

    /** The painted dialog surfaces (every bordered `radiusLg` quad but the notification cards). */
    function dialogSurfaces(cx:VisualTestContext):Array<Bounds> {
        return [for (bounds in surfaces(cx)) if (bounds.size.width != 382.) bounds];
    }

    function plainWindow(?cached:Counter):VisualTestContext {
        app.update(cx -> {
            // This test checks layer hosting, independently of animation time.
            cx.setReduceMotion(true);
        });
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            if (cached != null) {
                final content = rootCx.newEntity((_:Context<CachedContent>) -> new CachedContent(cached));
                final view = rootCx.newEntity((_:Context<CachedContentHost>) -> new CachedContentHost(content));
                return new Root(view, window, rootCx);
            }
            final view = rootCx.newEntity((_:Context<PlainView>) -> new PlainView());
            return new Root(view, window, rootCx);
        }, 800, 600);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    static function openAndNotify(window:Window, cx:App):Void {
        window.openDialog(cx, (dialog, _, _) -> dialog.title('Hello'));
        window.pushNotification(new Notification().message('Saved').autohide(false), cx);
    }

    function testARootRendersTheLayersAPlainViewLeavesOut() {
        final cx = plainWindow();
        assertEquals(0, dialogSurfaces(cx).length);
        cx.update((window, cx) -> openAndNotify(window, cx));
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        assertEquals(1, dialogSurfaces(cx).length, 'the dialog must reach the screen without the view rendering the layer');
        assertEquals(1, notificationCards(cx).length);
    }

    function testAutomaticNotificationsArePositionedInsideTheWindow() {
        final cx = plainWindow();
        cx.update((window, cx) -> window.pushNotification(new Notification().message('Saved').autohide(false), cx));
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
        final bounds = notificationCards(cx)[0];
        assertTrue(bounds.origin.x >= 0. && bounds.origin.y >= 0.);
        assertTrue(bounds.origin.x + bounds.size.width <= 800.);
        assertTrue(bounds.origin.y + bounds.size.height <= 600.);
    }

    function testInitializationLeavesQuitAndCloseShortcutsToTheApplication() {
        app.update(cx -> {
            for (shortcut in ['cmd-q', 'cmd-w', 'alt-f4']) {
                assertEquals(0, cx.allBindingsForInput([glaze.Keystroke.parse(shortcut)]).length, '$shortcut must remain an application-owned binding');
            }
        });
    }

    function testCachedContentDoesNotDuplicateAutomaticLayers() {
        final renders = new Counter();
        final cx = plainWindow(renders);
        cx.update((window, cx) -> {
            window.openSheet(cx, (sheet, _, _) -> sheet.title('Sheet'));
            openAndNotify(window, cx);
        });
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        assertEquals(1, dialogSurfaces(cx).length);
        assertEquals(1, notificationCards(cx).length);
        final firstRenders = renders.value;
        assertTrue(firstRenders > 0);
        // Unlike a refresh, draw does not force a refresh of cached views.
        cx.update((window, _) -> window.draw());
        assertEquals(1, dialogSurfaces(cx).length);
        assertEquals(1, notificationCards(cx).length);
        assertEquals(firstRenders, renders.value, 'the second frame must reuse the cached host');
    }

// kit/tests/integration/overlays.rs (dialog, sheet and notification parts)

    function workspace():{cx:VisualTestContext, view:Entity<Workspace>} {
        var workspace:Null<Entity<Workspace>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            workspace = rootCx.newEntity((viewCx:Context<Workspace>) -> new Workspace(viewCx.focusHandle().tabStop(true)));
            return new Root(workspace, window, rootCx);
        }, 800, 700);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.setActive(true));
        opened.cx.update((window, _) -> window.draw());
        return {cx: opened.cx, view: workspace};
    }

    function clickProbe(cx:VisualTestContext, selector:String):Void {
        final bounds = BoundsProbe.bounds.get(selector);
        assertTrue(bounds != null, 'no $selector in ${[for (k in BoundsProbe.bounds.keys()) k]}');
        cx.simulateClick(bounds.center());
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    /** Rust `wait_for`: advances the test clock until `done`, at most `seconds`. */
    function waitFor(cx:VisualTestContext, seconds:Float, done:(Window) -> Bool):Void {
        var waited = 0.;
        while (!cx.update((window, _) -> {
            window.draw();
            return done(window);
        })) {
            assertTrue(waited < seconds, 'timed out');
            advance(cx, 0.05);
            waited += 0.05;
        }
    }

    function testEscapeDismissesDialogAndSheetAndRestoresFocus() {
        final opened = workspace();
        final cx = opened.cx;
        final name = cx.update((_, app) -> opened.view.read(app).name);
        cx.update((window, app) -> name.focus(window, app));
        clickProbe(cx, 'edit');
        waitFor(cx, 1., window -> window.hasActiveDialog(app));
        cx.simulateKeystrokes('escape');
        waitFor(cx, 1., window -> !window.hasActiveDialog(app) && dialogSurfaces(cx).length == 0 && name.isFocused(window));
        assertTrue(cx.update((window, _) -> name.isFocused(window)));
        clickProbe(cx, 'inspect');
        waitFor(cx, 1., window -> window.hasActiveSheet(app));
        cx.simulateKeystrokes('escape');
        waitFor(cx, 1., window -> !window.hasActiveSheet(app));
        assertTrue(cx.update((window, _) -> name.isFocused(window)));
    }

    function testNotificationAutoDismissesAfterItsTimer() {
        final opened = workspace();
        final cx = opened.cx;
        clickProbe(cx, 'notify');
        waitFor(cx, 1., _ -> notificationCards(cx).length == 1);
        // The default timeout is five seconds; the notification must remain
        // mounted before that deadline, not merely disappear eventually.
        for (_ in 0...40) {
            advance(cx, 0.1);
            cx.update((window, _) -> window.draw());
            assertEquals(1, notificationCards(cx).length);
        }
        waitFor(cx, 10., _ -> notificationCards(cx).length == 0);
    }

    /**
     * Opens the dialog, then moves focus back to the control behind it: what
     * a native web view or an always-on-top window does on its own.
     */
    function openDialogAndStealFocus(open:String):VisualTestContext {
        final opened = workspace();
        final cx = opened.cx;
        clickProbe(cx, open);
        waitFor(cx, 1., window -> window.hasActiveDialog(app));
        final outside = cx.update((_, app) -> opened.view.read(app).name);
        cx.update((window, app) -> {
            outside.focus(window, app);
            window.draw();
            assertTrue(outside.isFocused(window), 'focus must sit outside the dialog');
        });
        return cx;
    }

    function testDialogActionConfirmsItsDialogWhenFocusWasStolen() {
        final cx = openDialogAndStealFocus('open');
        clickProbe(cx, 'ok');
        waitFor(cx, 1., window -> !window.hasActiveDialog(app));
    }

    function testDialogCloseTriggerCancelsItsDialogWhenFocusWasStolen() {
        final cx = openDialogAndStealFocus('open');
        clickProbe(cx, 'footer-close');
        waitFor(cx, 1., window -> !window.hasActiveDialog(app));
    }

    function testAlertDialogDefaultButtonsReachTheirDialogWhenFocusWasStolen() {
        final cx = openDialogAndStealFocus('open-alert');
        // The default OK button is the primary button of the alert footer.
        final ok = cx.update((window, app) -> {
            final primary = Theme.global(app).tokens.buttonPrimary.color;
            final scale = window.scaleFactor();
            for (quad in window.renderedScene().quads) {
                // The dialog may still be entering (its opacity scales the alpha).
                if (quad.backgroundTag == 0 && Math.abs(quad.backgroundSolidL - primary.l) < 1e-4 && quad.boundsWidth < 400
                    && Math.abs(quad.backgroundSolidS - primary.s) < 1e-4 && quad.boundsWidth > 0) {
                    return new Point((quad.boundsX + quad.boundsWidth / 2) / scale, (quad.boundsY + quad.boundsHeight / 2) / scale);
                }
            }
            return null;
        });
        assertTrue(ok != null, 'the OK button was not painted');
        cx.simulateClick(ok);
        cx.runUntilParked();
        waitFor(cx, 1., window -> !window.hasActiveDialog(app));
    }

    /** The most opaque background painted at the surface's current bounds. */
    function surfaceAlpha(cx:VisualTestContext):Float {
        final bounds = surface(cx, 0);
        return cx.update((window, _) -> {
            final scale = window.scaleFactor();
            final left = bounds.origin.x * scale;
            final top = bounds.origin.y * scale;
            final width = bounds.size.width * scale;
            final height = bounds.size.height * scale;
            // DEV-002: under an opaque border the background is inset by half
            // the border width, in whole device pixels (a fading surface is
            // translucent and keeps the full bounds)
            var alpha = 0.;
            for (inset in [0., Math.ffloor(scale / 2)]) {
                for (quad in window.renderedScene().quads) {
                    if (Math.abs(quad.boundsX - left - inset) < 1.0 && Math.abs(quad.boundsY - top - inset) < 1.0
                        && Math.abs(quad.boundsWidth - width + 2 * inset) < 1.0 && Math.abs(quad.boundsHeight - height + 2 * inset) < 1.0
                        && quad.backgroundTag == 0 && quad.borderWidthTop == 0) {
                        alpha = Math.max(alpha, quad.backgroundSolidA);
                    }
                }
            }
            return alpha;
        });
    }

    /** Rust `cx.background_executor.advance_clock` (the dispatcher steps through the due timers). */
    static function advance(cx:VisualTestContext, seconds:Float):Void {
        cx.advanceClock(seconds);
        cx.runUntilParked();
    }

}

private class Counter {

    public var value:Int = 0;

    public function new() {}

}

/**
 * A target beneath the dialog's backdrop, so tests can observe whether
 * presses reach the application while it is covered.
 */
private class DialogHost extends Model implements Render {

    final clicks:Counter;

    public function new(clicks:Counter) {
        super();
        this.clicks = clicks;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final clicks = this.clicks;
        return div().sizeFull().child(div()
            .id('background-target')
            .absolute()
            .top0()
            .left0()
            .wFull()
            .h(px(200.))
            .onClick((_, _, _) -> clicks.value++));
    }

}

private class FooKind {}

private class BarKind {}

private class NotificationRoot extends Model implements Render {

    public final list:Entity<NotificationList>;

    public final otherFocus:FocusHandle;

    public function new(list:Entity<NotificationList>, otherFocus:FocusHandle) {
        super();
        this.list = list;
        this.otherFocus = otherFocus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .child(list)
            .child(div().trackFocus(otherFocus));
    }

}

private class SurfaceProbe extends Model implements Render {

    public var progress:Float = 0.;

    public var requestedY:Float = 200.;

    public var clicks:Int = 0;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final surface = @:privateAccess new EntranceSurface(new BoundsProbe('entrance-surface', div()
            .id('surface')
            .w(px(200.))
            .h(px(300.))
            .onClick(cx.listener((probe:SurfaceProbe, _, _, _) -> probe.clicks++))).intoAnyElement(), px(8.), px(16.));
        @:privateAccess surface.progress = progress;
        return div().sizeFull().child(Positioner.corner(TopLeft, new Point(100., requestedY))
            .margin(16.)
            .child(surface));
    }

}

/** A view that never mentions the layers. */
private class PlainView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child('plain');
    }

}

private class CachedContent extends Model implements Render {

    final renders:Counter;

    public function new(renders:Counter) {
        super();
        this.renders = renders;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders.value++;
        return div().sizeFull().child('cached content');
    }

}

private class CachedContentHost extends Model implements Render {

    final content:Entity<CachedContent>;

    public function new(content:Entity<CachedContent>) {
        super();
        this.content = content;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(content.cached(new glaze.StyleBuilder().sizeFull().style()));
    }

}

/**
 * The integration tests' workspace, with a focusable stand-in for the
 * input fields (the input module comes with wave 6): it opens a dialog
 * whose footer confirms with a `DialogAction` or cancels with a
 * `DialogClose`, an alert dialog, a sheet, and notifications.
 */
private class Workspace extends Model implements Render {

    public final name:FocusHandle;

    public function new(name:FocusHandle) {
        super();
        this.name = name;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .p4()
            .flex()
            .flexCol()
            .gap4()
            .child(div().id('name').h(px(30.)).trackFocus(name))
            .child(new BoundsProbe('edit', glaze.kit.button.Button.component('edit')
                .label('Edit')
                .onClick((_, window, cx) -> window.openDialog(cx, (dialog, _, _) -> dialog
                    .title('Edit profile')
                    .child('body')))))
            .child(new BoundsProbe('inspect', glaze.kit.button.Button.component('inspect')
                .label('Inspect')
                .onClick((_, window, cx) -> window.openSheet(cx, (sheet, _, _) -> sheet.title('Inspector').child('Details')))))
            .child(new BoundsProbe('notify', glaze.kit.button.Button.component('notify')
                .label('Notify')
                .onClick((_, window, cx) -> window.pushNotification(new Notification().message('Updated').autohide(true), cx))))
            .child(new BoundsProbe('open', glaze.kit.button.Button.component('open')
                .label('Open')
                .onClick((_, window, cx) -> window.openDialog(cx, (dialog, _, _) -> dialog
                    .title('Stolen focus')
                    .footer(glaze.kit.dialog.DialogFooter.component()
                        .child(new BoundsProbe('footer-close', new glaze.kit.dialog.DialogFooter.DialogClose().trigger(button -> button.label('Cancel'))))
                        .child(new BoundsProbe('ok', new glaze.kit.dialog.DialogFooter.DialogAction().child(glaze.kit.button.Button.component('ok').label('OK')))))))))
            .child(new BoundsProbe('open-alert', glaze.kit.button.Button.component('open-alert')
                .label('Alert')
                .onClick((_, window, cx) -> window.openAlertDialog(cx, (dialog, _, _) -> dialog.title('Stolen focus').confirm()))));
    }

}
