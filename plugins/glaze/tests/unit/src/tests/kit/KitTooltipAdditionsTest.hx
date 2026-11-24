// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Hsla;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.theme.Theme;
import glaze.kit.tooltip.Tooltip;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tooltip additions without upstream equivalent: colors of its own, a
 * gap and an arrow (KIT-040), a tooltip shown for a gesture (KIT-041).
 */
class KitTooltipAdditionsTest extends KitAdditionsTestCase {

    static final BUBBLE = hsla(0.75, 0.6, 0.3, 1.);

    /** The area the tooltips of these tests describe. */
    static final AREA = new Bounds(new glaze.Point(200., 200.), new glaze.Size(40., 20.));

    /** An empty window in a kit root, whose tooltips have a color of their own. */
    function tooltipWindow(configure:(Theme) -> Void):VisualTestContext {
        Theme.update(app, theme -> {
            theme.tooltipBackground = BUBBLE;
            configure(theme);
        });
        return open((_, _) -> div().sizeFull(), 800, 600, true);
    }

    function show(cx:VisualTestContext, placement:Placement):Void {
        cx.update((window, app) -> Tooltip.showAt(AREA, 'Frame 12', window, app, placement));
        // The tooltip slides in: wait for it to be in place
        for (_ in 0...30) nextFrame(cx);
    }

    /** The popup of the tooltip shown: the largest quad of its color. */
    function bubble(cx:VisualTestContext):Null<Bounds> {
        var found:Null<Bounds> = null;
        for (entry in quadsFilled(cx, BUBBLE)) {
            if (found == null || (entry.bounds.size.width : Float) > (found.size.width : Float)) found = entry.bounds;
        }
        return found;
    }

    function paths(cx:VisualTestContext):Int {
        return cx.update((window, _) -> window.renderedScene().paths.length);
    }

    function testATooltipIsShownForAnAreaAndHidden() {
        final cx = tooltipWindow(_ -> {});
        assertNull(bubble(cx));
        show(cx, Placement.Right);
        final shown = bubble(cx);
        assertNotNull(shown, 'shown at once, without a hover');
        // To the right of the area, at its height
        assertTrue((shown.origin.x : Float) >= 240.);
        assertTrue(Math.abs((shown.center().y : Float) - 210.) < 1.5, '${shown.center().y}');
        cx.update((window, app) -> Tooltip.hideShown(window, app));
        for (_ in 0...30) nextFrame(cx);
        assertNull(bubble(cx));
    }

    function testTheGapIsTheDistanceToTheArea() {
        // The theme is the one of every window: each distance is read before the next one is set
        final near = tooltipWindow(theme -> theme.tooltipGap = 4.);
        show(near, Placement.Right);
        final nearX:Float = bubble(near).origin.x;
        final far = tooltipWindow(theme -> theme.tooltipGap = 14.);
        show(far, Placement.Right);
        final farX:Float = bubble(far).origin.x;
        assertEquals(10., farX - nearX);
        // 4 pixels from the right edge of the area, which is at 240
        assertTrue(Math.abs(nearX - 244.) <= 0.5, '$nearX');
    }

    function testTheArrowIsDrawnOnlyWhenAsked() {
        final plain = tooltipWindow(_ -> {});
        show(plain, Placement.Right);
        assertEquals(0, paths(plain));
        final arrowed = tooltipWindow(theme -> theme.tooltipArrow = true);
        show(arrowed, Placement.Right);
        assertTrue(paths(arrowed) > 0, 'a triangle aimed at the area');
        // The popup itself has the same size
        assertEquals((bubble(plain).size.width : Float), (bubble(arrowed).size.width : Float));
        assertEquals((bubble(plain).size.height : Float), (bubble(arrowed).size.height : Float));
    }

}
