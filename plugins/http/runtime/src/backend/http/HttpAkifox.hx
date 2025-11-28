package backend.http;

#if akifox_asynchttp

class HttpAkifox {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void):Void {

#if ceramic_debug_http
        com.akifox.asynchttp.AsyncHttp.logEnabled = true;
        com.akifox.asynchttp.AsyncHttp.logErrorEnabled = true;
#else
        com.akifox.asynchttp.AsyncHttp.logEnabled = false;
        com.akifox.asynchttp.AsyncHttp.logErrorEnabled = false;
#end

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders;
        if (options.headers != null) {
            httpHeaders = new com.akifox.asynchttp.HttpHeaders();
            var i = 0;
            while (i < options.headers.length) {
                var key = options.headers[i];
                var value = options.headers[i + 1];
                if (key.toLowerCase() == 'content-type') {
                    contentType = value;
                } else {
                    httpHeaders.add(key, value);
                }
                i += 2;
            }
        } else {
            httpHeaders = null;
        }

        var content:String = null;
        if (options.content != null) {
            content = options.content + "\n";
        }

        var requestOptions:com.akifox.asynchttp.HttpRequest.HttpRequestOptions = {
            url: options.url,
            method: options.method != null ? options.method : 'GET',
            contentType: contentType,
            headers: httpHeaders,
            timeout: options.timeout != null && options.timeout > 0 ? options.timeout : null,
            callback: function(res:com.akifox.asynchttp.HttpResponse) {

                if (done == null) return;

                var headers:Array<String> = [];
                for (key in res.headers.keys()) {
                    headers.push(key);
                    headers.push(res.headers.get(key));
                }

                var response:HttpResponse = {
                    status: res.status,
                    content: res.contentIsBinary ? null : res.content,
                    binaryContent: res.contentIsBinary ? res.contentRaw : null,
                    headers: headers,
                    error: null // TODO
                };

                var _done = done;
                done = null;
                _done(response);

            }
        };

        // Add content
        if (options.content != null) {
            requestOptions.content = options.content;
            requestOptions.contentIsBinary = false;
        }

        var request = new com.akifox.asynchttp.HttpRequest(requestOptions);

        if (options.timeout != null && options.timeout > 0) {
            request.timeout = options.timeout;

            ceramic.Timer.delay(null, options.timeout + 1.0, function() {
                if (done == null) return;
                var _done = done;
                done = null;
                _done({
                    status: 408,
                    content: null,
                    binaryContent: null,
                    headers: [],
                    error: null
                });
            });
        }

        request.send();

    }

}

#end
