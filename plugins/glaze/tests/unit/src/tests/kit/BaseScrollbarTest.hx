// Ported from gpui-kit 0.8.1: crates/base/src/scrollbar.rs and crates/base/src/theme.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Axis;
import glaze.Background;
import glaze.Bounds;
import glaze.Context;
import glaze.Element;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Model;
import glaze.MouseButton;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Scrollbar;
import glaze.kit.base.theme.ScrollbarMode;
import glaze.kit.base.theme.ScrollbarTheme;
import glaze.kit.base.theme.Theme as BaseTheme;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tests of gpui-base's `scrollbar.rs` (and the scrollbar part of
 * `theme.rs`). Instants are `Float` seconds.
 */
class BaseScrollbarTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    /** Timing standing in for what a styled layer projects. */
    static inline final ENTER:Float = 0.3;

    static inline final EXIT:Float = 0.5;

    static inline final EXPAND:Float = 0.3;

    static inline final DEFAULT_IDLE:Float = ScrollbarMotion.DEFAULT_IDLE;

    static inline function bg(color:glaze.Hsla):Background {
        return (color : glaze.IntoBackground);
    }

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    function testThumbRadiusIsLimitedByItsActualBounds() {
        final verticalThumb = new Bounds(new Point(), new Size(8., 80.));
        final horizontalThumb = new Bounds(new Point(), new Size(80., 6.));
        assertEquals(4., @:privateAccess Scrollbar.clampThumbRadius(6., verticalThumb));
        assertEquals(3., @:privateAccess Scrollbar.clampThumbRadius(6., horizontalThumb));
        assertEquals(0., @:privateAccess Scrollbar.clampThumbRadius(0., verticalThumb));
    }

    function testVisibilityAnimationUsesDirectionSpecificCurvesAndDurations() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);

        @:privateAccess animation.setVisible(true, SlideAndFade, ENTER, EXIT, start);
        assertEquals(0., @:privateAccess animation.sample(start).opacity);
        final entering = @:privateAccess animation.sample(start + ENTER / 2).position;
        assertTrue(entering > 0.5, 'ease-out must advance quickly');
        final entered = @:privateAccess animation.sample(start + ENTER);
        assertEquals(1., entered.opacity);
        assertEquals(1., entered.position);

        @:privateAccess animation.setVisible(false, SlideAndFade, ENTER, EXIT, start + ENTER);
        final exiting = @:privateAccess animation.sample(start + ENTER + EXIT / 2).opacity;
        assertTrue(exiting > 0.5, 'ease-in must remain visible early in exit');
        assertEquals(0., @:privateAccess animation.sample(start + ENTER + EXIT).opacity);
    }

    function testEntranceFadesLinearlyWhilePositionEasesOut() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, SlideAndFade, ENTER, EXIT, start);

        final halfway = @:privateAccess animation.sample(start + ENTER / 2);
        assertTrue(Math.abs(halfway.opacity - 0.5) < 0.001);
        assertTrue(halfway.position > halfway.opacity);
    }

    function testFadeEntranceSnapsPositionAndAnimatesOpacity() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, Fade, ENTER, EXIT, start);

        final initial = @:privateAccess animation.sample(start);
        assertEquals(0., initial.opacity);
        assertEquals(1., initial.position);
        final halfway = @:privateAccess animation.sample(start + ENTER / 2);
        assertTrue(Math.abs(halfway.opacity - 0.5) < 0.001);
        assertEquals(1., halfway.position);
    }

    function testActiveVisibilityAdoptsAChangedEntrancePolicy() {
        final start = 10.;
        final halfway = start + ENTER / 2;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, SlideAndFade, ENTER, EXIT, start);
        final before = @:privateAccess animation.sample(halfway);

        @:privateAccess animation.setVisible(true, Fade, ENTER, EXIT, halfway);
        final after = @:privateAccess animation.sample(halfway);

        assertEquals(before.opacity, after.opacity, 'policy changes must not flash');
        assertEquals(1., after.position, 'fade entrance must stop stale sliding');
    }

    function testBaseShipsNoMotionOfItsOwn() {
        final motion = new ScrollbarMotion();
        assertEquals(0., motion.enter());
        assertEquals(0., motion.exit());
        assertEquals(0., motion.expand());
        assertEquals(Fade, motion.entrance());
        assertEquals(Fade, motion.thumbHoverEntrance());
        assertEquals(DEFAULT_IDLE, motion.idle(), 'the visibility hold is behavior, not motion, and must stay usable');
    }

    function testHoverModeSlidesOnlyWhenTheThumbIsHovered() {
        final motion = new ScrollbarMotion().withEntrance(Fade).withThumbHoverEntrance(SlideAndFade);
        assertEquals(Fade, @:privateAccess motion.entranceFor(Hover, false));
        assertEquals(SlideAndFade, @:privateAccess motion.entranceFor(Hover, true));
        assertEquals(Fade, @:privateAccess motion.entranceFor(Scrolling, true));
    }

    function testHiddenScrollingModeDoesNotTrackThumbHover() {
        assertFalse(@:privateAccess Scrollbar.tracksThumbHover(Scrolling, false));
        assertTrue(@:privateAccess Scrollbar.tracksThumbHover(Scrolling, true));
        assertTrue(@:privateAccess Scrollbar.tracksThumbHover(Hover, false));
    }

    function testVisibleScrollingModeStaysVisibleWhileHovered() {
        assertFalse(@:privateAccess Scrollbar.hoverKeepsVisible(Scrolling, true, false));
        assertTrue(@:privateAccess Scrollbar.hoverKeepsVisible(Scrolling, true, true));
        assertTrue(@:privateAccess Scrollbar.hoverKeepsVisible(Hover, true, false));
    }

    function testMotionlessBaseSnapsEveryTransition() {
        final now = 10.;
        final motion = new ScrollbarMotion();
        final visibility = @:privateAccess VisibilityAnimation.hidden(now);

        @:privateAccess visibility.setVisible(true, motion.entrance(), motion.enter(), motion.exit(), now);
        final shown = @:privateAccess visibility.sample(now);
        assertEquals(1., shown.opacity);
        assertEquals(1., shown.position);
        assertFalse(shown.running, 'a motionless theme must request no frames');
        assertTrue(@:privateAccess Scrollbar.visibilityTranslation(Vertical, 16., shown.position).equals(new Point()));

        @:privateAccess visibility.setVisible(false, motion.entrance(), motion.enter(), motion.exit(), now);
        final hidden = @:privateAccess visibility.sample(now);
        assertEquals(0., hidden.opacity);
        assertEquals(0., hidden.position);
        assertFalse(hidden.running);

        final width = @:privateAccess new WidthAnimation(now);
        final sample = @:privateAccess width.setTarget(8., motion.expand(), now);
        assertEquals(8., sample.value);
        assertFalse(sample.running);
    }

    function testAZeroDurationSettlesATransitionAlreadyInFlight() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, SlideAndFade, ENTER, EXIT, start);

        // Reduced motion turns on midway through the entrance.
        final midway = start + ENTER / 2;
        @:privateAccess animation.setVisible(true, SlideAndFade, 0., 0., midway);
        final settled = @:privateAccess animation.sample(midway);
        assertEquals(1., settled.opacity);
        assertEquals(1., settled.position);
        assertFalse(settled.running);
    }

    function testThumbExpansionAnimatesInBothDirections() {
        final start = 10.;
        final animation = @:privateAccess new WidthAnimation(start);
        final first = @:privateAccess animation.setTarget(6., EXPAND, start);
        assertEquals(6., first.value);
        assertFalse(first.running);

        final initial = @:privateAccess animation.setTarget(8., EXPAND, start);
        assertEquals(6., initial.value);
        assertTrue(initial.running);
        final expandedHalfway = @:privateAccess animation.sample(start + EXPAND / 2).value;
        assertTrue(expandedHalfway > 7.);

        final reversal = start + EXPAND / 2;
        final before = @:privateAccess animation.sample(reversal).value;
        final afterReversal = @:privateAccess animation.setTarget(6., EXPAND, reversal);
        assertEquals(before, afterReversal.value);
        assertTrue(afterReversal.running);
        assertEquals(6., @:privateAccess animation.sample(reversal + EXPAND).value);
    }

    function testReducedMotionSnapsThumbExpansion() {
        final now = 10.;
        final animation = @:privateAccess new WidthAnimation(now);
        final sample = @:privateAccess animation.setTarget(8., 0., now);
        assertEquals(8., sample.value);
        assertFalse(sample.running);
    }

    function testVisibilityTranslationMovesTowardTheNearestEdge() {
        assertTrue(@:privateAccess Scrollbar.visibilityTranslation(Vertical, 16., 0.).equals(new Point(16., 0.)));
        assertTrue(@:privateAccess Scrollbar.visibilityTranslation(Horizontal, 16., 0.).equals(new Point(0., 16.)));
        assertTrue(@:privateAccess Scrollbar.visibilityTranslation(Vertical, 16., 1.).equals(new Point()));
    }

    function testVisibilityAnimationReversesFromCurrentProgress() {
        final start = 10.;
        final animation = @:privateAccess VisibilityAnimation.hidden(start);
        @:privateAccess animation.setVisible(true, SlideAndFade, ENTER, EXIT, start);
        final reversalTime = start + 0.06;
        final before = @:privateAccess animation.sample(reversalTime);

        @:privateAccess animation.setVisible(false, SlideAndFade, ENTER, EXIT, reversalTime);
        final reversed = @:privateAccess animation.sample(reversalTime);
        assertEquals(before.opacity, reversed.opacity);
        assertEquals(before.position, reversed.position);
        final after = @:privateAccess animation.sample(reversalTime + 0.01);
        assertTrue(after.opacity < before.opacity);
        assertTrue(after.position < before.position);
    }

    function testAlwaysHoverDragAndRecentScrollRequestVisibility() {
        final now = 10.;
        final idle = DEFAULT_IDLE;
        assertTrue(@:privateAccess Scrollbar.wantsVisible(Always, false, false, null, idle, now));
        assertTrue(@:privateAccess Scrollbar.wantsVisible(Hover, true, false, null, idle, now));
        assertTrue(@:privateAccess Scrollbar.wantsVisible(Scrolling, false, true, null, idle, now));
        assertTrue(@:privateAccess Scrollbar.wantsVisible(Scrolling, false, false, now - idle + 0.001, idle, now));
        assertFalse(@:privateAccess Scrollbar.wantsVisible(Scrolling, false, false, now - idle, idle, now));

        final settled = @:privateAccess VisibilityAnimation.hidden(now - ENTER);
        @:privateAccess settled.setVisible(true, SlideAndFade, ENTER, EXIT, now - ENTER);
        assertFalse(@:privateAccess settled.sample(now).running, 'idle hold must not animate');
    }

    function testLeavingHoverStartsAFreshIdleHold() {
        final enteredAt = 10.;
        final leftAt = enteredAt + 5.;
        final state = @:privateAccess new ScrollbarState(enteredAt);

        @:privateAccess state.withHovered(Vertical, enteredAt);
        assertEquals(enteredAt, @:privateAccess state.lastScrollTime);
        @:privateAccess state.withHovered(null, leftAt);
        assertEquals(leftAt, @:privateAccess state.lastScrollTime);
        assertTrue(@:privateAccess Scrollbar.wantsVisible(Hover, false, false, state.lastScrollTime, DEFAULT_IDLE, leftAt + DEFAULT_IDLE - 0.001));
    }

    function testIdleBoundaryStartsTheExitWithoutAJump() {
        final activity = 10.;
        final exitStart = activity + DEFAULT_IDLE;
        final animation = @:privateAccess VisibilityAnimation.hidden(activity - ENTER);
        @:privateAccess animation.setVisible(true, Fade, ENTER, EXIT, activity - ENTER);
        assertFalse(@:privateAccess Scrollbar.wantsVisible(Scrolling, false, false, activity, DEFAULT_IDLE, exitStart));

        @:privateAccess animation.setVisible(false, Fade, ENTER, EXIT, exitStart);
        final start = @:privateAccess animation.sample(exitStart);
        assertEquals(1., start.opacity);
        assertEquals(1., start.position);
        assertEquals(0., @:privateAccess animation.sample(exitStart + EXIT).opacity);
    }

    /// Harnesses

    function harness(axis:ScrollbarAxis, mode:ScrollbarMode, contentSize:Size, ?scrollViewportSize:Size):{cx:VisualTestContext, handle:TestHandle} {
        final handle = new TestHandle(contentSize);
        final cx = open((_, _) -> {
            final scrollbar = new Scrollbar(handle).axis(axis).mode(mode);
            if (scrollViewportSize != null) {
                @:privateAccess scrollbar.scrollViewportSize(scrollViewportSize);
            }
            return div().relative().size(px(100.)).child(scrollbar);
        });
        return {cx: cx, handle: handle};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    function testThumbDragReachesContentEndWhenTrackIncludesPadding() {
        final h = harness(Vertical, Always, new Size(100., 160.), new Size(100., 80.));
        h.cx.simulateMouseDown(new Point(95., 20.), Left);
        draw(h.cx);
        h.cx.simulateMouseMove(new Point(95., 99.), Left);
        draw(h.cx);
        h.cx.simulateMouseUp(new Point(95., 99.), Left);
        assertEquals(-80., h.handle.offset().y);
    }

    function testExplicitViewportBoundsOverrideHandleBounds() {
        final expected = new Bounds(new Point(12., 24.), new Size(240., 96.));
        final scrollbar = Scrollbar.vertical(new TestHandle(new Size(240., 480.))).viewportBounds(expected);
        assertTrue(@:privateAccess scrollbar.resolvedViewportBounds(new Bounds()).equals(expected));
    }

    function testLayoutViewportUsesCurrentElementBounds() {
        final expected = new Bounds(new Point(20., 30.), new Size(180., 12.));
        final scrollbar = Scrollbar.horizontal(new TestHandle(new Size(600., 12.))).viewportFromLayout();
        assertTrue(@:privateAccess scrollbar.resolvedViewportBounds(expected).equals(expected));
    }

    function testTypedStylesAreFluentAndIncludeGeometry() {
        final track = hsla(0.1, 0.2, 0.3, 1.0);
        final border = hsla(0.2, 0.3, 0.4, 1.0);
        final thumb = hsla(0.3, 0.4, 0.5, 1.0);
        final hover = hsla(0.4, 0.5, 0.6, 1.0);
        final active = hsla(0.5, 0.6, 0.7, 1.0);
        final scrollbar = new Scrollbar(new TestHandle(new Size())).styles(styles -> styles
            .track(style -> style.width(14.).bg(track).borderColor(border).when(false, style -> style.width(99.)))
            .thumb(style -> style.width(7.).inset(3.).radius(3.5).minLength(40.).bg(thumb))
            .thumbHover(style -> style.width(9.).bg(hover))
            .thumbActive(style -> style.radius(4.5).bg(active)));

        final styles = @:privateAccess scrollbar._styles;
        assertTrue(track.equals(styles.trackStyle().backgroundValue()));
        assertTrue(border.equals(styles.trackStyle().borderValue()));
        assertEquals(14., styles.trackStyle().widthValue());
        assertNotNull(styles.thumbStyle().backgroundValue());
        assertEquals(7., styles.thumbStyle().widthValue());
        assertEquals(3., styles.thumbStyle().insetValue());
        assertEquals(3.5, styles.thumbStyle().radiusValue());
        assertEquals(40., styles.thumbStyle().minLengthValue());
        assertNotNull(styles.thumbHoverStyle().backgroundValue());
        assertEquals(9., styles.thumbHoverStyle().widthValue());
        assertNotNull(styles.thumbActiveStyle().backgroundValue());
        assertEquals(4.5, styles.thumbActiveStyle().radiusValue());
    }

    function testUnstyledThumbFollowsTheThemeRatherThanAFixedColour() {
        app.update(cx -> {
            final scrollbar = new Scrollbar(new TestHandle(new Size()));

            final light = hsla(0., 0., 0.04, 1.0);
            BaseTheme.globalMut(cx).tokens.colors.foreground = light;
            final onLight = @:privateAccess scrollbar.styleForNormal(cx).thumb;

            final dark = hsla(0., 0., 0.98, 1.0);
            BaseTheme.globalMut(cx).tokens.colors.foreground = dark;
            final onDark = @:privateAccess scrollbar.styleForNormal(cx).thumb;

            assertTrue(onLight.equals(bg(light.alpha(0.35))));
            assertTrue(onDark.equals(bg(dark.alpha(0.35))));
            // The point of the change: a thumb that never moved with the
            // palette was invisible on one of the two surfaces.
            assertFalse(onLight.equals(onDark));
            return null;
        });
    }

    function testAStyledThumbStillBeatsTheThemeDerivedDefault() {
        app.update(cx -> {
            final chosen = hsla(0.6, 0.5, 0.5, 1.0);
            BaseTheme.globalMut(cx).tokens.colors.foreground = hsla(0., 0., 0.98, 1.0);

            final scrollbar = new Scrollbar(new TestHandle(new Size())).styles(styles -> styles.thumb(style -> style.bg(chosen)));
            final thumb = @:privateAccess scrollbar.styleForNormal(cx).thumb;
            assertTrue(thumb.equals(bg(chosen)));
            return null;
        });
    }

    function testInstanceStylesOverrideThemeScrollbarDefaults() {
        app.update(cx -> {
            final themeTrack = hsla(0.1, 0.2, 0.3, 1.0);
            final themeThumb = hsla(0.2, 0.3, 0.4, 1.0);
            final instanceThumb = hsla(0.3, 0.4, 0.5, 1.0);

            BaseTheme.globalMut(cx).scrollbar = new ScrollbarTheme()
                .withMode(Always)
                .withMotion(new ScrollbarMotion())
                .withStyles(new ScrollbarStyles()
                    .track(style -> style.width(13.).bg(themeTrack))
                    .thumb(style -> style.width(7.).bg(themeThumb)));

            final scrollbar = new Scrollbar(new TestHandle(new Size())).styles(styles -> styles.thumb(style -> style.bg(instanceThumb)));
            final style = @:privateAccess scrollbar.styleForNormal(cx);

            assertTrue(style.thumb.equals(bg(instanceThumb)));
            assertTrue(style.track.equals(themeTrack));
            assertEquals(7., style.width);
            assertEquals(13., BaseTheme.global(cx).scrollbar.styles().trackStyle().widthValue());
            return null;
        });
    }

    function testAutoHideModesUseASixPixelRestingThumb() {
        app.update(cx -> {
            final handle = new TestHandle(new Size());
            final scrolling = new Scrollbar(handle).mode(Scrolling);
            final always = new Scrollbar(handle).mode(Always);
            assertEquals(6., @:privateAccess scrolling.styleForNormal(cx).width);
            assertEquals(6., @:privateAccess always.styleForNormal(cx).width);
            return null;
        });
    }

    function testEveryModeExpandsOnlyForThumbHover() {
        app.update(cx -> {
            final handle = new TestHandle(new Size());
            for (mode in [Scrolling, Hover, Always]) {
                final scrollbar = new Scrollbar(handle).mode(mode);
                assertEquals(6., @:privateAccess scrollbar.styleForNormal(cx).width);
                assertEquals(6., @:privateAccess scrollbar.styleForHoveredBar(cx).width);
                assertEquals(8., @:privateAccess scrollbar.styleForHoveredThumb(cx).width);
            }
            return null;
        });
    }

    function testVerticalTrackClickUpdatesVerticalOffset() {
        final h = harness(Vertical, Always, new Size(100., 500.));
        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().y < 0.);
        assertEquals(0., h.handle.offset().x);
    }

    function testHorizontalTrackClickUpdatesHorizontalOffset() {
        final h = harness(Horizontal, Always, new Size(500., 100.));
        h.cx.simulateClick(new Point(80., 95.));
        assertTrue(h.handle.offset().x < 0.);
        assertEquals(0., h.handle.offset().y);
    }

    function testNoOverflowHasNoInteractiveTrack() {
        final h = harness(Both, Always, new Size(100., 100.));
        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().equals(new Point()));
    }

    function testHiddenHoverScrollbarIgnoresTrackClick() {
        final h = harness(Vertical, Hover, new Size(100., 500.));
        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().equals(new Point()));
    }

    function testHiddenHoverScrollbarIgnoresThumbDrag() {
        final h = harness(Vertical, Hover, new Size(100., 500.));
        h.cx.simulateMouseDown(new Point(95., 20.), Left);
        h.cx.simulateMouseMove(new Point(95., 70.), Left);
        h.cx.simulateMouseUp(new Point(95., 70.), Left);
        assertEquals(0, h.handle.dragStarts);
        assertEquals(0, h.handle.dragEnds);
        assertTrue(h.handle.offset().equals(new Point()));
    }

    /** A vertical scrollbar with an occluding element over part of it, as a menu or dialog would be. */
    function coveredHarness(mode:ScrollbarMode, cover:Bounds):{cx:VisualTestContext, handle:TestHandle} {
        final handle = new TestHandle(new Size(100., 500.));
        final cx = open((_, _) -> div()
            .relative()
            .size(px(100.))
            .child(new Scrollbar(handle).axis(Vertical).mode(mode))
            .child(div()
                .absolute()
                .left(px(cover.left()))
                .top(px(cover.top()))
                .w(px(cover.size.width))
                .h(px(cover.size.height))
                .occlude()));
        return {cx: cx, handle: handle};
    }

    function testAPressOnAnElementOverTheTrackIsLeftToIt() {
        final cover = new Bounds(new Point(50., 60.), new Size(50., 40.));
        final h = coveredHarness(Always, cover);
        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().equals(new Point()));

        // The track left uncovered still takes a press.
        h.cx.simulateClick(new Point(95., 50.));
        assertTrue(h.handle.offset().y < 0.);
    }

    function testHoveringAnElementOverAHoverScrollbarDoesNotRevealIt() {
        final cover = new Bounds(new Point(50., 0.), new Size(50., 50.));
        final h = coveredHarness(Hover, cover);
        h.cx.simulateMouseMove(new Point(95., 20.));
        h.cx.runUntilParked();

        // Uncovered, but the bar never showed, so it takes no press.
        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().equals(new Point()));
    }

    function testHoveringRevealsScrollbarForTrackInteraction() {
        final h = harness(Vertical, Hover, new Size(100., 500.));
        // Base ships no motion, so the reveal is immediate.
        h.cx.simulateMouseMove(new Point(95., 50.));
        h.cx.runUntilParked();

        h.cx.simulateClick(new Point(95., 80.));
        assertTrue(h.handle.offset().y < 0.);
    }

    /// Hover while scrolling (the port's default mode, DEV-020)

    /**
     * A vertical `Hover` scrollbar over a 100 px scroll area of 500 px of
     * content, the pointer never over the bar strip (x from 94 to 100).
     */
    function scrollAreaHarness():{cx:VisualTestContext, view:glaze.Entity<ScriptView>, handle:glaze.ScrollHandle, bar:BarHolder} {
        final handle = new glaze.ScrollHandle();
        final bar = new BarHolder();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> {
            final scrollbar = new Scrollbar(handle).axis(Vertical).mode(Hover);
            bar.scrollbar = scrollbar;
            return div()
                .relative()
                .size(px(100.))
                .child(div().id('content').size(px(100.)).overflowYScroll().trackScroll(handle).child(div().wFull().h(px(500.))))
                .child(scrollbar);
        }));
        contexts.push(opened.cx);
        draw(opened.cx);
        return {cx: opened.cx, view: opened.view, handle: handle, bar: bar};
    }

    /** Whether the vertical bar of the last drawn frame is shown. */
    static function barShown(bar:BarHolder):Bool {
        final states = @:privateAccess bar.scrollbar.states;
        if (states.length == 0) return false;
        final state = states[0];
        return state.visibilityRequested && state.visibilityOpacity > 0.;
    }

    /** The bar hides once the idle hold after the last scroll is over. */
    function assertHidesAfterTheIdleHold(cx:VisualTestContext, bar:BarHolder):Void {
        cx.advanceClock(DEFAULT_IDLE - 0.1);
        cx.runUntilParked();
        draw(cx);
        assertTrue(barShown(bar), 'still shown within the idle hold');
        cx.advanceClock(0.1);
        cx.runUntilParked();
        draw(cx);
        assertFalse(barShown(bar), 'hidden after the idle hold');
    }

    function testHoverRevealsTheBarForAWheelOutsideTheBarStrip() {
        final h = scrollAreaHarness();
        assertFalse(barShown(h.bar));
        h.cx.simulateEvent(new glaze.ScrollEvent(new Point(30., 50.), glaze.ScrollDelta.Pixels(new Point(0., -40.))));
        draw(h.cx);
        assertEquals(-40., h.handle.offset().y);
        assertTrue(barShown(h.bar));
        assertHidesAfterTheIdleHold(h.cx, h.bar);
    }

    function testHoverRevealsTheBarForAProgrammaticScroll() {
        final h = scrollAreaHarness();
        assertFalse(barShown(h.bar));
        h.handle.setOffset(new Point(0., -120.));
        h.cx.update((_, cx) -> cx.notify(h.view.entityId()));
        h.cx.runUntilParked();
        draw(h.cx);
        assertTrue(barShown(h.bar));
        assertHidesAfterTheIdleHold(h.cx, h.bar);
    }

    function testHoverRevealsTheBarForAKeyboardDrivenListScroll() {
        final handle = new glaze.UniformListScrollHandle();
        final bar = new BarHolder();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> {
            final scrollbar = new Scrollbar(handle).axis(Vertical).mode(Hover);
            bar.scrollbar = scrollbar;
            return div()
                .relative()
                .size(px(100.))
                .child(uniformList('rows', 50, (start, end, _, _) -> [for (ix in start...end) div().id(ix).h(px(20.))])
                    .trackScroll(handle)
                    .size(px(100.)))
                .child(scrollbar);
        }));
        final cx = opened.cx;
        contexts.push(cx);
        draw(cx);
        assertFalse(barShown(bar));

        // What a key handler moving a selection does: scroll the row into
        // view and notify the view
        handle.scrollToItem(30, glaze.ScrollStrategy.Top);
        cx.update((_, app) -> app.notify(opened.view.entityId()));
        cx.runUntilParked();
        draw(cx);
        assertTrue(handle.state.baseHandle.offset().y < 0.);
        // The list applies the deferred scroll at its own layout: the bar
        // sees the new offset at the latest on the frame after
        if (!barShown(bar)) draw(cx);
        assertTrue(barShown(bar));
        assertHidesAfterTheIdleHold(cx, bar);
    }

    function testDragNotificationsAreThrottledAndDeliverTheLatestOffset() {
        final handle = new TestHandle(new Size(100., 1000.));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> div()
            .relative()
            .size(px(100.))
            .child(new Scrollbar(handle).axis(Vertical).mode(Always))));
        final cx = opened.cx;
        contexts.push(cx);
        draw(cx);
        final observed:Array<Float> = [];
        final subscription = cx.update((_, app) -> app.observe(opened.view, (_, _) -> observed.push(handle.offset().y)));
        final now = dispatcher.now();
        final state = @:privateAccess new ScrollbarState(now);
        final interval = 1. / 30.;
        @:privateAccess state.withDragPos(Vertical, new Point(), now);
        @:privateAccess state.lastUpdate = now;
        final viewId = opened.view.entityId();
        function update(offset:Float, elapsed:Float) {
            handle.setOffset(new Point(0., offset));
            cx.update((window, app) -> @:privateAccess state.notifyDrag(now + elapsed, interval, viewId, window, app));
            cx.runUntilParked();
        }
        update(-10., 0.);
        cx.advanceClock(0.016);
        update(-20., 0.016);
        update(-30., 0.016);
        // Rendering at 120 Hz must not bypass the configured 30 Hz timer.
        cx.update((window, app) -> window.simulateNextFrame(app));
        cx.runUntilParked();
        assertEquals(0, observed.length);
        cx.advanceClock(0.016);
        cx.runUntilParked();
        assertEquals(0, observed.length);
        cx.advanceClock(0.002);
        cx.runUntilParked();
        assertEquals('[-30]', '[' + observed.join(',') + ']', 'one trailing notification must see the newest offset even when movement stops');

        // A second burst gets its own interval, and release invalidates its timer.
        final next = @:privateAccess state.lastUpdate;
        handle.setOffset(new Point(0., -40.));
        cx.update((window, app) -> @:privateAccess state.notifyDrag(next, interval, viewId, window, app));
        cx.runUntilParked();
        @:privateAccess state.withUnsetDragPos(dispatcher.now());
        handle.setOffset(new Point(0., -50.));
        cx.update((_, app) -> app.notify(viewId));
        assertEquals('[-30,-50]', '[' + observed.join(',') + ']');
        cx.advanceClock(interval);
        cx.runUntilParked();
        assertEquals('[-30,-50]', '[' + observed.join(',') + ']', 'release must not leave a stale trailing notification');
        subscription.dispose();
    }

    function testFullTrackThumbDoesNotResetTheScrollOffset() {
        final geometry = new ThumbGeometry(20., 40., 40., 500., 0., 4., 64.);
        final offset = new Point(0., -100.);
        assertTrue(geometry.dragOffset(Vertical, new Point(0., 50.), new Point(0., 8.), offset).equals(offset));
    }

    function testThumbGeometryMapsContentViewportToPaddedTrack() {
        final geometry = new ThumbGeometry(20., 96., 80., 160., 0., 0., 0.);

        assertEquals(48., geometry.length);
        assertEquals(48., geometry.travel);
        assertEquals(80., geometry.extent);
        assertEquals(-80., geometry.offset(68., 0.));

        final barelyOverflowing = new ThumbGeometry(20., 96., 80., 85., 0., 0., 0.);
        assertEquals(5., barelyOverflowing.extent);
        assertTrue(barelyOverflowing.travel > 0.);
        assertEquals(-5., barelyOverflowing.offset(20. + barelyOverflowing.travel, 0.));
    }

    /**
     * The mouse half of `repeated_touch_and_mouse_drags_keep_the_painted_grab_point`
     * (the port has no touch input).
     */
    function testRepeatedTouchAndMouseDragsKeepThePaintedGrabPoint() {
        for (touch in [true, false]) for (vertical in [true, false]) {
            for (config in [{origin: new Point(), viewport: 200., content: 1000.}, {origin: new Point(30., 40.), viewport: 240., content: 500.}]) {
                final handle = new TestHandle(new Size(config.content, config.content));
                handle.setOffset(new Point(-100., -100.));
                final painted = new PaintedProbe();
                final axis:ScrollbarAxis = vertical ? Vertical : Both;
                final viewport = new Bounds(config.origin, new Size(config.viewport, config.viewport));
                final cx = open((_, _) -> div().size(px(400.)).child(new ProbeElement(new Scrollbar(handle)
                    .axis(axis)
                    .mode(Always)
                    .viewportBounds(viewport)
                    .styles(style -> style
                        .thumb(style -> style.inset(6.).minLength(64.))
                        .thumbActive(style -> style.inset(3.).minLength(72.))), painted)));
                draw(cx);
                final initial = painted.bounds;
                final start = initial.center();
                final grab = vertical ? start.y - initial.origin.y : start.x - initial.origin.x;
                inline function axisDelta(value:Float):Point {
                    return vertical ? new Point(0., value) : new Point(value, 0.);
                }
                inline function axisValue(point:Point):Float {
                    return vertical ? point.y : point.x;
                }
                final startedPosition = touch ? start.add(axisDelta(5.)) : start;
                if (touch) {
                    cx.simulateEvent(new glaze.TouchDragEvent(Started, start, startedPosition));
                }
                else {
                    cx.simulateMouseDown(start, Left);
                }
                draw(cx);
                assertTrue(Math.abs(axisValue(painted.bounds.origin) + grab - axisValue(startedPosition)) < 0.1, 'starting must preserve the grab point and first displacement');
                var referenceOffset = 0.;
                var offsetPerPixel = 0.;
                for (delta in [0., 24., -8., 32., -10., 8., 0.]) {
                    final position = start.add(axisDelta(delta));
                    if (touch) {
                        cx.simulateEvent(new glaze.TouchDragEvent(Moved, start, position));
                    }
                    else {
                        cx.simulateMouseMove(position, Left);
                    }
                    draw(cx);
                    if (delta == 0.) {
                        referenceOffset = axisValue(handle.offset());
                    }
                    if (delta == 24.) {
                        offsetPerPixel = (axisValue(handle.offset()) - referenceOffset) / 24.;
                    }
                    final actual = (vertical ? painted.bounds.origin.y : painted.bounds.origin.x) + grab;
                    final expected = vertical ? position.y : position.x;
                    assertTrue(Math.abs(actual - expected) < 0.1, 'touch=$touch vertical=$vertical delta=$delta: painted grab $actual, pointer $expected');
                }
                // Release contains a final displacement without an intervening move.
                final expectedOffset = referenceOffset + 12. * offsetPerPixel;
                if (touch) {
                    cx.simulateEvent(new glaze.TouchDragEvent(Ended, start, start.add(axisDelta(12.))));
                }
                else {
                    cx.simulateMouseUp(start.add(axisDelta(12.)), Left);
                }
                assertTrue(Math.abs(axisValue(handle.offset()) - expectedOffset) < 0.1, 'release must flush the last displacement');
                final releasedOffset = handle.offset();
                draw(cx);
                assertTrue(handle.offset().equals(releasedOffset), 'leaving active styling must not scroll');
            }
        }
    }

    function testTouchThumbDragMovesDownAndCancelReleasesHandle() {
        final h = harness(Vertical, Always, new Size(100., 500.));
        final startPosition = new Point(95., 20.);
        h.cx.simulateEvent(new glaze.TouchDragEvent(Started, startPosition, startPosition));
        h.cx.simulateEvent(new glaze.TouchDragEvent(Moved, startPosition, new Point(95., 45.)));
        h.cx.simulateEvent(new glaze.TouchDragEvent(Cancelled, startPosition, new Point(95., 45.)));
        assertTrue(h.handle.offset().y < 0., 'thumb down must scroll toward later content');
        assertEquals(0., h.handle.offset().x);
        assertEquals(1, h.handle.dragStarts);
        assertEquals(1, h.handle.dragEnds);
    }

    function testThumbDragNotifiesHandleStartAndEnd() {
        final h = harness(Vertical, Always, new Size(100., 500.));
        h.cx.simulateMouseDown(new Point(95., 20.), Left);
        h.cx.simulateMouseMove(new Point(95., 70.), Left);
        h.cx.simulateMouseUp(new Point(95., 70.), Left);
        assertEquals(1, h.handle.dragStarts);
        assertEquals(1, h.handle.dragEnds);
    }

    /// theme.rs

    function testScrollbarThemeSupportsBuilderConstruction() {
        final mode = ScrollbarMode.Hover;
        final motion = new ScrollbarMotion().withEnter(0.12);
        final styles = new ScrollbarStyles();
        final theme = new ScrollbarTheme().withMode(mode).withMotion(motion).withStyles(styles);
        assertEquals(mode, theme.mode());
        assertTrue(theme.motion().equals(motion));
        assertEquals(styles, theme.styles());
    }

}

