// Ported from gpui-pre-http-client 0.3.10: src/http_client.rs (FakeHttpClient)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.HttpClient;

/**
 * An HTTP client for tests: every request is answered by a handler
 * (Rust `FakeHttpClient`, feature `test-support`).
 */
class FakeHttpClient implements HttpClient {

    var handler:(HttpRequest) -> Task<HttpResponse>;

    /** The requests sent so far, in order */
    public final requests:Array<HttpRequest> = [];

    function new(handler:(HttpRequest) -> Task<HttpResponse>) {
        this.handler = handler;
    }

    /** A client whose requests are answered by `handler` */
    public static function create(handler:(HttpRequest) -> Task<HttpResponse>):FakeHttpClient {
        return new FakeHttpClient(handler);
    }

    /** A client that answers every request with an empty 404 response */
    public static function with404Response():FakeHttpClient {
        return create(_ -> Task.ready(new HttpResponse(404, [], null)));
    }

    /** A client that answers every request with an empty 200 response */
    public static function with200Response():FakeHttpClient {
        return create(_ -> Task.ready(new HttpResponse(200, [], null)));
    }

    /** Replaces the handler; the new one receives the previous one */
    public function replaceHandler(newHandler:((HttpRequest) -> Task<HttpResponse>, HttpRequest)->Task<HttpResponse>):Void {
        final previous = handler;
        handler = request -> newHandler(previous, request);
    }

    public function userAgent():Null<String> {
        return 'glaze.FakeHttpClient';
    }

    public function proxy():Null<String> {
        return null;
    }

    public function send(request:HttpRequest):Task<HttpResponse> {
        requests.push(request);
        try {
            return handler(request);
        }
        catch (e:Dynamic) {
            return Task.failed(e);
        }
    }

}
