// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Hsla;
import glaze.kit.switch_.Switch;
import glaze.kit.theme.Theme;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The switch additions without upstream equivalent (KIT-032): a focus ring
 * of its own.
 */
class KitSwitchAdditionsTest extends KitAdditionsTestCase {

    static final ACCENT = hsla(0.6, 0.8, 0.5, 0.4);

    /** A large switch at (20, 20), focused when `focused`. */
    function switchWindow(configure:(Switch) -> Switch, focused:Bool, themeRing:Bool = true):VisualTestContext {
        Theme.update(app, theme -> theme.focusRing = themeRing);
        final cx = open((_, _) -> div().id('root').tabGroup().p(px(20.)).child(probe('switch', configure(Switch.component('switch').withSize(glaze.kit.Size.Large)))));
        if (focused) {
            cx.update((window, app) -> window.focusNext(app));
            rerender(cx);
        }
        draw(cx);
        return cx;
    }

    /** The quads whose border has `color`, in logical pixels, with their border width. */
    function borders(cx:VisualTestContext, color:Hsla):Array<{bounds:Bounds, width:Float, radius:Float}> {
        final scale = cx.update((window, _) -> window.scaleFactor());
        return [for (entry in quads(cx)) {
            final q = entry.quad;
            if (q.borderWidthTop > 0. && Math.abs(q.borderColorH - color.h) < 0.0001 && Math.abs(q.borderColorS - color.s) < 0.0001
                && Math.abs(q.borderColorL - color.l) < 0.0001 && Math.abs(q.borderColorA - color.a) < 0.0001)
                {bounds: entry.bounds, width: q.borderWidthTop / scale, radius: q.cornerRadiusTopLeft / scale};
            else continue;
        }];
    }

    /** `borders`, one entry per box (GPUI paints a border as four quads, one per side). */
    function rings(cx:VisualTestContext, color:Hsla):Array<{bounds:Bounds, width:Float, radius:Float}> {
        final result:Array<{bounds:Bounds, width:Float, radius:Float}> = [];
        for (entry in borders(cx, color)) {
            var seen = false;
            for (other in result) if (near(other.bounds, entry.bounds)) seen = true;
            if (!seen) result.push(entry);
        }
        return result;
    }

    function testOwnFocusRingDrawsTheGivenRingOutsideTheTrack() {
        final track = new Bounds(new glaze.Point(20., 20.), new glaze.Size(44., 24.));
        for (themeRing in [true, false]) {
            // focused: 2 px of the color around the 44 x 24 track
            final cx = switchWindow(s -> s.ownFocusRing(px(2.), ACCENT), true, themeRing);
            final rings = this.rings(cx, ACCENT);
            assertEquals(1, rings.length, 'theme ring $themeRing');
            assertTrue(near(rings[0].bounds, new Bounds(new glaze.Point(18., 18.), new glaze.Size(48., 28.))), '${rings[0].bounds}');
            assertEquals(2., rings[0].width);
            // the track's own border is not tinted with the theme's ring
            final ring = cx.update((_, app) -> Theme.global(app).ring);
            assertEquals(0, borders(cx, ring).length);
            // an offset moves it out
            final apart = this.rings(switchWindow(s -> s.ownFocusRing(px(2.), ACCENT, px(3.)), true, themeRing), ACCENT);
            assertEquals(1, apart.length);
            assertTrue(near(apart[0].bounds, new Bounds(new glaze.Point(15., 15.), new glaze.Size(54., 34.))), '${apart[0].bounds}');
            // not focused: none
            assertEquals(0, borders(switchWindow(s -> s.ownFocusRing(px(2.), ACCENT), false, themeRing), ACCENT).length);
            // the switch's own `focusRing(false)` still turns it off
            assertEquals(0, borders(switchWindow(s -> s.ownFocusRing(px(2.), ACCENT).focusRing(false), true, themeRing), ACCENT).length);
        }
        // the track itself does not move
        final plain = boundsOf(switchWindow(s -> s, true), 'switch');
        final own = boundsOf(switchWindow(s -> s.ownFocusRing(px(2.), ACCENT), true), 'switch');
        assertTrue(near(plain, own));
        assertTrue(near(new Bounds(new glaze.Point(20., 20.), new glaze.Size(44., 24.)), new Bounds(own.origin, new glaze.Size(44., 24.))));
        Theme.update(app, theme -> theme.focusRing = true);
    }

    function testWithoutOwnFocusRingTheThemeDecides() {
        // the theme's ring: the border tinted with `ring`, the halo outside
        final cx = switchWindow(s -> s, true, true);
        final ring = cx.update((_, app) -> Theme.global(app).ring);
        assertTrue(borders(cx, ring).length > 0);
        Theme.update(app, theme -> theme.focusRing = true);
    }


    // KIT-044: a thumb color for each state, a custom size

    /** A switch at (20, 20). */
    function plainSwitch(configure:(Switch) -> Switch):VisualTestContext {
        final cx = open((_, _) -> div().p(px(20.)).flex().itemsStart().child(probe('switch', configure(Switch.component('switch')))));
        draw(cx);
        return cx;
    }

    function testACustomSizeIsTheHeightOfTheTrack() {
        // 14 high: 26 wide, a thumb of 10 two pixels inside
        final custom:glaze.kit.Size = Size(px(14.));
        final cx = plainSwitch(s -> s.withSize(custom).thumbColor(hsla(0.1, 0.9, 0.5, 1.)));
        final track = boundsOf(cx, 'switch');
        assertEquals(26., (track.size.width : Float));
        assertEquals(14., (track.size.height : Float));
        final thumbs = quadsFilled(cx, hsla(0.1, 0.9, 0.5, 1.));
        assertEquals(1, thumbs.length);
        assertTrue(near(thumbs[0].bounds, new Bounds(new glaze.Point(22., 22.), new glaze.Size(10., 10.))), '${thumbs[0].bounds}');
        // The named sizes are as before
        assertEquals(36., (boundsOf(plainSwitch(s -> s), 'switch').size.width : Float));
        assertEquals(28., (boundsOf(plainSwitch(s -> s.withSize(glaze.kit.Size.Small)), 'switch').size.width : Float));
    }

    function testTheThumbHasAColorForEachState() {
        final off = hsla(0.1, 0.9, 0.5, 1.);
        final on = hsla(0.4, 0.9, 0.5, 1.);
        // Off: the first color
        var cx = plainSwitch(s -> s.thumbColor(off, on));
        assertEquals(1, quadsFilled(cx, off).length);
        assertEquals(0, quadsFilled(cx, on).length);
        // On: the second one
        cx = plainSwitch(s -> s.checked(true).thumbColor(off, on));
        assertEquals(0, quadsFilled(cx, off).length);
        assertEquals(1, quadsFilled(cx, on).length);
        // On, with a color for off only: the color of the theme
        cx = plainSwitch(s -> s.checked(true).thumbColor(off));
        assertEquals(0, quadsFilled(cx, off).length);
    }

}
