// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.BoxShadow;
import glaze.Bounds;
import glaze.Hsla;
import glaze.kit.alert.Alert;
import glaze.kit.dialog.Dialog;
import glaze.kit.separator.Separator;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/**
 * Three small additions without upstream equivalent: the shadow of a
 * dialog from its own style (KIT-009), an alert around an element
 * (KIT-010), a style for the label of a separator (KIT-011).
 */
class KitPopupAdditionsTest extends KitAdditionsTestCase {

    function dialog(build:(Dialog) -> Dialog):VisualTestContext {
        app.update(cx -> cx.setReduceMotion(true));
        final cx = open((_, _) -> div().sizeFull(), 800, 600, true);
        cx.update((window, app) -> window.openDialog(app, (dialog, _, _) -> build(dialog)));
        cx.runUntilParked();
        draw(cx);
        draw(cx);
        return cx;
    }

    /** The shadows of the frame drawn last: blur radius in logical pixels, and color. */
    function shadows(cx:VisualTestContext):Array<{blur:Float, color:Hsla}> {
        return cx.update((window, _) -> {
            final scaleFactor = window.scaleFactor();
            return [for (shadow in window.renderedScene().shadows) {
                blur: shadow.blurRadius / scaleFactor,
                color: new Hsla(shadow.colorH, shadow.colorS, shadow.colorL, shadow.colorA)
            }];
        });
    }

    function testADialogKeepsItsDefaultShadow() {
        final drawn = shadows(dialog(d -> d.title('Hello').child(div().h(px(50.)))));
        assertEquals(2, drawn.length);
        assertEquals(25., drawn[0].blur);
        assertEquals(10., drawn[1].blur);
    }

    function testAShadowSetOnTheDialogReplacesTheDefault() {
        final shadow = new BoxShadow(px(0.), px(4.), hsla(0.6, 0.5, 0.5, 0.8)).withBlurRadius(px(32.));
        final drawn = shadows(dialog(d -> d.title('Hello').child(div().h(px(50.))).shadow([shadow])));
        assertEquals(1, drawn.length);
        assertEquals(32., drawn[0].blur);
        assertTrue(Math.abs(drawn[0].color.a - 0.8) < 0.0001);
        assertTrue(Math.abs(drawn[0].color.h - 0.6) < 0.0001);
    }

    function testAnAlertShowsItsMessageByDefault() {
        final cx = open((_, _) -> div().w(px(400.)).child(Alert.info('alert', 'Hello')), 800, 600, true);
        draw(cx);
        assertNull(boundsOf(cx, 'content'));
        assertTrue(cx.update((window, _) -> window.renderedScene().monochromeSprites.length) > 0);
    }

    function testAnAlertAroundAnElement() {
        final marker = hsla(0.3, 0.9, 0.5, 1.);
        final cx = open((_, _) -> div().w(px(400.))
            .child(probe('alert', Alert.info('alert', 'Not shown')
                .content(probe('content', div().w(px(120.)).h(px(40.)).bg(marker))))), 800, 600, true);
        draw(cx);
        final alert = boundsOf(cx, 'alert');
        final content = boundsOf(cx, 'content');
        assertNotNull(alert);
        assertNotNull(content);
        // The element is drawn, inside the frame of the alert, after its icon
        assertEquals(120., (content.size.width : Float));
        assertEquals(40., (content.size.height : Float));
        assertEquals(1, quadsFilled(cx, marker, content).length);
        assertTrue((content.origin.x : Float) > (alert.origin.x : Float) + 16.);
        assertTrue((content.origin.y : Float) >= (alert.origin.y : Float));
        assertTrue((content.origin.y : Float) + 40. <= (alert.origin.y : Float) + (alert.size.height : Float));
    }

    function testASeparatorLabelStyle() {
        final marker = hsla(0.8, 0.9, 0.5, 1.);
        final plain = open((_, _) -> div().w(px(400.)).child(Separator.horizontal().label('Section')), 800, 600, true);
        draw(plain);
        assertEquals(0, quadsFilled(plain, marker).length);
        final cx = open((_, _) -> div().w(px(400.))
            .child(Separator.horizontal().label('Section').labelStyle(s -> s.bg(marker).px(px(20.)).py0())), 800, 600, true);
        draw(cx);
        final filled = quadsFilled(cx, marker);
        assertEquals(1, filled.length);
        // No vertical padding left: the label is as high as its line of text
        final styled:Bounds = filled[0].bounds;
        assertTrue((styled.size.height : Float) < 20.);
        assertTrue((styled.size.width : Float) > 40.);
    }

}
