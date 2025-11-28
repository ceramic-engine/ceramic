package backend.http;

#if ceramic_http_tink

import haxe.io.Bytes;
import tink.http.Fetch;
import tink.http.Header;

class HttpTink {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void):Void {

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders = [];
        if (options.headers != null) {
            var i = 0;
            while (i < options.headers.length) {
                var key = options.headers[i];
                var value = options.headers[i + 1];
                if (key.toLowerCase() == 'content-type') {
                    contentType = value;
                } else {
                    httpHeaders.push(new HeaderField(key, value));
                }
                i += 2;
            }
        }
        httpHeaders.unshift(new HeaderField(CONTENT_TYPE, contentType));

        var fetchOptions:FetchOptions = {
            #if (ceramic_http_tink_curl_cli || (mac && !ceramic_no_http_tink_curl_cli))
            client: Curl,
            #else
            client: Default,
            #end
            method: cast (options.method != null ? options.method : 'GET'),
            headers: httpHeaders
        };

        // Add content
        if (options.content != null) {
            fetchOptions.body = options.content;
        }

        ceramic.Runner.runInBackground(function() {

            tink.http.Client.fetch(options.url, fetchOptions).all()
            .handle(function(o) {

                ceramic.Runner.runInMain(function() {

                    if (done == null) return;

                    switch o {
                        case Success(res):
                            var bytes = res.body.toBytes();

                            var resContentType:String = null;
                            var headers:Array<String> = [];
                            for (headerField in res.header) {
                                var name = ''+headerField.name;
                                var value = ''+headerField.value;
                                headers.push(name);
                                headers.push(value);

                                if (resContentType == null && name.toLowerCase() == 'content-type') {
                                    resContentType = value;
                                }
                            }

                            if (resContentType == null)
                                resContentType = 'application/octet-stream';

                            var resTextContent:String = null;
                            var resBinaryContent:Bytes = null;
                            if (ceramic.MimeType.isText(resContentType)) {
                                resTextContent = (bytes != null ? bytes.toString() : null);
                            }
                            else {
                                resBinaryContent = bytes;
                            }

                            var response:HttpResponse = {
                                status: res.header.statusCode.toInt(),
                                content: resTextContent,
                                binaryContent: resBinaryContent,
                                headers: headers,
                                error: null
                            };

                            var _done = done;
                            done = null;
                            _done(response);

                        case Failure(e):

                            var response:HttpResponse = {
                                status: 404,
                                content: null,
                                binaryContent: null,
                                headers: [],
                                error: e != null ? e.message + ' (${e.code})' : null
                            };

                            var _done = done;
                            done = null;
                            _done(response);
                    }
                });
            });
        });

        if (options.timeout != null && options.timeout > 0) {
            var timeout:Float = options.timeout;

            ceramic.Timer.delay(null, timeout + 1.0, function() {
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

    }

}

#end
