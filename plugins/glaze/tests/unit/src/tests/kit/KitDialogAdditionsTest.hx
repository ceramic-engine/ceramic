// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Window;
import glaze.kit.dialog.Dialog;
import glaze.kit.theme.Theme;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/**
 * The dialog additions without upstream equivalent (KIT-006): a maximum
 * height, an overlay that closes on a whole click, a public header.
 */
class KitDialogAdditionsTest extends KitAdditionsTestCase {

    /** An 800 x 600 window with the dialog `build` configures. */
    function dialog(build:(Dialog) -> Dialog):VisualTestContext {
        app.update(cx -> cx.setReduceMotion(true));
        final cx = open((_, _) -> div().sizeFull(), 800, 600, true);
        cx.update((window, app) -> window.openDialog(app, (dialog, _, _) -> build(dialog)));
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        return cx;
    }

    /** The bounds of the dialog surface: the bordered quad with the large radius. */
    function surface(cx:VisualTestContext):Bounds {
        final radius = cx.update((window, app) -> Theme.global(app).radiusLg * window.scaleFactor());
        for (entry in quads(cx)) {
            if (entry.quad.cornerRadiusTopLeft == radius && entry.quad.borderWidthTop > 0. && entry.quad.borderWidthLeft > 0.) return entry.bounds;
        }
        throw 'no dialog surface was painted';
    }

    function isOpen(cx:VisualTestContext):Bool {
        return cx.update((window, app) -> window.hasActiveDialog(app));
    }

    function tall(dialog:Dialog):Dialog {
        return dialog.title('Licenses').child(div().h(px(2000.)).w(px(10.)));
    }

    function press(cx:VisualTestContext, at:Point):Void {
        cx.simulateEvent(new MouseDownEvent(Left, at, Modifiers.none(), 1, false));
        draw(cx);
    }

    function release(cx:VisualTestContext, at:Point):Void {
        cx.simulateEvent(new MouseUpEvent(Left, at, Modifiers.none(), 1));
        cx.runUntilParked();
        draw(cx);
        draw(cx);
    }

    function testATallDialogStopsAtTheViewportMarginByDefault() {
        final cx = dialog(tall);
        final margin:Float = cx.update((_, app) -> (Theme.global(app).spacingTokens().lg : Float));
        assertEquals(600. - margin * 2., surface(cx).size.height);
    }

    function testMaxHLimitsTheHeight() {
        assertEquals(300., surface(dialog(d -> tall(d).maxH(px(300.)))).size.height);
        // 85 % of the 600 px viewport.
        assertEquals(510., surface(dialog(d -> tall(d).maxHRatio(0.85))).size.height);
        // The smaller of the two wins, and the viewport margin over both.
        assertEquals(200., surface(dialog(d -> tall(d).maxHRatio(0.85).maxH(px(200.)))).size.height);
        final cx = dialog(d -> tall(d).maxH(px(5000.)).maxHRatio(2.));
        final margin:Float = cx.update((_, app) -> (Theme.global(app).spacingTokens().lg : Float));
        assertEquals(600. - margin * 2., surface(cx).size.height);
    }

    function testAShortDialogIsNotStretchedByAMaxHeight() {
        final plain = surface(dialog(d -> d.title('Hello').child(div().h(px(50.)))));
        final limited = surface(dialog(d -> d.title('Hello').child(div().h(px(50.))).maxH(px(400.)).maxHRatio(0.85)));
        assertTrue(plain.equals(limited));
    }

    function testByDefaultAPressOnTheOverlayCloses() {
        final cx = dialog(d -> d.title('Hello'));
        assertTrue(isOpen(cx));
        press(cx, new Point(20., 500.));
        cx.runUntilParked();
        draw(cx);
        assertFalse(isOpen(cx));
    }

    function testWithOverlayCloseOnClickTheWholeClickMustBeOnTheOverlay() {
        final overlay = new Point(20., 500.);
        final cx = dialog(d -> d.title('Hello').child(div().h(px(100.))).overlayCloseOnClick(true));
        final inside = surface(cx).center();

        // The press alone does not close.
        press(cx, overlay);
        assertTrue(isOpen(cx));
        // Released inside the dialog: still open.
        release(cx, inside);
        assertTrue(isOpen(cx));

        // Pressed inside (a text selection), released on the overlay: still open.
        press(cx, inside);
        release(cx, overlay);
        assertTrue(isOpen(cx));

        // Another button on the overlay: still open.
        cx.simulateEvent(new MouseDownEvent(Right, overlay, Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Right, overlay, Modifiers.none(), 1));
        cx.runUntilParked();
        draw(cx);
        assertTrue(isOpen(cx));

        // Pressed and released on the overlay: closed.
        press(cx, overlay);
        release(cx, new Point(30., 510.));
        assertFalse(isOpen(cx));
    }

    function testOverlayCloseOnClickStillObeysOverlayClosable() {
        final overlay = new Point(20., 500.);
        final cx = dialog(d -> d.title('Hello').overlayCloseOnClick(true).overlayClosable(false));
        press(cx, overlay);
        release(cx, overlay);
        assertTrue(isOpen(cx));
    }

    // KIT-018

