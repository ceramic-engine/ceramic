// Ported from gpui-pre 0.3.10: src/window.rs and src/app/test_app.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Size;
import gpui.TestDispatcher;
import gpui.Window;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Scale factor changes (Rust `Window::bounds_changed`, window.rs:2803): the
 * platform window reports a new scale factor through its resize callback,
 * the window takes it, redraws everything and calls its bounds observers.
 *
 * `testScaleFactorChangePreservesViewportAndSurvivesResize` and
 * `testSimulateScaleFactorChange` are Rust
 * `test_scale_factor_change_preserves_bounds_and_survives_resize` and
 * `test_simulate_scale_factor_change` (`window.bounds()` is not ported: the
 * viewport size is checked). The platform window of a window opened with a
 * `scaleFactor` is a test window whose scale factor `simulateScaleFactorChange`
 * changes; a window opened without one follows the density of the Ceramic
 * screen, whose changes are simulated on the headless screen.
 */
class WindowScaleFactorTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    var initialDensity:Float = 1;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
        // The headless screens have different densities (1 on node, the
        // display's on native): every test starts at 1
        initialDensity = ceramic.App.app.screen.density;
        setScreenDensity(1);
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        restoreScreenDensity(initialDensity);
        ceramic.App.app.flushImmediate();
    }

    function open(?scaleFactor:Float, ?renderToTexture:Bool, render:(Window, Context<Dynamic>) -> IntoElement):Entity<ScaleTestView> {
        var view:Entity<ScaleTestView> = null;
        window = Window.open(app, {width: 200, height: 100, scaleFactor: scaleFactor, autoDraw: false, bindInput: false, renderToTexture: renderToTexture}, (window, cx) -> {
            view = cx.newEntity((_:Context<ScaleTestView>) -> new ScaleTestView(render));
            return view;
        });
        return view;
    }

    /** Rust `TestWindow::simulate_scale_factor_change`: the test platform window reports a new scale factor */
    static function simulateScaleFactorChange(window:Window, scaleFactor:Float):Void {
        @:privateAccess window.fixedScaleFactor = scaleFactor;
        // Rust `simulate_resize(size)` with the same logical size
        window.resize(window.viewportSize().width, window.viewportSize().height);
    }

    /** The headless screen reports a new density (browser zoom, another display): Ceramic emits `resize` */
    static function setScreenDensity(density:Float):Void {
        final screen = ceramic.App.app.screen;
        @:privateAccess screen.density = density;
        @:privateAccess screen.emitResize();
    }

    static function restoreScreenDensity(density:Float):Void {
        final screen = ceramic.App.app.screen;
        if (screen.density != density) {
            // Recomputed from the headless backend
            @:privateAccess screen.resize();
        }
    }

    /** Rust `test_scale_factor_change_preserves_bounds_and_survives_resize` */
    function testScaleFactorChangePreservesViewportAndSurvivesResize() {
        open(2, (_, _) -> div());
        assertEquals(2.0, window.scaleFactor());
        var expectedSize = window.viewportSize();

        for (step in [{scale: 1.0, w: 800.0, h: 600.0}, {scale: 1.25, w: 640.0, h: 480.0}, {scale: 2.0, w: 1024.0, h: 768.0}]) {
            simulateScaleFactorChange(window, step.scale);
            assertEquals(step.scale, window.scaleFactor());
            assertTrue(window.viewportSize().equals(expectedSize));

            window.resize(step.w, step.h);
            expectedSize = new Size(step.w, step.h);
            assertEquals(step.scale, window.scaleFactor());
            assertTrue(window.viewportSize().equals(expectedSize));
        }
    }

    /** Rust `test_simulate_scale_factor_change` (test_app.rs) */
    function testSimulateScaleFactorChange() {
        open(2, (_, _) -> div());
        final viewportSize = window.viewportSize();
        simulateScaleFactorChange(window, 1.0);
        assertEquals(1.0, window.scaleFactor());
        assertTrue(window.viewportSize().equals(viewportSize));
    }

    function testWindowFollowsScreenDensity() {
        open((_, _) -> div().size(px(50)).bg(red()));
        assertEquals(1.0, window.scaleFactor());
        window.draw();
        assertEquals(50.0, window.renderedScene().quads[0].boundsWidth);
        assertFalse(window.dirty);

        setScreenDensity(2);
        assertEquals(2.0, window.scaleFactor());
        assertTrue(window.dirty, 'a new scale factor redraws the window');
        // The frame drawn at the old scale is not shown at the new one
        assertEquals(1.0, window.renderable.sceneScale);

        window.draw();
        assertEquals(100.0, window.renderedScene().quads[0].boundsWidth);
        assertEquals(2.0, window.renderable.sceneScale);

        // Back to 1: the size in logical pixels never changed
        setScreenDensity(1);
        assertEquals(1.0, window.scaleFactor());
        window.draw();
        assertEquals(50.0, window.renderedScene().quads[0].boundsWidth);
        assertTrue(window.viewportSize().equals(new Size(200, 100)));
    }

    function testScaledQuadsAfterDensityChange() {
        open((_, _) -> div().p(px(10)).child(div().size(px(30)).roundedMd().bg(blue())));
        window.draw();
        final before = window.renderedScene().quads[0];
        assertEquals(10.0, before.boundsX);
        assertEquals(30.0, before.boundsWidth);
        assertEquals(6.0, before.cornerRadiusTopLeft);

        setScreenDensity(1.5);
        window.draw();
        final after = window.renderedScene().quads[0];
        assertEquals(15.0, after.boundsX);
        assertEquals(45.0, after.boundsWidth);
        assertEquals(9.0, after.cornerRadiusTopLeft);
    }

    function testFixedScaleFactorIgnoresScreenDensity() {
        open(2, (_, _) -> div().size(px(50)).bg(red()));
        window.draw();
        setScreenDensity(3);
        assertEquals(2.0, window.scaleFactor());
        assertFalse(window.dirty);
    }

    function testGlyphsRasterizedAtTheNewScale() {
        open((_, _) -> div().textColor(red()).fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).child('H'));
        window.draw();
        final sprite1 = window.renderedScene().monochromeSprites[0];
        final tileHeight1 = sprite1.tileHeight;
        final boundsHeight1 = sprite1.boundsHeight;
        // The scenes are reused: keep the values
        final tile1 = [sprite1.tileX, sprite1.tileY, sprite1.textureIndex];
        assertTrue(tileHeight1 > 0);

        setScreenDensity(2);
        window.draw();
        final sprites = window.renderedScene().monochromeSprites;
        assertEquals(1, sprites.length);
        final sprite2 = sprites[0];
        // A new tile rasterized at scale 2, not the tile of scale 1
        assertTrue(sprite2.tileHeight >= tileHeight1 * 2 - 2 && sprite2.tileHeight <= tileHeight1 * 2 + 2, 'tile ${sprite2.tileHeight} for ${tileHeight1} at scale 1');
        assertTrue(sprite2.boundsHeight >= boundsHeight1 * 2 - 2, 'bounds ${sprite2.boundsHeight} for ${boundsHeight1} at scale 1');
        // Both tiles stay in the atlas, each under its own scale (Rust keys glyph tiles by `RenderGlyphParams`)
        assertFalse(tile1[0] == sprite2.tileX && tile1[1] == sprite2.tileY && tile1[2] == sprite2.textureIndex);
    }

    function testBoundsObserversOnScaleFactorChangeAndResize() {
        final view = open((_, _) -> div());
        var calls = 0;
        var observedScale = 0.0;
        final subscription = view.update(app, (_, cx) -> cx.observeWindowBounds(window, (_, window, _) -> {
            calls++;
            observedScale = window.scaleFactor();
        }));
        setScreenDensity(2);
        assertEquals(1, calls);
        assertEquals(2.0, observedScale);
        // Same density: nothing changed
        setScreenDensity(2);
        assertEquals(1, calls);
        window.resize(300, 200);
        assertEquals(2, calls);
        subscription.dispose();
        window.resize(310, 200);
        assertEquals(2, calls);
    }

    function testRenderTextureResizedToTheNewPixelSize() {
        open(null, true, (_, _) -> div().size(px(50)).bg(red()));
        window.draw();
        final renderable = window.renderable;
        @:privateAccess renderable.computeContent();
        final texture1:ceramic.RenderTexture = @:privateAccess renderable.targetTexture;
        assertTrue(texture1 != null);
        assertEquals(1.0, texture1.density);

        setScreenDensity(2);
        window.draw();
        @:privateAccess renderable.computeContent();
        final texture2:ceramic.RenderTexture = @:privateAccess renderable.targetTexture;
        assertEquals(2.0, texture2.density);
        assertEquals(400.0, Math.round(texture2.width * texture2.density));
        assertEquals(200.0, Math.round(texture2.height * texture2.density));
    }

}

private class ScaleTestView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}
