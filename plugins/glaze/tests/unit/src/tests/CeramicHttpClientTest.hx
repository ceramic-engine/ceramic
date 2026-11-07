package tests;

#if plugin_http

import gpui.App;
import gpui.CeramicDispatcher;
import gpui.CeramicHttpClient;
import gpui.HttpClient;
import gpui.ImageAssetLoader;
import gpui.ImageAssets;
import gpui.ImageCacheError;
import gpui.ImageLoadResult;
import gpui.Resource;
import haxe.io.Bytes;
import testing.LocalHttpServer;
import testing.TestCase;

/**
 * `Resource.Uri` images loaded through `CeramicHttpClient` (Ceramic's `http`
 * plugin) from a local HTTP server on 127.0.0.1 (no network): raster and SVG
 * bodies, error statuses, failed connections, redirects, query strings and
 * the app's asset cache. Asynchronous: they run with the Ceramic app loop.
 */
class CeramicHttpClientTest extends TestCase {

    static final SVG_10x5 = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="5"><rect width="10" height="5" fill="#ff0000"/></svg>';

    var server:Null<LocalHttpServer> = null;

    var previousApp:Null<App> = null;

    var app:App;

    override function setup() {
        previousApp = @:privateAccess App._current;
        app = new App(new CeramicDispatcher());
    }

    override function teardown() {
        if (server != null) {
            server.stop();
            server = null;
        }
        App.current = previousApp;
    }

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

    static function respond(method:String, path:String):LocalHttpResponse {
        return switch path {
            case '/image.png':
                {status: 200, headers: ['Content-Type', 'image/png'], body: pngBytes(3, 2)};
            case '/image.svg':
                // A text content type: the body must still come as bytes
                {status: 200, headers: ['Content-Type', 'image/svg+xml; charset=utf-8'], body: Bytes.ofString(SVG_10x5)};
            case '/missing.png':
                {status: 404, headers: ['Content-Type', 'text/plain'], body: Bytes.ofString('Not Found  \r\nsecond line\n')};
            case '/redirect.png':
                {status: 302, headers: ['Location', '/image.png'], body: Bytes.alloc(0)};
            case '/hello.txt':
                {status: 200, headers: ['Content-Type', 'text/plain; charset=utf-8'], body: Bytes.ofString('hello\r\n')};
            case '/query.png?v=1&w=2':
                {status: 200, headers: ['Content-Type', 'image/png'], body: pngBytes(5, 1)};
            case _:
                {status: 404, headers: [], body: Bytes.alloc(0)};
        }
    }

    function withServer(f:(LocalHttpServer) -> Void):Void {
        server = new LocalHttpServer(respond);
        server.start(() -> f(server));
    }

    /** Calls `then` on the first frame where `condition` holds. */
    static function waitUntil(condition:() -> Bool, then:() -> Void):Void {
        if (condition()) {
            then();
            return;
        }
        ceramic.App.app.onceUpdate(null, _ -> waitUntil(condition, then));
    }

    function load(uri:String, done:(ImageLoadResult) -> Void):Void {
        ImageAssetLoader.load(Resource.Uri(uri), app).then(done);
    }

    function assertLoaded(result:ImageLoadResult, width:Float, height:Float, ?pos:haxe.PosInfos):Void {
        switch result {
            case Loaded(image):
                assertEquals(width, image.size(0).width, null, pos);
                assertEquals(height, image.size(0).height, null, pos);
            case Failed(error):
                fail('unexpected failure: ' + error.toString(), pos);
        }
    }

    function asyncTestDefaultClientIsCeramic(done:() -> Void) {
        assertTrue(Std.isOfType(app.httpClient(), CeramicHttpClient));
        // A test dispatcher keeps GPUI's NullHttpClient
        final testApp = new App(new gpui.TestDispatcher());
        assertTrue(Std.isOfType(testApp.httpClient(), NullHttpClient));
        done();
    }

    function asyncTestPng(done:() -> Void) {
        withServer(server -> {
            load(server.url('/image.png'), result -> {
                assertLoaded(result, 3, 2);
                done();
            });
        });
    }

    function asyncTestSvgServedAsText(done:() -> Void) {
        withServer(server -> {
            load(server.url('/image.svg'), result -> {
                // SVG rendered at scale 1 by `render_single_frame`, then sized
                // by its own size
                switch result {
                    case Loaded(image):
                        assertTrue(image.size(0).width > 0);
                        assertEquals(image.size(0).width, image.size(0).height * 2);
                    case Failed(error):
                        fail('unexpected failure: ' + error.toString());
                }
                done();
            });
        });
    }

