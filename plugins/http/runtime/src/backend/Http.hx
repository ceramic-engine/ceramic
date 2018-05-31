package backend;

using StringTools;

class Http implements spec.Http {

    public function new() {}

    public function request(options:HttpRequestOptions, done:HttpResponse->Void):Void {

#if nodejs

        var isSSL = options.url.startsWith('https');
        var http = isSSL ? js.Node.require('https') : js.Node.require('http');
        var url = js.node.Url.parse(options.url);

        var requestOptions:Dynamic = {};
        requestOptions.host = url.hostname;
        requestOptions.port = url.port != null ? url.port : (isSSL ? 443 : 80);
        requestOptions.path = url.path;
        requestOptions.method = options.method != null ? options.method : 'GET';

        if (options.headers != null) {
            requestOptions.headers = {};
            for (key in options.headers) {
                Reflect.setField(requestOptions.headers, key, options.headers.get(key));
            }
        }

        var resContent = '';
        var resError = null;
        var resHeaders = new Map<String,String>();
        var resStatus = 404;

        var req:Dynamic = http.request(requestOptions, function(res:Dynamic) {

            resStatus = res.statusCode;

            res.setEncoding('utf8');

            res.on('data', function(chunk) {
                resContent += chunk;
            });

            res.on('end', function() {

                for (key in Reflect.fields(res.headers)) {
                    resHeaders.set(key, Reflect.field(res.headers, key));
                }

            });
        });

        req.on('error', function(e) {
            resError = e.message;
        });

        req.on('close', function() {
            done({
                status: resStatus,
                content: resStatus < 200 || resStatus >= 300 ? null : resContent,
                headers: resHeaders,
                error: resError
            });
        });

        // Write request body (if any)
        if (options.content != null) {
            req.write(options.content);
        }
        
        req.end();

#elseif akifox_asynchttp

        var httpHeaders;
        if (options.headers != null) {
            httpHeaders = new com.akifox.asynchttp.HttpHeaders();
            for (key in options.headers) {
                httpHeaders.add(key, options.headers.get(key));
            }
        } else {
            httpHeaders = null;
        }

        var request = new com.akifox.asynchttp.HttpRequest({
            url: options.url,
            method: options.method != null ? options.method : 'GET',
            content: options.content,
            headers: httpHeaders,
            callback: function(res:com.akifox.asynchttp.HttpResponse) {

                var headers = new Map<String,String>();
                for (key in res.headers.keys()) {
                    headers.set(key, res.headers.get(key));
                }

                var response:HttpResponse = {
                    status: res.status,
                    content: res.content,
                    headers: headers,
                    error: null // TODO
                };

                done(response);

            }
        });

        request.send();

#else
        // Not implemented
        done({
            status: 404,
            content: null,
            headers: new Map(),
            error: 'Not implemented'
        });
#end

    } //request

} //Http
