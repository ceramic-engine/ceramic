// Ported from gpui-pre 0.3.10: src/elements/img.rs (tests), src/assets.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.CeramicAssetSource;
import gpui.Context;
import gpui.ImageCache;
import gpui.ImageLoadResult;
import gpui.Img.ImgState;
import gpui.IntoElement;
import gpui.Model;
import gpui.ObjectFit;
import gpui.Point;
import gpui.Render;
import gpui.RenderImage;
import gpui.Resource;
import gpui.RetainAllImageCache;
import gpui.Size;
import gpui.SizeOf;
import gpui.TestDispatcher;
import gpui.Unit;
import gpui.Window;
import gpui.scene.PolychromeSprite;
import haxe.io.Bytes;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * Tests of `img()`, `ImageSource`, `ObjectFit` and the image caches. The first
 * ones are ports of the Rust tests of `img.rs` and `assets.rs`; the others
 * check the behaviour of the port (intrinsic sizing, asynchronous loads,
 * loading and fallback elements, image cache elements).
 */
class ImgTest extends TestCase {

    static inline final TEST_IMG_ID = 'test-img';

    var app:App;

    var dispatcher:TestDispatcher;

    var cx:Null<VisualTestContext> = null;

    var view:ImgTestView;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    /** Rust `cx.add_empty_window()` */
    function addEmptyWindow():Void {
        final result = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ImgTestView>) -> new ImgTestView());
        view = result.view;
        cx = result.cx;
    }

    /**
     * Rust `VisualTestContext::draw`: lays out the element as a root in `space`,
     * prepaints it at `origin` and paints it (from a canvas of the window's
     * view), then reads the rendered frame.
     */
    function draw(origin:Point, space:Size, build:() -> IntoElement):Void {
        view.origin = origin;
        view.space = space;
        view.build = build;
        cx.update((window, app) -> {
            window.refresh();
            window.draw();
        });
    }

    /** Redraws the window (the view is rendered again). */
    function redraw():Void {
        cx.update((window, app) -> {
            window.refresh();
            window.draw();
        });
    }

    function sprites():Array<PolychromeSprite> {
        return cx.window.renderedScene().polychromeSprites;
    }

    function lastSprite():PolychromeSprite {
        final list = sprites();
        return list.length > 0 ? list[list.length - 1] : null;
    }

    /** One BGRA frame of `width` x `height` transparent pixels */
    static function frame(width:Int, height:Int):gpui.RenderImage.RenderImageFrame {
        return new gpui.RenderImage.RenderImageFrame(width, height, Bytes.alloc(width * height * 4), null, 0.1);
    }

    static function testImage(frameCount:Int):RenderImage {
        return new RenderImage([for (_ in 0...frameCount) frame(1, 1)]);
    }

    static function testImageWithSize(width:Int, height:Int):RenderImage {
        return new RenderImage([frame(width, height)]);
    }

    /** Overwrites the cached `frameIndex` of the sibling `img` during paint. */
    static function seedFrameIndex(frameIndex:Int):IntoElement {
        return canvas((_, _, _) -> Unit.unit, (_, _, window, _) -> {
            window.withGlobalId(TEST_IMG_ID, (id, window) -> {
                window.withElementState(id, ImgState, (state, _) -> {
                    if (state.value == null)
                        throw 'img state should be initialized';
                    state.value.frameIndex = frameIndex;
                    return Unit.unit;
                });
            });
        });
    }

    static final SVG_10x5 = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="5"><rect width="10" height="5" fill="#ff0000"/></svg>';

    function useAssets(files:Map<String, String>):Void {
        final source = new CeramicAssetSource();
        for (path => content in files) {
            source.add(path, Bytes.ofString(content));
        }
        app.setAssetSource(source);
    }

/// Rust tests (assets.rs)

    function testEmptyRenderImageDoesNotPanic() {
        final image = new RenderImage([]);
        assertEquals(0, image.frameCount());
        assertTrue(image.size(0).equals(new Size(0, 0)));
        assertNull(image.asBytes(0));
        assertTrue(image.renderSize(0).equals(new Size(0, 0)));
        assertEquals(0.1, image.delay(0));
        assertTrue(image.toString().length > 0);
    }

