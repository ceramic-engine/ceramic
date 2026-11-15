// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Background;
import glaze.Hsla;
import glaze.kit.button.Button;
import glaze.kit.button.Button.ButtonCustomVariant;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.button.Button.ButtonVariantTools;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.theme.Colorize;

/**
 * The button additions without upstream equivalent (KIT-010): a hover and
 * an active foreground for the custom variant, and its exact colors.
 */
@:access(glaze.kit.button.Button.ButtonVariantTools)
class KitButtonAdditionsTest extends KitAdditionsTestCase {

    static final BLUE = hsla(0.6, 0.8, 0.5, 1.);
    static final RED = hsla(0., 0.8, 0.5, 1.);
    static final GREEN = hsla(0.33, 0.8, 0.4, 1.);
    static final INK = hsla(0., 0., 0.1, 1.);

    function custom():ButtonCustomVariant {
        return app.update(cx -> new ButtonCustomVariant(cx).color(BLUE).foreground(INK).hover(RED).active(GREEN));
    }

    function solid(background:Background):Hsla {
        return background.solid;
    }

    function testByDefaultTheForegroundIsTheSameInEveryState() {
        final variant = Custom(custom());
        app.update(cx -> {
            assertTrue(ButtonVariantTools.normal(variant, false, cx).fg.equals(INK));
            assertTrue(ButtonVariantTools.hovered(variant, false, cx).fg.equals(INK));
            assertTrue(ButtonVariantTools.active(variant, false, cx).fg.equals(INK));
            return null;
        });
    }

    function testHoverForegroundColorsTheHoveredAndThePressedButton() {
        final variant = Custom(custom().hoverForeground(RED));
        app.update(cx -> {
            assertTrue(ButtonVariantTools.normal(variant, false, cx).fg.equals(INK));
            assertTrue(ButtonVariantTools.hovered(variant, false, cx).fg.equals(RED));
            assertTrue(ButtonVariantTools.active(variant, false, cx).fg.equals(RED), 'the pressed button keeps the hover foreground');
            assertTrue(ButtonVariantTools.selected(variant, false, cx).fg.equals(INK));
            // outline buttons too
            assertTrue(ButtonVariantTools.hovered(variant, true, cx).fg.equals(RED));
            return null;
        });
        final both = Custom(custom().hoverForeground(RED).activeForeground(GREEN));
        app.update(cx -> {
            assertTrue(ButtonVariantTools.hovered(both, false, cx).fg.equals(RED));
            assertTrue(ButtonVariantTools.active(both, false, cx).fg.equals(GREEN));
            return null;
        });
        final activeOnly = Custom(custom().activeForeground(GREEN));
        app.update(cx -> {
            assertTrue(ButtonVariantTools.hovered(activeOnly, false, cx).fg.equals(INK));
            assertTrue(ButtonVariantTools.active(activeOnly, false, cx).fg.equals(GREEN));
            return null;
        });
    }

    function testTheRestingBackgroundIsDilutedByDefaultAndExactOnDemand() {
        final plain = Custom(custom());
        final exact = Custom(custom().exact());
        app.update(cx -> {
            final theme = Theme.global(cx);
            // gpui-kit's rule: 20 % of transparent mixed in
            final diluted = BLUE.mixOklab(theme.transparent, 0.2);
            assertFalse(diluted.equals(BLUE));
            assertTrue(solid(ButtonVariantTools.normal(plain, false, cx).bg).equals(diluted));
            assertTrue(solid(ButtonVariantTools.normal(plain, true, cx).bg).equals(diluted));
            assertFalse(ButtonVariantTools.normal(plain, true, cx).border.equals(BLUE));
            // exact: the colors as given
            assertTrue(solid(ButtonVariantTools.normal(exact, false, cx).bg).equals(BLUE));
            assertTrue(solid(ButtonVariantTools.normal(exact, true, cx).bg).equals(BLUE));
            assertTrue(ButtonVariantTools.normal(exact, false, cx).border.equals(BLUE));
            assertTrue(ButtonVariantTools.normal(exact, true, cx).border.equals(BLUE));
            // hover and active were already the given colors
            assertTrue(solid(ButtonVariantTools.hovered(plain, false, cx).bg).equals(RED));
            assertTrue(solid(ButtonVariantTools.active(plain, false, cx).bg).equals(GREEN));
            assertTrue(solid(ButtonVariantTools.hovered(exact, false, cx).bg).equals(RED));
            return null;
        });
    }

    function testEqualityCountsTheNewFields() {
        assertTrue(ButtonVariantTools.equals(Custom(custom()), Custom(custom())));
        assertTrue(ButtonVariantTools.equals(Custom(custom().hoverForeground(RED)), Custom(custom().hoverForeground(RED))));
        assertFalse(ButtonVariantTools.equals(Custom(custom().hoverForeground(RED)), Custom(custom())));
        assertFalse(ButtonVariantTools.equals(Custom(custom().hoverForeground(RED)), Custom(custom().hoverForeground(GREEN))));
        assertFalse(ButtonVariantTools.equals(Custom(custom().activeForeground(RED)), Custom(custom())));
        assertFalse(ButtonVariantTools.equals(Custom(custom().exact()), Custom(custom())));
    }

    /** A hovered custom button paints with its hover style: the scene of the default is unchanged by the new fields left unset. */
    function testAButtonWithoutTheNewFieldsDrawsTheSame() {
        final plain = open((_, cx) -> div().p(px(20.)).child(Button.component('b').label('Run').custom(new ButtonCustomVariant(cx.app).color(BLUE).foreground(INK).hover(RED))));
        final unset = open((_, cx) -> div().p(px(20.)).child(Button.component('b').label('Run').custom(new ButtonCustomVariant(cx.app).color(BLUE).foreground(INK).hover(RED).hoverForeground(null).activeForeground(null).exact(false))));
        assertEquals(sceneSignature(plain), sceneSignature(unset));
        final exact = open((_, cx) -> div().p(px(20.)).child(Button.component('b').label('Run').custom(new ButtonCustomVariant(cx.app).color(BLUE).foreground(INK).hover(RED).exact())));
        assertTrue(sceneSignature(plain) != sceneSignature(exact));
        assertTrue(quadsFilled(exact, BLUE).length > 0, 'the exact color fills the button');
        assertEquals(0, quadsFilled(plain, BLUE).length);
    }

}
