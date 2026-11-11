// Original code for Glaze (not a port): tests of the scrollbar appearance setting (DEV-023).
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.Point;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Scrollbar;
import glaze.kit.base.ScrollbarAppearance;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.base.theme.Theme as BaseTheme;
import glaze.kit.theme.Theme;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.scroll.Scrollable;

/**
 * How kit scrollbars show, hide and react to hover (`ScrollbarAppearance`,
 * deviation DEV-023): the default quick fade in place without thumb growth,
 * the instant and gpui-kit options, durations, and the global (kit theme)
 * and per scrollbar settings. Independent of the golden, which forces
 * gpui-kit's behaviour (define `glaze_scrollbar_appearance: gpuikit`).
 *
 * Every harness is a vertical scrollbar over a 100 px area of 500 px of
 * content: the track is x 84 to 100, the resting thumb x 90 to 96 (6 px, 4 px
 * from the edge), y 4 to 44 at the top; the hovered gpui-kit thumb is 8 px
 * wide (x 88 to 96).
 */
class ScrollbarAppearanceTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    static inline final IDLE:Float = 2.;

    static inline final EPSILON:Float = 0.01;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
        Theme.init(app);
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    static function advance(cx:VisualTestContext, seconds:Float):Void {
        cx.advanceClock(seconds);
        draw(cx);
    }

    function harness(mode:ScrollbarMode, ?appearance:ScrollbarAppearance):AppearanceHarness {
        final h = new AppearanceHarness();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> {
            final scrollbar = new Scrollbar(h.handle).axis(Vertical).mode(mode);
            if (appearance != null) scrollbar.appearance(appearance);
            h.scrollbar = scrollbar;
            return div()
                .relative()
                .size(px(100.))
                .child(div().id('content').size(px(100.)).overflowYScroll().trackScroll(h.handle).child(div().wFull().h(px(500.))))
                .child(scrollbar);
        }));
        h.cx = opened.cx;
        h.app = app;
        contexts.push(opened.cx);
        draw(opened.cx);
        return h;
    }

    /** A wheel over the content, away from the bar strip. */
    static function wheel(h:AppearanceHarness):Void {
        h.cx.simulateEvent(new ScrollEvent(new Point(30., 50.), Pixels(new Point(0., -10.))));
        draw(h.cx);
    }

    static function setAppearance(appearance:ScrollbarAppearance, cx:App):Void {
        Theme.setScrollbarAppearance(appearance, cx);
    }

    /// Defaults

    function testTheDefaultIsAQuickFadeInPlaceWithoutThumbGrowth() {
        final appearance = ScrollbarAppearance.defaultValue();
        assertEquals(ScrollbarTransition.Fade, appearance.transition);
        assertFalse(appearance.thumbGrowth);
        assertEquals(0.12, appearance.resolvedShowDuration());
        assertEquals(0.12, appearance.resolvedHideDuration());
        assertEquals(0., appearance.resolvedGrowthDuration());
        assertTrue(Theme.global(app).scrollbarAppearance.equals(ScrollbarAppearance.fade()));
        assertTrue(BaseTheme.global(app).scrollbar.appearance().equals(ScrollbarAppearance.fade()));
    }

    function testPresetsAndBuilders() {
        final instant = ScrollbarAppearance.instant();
        assertEquals(ScrollbarTransition.Instant, instant.transition);
        assertEquals(0., instant.resolvedShowDuration());
        assertEquals(0., instant.resolvedHideDuration());
        assertFalse(instant.thumbGrowth);

        final kit = ScrollbarAppearance.gpuiKit();
        assertEquals(ScrollbarTransition.GpuiKit, kit.transition);
        assertTrue(kit.thumbGrowth);
        assertEquals(0.3, kit.resolvedShowDuration());
        assertEquals(0.5, kit.resolvedHideDuration());
        assertEquals(0.3, kit.resolvedGrowthDuration());

        final custom = ScrollbarAppearance.fade().withShowDuration(0.05).withHideDuration(0.4);
        assertEquals(0.05, custom.resolvedShowDuration());
        assertEquals(0.4, custom.resolvedHideDuration());
        final both = custom.withDuration(0.2);
        assertEquals(0.2, both.resolvedShowDuration());
        assertEquals(0.2, both.resolvedHideDuration());
        assertEquals(0.25, ScrollbarAppearance.fade(0.25).resolvedHideDuration());
        assertEquals(0.12, both.withDuration(null).resolvedShowDuration(), 'null gives the transition its own duration back');
        // Values are immutable
        assertEquals(0.05, custom.resolvedShowDuration());
        assertTrue(ScrollbarAppearance.fade().withThumbGrowth(true).thumbGrowth);
        assertFalse(ScrollbarAppearance.fade().equals(ScrollbarAppearance.fade().withThumbGrowth(true)));
        assertEquals(ScrollbarTransition.Instant, ScrollbarAppearance.fade().withTransition(Instant).transition);
    }

    /**
     * gpui-kit's preset gives exactly the motion the kit theme projects
     * (gpui-kit's `scrollbar_motion`), so the golden, which forces it, stays
     * gpui-kit's.
     */
    function testTheGpuiKitPresetMatchesTheProjectedMotion() {
        final kit = ScrollbarAppearance.gpuiKit();
        for (mode in [Scrolling, Hover, Always]) {
            final motion = @:privateAccess Theme.scrollbarMotion(mode);
            assertEquals(motion.enter(), kit.resolvedShowDuration());
            assertEquals(motion.exit(), kit.resolvedHideDuration());
            assertEquals(motion.expand(), kit.resolvedGrowthDuration());
        }
    }

    /// Fade (the default)

    function testTheDefaultFadeShowsAndHidesWithOpacityOnly() {
        final h = harness(Scrolling);
        assertFalse(h.shown());
        wheel(h);
        final x = h.thumbX();
        assertTrue(Math.abs(h.opacity()) < EPSILON, 'the fade starts transparent');
        assertEquals(1., h.position(), 'no slide in');
        advance(h.cx, 0.06);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'linear fade in: ${h.opacity()}');
        assertEquals(x, h.thumbX());
        advance(h.cx, 0.06);
        assertEquals(1., h.opacity());

        // Hide after the idle hold: a linear fade, in place
        advance(h.cx, IDLE - 0.12);
        assertTrue(h.opacity() > 1. - EPSILON, 'starts hiding at the end of the hold');
        advance(h.cx, 0.03);
        assertTrue(Math.abs(h.opacity() - 0.75) < EPSILON, 'linear fade out: ${h.opacity()}');
        assertEquals(1., h.position(), 'no slide out');
        assertTrue(@:privateAccess Scrollbar.visibilityTranslation(Vertical, 16., h.position()).equals(new Point()));
        assertEquals(x, h.thumbX());
        advance(h.cx, 0.03);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'linear fade out: ${h.opacity()}');
        assertEquals(1., h.position());
        advance(h.cx, 0.06);
        assertEquals(0., h.opacity());
        assertFalse(h.shown());
    }

    function testTheDefaultFadeKeepsTheThumbWidthOnHoverAndDrag() {
        final h = harness(Hover);
        h.cx.simulateMouseMove(new Point(93., 20.));
        draw(h.cx);
        assertTrue(Math.abs(h.opacity()) < EPSILON, 'the fade starts transparent');
        assertEquals(1., h.position(), 'pointing at the hidden thumb fades it in place');
        assertEquals(6., h.thumbWidth());
        assertEquals(90., h.thumbX());
        advance(h.cx, 0.06);
        assertEquals(1., h.position(), 'no slide in');
        advance(h.cx, 0.44);
        assertTrue(h.shown());
        assertEquals(6., h.thumbWidth(), 'no growth on hover');
        assertEquals(90., h.thumbX());
        assertTrue(@:privateAccess h.scrollbar.scrollbarState.hoveredOnThumb != null);

        h.cx.simulateMouseDown(new Point(93., 20.), Left);
        draw(h.cx);
        advance(h.cx, 0.5);
        assertEquals(6., h.thumbWidth(), 'no growth while dragged');
        assertEquals(90., h.thumbX());
        h.cx.simulateMouseMove(new Point(93., 60.), Left);
        draw(h.cx);
        assertTrue(h.handle.offset().y < 0., 'the drag still scrolls');
        h.cx.simulateMouseUp(new Point(93., 60.), Left);
        draw(h.cx);
        assertEquals(6., h.thumbWidth());
    }

    function testFadeDurationsAreConfigurableGlobally() {
        setAppearance(ScrollbarAppearance.fade().withShowDuration(0.2).withHideDuration(0.4), app);
        final h = harness(Scrolling);
        wheel(h);
        advance(h.cx, 0.1);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'half of a 0.2 s fade in: ${h.opacity()}');
        advance(h.cx, 0.1);
        assertEquals(1., h.opacity());
        advance(h.cx, IDLE - 0.2);
        advance(h.cx, 0.2);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'half of a 0.4 s fade out: ${h.opacity()}');
        assertEquals(1., h.position());
        advance(h.cx, 0.2);
        assertEquals(0., h.opacity());

        // One value for both
        setAppearance(ScrollbarAppearance.fade(0.3), app);
        wheel(h);
        advance(h.cx, 0.15);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'half of a 0.3 s fade in: ${h.opacity()}');
    }

    /// Instant

    function testInstantShowsAndHidesInOneFrame() {
        setAppearance(ScrollbarAppearance.instant(), app);
        final h = harness(Scrolling);
        assertFalse(h.shown());
        wheel(h);
        assertEquals(1., h.opacity(), 'fully visible in the frame it appears');
        assertEquals(1., h.position());
        assertFalse(h.running());
        advance(h.cx, IDLE - 0.01);
        assertEquals(1., h.opacity(), 'still fully visible just before the end of the hold');
        advance(h.cx, 0.01);
        assertEquals(0., h.opacity(), 'gone in the frame it hides');
        assertFalse(h.shown());
        assertFalse(h.running());
    }

    function testInstantKeepsTheThumbWidthOnHover() {
        setAppearance(ScrollbarAppearance.instant(), app);
        final h = harness(Hover);
        h.cx.simulateMouseMove(new Point(93., 20.));
        draw(h.cx);
        assertEquals(1., h.opacity());
        assertEquals(6., h.thumbWidth());
        advance(h.cx, 0.5);
        assertEquals(6., h.thumbWidth());
    }

    /// gpui-kit (option)

    function testGpuiKitSlidesOutAndGrowsOnHover() {
        setAppearance(ScrollbarAppearance.gpuiKit(), app);
        final h = harness(Scrolling);
        wheel(h);
        assertTrue(Math.abs(h.opacity()) < EPSILON);
        assertEquals(1., h.position(), 'a scroll fades it in place');
        advance(h.cx, 0.15);
        assertTrue(Math.abs(h.opacity() - 0.5) < EPSILON, 'linear fade in over 0.3 s: ${h.opacity()}');
        advance(h.cx, 0.15);
        assertEquals(1., h.opacity());

        // Hover the thumb: it grows from 6 to 8 px over 0.3 s
        h.cx.simulateMouseMove(new Point(93., 20.));
        draw(h.cx);
        advance(h.cx, 0.3);
        assertEquals(8., h.thumbWidth());
        assertEquals(88., h.thumbX());
        h.cx.simulateMouseMove(new Point(30., 20.));
        draw(h.cx);
        advance(h.cx, 0.3);
        assertEquals(6., h.thumbWidth());

        // Hide after the idle hold: ease-in fade over 0.5 s while sliding right
        advance(h.cx, IDLE - 0.3);
        advance(h.cx, 0.25);
        assertTrue(h.opacity() > 0.5, 'ease-in keeps it visible early: ${h.opacity()}');
        assertTrue(h.position() < 1., 'slides out');
        final translation = @:privateAccess Scrollbar.visibilityTranslation(Vertical, 16., h.position());
        assertTrue(translation.x > 0., 'toward the right edge');
        advance(h.cx, 0.25);
        assertEquals(0., h.opacity());
    }

    function testGpuiKitSlidesInWhenPointingAtTheHiddenThumbInHoverMode() {
        setAppearance(ScrollbarAppearance.gpuiKit(), app);
        final h = harness(Hover);
        h.cx.simulateMouseMove(new Point(93., 20.));
        draw(h.cx);
        advance(h.cx, 0.15);
        assertTrue(h.position() < 1., 'slides in: ${h.position()}');
        assertTrue(h.opacity() > 0.);
    }

    /// Thumb growth alone, global setting changes

    function testThumbGrowthCanBeTurnedOnWithTheFade() {
        setAppearance(ScrollbarAppearance.fade().withThumbGrowth(true), app);
        final h = harness(Hover);
        h.cx.simulateMouseMove(new Point(93., 20.));
        draw(h.cx);
        advance(h.cx, 0.3);
        assertEquals(8., h.thumbWidth());
        h.cx.simulateMouseMove(new Point(30., 20.));
        draw(h.cx);
        advance(h.cx, 0.3);
        assertEquals(6., h.thumbWidth());
        // Leaving the bar starts the idle hold, then a fade in place
        advance(h.cx, IDLE - 0.3);
        advance(h.cx, 0.06);
        assertTrue(Math.abs(h.opacity() - 0.5) < 0.1, 'fading: ${h.opacity()}');
        assertEquals(1., h.position(), 'no slide out');
    }

    function testTheGlobalSettingCanChangeAtRuntimeAndSurvivesThemeChanges() {
        final h = harness(Scrolling);
        setAppearance(ScrollbarAppearance.instant(), app);
        draw(h.cx);
        wheel(h);
        assertEquals(1., h.opacity());

        Theme.setMode(Dark, app);
        assertEquals(ScrollbarTransition.Instant, Theme.global(app).scrollbarAppearance.transition);
        assertEquals(ScrollbarTransition.Instant, BaseTheme.global(app).scrollbar.appearance().transition);

        setAppearance(null, app);
        assertTrue(Theme.global(app).scrollbarAppearance.equals(ScrollbarAppearance.defaultValue()), 'null restores the default');
    }

    function testAlwaysModeAndReducedMotionStaySnapped() {
        final h = harness(Always);
        assertEquals(1., h.opacity(), 'an always visible bar shows at once');
        assertFalse(h.running());

        app.setReduceMotion(true);
        final r = harness(Scrolling);
        wheel(r);
        assertEquals(1., r.opacity(), 'reduced motion shows at once');
        advance(r.cx, IDLE);
        assertEquals(0., r.opacity(), 'and hides at once');
        app.setReduceMotion(false);
    }

    /// Per scrollbar settings

    function testAScrollbarOverridesTheGlobalAppearance() {
        setAppearance(ScrollbarAppearance.gpuiKit(), app);
        final h = harness(Scrolling, ScrollbarAppearance.instant());
        wheel(h);
        assertEquals(1., h.opacity(), 'instant on this scrollbar');
        advance(h.cx, IDLE);
        assertEquals(0., h.opacity());

        setAppearance(ScrollbarAppearance.fade(), app);
        final g = harness(Hover, ScrollbarAppearance.gpuiKit());
        g.cx.simulateMouseMove(new Point(93., 20.));
        draw(g.cx);
        advance(g.cx, 0.3);
        assertEquals(8., g.thumbWidth(), 'gpui-kit growth on this scrollbar');

        final f = harness(Scrolling, ScrollbarAppearance.fade(0.4));
        wheel(f);
        advance(f.cx, 0.2);
        assertTrue(Math.abs(f.opacity() - 0.5) < EPSILON, 'this scrollbar fades in over 0.4 s: ${f.opacity()}');
    }

    /**
     * `Scrollable.scrollbarAppearance` reaches its scrollbar: under the
     * default fade, an instant scrollable paints its thumb at full alpha in
     * the frame of the scroll.
     */
    function testAScrollableTakesAnAppearance() {
        function render(appearance:Null<ScrollbarAppearance>):VisualTestContext {
            final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> {
                final scrollable = div().size(px(100.)).overflowYScrollbar().id('scrollable').child(div().wFull().h(px(500.)).flexShrink0());
                if (appearance != null) scrollable.scrollbarAppearance(appearance);
                return div().size(px(100.)).child(scrollable);
            }));
            contexts.push(opened.cx);
            draw(opened.cx);
            opened.cx.simulateEvent(new ScrollEvent(new Point(30., 50.), Pixels(new Point(0., -10.))));
            draw(opened.cx);
            return opened.cx;
        }
        final instant = render(ScrollbarAppearance.instant());
        final alpha = thumbAlpha(instant);
        assertTrue(alpha > 0., 'instant: painted in the frame of the scroll');
        instant.advanceClock(0.5);
        draw(instant);
        assertEquals(alpha, thumbAlpha(instant), 'already at full alpha');

        final fade = render(null);
        assertTrue(thumbAlpha(fade) < EPSILON, 'the default fade starts transparent');
        fade.advanceClock(0.5);
        draw(fade);
        assertTrue(Math.abs(thumbAlpha(fade) - alpha) < 1e-4, 'then reaches the same alpha');
    }

    /**
     * The alpha of the painted resting thumb (6 px wide at x 90, in device
     * pixels in the scene), 0 when not painted.
     */
    static function thumbAlpha(cx:VisualTestContext):Float {
        final scale = cx.window.scaleFactor();
        var result = 0.;
        for (quad in cx.window.renderedScene().quads) {
            if (Math.abs(quad.boundsX - 90. * scale) < 1e-3 && Math.abs(quad.boundsWidth - 6. * scale) < 1e-3) {
                result = Math.max(result, quad.backgroundSolidA);
            }
        }
        return result;
    }

    /// Visibility animation

    function testAFadeOutHoldsItsPositionAndIsLinear() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, Fade, 0.12, 0.12, start, false);
        @:privateAccess animation.setVisible(false, Fade, 0.12, 0.12, start + 0.12, false);
        final half = @:privateAccess animation.sample(start + 0.18);
        assertTrue(Math.abs(half.opacity - 0.5) < 0.001, 'linear: ${half.opacity}');
        assertEquals(1., half.position);
        assertTrue(half.running);
        final done = @:privateAccess animation.sample(start + 0.24);
        assertEquals(0., done.opacity);
        assertFalse(done.running);

        // gpui-kit's exit (the default of `setVisible`) eases in and slides
        @:privateAccess animation.setVisible(true, Fade, 0.12, 0.12, start + 1, true);
        @:privateAccess animation.setVisible(false, Fade, 0.12, 0.12, start + 1.12, true);
        final kit = @:privateAccess animation.sample(start + 1.18);
        assertTrue(kit.opacity > 0.8, 'ease-in: ${kit.opacity}');
        assertTrue(kit.position < 1.);
    }

}

private class AppearanceHarness {

    public final handle:ScrollHandle = new ScrollHandle();

    public var scrollbar:Null<Scrollbar> = null;

    public var cx:Null<VisualTestContext> = null;

    public var app:Null<App> = null;

    public function new() {}

    function state():Null<AxisPrepaintState> {
        final states = @:privateAccess scrollbar.states;
        return states.length > 0 ? states[0] : null;
    }

    public function opacity():Float {
        return state().visibilityOpacity;
    }

    public function position():Float {
        return state().visibilityPosition;
    }

    public function shown():Bool {
        final s = state();
        return s != null && s.visibilityRequested && s.visibilityOpacity > 0.;
    }

    public function running():Bool {
        final animation = @:privateAccess scrollbar.scrollbarState.visibility;
        final now = app.backgroundExecutor().now();
        return @:privateAccess animation.sample(now).running;
    }

    public function thumbWidth():Float {
        return state().thumbFillBounds.size.width;
    }

    public function thumbX():Float {
        return state().thumbFillBounds.origin.x;
    }

}
