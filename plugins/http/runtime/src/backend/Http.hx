package backend;

#if android
import android.Http as AndroidHttp;
#elseif ios
import ios.Http as IosHttp;
#elseif js
import js.html.XMLHttpRequest;
#end

import ceramic.Shortcuts.*;

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

        if (options.timeout != null && options.timeout > 0) {
            requestOptions.timeout = options.timeout * 1000;
        }

        if (options.headers != null) {
            requestOptions.headers = {};
            for (key in options.headers.keys()) {
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

#elseif android

        var requestOptions:Dynamic = {};
        requestOptions.url = options.url;
        requestOptions.method = options.method != null ? options.method : 'GET';
        if (options.headers != null) {
            requestOptions.headers = {};
            for (key in options.headers.keys()) {
                Reflect.setField(requestOptions.headers, key, options.headers.get(key));
            }
        }
        if (options.content != null) {
            requestOptions.content = options.content;
        }

        if (options.timeout != null && options.timeout > 0) {
            requestOptions.timeout = options.timeout;
        }

        AndroidHttp.sendHttpRequest(requestOptions, function(rawResponse) {
            var useContent = rawResponse.status >= 200 && rawResponse.status < 300;
            var headers = new Map<String,String>();
            if (rawResponse.headers != null) {
                for (key in Reflect.fields(rawResponse.headers)) {
                    headers.set(key, Reflect.field(rawResponse.headers, key));
                }
            }
            done({
                status: rawResponse.status,
                content: useContent ? rawResponse.content : null,
                headers: headers,
                error: rawResponse.error
            });
        });

#elseif ios

        var requestOptions:Dynamic = {};
        requestOptions.url = options.url;
        requestOptions.method = options.method != null ? options.method : 'GET';
        if (options.headers != null) {
            requestOptions.headers = {};
            for (key in options.headers.keys()) {
                Reflect.setField(requestOptions.headers, key, options.headers.get(key));
            }
        }
        if (options.content != null) {
            requestOptions.content = options.content;
        }

        if (options.timeout != null && options.timeout > 0) {
            requestOptions.timeout = options.timeout;
        }

        IosHttp.sendHTTPRequest(requestOptions, function(rawResponse) {
            var useContent = rawResponse.status >= 200 && rawResponse.status < 300;
            var headers = new Map<String,String>();
            if (rawResponse.headers != null) {
                for (key in Reflect.fields(rawResponse.headers)) {
                    headers.set(key, Reflect.field(rawResponse.headers, key));
                }
            }
            done({
                status: rawResponse.status,
                content: useContent ? rawResponse.content : null,
                headers: headers,
                error: rawResponse.error
            });
        });

#elseif js

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders:Map<String,String>;
        if (options.headers != null) {
            httpHeaders = new Map();
            for (key in options.headers.keys()) {
                if (key.toLowerCase() == 'content-type') {
                    contentType = options.headers.get(key);
                } else {
                    httpHeaders.set(key, options.headers.get(key));
                }
            }
        } else {
            httpHeaders = null;
        }

        var content:String = null;
        if (options.content != null) {
            content = options.content;
        }

        var xhr = new XMLHttpRequest();

        if (options.timeout != null && options.timeout > 0) {
            xhr.timeout = options.timeout * 1000;
            trace('OPTION TIMEOUT = ${xhr.timeout}');

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
            for (key in httpHeaders.keys()) {
                xhr.setRequestHeader(key, httpHeaders.get(key));
            }
        }

        if (content != null) {
            xhr.setRequestHeader('Content-Type', contentType);
        }

        var handleTimeout = function() {
            if (done == null) return;

            var headers = new Map<String,String>();

            var response:HttpResponse = {
                status: 408,
                content: null,
                headers: headers,
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
            var headers = new Map<String,String>();
            if (rawHeaders != null) {
                for (rawHeader in rawHeaders.split("\n")) {
                    if (rawHeader.trim() == '') continue;
                    var colonIndex = rawHeader.indexOf(':');
                    if (colonIndex != -1) {
                        var key = rawHeader.substring(0, colonIndex).trim();
                        var value = rawHeader.substring(colonIndex + 1).trim();
                        headers.set(key, value);
                    }
                    else {
                        warning('Failed to parse header: $rawHeader');
                    }
                }
            }

            var response:HttpResponse = {
                status: xhr.status,
                content: xhr.responseText,
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
            var headers = new Map<String,String>();
            if (rawHeaders != null) {
                for (rawHeader in rawHeaders.split("\n")) {
                    if (rawHeader.trim() == '') continue;
                    var colonIndex = rawHeader.indexOf(':');
                    if (colonIndex != -1) {
                        var key = rawHeader.substring(0, colonIndex).trim();
                        var value = rawHeader.substring(colonIndex + 1).trim();
                        headers.set(key, value);
                    }
                    else {
                        warning('Failed to parse header: $rawHeader');
                    }
                }
            }

            var response:HttpResponse = {
                status: xhr.status,
                content: null,
                headers: headers,
                error: xhr.statusText
            };

            var _done = done;
            done = null;
            _done(response);
        };

        xhr.send(content);

#elseif akifox_asynchttp

#if ceramic_debug_http
        com.akifox.asynchttp.AsyncHttp.logEnabled = true;
#else
        com.akifox.asynchttp.AsyncHttp.logEnabled = false;
#end

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders;
        if (options.headers != null) {
            httpHeaders = new com.akifox.asynchttp.HttpHeaders();
            for (key in options.headers.keys()) {
                if (key.toLowerCase() == 'content-type') {
                    contentType = options.headers.get(key);
                } else {
                    httpHeaders.add(key, options.headers.get(key));
                }
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
        };

        // Add content
        if (options.content != null) {
            requestOptions.content = options.content;
            requestOptions.contentIsBinary = false;
        }

        var request = new com.akifox.asynchttp.HttpRequest(requestOptions);

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