    function asyncTestNotFound(done:() -> Void) {
        withServer(server -> {
            final uri = server.url('/missing.png');
            load(uri, result -> {
                switch result {
                    case Failed(BadStatus(u, status, body)):
                        assertEquals(uri, u);
                        assertEquals(404, status);
                        assertEquals('Not Found', body);
                    case _:
                        fail('expected BadStatus, got $result');
                }
                done();
            });
        });
    }

    function asyncTestConnectionRefused(done:() -> Void) {
        // Nothing listens on port 1
        final uri = 'http://127.0.0.1:1/image.png';
        load(uri, result -> {
            switch result {
                case Failed(Other(message)):
                    assertTrue(StringTools.startsWith(message, 'loading image asset from "$uri": '), message);
                case _:
                    fail('expected Other, got $result');
            }
            done();
        });
    }

    function asyncTestRedirectIsFollowed(done:() -> Void) {
        withServer(server -> {
            load(server.url('/redirect.png'), result -> {
                assertLoaded(result, 3, 2);
                assertEquals(1, server.hitCount('/redirect.png'));
                assertEquals(1, server.hitCount('/image.png'));
                done();
            });
        });
    }

    function asyncTestQueryStringIsSent(done:() -> Void) {
        withServer(server -> {
            load(server.url('/query.png?v=1&w=2'), result -> {
                assertLoaded(result, 5, 1);
                done();
            });
        });
    }

    /**
     * Opt-in (`GPUI_TEST_NETWORK=1`), never part of the gate: loads the
     * remote images of the story (README badges and logo, image story) and
     * prints what each gives. Nothing is asserted.
     */
    function asyncTestRemoteStoryImages(done:() -> Void) {
        if (Sys.getEnv('GPUI_TEST_NETWORK') != '1') {
            done();
            return;
        }
        final uris = [
            'https://raw.githubusercontent.com/longbridge/gpui-kit/main/website/public/logo.svg',
            'https://github.com/longbridge/gpui-kit/actions/workflows/ci.yml/badge.svg',
            'https://docs.rs/gpui-kit/badge.svg',
            'https://img.shields.io/crates/v/gpui-kit.svg',
            'https://github.com/user-attachments/assets/e1ecb9c3-2dd3-431e-bd97-5a819c30e551',
            'https://pub.lbkrs.com/files/202503/vEnnmgUM6bo362ya/sdk.svg',
        ];
        var index = 0;
        function next() {
            if (index >= uris.length) {
                done();
                return;
            }
            final uri = uris[index++];
            load(uri, result -> {
                switch result {
                    case Loaded(image):
                        Sys.println('network: loaded ${image.size(0).width}x${image.size(0).height} $uri');
                    case Failed(error):
                        Sys.println('network: failed $uri: ' + error.toString());
                }
                next();
            });
        }
        next();
    }

    /** `ceramic.Http` without `binary`: text bodies come as strings, like before */
    function asyncTestCeramicHttpTextMode(done:() -> Void) {
        withServer(server -> {
            ceramic.Http.request({url: server.url('/hello.txt')}, response -> {
                assertEquals(200, response.status);
                assertEquals('hello', response.content);
                assertNull(response.binaryContent);
                assertNull(response.error);
                ceramic.Http.request({url: server.url('/image.png')}, response -> {
                    assertEquals(200, response.status);
                    assertNull(response.content);
                    assertNotNull(response.binaryContent);
                    if (response.binaryContent != null)
                        assertEquals(pngBytes(3, 2).toHex(), response.binaryContent.toHex());
                    done();
                });
            });
        });
    }

    function asyncTestCacheHit(done:() -> Void) {
        withServer(server -> {
            final uri = server.url('/image.png');
            final key = 'resource:' + Resource.Uri(uri).key();
            final assets = ImageAssets.of(app);
            final loader = (cx:App) -> ImageAssetLoader.load(Resource.Uri(uri), cx);
            final first = assets.entry(key, loader, app);
            final second = assets.entry(key, loader, app);
            assertTrue(first == second);
            waitUntil(() -> first.isLoaded(), () -> {
                assertLoaded(first.get(), 3, 2);
                // Loaded: served from the cache, no new request
                assertNotNull(assets.fetch(key, loader, app));
                assertEquals(1, server.hitCount('/image.png'));
                done();
            });
        });
    }

}

#end