    /** The shadows of the frame drawn last: blur radius in logical pixels and color. */
    function shadows(cx:VisualTestContext):Array<String> {
        return cx.update((window, _) -> {
            final scale = window.scaleFactor();
            return [for (shadow in window.renderedScene().shadows)
                '${shadow.blurRadius / scale}:${Math.round(shadow.colorH * 100) / 100},${Math.round(shadow.colorS * 100) / 100},${Math.round(shadow.colorL * 100) / 100},${Math.round(shadow.colorA * 100) / 100}'];
        });
    }

    function testByDefaultTheDialogHasItsOwnShadow() {
        assertEquals('25:0,0,0,0.1|10:0,0,0,0.1', shadows(dialog(d -> d.title('Hello'))).join('|'));
    }

    function testAShadowSetByTheCallerIsKept() {
        final own = new glaze.BoxShadow(px(0.), px(4.), hsla(0.6, 0.5, 0.5, 0.4)).withBlurRadius(px(12.));
        assertEquals('12:0.6,0.5,0.5,0.4', shadows(dialog(d -> d.title('Hello').shadow([own]))).join('|'));
        // The geometry of the dialog does not depend on it
        assertTrue(surface(dialog(d -> d.title('Hello'))).equals(surface(dialog(d -> d.title('Hello').shadow([own])))));
        // An empty list: no shadow
        assertEquals('', shadows(dialog(d -> d.title('Hello').shadow([]))).join('|'));
    }

    function testAHeaderIsRenderedAboveTheTitle() {
        final cx = dialog(d -> d
            .header(probe('header', div().h(px(24.)).child('Back')))
            .title(probe('title', div().child('Text styles'))));
        final header = boundsOf(cx, 'header');
        final title = boundsOf(cx, 'title');
        final surface = surface(cx);
        assertNotNull(header);
        assertTrue(header.top() >= surface.top() && header.bottom() <= title.top(), 'header ${header.top()}..${header.bottom()}, title at ${title.top()}');
        // Inside the dialog's horizontal paddings.
        assertEquals(surface.left() + 16. + 1., header.left());
    }

    /** KIT-026: `bodyGap` sets the space between the header and what follows; 8 px by default. */
    function testBodyGapSetsTheSpaceUnderTheHeader() {
        final build = (gap:Null<Float>) -> dialog(d -> {
            d.header(probe('header', div().h(px(24.)).child('Back'))).child(probe('body', div().h(px(50.)).wFull()));
            return gap != null ? d.bodyGap(px(gap)) : d;
        });
        final plain = build(null);
        assertEquals(8., boundsOf(plain, 'body').top() - boundsOf(plain, 'header').bottom());
        final plainHeight = surface(plain).size.height;
        final plainSignature = sceneSignature(plain);

        final none = build(0.);
        assertEquals(0., boundsOf(none, 'body').top() - boundsOf(none, 'header').bottom());
        assertEquals(plainHeight - 8., surface(none).size.height);
        assertEquals(boundsOf(plain, 'header').top() - surface(plain).top(), boundsOf(none, 'header').top() - surface(none).top());

        final wide = build(20.);
        assertEquals(20., boundsOf(wide, 'body').top() - boundsOf(wide, 'header').bottom());

        // the default gap given explicitly draws the same frame
        assertEquals(plainSignature, sceneSignature(build(8.)));
    }

    // KIT-029

    /** Two centered dialogs of the same size, the second built by `build`: the top of each one's content. */
    function stackedTops(build:(Dialog) -> Dialog, centered:Bool):Array<Float> {
        final cx = dialog(d -> {
            d.title('First').child(probe('first', div().h(px(80.)).wFull()));
            return centered ? d.centered() : d;
        });
        cx.update((window, app) -> window.openDialog(app, (d, _, _) -> {
            d.title('First').child(probe('second', div().h(px(80.)).wFull()));
            return build(centered ? d.centered() : d);
        }));
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        return [boundsOf(cx, 'first').top(), boundsOf(cx, 'second').top()];
    }

    /** KIT-029: `layerOffset` sets the step of a dialog over another one; 16 px by default. */
    function testLayerOffsetSetsTheStepOfAStackedDialog() {
        for (centered in [false, true]) {
            final plain = stackedTops(d -> d, centered);
            assertEquals(16., plain[1] - plain[0]);
            final explicit = stackedTops(d -> d.layerOffset(px(16.)), centered);
            assertEquals(plain[0], explicit[0]);
            assertEquals(plain[1], explicit[1]);
            final none = stackedTops(d -> d.layerOffset(px(0.)), centered);
            assertEquals(plain[0], none[0]);
            assertEquals(none[0], none[1]);
            final wide = stackedTops(d -> d.layerOffset(px(24.)), centered);
            assertEquals(24., wide[1] - wide[0]);
        }
        // A dialog alone does not move.
        final alone = dialog(d -> d.title('First').child(probe('first', div().h(px(80.)).wFull())).layerOffset(px(40.)));
        final reference = dialog(d -> d.title('First').child(probe('first', div().h(px(80.)).wFull())));
        assertEquals(boundsOf(reference, 'first').top(), boundsOf(alone, 'first').top());
    }

}
