package backend.http;

#if js

import haxe.io.Bytes;
import js.html.XMLHttpRequest;

import ceramic.Shortcuts.*;

using StringTools;

class HttpWeb {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void):Void {

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders:Array<String> = null;
        if (options.headers != null) {
            httpHeaders = [];
            var i = 0;
            while (i < options.headers.length) {
                var key = options.headers[i];
                var value = options.headers[i + 1];
                if (key.toLowerCase() == 'content-type') {
                    contentType = value;
                } else {
                    httpHeaders.push(key);
                    httpHeaders.push(value);
                }
                i += 2;
            }
        }

        var content:String = null;
        if (options.content != null) {
            content = options.content;
        }

        var xhr = new XMLHttpRequest();

        untyped xhr.responseType = 'arraybuffer';

        if (options.timeout != null && options.timeout > 0) {
            xhr.timeout = options.timeout * 1000;

            ceramic.Timer.delay(null, options.timeout + 1.0, function() {
                if (done == null) return;
                xhr.abort();
            });
        }

        xhr.open(
            options.method != null ? options.method : 'GET',
            options.url,
            true
        );

        if (httpHeaders != null) {
            var i = 0;
            while (i < httpHeaders.length) {
                var key = httpHeaders[i];
                var value = httpHeaders[i + 1];

                // Skip unsafe header
                if (key.toLowerCase() != 'content-length') {
                    xhr.setRequestHeader(key, value);
                }
                i += 2;
            }
        }

        if (content != null) {
            xhr.setRequestHeader('Content-Type', contentType);
        }

        var handleTimeout = function() {
            if (done == null) return;

            var response:HttpResponse = {
                status: 408,
                content: null,
                binaryContent: null,
                headers: [],
                error: null
            };

            var _done = done;
            done = null;
            _done(response);
        };

        xhr.onabort = handleTimeout;
        xhr.ontimeout = handleTimeout;

        xhr.onload = function() {
            if (done == null) return;

            var rawHeaders = xhr.getAllResponseHeaders();
            var headers:Array<String> = [];
            var contentType = null;
            if (rawHeaders != null) {
                for (rawHeader in rawHeaders.split("\n")) {
                    if (rawHeader.trim() == '') continue;
                    var colonIndex = rawHeader.indexOf(':');
                    if (colonIndex != -1) {
                        var key = rawHeader.substring(0, colonIndex).trim();
                        var value = rawHeader.substring(colonIndex + 1).trim();
                        headers.push(key);
                        headers.push(value);

                        if (contentType == null && key.toLowerCase() == 'content-type') {
                            contentType = value;
                        }
                    }
                    else {
                        log.warning('Failed to parse header: $rawHeader');
                    }
                }
            }
            if (contentType == null)
                contentType = 'application/octet-stream';

            var binaryContent:Bytes = null;
            if (xhr.response != null) {
                try {
                    var responseBuffer:js.lib.ArrayBuffer = xhr.response;
                    binaryContent = ceramic.UInt8Array.fromBuffer(responseBuffer, 0, responseBuffer.byteLength).toBytes();
                }
                catch (e:Dynamic) {}
            }

            var textContent:String = null;
            if (binaryContent != null && ceramic.MimeType.isText(contentType)) {
                // Treat text as utf-8. Could be improved
                textContent = binaryContent.toString();
                binaryContent = null;
            }

            var response:HttpResponse = {
                status: xhr.status,
                content: textContent,
                binaryContent: binaryContent,
                headers: headers,
                error: null
            };

            var _done = done;
            done = null;
            _done(response);
        };

        xhr.onerror = function() {
            if (done == null) return;

            var rawHeaders = xhr.getAllResponseHeaders();
            var headers:Array<String> = [];
            if (rawHeaders != null) {
                for (rawHeader in rawHeaders.split("\n")) {
                    if (rawHeader.trim() == '') continue;
                    var colonIndex = rawHeader.indexOf(':');
                    if (colonIndex != -1) {
                        var key = rawHeader.substring(0, colonIndex).trim();
                        var value = rawHeader.substring(colonIndex + 1).trim();
                        headers.push(key);
                        headers.push(value);
                    }
                    else {
                        log.warning('Failed to parse header: $rawHeader');
                    }
                }
            }

            var response:HttpResponse = {
                status: xhr.status,
                content: null,
                binaryContent: null,
                headers: headers,
                error: xhr.statusText
            };

            var _done = done;
            done = null;
            _done(response);
        };

        xhr.send(content);

    }

}

#end
