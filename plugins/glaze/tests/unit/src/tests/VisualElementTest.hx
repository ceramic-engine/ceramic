package tests;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.ObjectFit;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.VisualElement;
import glaze.Window;
import glaze.platform.SceneRenderable;
import glaze.scene.PolychromeSprite;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * `visual()` elements (Ceramic visuals in a Glaze window, specific to the
 * Haxe port) and the redraw of the render textures a scene shows when
 * their content changes (`RenderTexture.renderVersion`,
 * `SceneRenderable.checkExternalTextures()`).
 *
 * On node (headless backend), nothing is rendered: the render versions are
 * incremented by the tests, like the renderer does once per frame it draws
 * into a texture. The native run renders for real (`asyncTest*`).
 */
class VisualElementTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    var host:Null<glaze.Glaze> = null;

    var view:Null<VisualTestView> = null;

    var initialGrace:Int = 120;

    final created:Array<ceramic.Entity> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        initialGrace = VisualElement.gracePeriodFrames;
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        VisualElement.gracePeriodFrames = initialGrace;
        if (host != null) {
            host.destroy();
            host = null;
        }
        else if (window != null) {
            window.destroy();
        }
        window = null;
        view = null;
        for (entity in created) {
            if (!entity.destroyed) entity.destroy();
        }
        created.resize(0);
        ceramic.App.app.flushImmediate();
    }

    /** A Glaze visual of `width` x `height` at the screen origin, drawn on demand */
    function open(width:Float, height:Float, render:(Window, Context<Dynamic>) -> IntoElement, ?scaleFactor:Float):Window {
        host = new glaze.Glaze((window, cx) -> {
            final entity = cx.newEntity((_:Context<VisualTestView>) -> new VisualTestView(render));
            view = entity;
            return entity;
        }, {width: width, height: height, autoDraw: false, scaleFactor: scaleFactor, renderToTexture: true}, app);
        host.pos(0, 0);
        // Mounted, like a Glaze visual of an app's scene
        ceramic.App.app.screen.add(host);
        window = host.window;
        window.draw();
        return window;
    }

    function quad(width:Float, height:Float):ceramic.Quad {
        final q = new ceramic.Quad();
        q.size(width, height);
        q.color = ceramic.Color.RED;
        created.push(q);
        return q;
    }

    function renderTexture(width:Float, height:Float):ceramic.RenderTexture {
        final texture = new ceramic.RenderTexture(width, height, 1);
        created.push(texture);
        return texture;
    }

    /** Polychrome sprites of the last drawn frame */
    function sprites():Array<PolychromeSprite> {
        return window.renderedScene().polychromeSprites;
    }

    function target():ceramic.RenderTexture {
        if (@:privateAccess window.renderable.targetTexture == null) @:privateAccess window.renderable.computeContent();
        return @:privateAccess window.renderable.targetTexture;
    }

    /**
     * What a Ceramic frame does before drawing (without rendering on node):
     * computes the content (textures), the matrices and the touchable and
     * visible states of the visuals.
     */
    function ceramicFrame():Void {
        final ceramicApp = ceramic.App.app;
        @:privateAccess ceramicApp.computeHierarchy();
        @:privateAccess ceramicApp.updateVisuals(ceramicApp.visuals);
    }

    /** What Ceramic does after drawing the frame: the texture is clean */
    function finishCeramicDraw():Void {
        target().renderDirty = false;
    }

    static function emitMouse(kind:String, x:Float, y:Float):Void {
        final screen = ceramic.App.app.screen;
        switch kind {
            case 'down': @:privateAccess screen.emitMouseDown(0, x, y);
            case 'up': @:privateAccess screen.emitMouseUp(0, x, y);
            case 'move': @:privateAccess screen.emitMouseMove(x, y);
        }
    }

