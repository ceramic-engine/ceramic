package glaze;

#if plugin_http

import glaze.HttpClient;

/**
 * The HTTP client of the Ceramic platform: requests go through Ceramic's
 * `http` plugin (`ceramic.Http`), which uses XMLHttpRequest on the web,
 * Node's `http`/`https` on Node and a socket client on native targets.
 *
 * It stands for the clients GPUI apps install (`FetchHttpClient` of
 * `gpui_web`, `ReqwestClient` on desktop). The app gets one by default when
 * the `http` plugin is enabled (see `App.httpClient()`).
 *
 * Differences with GPUI's clients:
 *
 * - redirects are always followed (Ceramic's backends follow up to 8 or 10
 *   redirects): `RedirectPolicy.NoFollow` is not supported;
 * - on the web, the browser applies its rules like `FetchHttpClient`: a
 *   cross-origin response without CORS headers cannot be read and the request
 *   fails, the user agent is the browser's;
 * - native targets send their own user agent (`akifox-asynchttp`): the user
 *   agent given here is sent on Node only.
 *
 * Only available when the `http` plugin is enabled (define `plugin_http`).
 */
class CeramicHttpClient implements HttpClient {

    final _userAgent:Null<String>;

    /** Request timeout in seconds (0: the backend's default) */
    public var timeout:Int = 0;

    public function new(?userAgent:String) {
        _userAgent = userAgent;
    }

    /** Rust `ReqwestClient::user_agent` */
    public static function withUserAgent(userAgent:String):CeramicHttpClient {
        return new CeramicHttpClient(userAgent);
    }

    public function userAgent():Null<String> {
        return _userAgent;
    }

    public function proxy():Null<String> {
        return null;
    }

    public function send(request:HttpRequest):Task<HttpResponse> {
        final task = new Task<HttpResponse>();

        final method:Null<ceramic.HttpMethod> = switch request.method.toUpperCase() {
            case 'GET': GET;
            case 'POST': POST;
            case 'PUT': PUT;
            case 'DELETE': DELETE;
            case _: null;
        }
        if (method == null)
            return Task.failed('unsupported HTTP method: ' + request.method);

        final headers = new ceramic.HttpHeaders();
        var i = 0;
        while (i + 1 < request.headers.length) {
            headers.add(request.headers[i], request.headers[i + 1]);
            i += 2;
        }
        #if !web
        if (_userAgent != null)
            headers.add('User-Agent', _userAgent);
        #end

        final options:ceramic.HttpRequestOptions = {
            url: request.uri,
            method: method,
            headers: headers,
            binary: true
        };
        if (request.body != null)
            options.content = request.body.toString();
        if (timeout > 0)
            options.timeout = timeout;

        try {
            ceramic.Http.request(options, response -> {
                if (!task.isPending)
                    return;
                if (response.error != null || response.status <= 0) {
                    final message = response.error != null && response.error != '' ? response.error : 'request failed';
                    task.reject('$message (${request.method} ${request.uri})');
                    return;
                }
                final responseHeaders:Array<String> = [];
                if (response.headers != null) {
                    for (name => value in response.headers) {
                        responseHeaders.push(name);
                        responseHeaders.push(value);
                    }
                }
                task.resolve(new HttpResponse(response.status, responseHeaders, response.binaryContent));
            });
        }
        catch (e:Dynamic) {
            task.reject(Std.string(e));
        }

        return task;
    }

}

#end