/// Rust tests (img.rs)

    function testZeroFrameImageDoesNotPanicOnPaint() {
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img(gpui.ImageSource.Render(testImage(0))));
        assertEquals(0, sprites().length);
    }

    function testImageObjectFitCoverCropsToElementBounds() {
        addEmptyWindow();
        final image = testImageWithSize(200, 100);
        draw(new Point(0, 0), new Size(100, 100), () -> img(image).sizeFull().objectFit(ObjectFit.Fill));
        final full = lastSprite();
        assertNotNull(full, 'fill image should paint a sprite');
        final fullTileX = full.tileX;
        final fullTileY = full.tileY;

        draw(new Point(10, 20), new Size(100, 100), () -> img(image).sizeFull().objectFit(ObjectFit.Cover));
        final sprite = lastSprite();
        assertNotNull(sprite, 'cover image should paint a sprite');
        final scaleFactor = cx.window.scaleFactor();
        assertEquals(10 * scaleFactor, sprite.boundsX);
        assertEquals(20 * scaleFactor, sprite.boundsY);
        assertEquals(100 * scaleFactor, sprite.boundsWidth);
        assertEquals(100 * scaleFactor, sprite.boundsHeight);
        assertEquals(50.0, sprite.tileX - fullTileX);
        assertEquals(0.0, sprite.tileY - fullTileY);
        assertEquals(100.0, sprite.tileWidth);
        assertEquals(100.0, sprite.tileHeight);
    }

    function testExplicitAspectRatioIsNotOverriddenByIntrinsicRatio() {
        addEmptyWindow();
        // A portrait image in a square container
        draw(new Point(0, 0), new Size(100, 100), () -> div()
            .size(px(100.))
            .overflowHidden()
            .child(
                img(testImageWithSize(100, 200))
                    .sizeFull()
                    .aspectSquare()
                    .objectFit(ObjectFit.Contain)
            )
        );
        final sprite = lastSprite();
        assertNotNull(sprite, 'contained image should paint a sprite');
        final scaleFactor = cx.window.scaleFactor();
        // The element stays 100x100, so the image is letterboxed horizontally
        assertEquals(25 * scaleFactor, sprite.boundsX);
        assertEquals(0 * scaleFactor, sprite.boundsY);
        assertEquals(50 * scaleFactor, sprite.boundsWidth);
        assertEquals(100 * scaleFactor, sprite.boundsHeight);
    }

    function testImageObjectFitCoverClampsCornerRadiiToVisibleBounds() {
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img(testImageWithSize(200, 100))
            .sizeFull()
            .rounded(px(100.))
            .objectFit(ObjectFit.Cover)
        );
        final sprite = lastSprite();
        assertNotNull(sprite);
        assertEquals(50 * cx.window.scaleFactor(), sprite.cornerRadiusTopLeft);
    }

    function testStaleFrameIndexIsClampedWhenImageChanges() {
        addEmptyWindow();
        // A cached frame index from a previous multi-frame image must not be
        // used out of bounds when the image is replaced with one that has fewer frames.
        draw(new Point(0, 0), new Size(100, 100), () -> div()
            .child(img(testImage(5)).id(TEST_IMG_ID))
            .child(seedFrameIndex(4))
        );
        draw(new Point(0, 0), new Size(100, 100), () -> img(testImage(1)).id(TEST_IMG_ID));
        // The frame index was clamped to 0: the 1x1 image is painted
        assertNotNull(lastSprite());
    }