#if clay
/// Real rendering (native and web builds)

    /** Opens like `open()` (density 1), then lets Ceramic draw a few frames */
    function openDrawn(width:Float, height:Float, render:(Window, Context<Dynamic>) -> IntoElement, next:() -> Void):Void {
        open(width, height, render, 1);
        afterFrames(3, next);
    }

    /** Calls `next` after `count` Ceramic frames were drawn */
    function afterFrames(count:Int, next:() -> Void):Void {
        final owner = new ceramic.Entity();
        created.push(owner);
        var remaining = count;
        ceramic.App.app.onFinishDraw(owner, () -> {
            remaining--;
            if (remaining == 0) {
                owner.destroy();
                next();
            }
        });
    }

    /** The color of the window texture at `x, y` (window pixels, density 1), as 0xAARRGGBB */
    function pixelAt(x:Int, y:Int):Int {
        final texture = target();
        final width = Std.int(texture.nativeWidthActual);
        final height = Std.int(texture.nativeHeightActual);
        final pixels = new ceramic.UInt8Array(width * height * 4);
        texture.fetchPixels(pixels);
        // Rows are bottom up in the window texture (see `SceneTargetDrawer`), except on Unity
        final row = #if unity y #else Std.int(texture.nativeHeight) - 1 - y #end;
        final i = (row * width + x) * 4;
        return (pixels[i + 3] << 24) | (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
    }

    function resetPartialStats():Void {
        SceneRenderable.partialStatsDraws = 0;
        SceneRenderable.partialStatsPartialDraws = 0;
        SceneRenderable.partialStatsFullDraws = 0;
        SceneRenderable.partialStatsArea = 0;
        SceneRenderable.partialStatsTotalArea = 0;
        SceneRenderable.partialStatsRects = 0;
        SceneRenderable.partialVerifiedFrames = 0;
        SceneRenderable.partialMismatchedFrames = 0;
        SceneRenderable.partialFirstMismatch = null;
    }

    function asyncTestAnimatedVisualRedrawsOnlyItsRectangle(done:() -> Void) {
        SceneRenderable.verifyPartialRendering = true;
        final content = quad(40, 40);
        content.color = ceramic.Color.RED;
        openDrawn(100, 100, (_, _) -> div().sizeFull().pl(px(30.)).pt(px(30.)).child(visual(content).size(px(40.))), () -> {
            SceneRenderable.verifyPartialRendering = false;
            assertEquals(0xFFFF0000, pixelAt(50, 50));
            assertEquals(0, pixelAt(10, 10));
            final draws = window.drawCount;
            resetPartialStats();
            content.color = ceramic.Color.BLUE;
            afterFrames(3, () -> {
                assertEquals(0xFF0000FF, pixelAt(50, 50));
                // No view rendered, the rectangle of the sprite only (plus one pixel)
                assertEquals(draws, window.drawCount);
                assertTrue(SceneRenderable.partialStatsDraws > 0);
                assertEquals(0, SceneRenderable.partialStatsFullDraws);
                assertTrue(SceneRenderable.partialStatsArea <= SceneRenderable.partialStatsDraws * 42 * 42,
                    'redrawn ${SceneRenderable.partialStatsArea} pixels in ${SceneRenderable.partialStatsDraws} draws');
                // Same bytes as a full redraw
                assertTrue(SceneRenderable.partialVerifiedFrames > 0);
                assertEquals(0, SceneRenderable.partialMismatchedFrames, SceneRenderable.partialFirstMismatch);
                done();
            });
        });
    }

    function asyncTestRendererIncrementsRenderVersion(done:() -> Void) {
        final texture = renderTexture(8, 8);
        texture.autoRender = false;
        final q = quad(8, 8);
        q.renderTarget = texture;
        afterFrames(2, () -> {
            final version = texture.renderVersion;
            // Nothing drawn into it: unchanged
            afterFrames(2, () -> {
                assertEquals(version, texture.renderVersion);
                texture.renderDirty = true;
                afterFrames(1, () -> {
                    assertEquals(version + 1, texture.renderVersion);
                    // Auto rendering: once per frame
                    texture.autoRender = true;
                    afterFrames(1, () -> {
                        final auto = texture.renderVersion;
                        afterFrames(3, () -> {
                            assertEquals(auto + 3, texture.renderVersion);
                            done();
                        });
                    });
                });
            });
        });
    }

    function asyncTestImgOfAStampedRenderTextureIsRedrawn(done:() -> Void) {
        final texture = renderTexture(20, 20);
        texture.autoRender = false;
        final red = quad(20, 20);
        red.color = ceramic.Color.RED;
        red.active = false;
        final green = quad(20, 20);
        green.color = ceramic.Color.LIME;
        green.active = false;
        texture.stamp(red, () -> {
            openDrawn(60, 60, (_, _) -> div().sizeFull().pl(px(20.)).pt(px(20.)).child(img(texture).size(px(20.))), () -> {
                assertEquals(0xFFFF0000, pixelAt(30, 30));
                final draws = window.drawCount;
                texture.stamp(green, () -> {
                    afterFrames(2, () -> {
                        assertEquals(0xFF00FF00, pixelAt(30, 30));
                        assertEquals(draws, window.drawCount);
                        done();
                    });
                });
            });
        });
    }

    function asyncTestExplicitVisualRendersOnRequest(done:() -> Void) {
        final content = quad(40, 40);
        content.color = ceramic.Color.RED;
        openDrawn(100, 100, (_, _) -> div().sizeFull().pl(px(30.)).pt(px(30.)).child(visual(content).size(px(40.)).renderMode(Explicit)), () -> {
            final filter:ceramic.Filter = cast content.parent.parent;
            assertEquals(0xFFFF0000, pixelAt(50, 50));
            final version = filter.renderTexture.renderVersion;
            content.color = ceramic.Color.BLUE;
            afterFrames(3, () -> {
                // Not rendered at rest
                assertEquals(version, filter.renderTexture.renderVersion);
                assertEquals(0xFFFF0000, pixelAt(50, 50));
                VisualElement.renderNow(content, () -> {
                    afterFrames(2, () -> {
                        assertEquals(0xFF0000FF, pixelAt(50, 50));
                        done();
                    });
                });
            });
        });
    }

#end

/// RenderTexture.renderVersion

    function testRenderVersionChangesAcrossTheIntegerLimit() {
        final texture = renderTexture(4, 4);
        texture.renderVersion = 2147483646;
        var previous = texture.renderVersion;
        for (_ in 0...4) {
            texture.renderVersion++;
            assertTrue(texture.renderVersion != previous, 'each increment is a change, even when it wraps');
            previous = texture.renderVersion;
        }
        assertTrue(texture.renderVersion != 2147483646);
    }

    function testExternalTextureChangeAcrossTheIntegerLimitIsDrawn() {
        final texture = renderTexture(20, 10);
        texture.autoRender = false;
        texture.renderDirty = false;
        texture.renderVersion = 2147483647;
        open(100, 50, (_, _) -> div().sizeFull().child(img(texture).w(px(20.)).h(px(10.))));
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        assertFalse(window.renderable.checkExternalTextures());
        // Wraps to the smallest Int on hxcpp and C#, grows on JS: a change either way
        texture.renderVersion++;
        assertTrue(window.renderable.checkExternalTextures());
        assertTrue(target().renderDirty);
    }

/// External render textures of img()

    function testImgOfARenderTextureIsDrawnAgainWhenItsContentChanges() {
        final texture = renderTexture(20, 10);
        texture.autoRender = false;
        texture.renderDirty = false;
        open(100, 50, (_, _) -> div().sizeFull().child(img(texture).w(px(20.)).h(px(10.))));
        assertEquals(1, sprites().length);
        finishCeramicDraw();
        // The renderable's texture was drawn with the current version
        @:privateAccess window.renderable.recordExternalVersions();
        final draws = window.drawCount;
        final redraws = SceneRenderable.externalTextureRedraws;

        // Nothing changed: nothing to draw
        assertFalse(window.renderable.checkExternalTextures());
        assertFalse(target().renderDirty);

        // The renderer drew into the texture: the window texture is drawn
        // again, without any view render or layout
        texture.renderVersion++;
        assertTrue(window.renderable.checkExternalTextures());
        assertTrue(target().renderDirty);
        assertEquals(draws, window.drawCount);
        assertEquals(redraws + 1, SceneRenderable.externalTextureRedraws);

        // Drawn: clean again
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        assertFalse(window.renderable.checkExternalTextures());

        // About to be drawn this frame (renderDirty, autoRender): drawn too
        texture.renderDirty = true;
        assertTrue(window.renderable.checkExternalTextures());
        finishCeramicDraw();
        texture.renderDirty = false;
        texture.autoRender = true;
        assertTrue(window.renderable.checkExternalTextures());
        assertEquals(draws, window.drawCount);
    }

    function testTexturesNotShownAreNotChecked() {
        final shown = renderTexture(20, 10);
        shown.autoRender = false;
        shown.renderDirty = false;
        final other = renderTexture(20, 10);
        other.autoRender = true;
        open(100, 50, (_, _) -> div().sizeFull().child(img(shown).w(px(20.)).h(px(10.))));
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        other.renderVersion++;
        assertFalse(window.renderable.checkExternalTextures());
        // Without render to texture, the scene is drawn at every frame anyway
        window.renderable.renderToTexture = false;
        shown.renderVersion++;
        assertFalse(window.renderable.checkExternalTextures());
    }

    function testCheckedOncePerFrameByTheSystem() {
        final texture = renderTexture(20, 10);
        texture.autoRender = false;
        texture.renderDirty = false;
        open(100, 50, (_, _) -> div().sizeFull().child(img(texture).w(px(20.)).h(px(10.))));
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        texture.renderVersion++;
        final draws = window.drawCount;
        @:privateAccess glaze.GlazeSystem.ensure().lateUpdate(0);
        assertTrue(target().renderDirty);
        assertEquals(draws, window.drawCount);
    }

/// visual(): size, primitive, clipping

    function testTextureFollowsTheLayoutAndTheScaleFactor() {
        final content = quad(10, 10);
        var resized = [];
        open(200, 100, (_, _) -> div().sizeFull().pl(px(10.)).pt(px(5.)).child(
            visual(content).w(px(view.width)).h(px(30.)).onResize((w, h) -> resized.push('${w}x${h}'))
        ), 2);
        assertEquals('60x30', resized.join(','));
        assertEquals(60.0, VisualElement.contentWidth(content));
        assertEquals(30.0, VisualElement.contentHeight(content));
        // Reparented into the filter's content, active
        assertTrue(content.parent != null && Std.isOfType(content.parent.parent, ceramic.Filter));
        assertTrue(content.active);
        final filter:ceramic.Filter = cast content.parent.parent;
        final texture = filter.renderTexture;
        assertTrue(texture != null);
        assertEquals(2.0, texture.density);
        if (filter.textureTile == null) {
            // Its own texture (the shared atlas is at the screen's density)
            assertEquals(120.0, texture.nativeWidth);
            assertEquals(60.0, texture.nativeHeight);
        }
        // One polychrome sprite in device pixels showing that texture
        final list = sprites();
        assertEquals(1, list.length);
        final sprite = list[0];
        assertEquals(20.0, sprite.boundsX);
        assertEquals(10.0, sprite.boundsY);
        assertEquals(120.0, sprite.boundsWidth);
        assertEquals(60.0, sprite.boundsHeight);
        assertEquals(120.0, sprite.tileWidth);
        assertEquals(60.0, sprite.tileHeight);
        assertTrue(window.renderable.atlasTextures[sprite.textureIndex] == texture);

        // Resized with the layout
        view.width = 80;
        refresh();
        window.draw();
        assertEquals('60x30,80x30', resized.join(','));
        assertEquals(160.0, sprites()[0].boundsWidth);
        assertEquals(160.0, sprites()[0].tileWidth);
    }

    /** Notifies the root view (its fields changed) */
    function refresh():Void {
        final entity:Entity<VisualTestView> = view;
        entity.update(app, (_, cx) -> cx.notify());
    }

    function testSizeDefaultsToTheVisualSize() {
        final content = quad(30, 12);
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content)), 1);
        assertEquals(30.0, VisualElement.contentWidth(content));
        assertEquals(12.0, VisualElement.contentHeight(content));
        assertEquals(30.0, sprites()[0].boundsWidth);
    }

    function testSmallVisualsShareAnAtlas() {
        final a = quad(10, 10);
        final b = quad(10, 10);
        open(200, 100, (_, _) -> {
            final root = div().sizeFull().flex().child(visual(a).size(px(20.))).child(visual(b).size(px(20.)));
            return view.extra != null ? root.child(view.extra()) : root;
        }, 1);
        final list = sprites();
        assertEquals(2, list.length);
        if (ceramic.App.app.screen.texturesDensity == 1) {
            // Same texture, different tiles
            assertEquals(list[0].textureIndex, list[1].textureIndex);
            assertTrue(list[0].tileX != list[1].tileX || list[0].tileY != list[1].tileY);
        }
        // Explicit mode always gets its own texture
        final c = quad(10, 10);
        view.extra = () -> visual(c).size(px(20.)).renderMode(Explicit);
        refresh();
        window.draw();
        final filter:ceramic.Filter = cast c.parent.parent;
        assertTrue(filter.textureTilePacker == null);
        assertTrue(filter.explicitRender);
        // Inactive content at rest (nothing rendered)
        assertTrue(@:privateAccess filter.explicitRenderState != 0 || !filter.content.active);
    }

    function testDrawnInOrderUnderAPopover() {
        final content = quad(10, 10);
        open(200, 100, (_, _) -> div().sizeFull().relative()
            .child(visual(content).size(px(50.)))
            .child(deferred(div().absolute().left(px(10.)).top(px(10.)).size(px(20.)).bg(red()))));
        final scene = window.renderedScene();
        assertEquals(1, scene.polychromeSprites.length);
        var overlay:Null<glaze.scene.Quad> = null;
        for (q in scene.quads) overlay = q;
        assertTrue(overlay != null);
        assertTrue(overlay.order > scene.polychromeSprites[0].order, 'the popover is drawn over the visual');
    }

    function testClippedByAScrollingContainer() {
        final content = quad(10, 10);
        open(200, 100, (_, _) -> div().sizeFull().child(
            div().w(px(100.)).h(px(40.)).overflowHidden().child(visual(content).w(px(80.)).h(px(80.)))
        ), 1);
        final sprite = sprites()[0];
        assertEquals(80.0, sprite.boundsHeight);
        assertEquals(40.0, sprite.contentMaskHeight);
    }

    function testCornerRadiusAndOpacity() {
        final content = quad(10, 10);
        open(200, 100, (_, _) -> div().sizeFull().opacity(0.5).child(visual(content).size(px(40.)).rounded(px(6.))), 1);
        final sprite = sprites()[0];
        assertEquals(6.0, sprite.cornerRadiusTopLeft);
        assertEquals(0.5, sprite.opacity);
    }

    function testFitScalesTheVisualIntoTheArea() {
        final content = quad(20, 10);
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).w(px(40.)).h(px(40.)).fit(ObjectFit.Contain)));
        assertEquals(2.0, content.scaleX);
        assertEquals(2.0, content.scaleY);
        assertEquals(0.0, content.x);
        assertEquals(10.0, content.y);
    }

    function testNativeResolutionScalesTheTexture() {
        final content = quad(16, 8);
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).w(px(64.)).h(px(32.)).nativeResolution().textureFilter(NEAREST)), 1);
        final sprite = sprites()[0];
        assertEquals(64.0, sprite.boundsWidth);
        assertEquals(16.0, sprite.tileWidth);
    }

    function testExternalTextureOfAVisualIsCheckedEachFrame() {
        final content = quad(10, 10);
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).size(px(40.))));
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        final draws = window.drawCount;
        // `Always`: the filter's texture renders at every frame
        assertTrue(window.renderable.checkExternalTextures());
        assertEquals(draws, window.drawCount);
    }

    function testExplicitModeCostsNothingAtRest() {
        final content = quad(10, 10);
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).size(px(40.)).renderMode(Explicit)));
        final filter:ceramic.Filter = cast content.parent.parent;
        // The first render (shown) is under way: let it finish
        ceramic.App.app.flushImmediate();
        filter.renderTexture.renderDirty = false;
        @:privateAccess filter.explicitRenderState = 0;
        filter.content.active = false;
        finishCeramicDraw();
        @:privateAccess window.renderable.recordExternalVersions();
        assertFalse(window.renderable.checkExternalTextures());
        // renderNow(): drawn when the filter's texture is marked for this frame
        VisualElement.renderNow(content);
        assertTrue(filter.content.active);
        filter.renderTexture.renderDirty = true;
        assertTrue(window.renderable.checkExternalTextures());
    }