/** The scrollbar element of the last render. */
class BarHolder {

    public var scrollbar:Null<Scrollbar> = null;

    public function new() {}

}

/**
 * A scroll handle over a fixed content size (Rust `TestHandle`).
 */
class TestHandle implements ScrollbarHandleImpl {

    var _offset:Point = new Point();

    final _contentSize:Size;

    public var dragStarts:Int = 0;

    public var dragEnds:Int = 0;

    public function new(contentSize:Size) {
        _contentSize = contentSize;
    }

    public function viewportBounds():Bounds {
        return new Bounds(new Point(), new Size(100., 100.));
    }

    public function offset():Point {
        return _offset;
    }

    public function setOffset(offset:Point):Void {
        _offset = offset;
    }

    public function contentSize():Size {
        return _contentSize;
    }

    public function startDrag():Void {
        dragStarts++;
    }

    public function endDrag():Void {
        dragEnds++;
    }

}

/** The painted thumb bounds of a `ProbeElement`. */
class PaintedProbe {

    public var bounds:Bounds = new Bounds();

    public function new() {}

}

/**
 * Wraps a scrollbar and records its first axis' painted thumb bounds
 * (the `Probe` element of the Rust test).
 */
class ProbeElement extends Element {

    final scrollbar:Scrollbar;

    final painted:PaintedProbe;

    public function new(scrollbar:Scrollbar, painted:PaintedProbe) {
        this.scrollbar = scrollbar;
        this.painted = painted;
    }

    override public function elementId() {
        return scrollbar.elementId();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return scrollbar.requestLayout(id, window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        scrollbar.prepaint(id, bounds, window, cx);
        painted.bounds = @:privateAccess scrollbar.states[0].thumbFillBounds;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        scrollbar.paint(id, bounds, window, cx);
    }

}