/// Port behaviour

    function testObjectFitBounds() {
        final bounds = new Bounds(new Point(10, 20), new Size(100, 50));
        final image = new Size(40, 40);
        inline function check(fit:ObjectFit, x:Float, y:Float, w:Float, h:Float, ?pos:haxe.PosInfos) {
            final result = fit.getBounds(bounds, image);
            assertTrue(result.equals(new Bounds(new Point(x, y), new Size(w, h))), '$fit: $result', pos);
        }
        check(ObjectFit.Fill, 10, 20, 100, 50);
        check(ObjectFit.Contain, 35, 20, 50, 50);
        check(ObjectFit.Cover, 10, -5, 100, 100);
        check(ObjectFit.ScaleDown, 40, 25, 40, 40);
        check(ObjectFit.None, 10, 20, 40, 40);
        // Larger than the bounds: ScaleDown is Contain
        final large = new Size(400, 100);
        assertTrue(ObjectFit.ScaleDown.getBounds(bounds, large).equals(new Bounds(new Point(10, 32.5), new Size(100, 25))));
    }

    function testIntrinsicSize() {
        addEmptyWindow();
        final image = testImageWithSize(60, 30);
        final scaleFactor = 2.0;

        // No size: the image size (render size: pixels / scale factor of the image)
        draw(new Point(0, 0), new Size(400, 400), () -> div().flex().child(img(image)));
        var sprite = lastSprite();
        assertEquals(60 * scaleFactor, sprite.boundsWidth);
        assertEquals(30 * scaleFactor, sprite.boundsHeight);

        // Height only: width from the aspect ratio
        draw(new Point(0, 0), new Size(400, 400), () -> div().flex().child(img(image).h(px(20))));
        sprite = lastSprite();
        assertEquals(40 * scaleFactor, sprite.boundsWidth);
        assertEquals(20 * scaleFactor, sprite.boundsHeight);

        // Width only: height from the aspect ratio
        draw(new Point(0, 0), new Size(400, 400), () -> div().flex().child(img(image).w(px(100))));
        sprite = lastSprite();
        assertEquals(100 * scaleFactor, sprite.boundsWidth);
        assertEquals(50 * scaleFactor, sprite.boundsHeight);

        // A scale factor of 2 halves the render size
        final hidpi = testImageWithSize(60, 30);
        hidpi.scaleFactor = 2;
        draw(new Point(0, 0), new Size(400, 400), () -> div().flex().child(img(hidpi)));
        sprite = lastSprite();
        assertEquals(30 * scaleFactor, sprite.boundsWidth);
        assertEquals(15 * scaleFactor, sprite.boundsHeight);
    }

    function testGrayscaleAndOpacity() {
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> div().opacity(0.5).child(img(testImageWithSize(10, 10)).size(px(10)).grayscale(true)));
        final sprite = lastSprite();
        assertTrue(sprite.grayscale);
        assertEquals(0.5, sprite.opacity);
    }

    function testEmbeddedResourceLoadsAsynchronously() {
        useAssets(['images/rect.svg' => SVG_10x5]);
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> div().flex().child(img('images/rect.svg')));
        // Loading: nothing painted yet
        assertEquals(0, sprites().length);
        assertTrue(gpui.ImageSource.Resource(Resource.Embedded('images/rect.svg')).isAssetCached(app));

        // The load completes, the view is notified and drawn again
        cx.runUntilParked();
        final sprite = lastSprite();
        assertNotNull(sprite);
        // SVG images are rendered at twice their size, with a scale factor of 2: 10x5 logical
        assertEquals(20.0, sprite.boundsWidth);
        assertEquals(10.0, sprite.boundsHeight);

        gpui.ImageSource.Resource(Resource.Embedded('images/rect.svg')).removeAsset(app);
        assertFalse(gpui.ImageSource.Resource(Resource.Embedded('images/rect.svg')).isAssetCached(app));
    }

    function testMissingResourceShowsFallback() {
        useAssets([]);
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img('images/missing.png')
            .withFallback(() -> div().size(px(10)).bg(red()).intoAnyElement())
            .withLoading(() -> div().size(px(10)).bg(blue()).intoAnyElement())
        );
        assertEquals(0, cx.window.renderedScene().quads.length);
        cx.runUntilParked();
        final quads = cx.window.renderedScene().quads;
        assertEquals(1, quads.length);
        // red
        assertEquals(0.0, quads[0].backgroundSolidH);
        assertEquals(20.0, quads[0].boundsWidth);
    }

    function testUnsupportedUriShowsFallback() {
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img('https://example.com/image.png')
            .withFallback(() -> div().size(px(10)).bg(red()).intoAnyElement())
        );
        cx.runUntilParked();
        assertEquals(1, cx.window.renderedScene().quads.length);
    }