/// Pointer

    function testPointerReachesTheContentWithLocalCoordinates() {
        final content = quad(50, 50);
        var downs = [];
        content.onPointerDown(null, info -> {
            final p = new ceramic.Point();
            content.screenToVisual(info.x, info.y, p);
            downs.push('${Math.round(p.x)},${Math.round(p.y)}');
        });
        var glazeBehind = 0;
        open(200, 100, (_, _) -> div().sizeFull().onMouseDown(Left, (_, _, _) -> glazeBehind++).child(
            div().pl(px(20.)).pt(px(10.)).child(visual(content).size(px(50.)))
        ));
        ceramicFrame();
        emitMouse('down', 30, 25);
        emitMouse('up', 30, 25);
        assertEquals('10,15', downs.join(';'));
        // The Glaze element behind does not get it
        assertEquals(0, glazeBehind);
        // Outside the element: nothing
        ceramicFrame();
        emitMouse('down', 150, 80);
        emitMouse('up', 150, 80);
        assertEquals(1, downs.length);
        assertEquals(1, glazeBehind);
    }

    function testPointerFollowsTheGlazeVisualTransform() {
        final content = quad(50, 50);
        var downs = [];
        content.onPointerDown(null, info -> {
            final p = new ceramic.Point();
            content.screenToVisual(info.x, info.y, p);
            downs.push('${Math.round(p.x)},${Math.round(p.y)}');
        });
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).size(px(50.))));
        host.pos(100, 40);
        ceramicFrame();
        emitMouse('down', 105, 47);
        emitMouse('up', 105, 47);
        assertEquals('5,7', downs.join(';'));
    }

    function testPointerBlockedUnderAPopoverAndOutsideTheMask() {
        final content = quad(80, 80);
        var downs = 0;
        content.onPointerDown(null, _ -> downs++);
        var popoverDowns = 0;
        open(200, 100, (_, _) -> div().sizeFull().relative()
            .child(div().w(px(100.)).h(px(40.)).overflowHidden().child(visual(content).w(px(80.)).h(px(80.))))
            .child(deferred(div().absolute().left(px(10.)).top(px(10.)).size(px(20.)).bg(red()).occlude()
                .onMouseDown(Left, (_, _, _) -> popoverDowns++))));
        // Under the popover
        ceramicFrame();
        emitMouse('down', 15, 15);
        emitMouse('up', 15, 15);
        assertEquals(0, downs);
        assertEquals(1, popoverDowns);
        // Scrolled out (outside the mask)
        ceramicFrame();
        emitMouse('down', 50, 60);
        emitMouse('up', 50, 60);
        assertEquals(0, downs);
        // Visible part
        ceramicFrame();
        emitMouse('down', 50, 30);
        emitMouse('up', 50, 30);
        assertEquals(1, downs);
    }

    function testOverlayThatDoesNotBlockLetsThePointerThrough() {
        final content = quad(50, 50);
        var downs = 0;
        content.onPointerDown(null, _ -> downs++);
        var overlayMoves = 0;
        // A hover area over it (like a scrollbar's), without blocking
        open(200, 100, (_, _) -> div().sizeFull().relative()
            .child(visual(content).size(px(50.)))
            .child(div().absolute().left(px(0.)).top(px(0.)).size(px(100.)).onMouseMove((_, _, _) -> overlayMoves++)));
        ceramicFrame();
        emitMouse('down', 10, 10);
        emitMouse('up', 10, 10);
        assertEquals(1, downs);
    }

    function testNotInteractive() {
        final content = quad(50, 50);
        var downs = 0;
        content.onPointerDown(null, _ -> downs++);
        var glazeBehind = 0;
        open(200, 100, (_, _) -> div().sizeFull().onMouseDown(Left, (_, _, _) -> glazeBehind++).child(visual(content).size(px(50.)).interactive(false)));
        ceramicFrame();
        emitMouse('down', 10, 10);
        emitMouse('up', 10, 10);
        assertEquals(0, downs);
        assertEquals(1, glazeBehind);
    }

    function testFocusAndHover() {
        final content = quad(50, 50);
        content.onPointerDown(null, _ -> {});
        var handle:Null<FocusHandle> = null;
        open(200, 100, (window, cx) -> {
            if (handle == null) handle = cx.focusHandle();
            return div().sizeFull().child(visual(content).size(px(50.)).trackFocus(handle));
        });
        assertFalse(VisualElement.isFocused(content));
        ceramicFrame();
        emitMouse('move', 10, 10);
        assertTrue(VisualElement.isHovered(content));
        ceramicFrame();
        emitMouse('down', 10, 10);
        emitMouse('up', 10, 10);
        assertTrue(VisualElement.isFocused(content));
        assertTrue(handle.isFocused(window));
        ceramicFrame();
        emitMouse('move', 150, 10);
        assertFalse(VisualElement.isHovered(content));
    }

