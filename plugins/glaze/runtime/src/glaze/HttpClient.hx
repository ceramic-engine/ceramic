// Ported from gpui-pre-http-client 0.3.10: src/http_client.rs (HttpClient, RedirectPolicy), gpui-pre 0.3.10: src/app.rs (NullHttpClient)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;

/**
 * An HTTP client (Rust `http_client::HttpClient`), used by `img()` to load
 * `Resource.Uri` images (`App.httpClient()`).
 *
 * `send` gives a task of the response, whatever its status; the task fails
 * when no response could be received (connection, DNS, TLS, CORS on the web).
 *
 * Implementations: `NullHttpClient` (fails every request), `FakeHttpClient`
 * (tests), `CeramicHttpClient` (Ceramic's `http` plugin, when enabled).
 */
@:using(glaze.HttpClient.HttpClientTools)
interface HttpClient {

    /** The user agent sent with the requests, if any */
    function userAgent():Null<String>;

    /** The proxy used by the client, if any */
    function proxy():Null<String>;

    /** Sends a request. Fails when no response could be received. */
    function send(request:HttpRequest):Task<HttpResponse>;

}

class HttpClientTools {

    /**
     * Rust `HttpClient::get`: a GET request of `uri`, following redirects or
     * not.
     */
    public static function get(self:HttpClient, uri:String, body:Null<Bytes>, followRedirects:Bool):Task<HttpResponse> {
        return self.send(new HttpRequest('GET', uri, [], body, followRedirects ? RedirectPolicy.FollowAll : RedirectPolicy.NoFollow));
    }

}

/** Rust `http_client::RedirectPolicy` */
enum RedirectPolicy {

    NoFollow;

    FollowLimit(limit:Int);

    FollowAll;

}

/** An HTTP request (Rust `http::Request<AsyncBody>`) */
class HttpRequest {

    public final method:String;

    public final uri:String;

    /** Header names and values, flat: `[name, value, name, value...]` */
    public final headers:Array<String>;

    public final body:Null<Bytes>;

    public final redirectPolicy:RedirectPolicy;

    public function new(method:String, uri:String, headers:Array<String>, body:Null<Bytes>, redirectPolicy:RedirectPolicy) {
        this.method = method;
        this.uri = uri;
        this.headers = headers;
        this.body = body;
        this.redirectPolicy = redirectPolicy;
    }

}

/** An HTTP response (Rust `http::Response<AsyncBody>`), body read to the end */
class HttpResponse {

    public final status:Int;

    /** Header names and values, flat: `[name, value, name, value...]` */
    public final headers:Array<String>;

    public final body:Bytes;

    public function new(status:Int, headers:Array<String>, body:Null<Bytes>) {
        this.status = status;
        this.headers = headers != null ? headers : [];
        this.body = body != null ? body : Bytes.alloc(0);
    }

    /** Rust `StatusCode::is_success`: 200 to 299 */
    public inline function isSuccess():Bool {
        return status >= 200 && status < 300;
    }

}

/** Rust `NullHttpClient` (gpui `app.rs`): the client of an app that has none. */
class NullHttpClient implements HttpClient {

    public function new() {}

    public function userAgent():Null<String> {
        return null;
    }

    public function proxy():Null<String> {
        return null;
    }

    public function send(request:HttpRequest):Task<HttpResponse> {
        return Task.failed('No HttpClient available');
    }

}