/// Uri resources (Rust `ImageAssetLoader::load`, `Resource::Uri` branch)

    static final URI = 'https://example.com/image.png';

    /** PNG bytes of a `width` x `height` opaque red image */
    static function pngBytes(width:Int, height:Int):Bytes {
        final bgra = Bytes.alloc(width * height * 4);
        for (i in 0...width * height) {
            bgra.set(i * 4 + 2, 255);
            bgra.set(i * 4 + 3, 255);
        }
        final output = new haxe.io.BytesOutput();
        new format.png.Writer(output).write(format.png.Tools.build32BGRA(width, height, bgra));
        return output.getBytes();
    }

    /** Loads `resource` with `ImageAssetLoader` and runs the dispatcher until it is done. */
    function loadNow(resource:Resource):ImageLoadResult {
        final task = gpui.ImageAssetLoader.load(resource, app);
        dispatcher.runUntilParked();
        assertFalse(task.isPending, 'the load should be done');
        return task.value;
    }

    function useHttp(handler:(gpui.HttpClient.HttpRequest) -> gpui.HttpClient.HttpResponse):gpui.FakeHttpClient {
        final client = gpui.FakeHttpClient.create(request -> gpui.Task.ready(handler(request)));
        app.setHttpClient(client);
        return client;
    }

    function errorOf(result:ImageLoadResult):Null<gpui.ImageCacheError> {
        return switch result {
            case Failed(error): error;
            case Loaded(_): null;
        }
    }

    function testUriWithoutHttpClientFails() {
        // GPUI's default client (`NullHttpClient`)
        final error = errorOf(loadNow(Resource.Uri(URI)));
        assertNotNull(error);
        assertEquals('error: loading image asset from "$URI": No HttpClient available', error.toString());
    }

    function testUriLoadsPngThroughHttpClient() {
        final client = useHttp(_ -> new gpui.HttpClient.HttpResponse(200, ['content-type', 'image/png'], pngBytes(3, 2)));
        switch loadNow(Resource.Uri(URI)) {
            case Loaded(image):
                assertEquals(3.0, image.size(0).width);
                assertEquals(2.0, image.size(0).height);
            case Failed(error):
                fail('unexpected failure: ' + error.toString());
        }
        // Rust `client.get(uri, ().into(), true)`: a GET that follows redirects
        assertEquals(1, client.requests.length);
        assertEquals('GET', client.requests[0].method);
        assertEquals(URI, client.requests[0].uri);
        assertTrue(client.requests[0].redirectPolicy.match(FollowAll));
        assertNull(client.requests[0].body);
    }

    function testUriSvgIsDetectedByContent() {
        // Not a raster format: rendered as SVG, whatever the URL or content type
        useHttp(_ -> new gpui.HttpClient.HttpResponse(200, ['content-type', 'application/octet-stream'], Bytes.ofString(SVG_10x5)));
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> div().flex().child(img(URI)));
        assertEquals(0, sprites().length);
        cx.runUntilParked();
        final sprite = lastSprite();
        assertNotNull(sprite);
        assertEquals(20.0, sprite.boundsWidth);
        assertEquals(10.0, sprite.boundsHeight);
    }

    function testUriBadStatusKeepsFirstLineOfBody() {
        useHttp(_ -> new gpui.HttpClient.HttpResponse(404, [], Bytes.ofString('Not Found  \r\nsecond line\n')));
        final error = errorOf(loadNow(Resource.Uri(URI)));
        assertNotNull(error);
        switch error {
            case BadStatus(uri, status, body):
                assertEquals(URI, uri);
                assertEquals(404, status);
                assertEquals('Not Found', body);
            case _:
                fail('expected BadStatus, got ' + error.toString());
        }
        assertEquals('unexpected http status for $URI: 404 Not Found, body: Not Found', error.toString());
    }

    function testUriBadStatusShowsFallback() {
        app.setHttpClient(gpui.FakeHttpClient.with404Response());
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img(URI)
            .withFallback(() -> div().size(px(10)).bg(red()).intoAnyElement())
        );
        cx.runUntilParked();
        assertEquals(1, cx.window.renderedScene().quads.length);
        final error = errorOf(loadNow(Resource.Uri(URI + '?again')));
        assertEquals('unexpected http status for $URI?again: 404 Not Found, body: ', error.toString());
    }

    function testUriRequestFailureIsOtherError() {
        app.setHttpClient(gpui.FakeHttpClient.create(_ -> gpui.Task.failed('connection refused')));
        final error = errorOf(loadNow(Resource.Uri(URI)));
        assertNotNull(error);
        assertTrue(error.match(Other(_)));
        assertEquals('error: loading image asset from "$URI": connection refused', error.toString());
    }

    function testUriLoadIsCached() {
        final client = useHttp(_ -> new gpui.HttpClient.HttpResponse(200, [], pngBytes(4, 4)));
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> div().flex().child(img(URI)).child(img(URI)));
        cx.runUntilParked();
        redraw();
        assertEquals(2, sprites().length);
        assertEquals(1, client.requests.length);
        assertTrue(gpui.ImageSource.Resource(Resource.Uri(URI)).isAssetCached(app));
        // Removing the asset loads it again
        gpui.ImageSource.Resource(Resource.Uri(URI)).removeAsset(app);
        redraw();
        cx.runUntilParked();
        redraw();
        assertEquals(2, client.requests.length);
        assertEquals(2, sprites().length);
    }

    function testHttpStatusDisplay() {
        // Rust `http::StatusCode` display
        assertEquals('404 Not Found', gpui.ImageCacheError.ImageCacheErrorTools.statusToString(404));
        assertEquals('503 Service Unavailable', gpui.ImageCacheError.ImageCacheErrorTools.statusToString(503));
        assertEquals('299 <unknown status code>', gpui.ImageCacheError.ImageCacheErrorTools.statusToString(299));
    }

    function testLoadingElementAfterDelay() {
        addEmptyWindow();
        final source:gpui.ImageSource = gpui.ImageSource.Custom((_, _) -> null);
        draw(new Point(0, 0), new Size(100, 100), () -> img(source)
            .id('loading')
            .withLoading(() -> div().size(px(10)).bg(blue()).intoAnyElement())
        );
        assertEquals(0, cx.window.renderedScene().quads.length);
        cx.advanceClock(0.1);
        cx.runUntilParked();
        redraw();
        assertEquals(0, cx.window.renderedScene().quads.length);
        // The LOADING_DELAY timer notifies the view at exactly 0.2s (advanceClock
        // runs it on its way, like GPUI's test scheduler); the loading element shows
        // once strictly more than LOADING_DELAY has elapsed, on the next draw
        cx.advanceClock(0.2);
        cx.runUntilParked();
        redraw();
        assertEquals(1, cx.window.renderedScene().quads.length);
    }

    function testCustomSourceFailureShowsFallback() {
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> img(gpui.ImageSource.Custom((_, _) -> Failed(gpui.ImageCacheError.Other('nope'))))
            .withFallback(() -> div().size(px(12)).bg(red()).intoAnyElement())
        );
        final quads = cx.window.renderedScene().quads;
        assertEquals(1, quads.length);
        assertEquals(24.0, quads[0].boundsWidth);
    }

    function testImageCacheElementProvidesCache() {
        addEmptyWindow();
        final cache = new CountingImageCache(testImageWithSize(8, 8));
        draw(new Point(0, 0), new Size(100, 100), () -> imageCache(cache).child(img('a.png')).child(img('b.png')));
        assertEquals('embedded:a.png,embedded:b.png', cache.loads.slice(0, 2).join(','));
        assertEquals(2, sprites().length);

        // An explicit cache on the img wins over the ancestor's
        final own = new CountingImageCache(testImageWithSize(8, 8));
        cache.loads.resize(0);
        draw(new Point(0, 0), new Size(100, 100), () -> imageCache(cache).child(img('c.png').imageCache(own)));
        assertEquals(0, cache.loads.length);
        assertEquals('embedded:c.png', own.loads[0]);
    }

    function testRetainAllImageCache() {
        useAssets(['images/rect.svg' => SVG_10x5]);
        addEmptyWindow();
        final cache:RetainAllImageCache = cx.update((_, app) -> RetainAllImageCache.create(app));
        draw(new Point(0, 0), new Size(100, 100), () -> imageCache(cache).child(img('images/rect.svg')));
        assertEquals(1, cache.len());
        assertEquals(0, sprites().length);
        cx.runUntilParked();
        assertEquals(1, sprites().length);
        // The app's asset cache was not used
        assertFalse(gpui.ImageSource.Resource(Resource.Embedded('images/rect.svg')).isAssetCached(app));

        cx.update((window, app) -> cache.clear(window, app));
        assertTrue(cache.isEmpty());

        // An entity handle is accepted too
        final entity = cx.update((_, app) -> RetainAllImageCache.create(app));
        draw(new Point(0, 0), new Size(100, 100), () -> imageCache(entity).child(img('images/rect.svg')));
        cx.runUntilParked();
        assertEquals(1, entity.read(app).len());
        assertEquals(1, sprites().length);
    }

    function testRetainAllProvider() {
        useAssets(['images/rect.svg' => SVG_10x5]);
        addEmptyWindow();
        draw(new Point(0, 0), new Size(100, 100), () -> imageCache(retainAll('images')).child(img('images/rect.svg')));
        cx.runUntilParked();
        assertEquals(1, sprites().length);
        assertFalse(gpui.ImageSource.Resource(Resource.Embedded('images/rect.svg')).isAssetCached(app));
    }

    #if (clay || unity)
    /** A 4x2 red JPEG (opaque, decoded by the backend, not by `format.png`) */
    static final JPEG_RED_4x2 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAACAAQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD8X6KKK/ynP+/g/9k=';

    /**
     * An opaque image decoded by the backend reads back as 4 bytes per pixel
     * (on Unity, `LoadImage` gives a JPEG an RGB24 texture: reading it as
     * RGBA32 ran past its pixels).
     */
    function asyncTestJpegDecodesThroughTheBackend(done:() -> Void) {
        final bytes = haxe.crypto.Base64.decode(JPEG_RED_4x2);
        gpui.ImageAssetLoader.decodeRaster(bytes, gpui.ImageFormat.Jpeg).then(result -> {
            switch result {
                case Loaded(image):
                    assertEquals(4.0, image.size(0).width);
                    assertEquals(2.0, image.size(0).height);
                    final bgra = image.asBytes(0);
                    assertNotNull(bgra);
                    assertEquals(4 * 2 * 4, bgra.length);
                    for (i in 0...8) {
                        // Red (JPEG rounding), opaque
                        assertTrue(bgra.get(i * 4) < 16 && bgra.get(i * 4 + 1) < 16 && bgra.get(i * 4 + 2) > 239);
                        assertEquals(255, bgra.get(i * 4 + 3));
                    }
                case Failed(error):
                    fail('unexpected failure: ' + error.toString());
            }
            done();
        });
    }
    #end

}

class ImgTestView extends Model implements Render {

    public var origin:Point = new Point(0, 0);

    public var space:Size = new Size(100, 100);

    public var build:Null<() -> IntoElement> = null;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final build = this.build;
        final origin = this.origin;
        final space = this.space;
        return div().sizeFull().child(canvas((_, window, cx) -> {
            if (build == null)
                return null;
            final element:AnyElement = build().intoAnyElement();
            element.prepaintAsRoot(origin, new SizeOf<AvailableSpace>(Definite(space.width), Definite(space.height)), window, cx);
            return element;
        }, (_, element, window, cx) -> {
            if (element != null)
                element.paint(window, cx);
        }).sizeFull());
    }

}

class CountingImageCache implements ImageCache {

    public final loads:Array<String> = [];

    final image:RenderImage;

    public function new(image:RenderImage) {
        this.image = image;
    }

    public function load(resource:Resource, window:Window, cx:App):Null<ImageLoadResult> {
        loads.push(resource.key());
        return Loaded(image);
    }

}