/// Lifecycle

    function testHiddenVisualIsDetachedThenItsFilterDestroyed() {
        VisualElement.gracePeriodFrames = 3;
        final content = quad(10, 10);
        final hosts = VisualElement.hostCount();
        open(200, 100, (_, _) -> view.show ? div().sizeFull().child(visual(content).size(px(20.))) : div().sizeFull());
        final filter:ceramic.Filter = cast content.parent.parent;
        assertEquals(hosts + 1, VisualElement.hostCount());
        view.show = false;
        refresh();
        window.draw();
        // Detached and deactivated, never destroyed
        assertTrue(content.parent == null);
        assertFalse(content.active);
        assertFalse(content.destroyed);
        assertFalse(filter.destroyed);
        // Shown again within the grace period: the same filter
        view.show = true;
        refresh();
        window.draw();
        assertTrue(content.parent != null && content.parent.parent == filter);
        assertTrue(content.active);
        // Hidden for longer than the grace period: the filter is destroyed
        view.show = false;
        refresh();
        window.draw();
        for (_ in 0...5) @:privateAccess glaze.VisualHost.tick();
        assertTrue(filter.destroyed);
        assertFalse(content.destroyed);
        assertEquals(hosts, VisualElement.hostCount());
    }

    function testNoLeakAfterManyVisuals() {
        VisualElement.gracePeriodFrames = 0;
        final hosts = VisualElement.hostCount();
        final hitVisuals = @:privateAccess ceramic.App.app.screen.hitVisuals.length;
        open(200, 100, (_, _) -> view.extra != null ? div().sizeFull().child(view.extra()) : div().sizeFull());
        for (i in 0...100) {
            final q = quad(10, 10);
            view.extra = () -> visual(q).size(px(20.));
            refresh();
            window.draw();
            view.extra = null;
            refresh();
            window.draw();
            @:privateAccess glaze.VisualHost.tick();
            @:privateAccess glaze.VisualHost.tick();
        }
        assertEquals(hosts, VisualElement.hostCount());
        assertEquals(hitVisuals, @:privateAccess ceramic.App.app.screen.hitVisuals.length);
    }

    function testDestroyedVisualReleasesItsFilter() {
        final content = quad(10, 10);
        final hosts = VisualElement.hostCount();
        open(200, 100, (_, _) -> view.show ? div().sizeFull().child(visual(content).size(px(20.))) : div().sizeFull());
        final filter:ceramic.Filter = cast content.parent.parent;
        view.show = false;
        refresh();
        window.draw();
        content.destroy();
        assertTrue(filter.destroyed);
        assertEquals(hosts, VisualElement.hostCount());
    }

    function testClosedWindowReleasesItsVisuals() {
        VisualElement.gracePeriodFrames = 0;
        final content = quad(10, 10);
        final hosts = VisualElement.hostCount();
        open(200, 100, (_, _) -> div().sizeFull().child(visual(content).size(px(20.))));
        host.destroy();
        host = null;
        window = null;
        assertTrue(content.parent == null);
        assertFalse(content.destroyed);
        @:privateAccess glaze.VisualHost.tick();
        @:privateAccess glaze.VisualHost.tick();
        assertEquals(hosts, VisualElement.hostCount());
    }

    /** A view (`inner`) showing the visual, inside the root view */
    function openNested(content:ceramic.Visual):Entity<VisualTestView> {
        var inner:Null<Entity<VisualTestView>> = null;
        open(200, 100, (window, cx) -> {
            if (inner == null) inner = cx.newEntity((_:Context<VisualTestView>) -> new VisualTestView((_, _) -> {
                final model:VisualTestView = inner;
                return div().size(px(60.)).bg(model.show ? red() : blue()).child(visual(content).size(px(50.)));
            }));
            return div().sizeFull().flex().child(inner).child(div().w(px(view.width)).h(px(10.)));
        });
        return inner;
    }

    function cachedViewKeepsTheVisual(verify:Bool) {
        if (!verify) countsRenders();
        final content = quad(50, 50);
        var downs = 0;
        content.onPointerDown(null, _ -> downs++);
        openNested(content);
        final filter:ceramic.Filter = cast content.parent.parent;
        // The root view renders again, the inner one is reused from the cache
        view.width = 30;
        refresh();
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        if (!verify) assertTrue(window.reusedViewCount >= 1, 'the inner view is reused (rendered ${window.renderedViewCount}, reused ${window.reusedViewCount}, in place ${window.inPlaceViewCount})');
        assertEquals(1, sprites().length);
        assertTrue(content.parent != null && content.parent.parent == filter);
        assertTrue(content.active);
        ceramicFrame();
        emitMouse('down', 10, 10);
        emitMouse('up', 10, 10);
        assertEquals(1, downs);
    }

    function testCachedViewKeepsTheVisual() {
        cachedViewKeepsTheVisual(false);
    }

    function testCachedViewKeepsTheVisualVerified() {
        cachedViewKeepsTheVisual(true);
    }

    function testViewRenderedInPlaceKeepsTheVisual() {
        final content = quad(50, 50);
        var downs = 0;
        content.onPointerDown(null, _ -> downs++);
        final inner = openNested(content);
        final filter:ceramic.Filter = cast content.parent.parent;
        // Only the inner view renders again (same size): in place
        inner.update(app, (model, cx) -> {
            model.show = false;
            cx.notify();
        });
        ceramic.App.app.flushImmediate();
        window.drawIfDirty();
        assertEquals(1, window.inPlaceViewCount);
        assertEquals(1, sprites().length);
        assertTrue(content.parent != null && content.parent.parent == filter);
        assertTrue(content.active);
        ceramicFrame();
        emitMouse('down', 10, 10);
        emitMouse('up', 10, 10);
        assertEquals(1, downs);
        // The next full frame keeps it too
        view.width = 20;
        refresh();
        window.draw();
        assertTrue(content.parent != null && content.parent.parent == filter);
    }

}

class VisualTestView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public var width:Float = 60;

    public var show:Bool = true;

    public var extra:Null<() -> IntoElement> = null;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}
