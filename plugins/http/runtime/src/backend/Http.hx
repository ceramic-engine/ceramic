package backend;

import ceramic.IntMap;
import ceramic.Path;
import ceramic.Runner;
import ceramic.Shortcuts.*;
import haxe.crypto.Base64;
import haxe.io.Bytes;

using StringTools;
#if android
import android.Http as AndroidHttp;
#elseif ios
import ios.Http as IosHttp;
#elseif js
import js.html.XMLHttpRequest;
#elseif (cs && unity)
import unityengine.networking.DownloadHandler;
import unityengine.networking.UnityWebRequest;
#elseif ceramic_http_tink
import tink.http.Fetch;
import tink.http.Header;
#end

#if (cpp || cs || sys || nodejs || hxnodejs || node)
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Platform-specific HTTP implementation providing cross-platform HTTP request functionality.
 * 
 * This class implements the low-level HTTP backend for the Ceramic HTTP plugin, providing
 * native HTTP request capabilities across all supported platforms including:
 * 
 * Supported Platforms:
 * - Node.js (nodejs/hxnodejs/node): Uses Node.js http/https modules
 * - Android: Uses Android native HTTP implementation
 * - iOS: Uses iOS native HTTP implementation  
 * - Web/JS: Uses XMLHttpRequest with ArrayBuffer responses
 * - Unity C#: Uses UnityWebRequest with coroutine-based async handling
 * - Tink HTTP: Uses tink_http library for additional platform support
 * - AkifoxAsyncHttp: Alternative HTTP library support
 * 
 * Features:
 * - Automatic redirect handling (up to 8 redirects)
 * - Timeout support with proper cleanup
 * - Binary and text response handling based on MIME types
 * - Header processing and normalization
 * - File download capabilities with progress tracking
 * - Cross-platform error handling and reporting
 * 
 * The implementation automatically detects the target platform and uses the most
 * appropriate HTTP mechanism available. All platform-specific code is contained
 * within conditional compilation blocks.
 * 
 * Note: This class should not be used directly by application code. Use the
 * high-level ceramic.Http class instead.
 */
#if (cs && unity)
@:classCode('
System.Collections.IEnumerator unityRunWebRequest(int id, UnityEngine.Networking.UnityWebRequest request) {
    yield return request.SendWebRequest();
    unityHandleWebRequestResponse(id, request.downloadHandler);
}
')
#end
class Http implements spec.Http {

    #if (cs && unity)
    /** Unity-specific: Counter for generating unique request IDs */
    var nextRequestId:Int = 1;
    
    /** Unity-specific: Map of request IDs to their completion callbacks */
    var requestCallbacks:Map<Int, DownloadHandler->Void> = new Map();

    /**
     * Unity-specific callback handler for completed web requests.
     * 
     * This method is called from the Unity coroutine when a web request completes.
     * It retrieves and executes the appropriate callback for the request.
     * 
     * @param requestId The unique ID of the completed request
     * @param downloadHandler The Unity download handler containing the response data
     */
    @:keep function unityHandleWebRequestResponse(requestId:Int, downloadHandler:DownloadHandler):Void {

        var callback:DownloadHandler->Void = requestCallbacks.get(requestId);
        if (callback != null) {
            requestCallbacks.remove(requestId);
            callback(downloadHandler);
            callback = null;
        }

    }
    #end

    /** Creates a new HTTP backend instance */
    public function new() {}

    /**
     * Performs an HTTP request using the appropriate platform-specific implementation.
     * 
     * This method dispatches to the correct platform implementation and ensures
     * that the response callback is executed on the main thread for thread safety.
     * It handles the complete request lifecycle including timeouts, redirects,
     * and proper resource cleanup.
     * 
     * The method automatically:
     * - Detects and handles different content types (text vs binary)
     * - Follows HTTP redirects (up to 8 levels deep)
     * - Applies timeouts and handles timeout cleanup
     * - Processes response headers and status codes
     * - Ensures thread-safe callback execution
     * 
     * @param options The HTTP request configuration
     * @param requestDone Callback function that receives the HTTP response
     */
    public function request(options:HttpRequestOptions, requestDone:HttpResponse->Void):Void {

        var done:HttpResponse->Void = null;
        done = (response:HttpResponse) -> {
            ceramic.App.app.onceUpdate(null, _ -> {
                requestDone(response);
                requestDone = null;
                done = null;
            });
        };

        _request(options, done);

    }

    /**
     * Internal method that performs the actual HTTP request with platform-specific implementations.
     * 
     * This method contains all the platform-specific HTTP request logic using conditional
     * compilation to select the appropriate implementation. It handles redirects recursively
     * and manages the complete request lifecycle for each platform.
     * 
     * Platform implementations:
     * - Node.js: Uses native http/https modules with stream handling
     * - Android: Delegates to Android native HTTP implementation
     * - iOS: Delegates to iOS native HTTP implementation
     * - Web: Uses XMLHttpRequest with ArrayBuffer for binary support
     * - Unity: Uses UnityWebRequest with coroutine-based async execution
     * - Tink HTTP: Uses tink_http library for cross-platform support
     * - AkifoxAsyncHttp: Alternative HTTP library implementation
     * 
     * @param options The HTTP request configuration
     * @param done Callback function that receives the HTTP response
     * @param numRedirects Current redirect count for redirect loop prevention
     */
    function _request(options:HttpRequestOptions, done:HttpResponse->Void, numRedirects:Int = 0):Void {

#if (nodejs || hxnodejs || node)

        var isSSL = options.url.startsWith('https');
        var http = isSSL ? js.Node.require('https') : js.Node.require('http');
        var url = new js.node.url.URL(options.url);

        var requestOptions:Dynamic = {};
        requestOptions.host = url.hostname;
        requestOptions.port = url.port != null ? url.port : (isSSL ? 443 : 80);
        requestOptions.path = url.pathname;
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

        var resContent = [];
        var resError = null;
        var resHeaders = new Map<String,String>();
        var resStatus = 404;
        var textContent:String = null;
        var binaryContent:Bytes = null;
        var didRedirect:Bool = false;

        var req:Dynamic = http.request(requestOptions, function(res:Dynamic) {

            resStatus = res.statusCode;

            if (numRedirects < 8 && (resStatus >= 300 && resStatus <= 399) && res.headers.location != null) {

                didRedirect = true;

                var newUrl:String = options.url;
                var newLocation:String = res.headers.location;
                if (!newLocation.toLowerCase().startsWith('http://') && !newLocation.toLowerCase().startsWith('https://')) {
                    var slashIndex = newUrl.indexOf('/', 8);
                    if (slashIndex != -1) {
                        newUrl = newUrl.substring(0, slashIndex);
                    }
                    if (newLocation.charAt(0) != '/')
                        newUrl += '/';
                    newUrl += newLocation;
                }
                else {
                    newUrl = newLocation;
                }

                var redirectedOptions:HttpRequestOptions = {
                    url: newUrl
                };
                redirectedOptions.timeout = options.timeout;
                if (resStatus == 307) {
                    redirectedOptions.method = options.method;
                    redirectedOptions.content = options.content;
                    redirectedOptions.headers = options.headers;
                }
                else {
                    redirectedOptions.method = GET;
                    redirectedOptions.content = null;
                }
                _request(redirectedOptions, done, numRedirects + 1);
                return;
            }

            res.on('data', function(chunk) {
                if (!didRedirect) {
                    resContent.push(chunk);
                }
            });

            res.on('end', function() {
                if (!didRedirect) {
                    var buffer:Dynamic = js.Syntax.code('Buffer.concat({0})', resContent);

                    var resContentType:String = null;
                    for (key in Reflect.fields(res.headers)) {
                        resHeaders.set(key, Reflect.field(res.headers, key));

                        if (resContentType == null && key.toLowerCase() == 'content-type') {
                            resContentType = Reflect.field(res.headers, key);
                        }
                    }

                    if (resContentType == null)
                        resContentType = 'application/octet-stream';

                    if (ceramic.MimeType.isText(resContentType)) {
                        textContent = buffer.toString('utf8');
                    }
                    else {
                        // Copy data and get rid of nodejs buffer
                        var bufferData = new js.lib.Uint8Array(buffer.length);
                        for (i in 0...buffer.length) {
                            bufferData[i] = js.Syntax.code("{0}[{1}]", buffer, i);
                        }
                        binaryContent = haxe.io.Bytes.ofData(bufferData.buffer);
                    }
                }
            });
        });

        req.on('error', function(e) {
            if (!didRedirect) {
                resError = e.message;
            }
        });

        req.on('close', function() {
            if (!didRedirect) {
                done({
                    status: resStatus,
                    content: resStatus < 200 || resStatus >= 300 ? null : textContent,
                    binaryContent: resStatus < 200 || resStatus >= 300 ? null : binaryContent,
                    headers: resHeaders,
                    error: resError
                });
            }
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

            var binaryContent:Bytes = null;
            if (rawResponse.binaryContent != null) {
                var binaryContentRaw:String = rawResponse.binaryContent;
                binaryContent = Base64.decode(binaryContentRaw);
            }

            done({
                status: rawResponse.status,
                content: useContent ? rawResponse.content : null,
                binaryContent: binaryContent,
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

        trace('IOS HTTP SEND HTTP REQUEST');
        IosHttp.sendHTTPRequest(requestOptions, function(rawResponse) {
            var useContent = rawResponse.status >= 200 && rawResponse.status < 300;
            var headers = new Map<String,String>();
            if (rawResponse.headers != null) {
                for (key in Reflect.fields(rawResponse.headers)) {
                    headers.set(key, Reflect.field(rawResponse.headers, key));
                }
            }

            var binaryContent:Bytes = null;
            if (rawResponse.binaryContent != null) {
                binaryContent = Bytes.ofData(rawResponse.binaryContent);
            }

            done({
                status: rawResponse.status,
                content: useContent ? rawResponse.content : null,
                binaryContent: binaryContent,
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
            for (key in httpHeaders.keys()) {

                // Skip unsafe header
                if (key.toLowerCase() == 'content-length')
                    continue;

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
                binaryContent: null,
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
            var contentType = null;
            if (rawHeaders != null) {
                for (rawHeader in rawHeaders.split("\n")) {
                    if (rawHeader.trim() == '') continue;
                    var colonIndex = rawHeader.indexOf(':');
                    if (colonIndex != -1) {
                        var key = rawHeader.substring(0, colonIndex).trim();
                        var value = rawHeader.substring(colonIndex + 1).trim();
                        headers.set(key, value);

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

#elseif (cs && unity)

        var requestId = nextRequestId;
        nextRequestId = (nextRequestId + 1) % 999999999;

        var content:String = null;
        if (options.content != null)
            content = options.content;

        var url = options.url;

        var webRequest:UnityWebRequest = null;
        try {
            if (content == null || options.method == GET || options.method == DELETE) {
                webRequest = switch options.method {
                    case GET: UnityWebRequest.Get(url);
                    case DELETE: UnityWebRequest.Delete(url);
                    case _: UnityWebRequest.Get(url);
                }
            }
            else {
                webRequest = new UnityWebRequest();
                webRequest.url = url;
                webRequest.method = switch options.method {
                    case POST: untyped __cs__('UnityEngine.Networking.UnityWebRequest.kHttpVerbPOST');
                    case PUT: untyped __cs__('UnityEngine.Networking.UnityWebRequest.kHttpVerbPUT');
                    case _: untyped __cs__('UnityEngine.Networking.UnityWebRequest.kHttpVerbPOST');
                };
                webRequest.downloadHandler = untyped __cs__('new UnityEngine.Networking.DownloadHandlerBuffer()');
                webRequest.uploadHandler = untyped __cs__('new UnityEngine.Networking.UploadHandlerRaw(System.Text.Encoding.UTF8.GetBytes({0}))', content);
            }
            webRequest.disposeUploadHandlerOnDispose = true;
            webRequest.disposeDownloadHandlerOnDispose = true;

            if (options.headers != null) {
                for (key in options.headers.keys()) {
                    if (key.toLowerCase() != 'content-length') {
                        webRequest.SetRequestHeader(key, options.headers.get(key));
                    }
                }
            }

            requestCallbacks.set(requestId, function(downloadHandler) {

                var resStatus = Std.int(webRequest.responseCode);
                var resHeaders = new Map<String, String>();

                if (webRequest.isNetworkError || webRequest.isHttpError) {
                    done({
                        status: resStatus,
                        content: resStatus < 200 || resStatus >= 300 ? null : downloadHandler.text,
                        binaryContent: null,
                        headers: resHeaders,
                        error: webRequest.error
                    });
                }
                else {

                    var rawHeaders = webRequest.GetResponseHeaders();
                    untyped __cs__('foreach(var rawHeaderEntry in ((System.Collections.Generic.Dictionary<string,string>){0})) {', rawHeaders);
                    var headerName:String = untyped __cs__('rawHeaderEntry.Key');
                    var headerValue:String = untyped __cs__('rawHeaderEntry.Value');
                    resHeaders.set(headerName, headerValue);
                    untyped __cs__('}');

                    var resContentType:String = null;
                    for (key in resHeaders.keys()) {
                        if (resContentType == null && key.toLowerCase() == 'content-type') {
                            resContentType = resHeaders.get(key);
                        }
                    }

                    if (resContentType == null)
                        resContentType = 'application/octet-stream';

                    var resTextContent:String = null;
                    var resBinaryContent:Bytes = null;
                    if (ceramic.MimeType.isText(resContentType)) {
                        resTextContent = downloadHandler.text;
                    }
                    else {
                        resBinaryContent = haxe.io.Bytes.ofData(cast downloadHandler.data);
                    }

                    done({
                        status: resStatus,
                        content: resTextContent,
                        binaryContent: resBinaryContent,
                        headers: resHeaders,
                        error: webRequest.error
                    });
                }

                if (webRequest != null)
                    webRequest.Dispose();
                if (downloadHandler != null)
                    downloadHandler.Dispose();

            });

            var monoBehaviour = Main.monoBehaviour;
            untyped __cs__('{0}.StartCoroutine(unityRunWebRequest({1}, {2}))', monoBehaviour, requestId, webRequest);

        } catch (e:Dynamic) {
            if (webRequest != null) {
                try {
                    webRequest.Dispose();
                    webRequest = null;
                }
                catch (e1:Dynamic) {}
            }

            done({
                status: 404,
                content: null,
                binaryContent: null,
                headers: new Map(),
                error: 'Error: ' + e
            });
        }

#elseif ceramic_http_tink

        var contentType = "application/x-www-form-urlencoded";
        var httpHeaders = [];
        if (options.headers != null) {
            for (key in options.headers.keys()) {
                if (key.toLowerCase() == 'content-type') {
                    contentType = options.headers.get(key);
                } else {
                    httpHeaders.push(new HeaderField(key, options.headers.get(key)));
                }
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
                            var headers = new Map<String,String>();
                            for (headerField in res.header) {
                                headers.set(''+headerField.name, ''+headerField.value);

                                if (resContentType == null && (''+headerField.name).toLowerCase() == 'content-type') {
                                    resContentType = ''+headerField.value;
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
                                headers: new Map(),
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
                    headers: new Map(),
                    error: null
                });
            });
        }

#elseif akifox_asynchttp

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
            timeout: options.timeout != null && options.timeout > 0 ? options.timeout : null,
            callback: function(res:com.akifox.asynchttp.HttpResponse) {

                if (done == null) return;

                var headers = new Map<String,String>();
                for (key in res.headers.keys()) {
                    headers.set(key, res.headers.get(key));
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
                    headers: new Map(),
                    error: null
                });
            });
        }

        request.send();

#else
        // Not implemented
        done({
            status: 404,
            content: null,
            binaryContent: null,
            headers: new Map(),
            error: 'Not implemented'
        });
#end

    }

    /**
     * Downloads a file from the specified URL to a local file path.
     * 
     * This method provides cross-platform file download functionality with automatic
     * path resolution and temporary file handling for safe downloads. The implementation
     * varies by platform to use the most efficient download mechanism available.
     * 
     * Features:
     * - Automatic path resolution (relative paths are resolved against storage directory)
     * - Safe download using temporary files (prevents corruption on failure)
     * - Platform-optimized download methods (curl on Unix, native APIs on mobile)
     * - Automatic directory creation if needed
     * - Progress tracking and error handling
     * 
     * Platform implementations:
     * - iOS/Android: Uses native download APIs with progress callbacks
     * - Mac/Linux: Uses system curl command for reliable downloads
     * - Windows: Uses curl via PowerShell
     * - Unity: Uses UnityWebRequest with file download handler
     * - Node.js: Uses http/https modules with file streams
     * 
     * The method ensures atomic downloads by first downloading to a temporary file
     * (.tmpdl extension) and then moving it to the final location upon success.
     * 
     * @param url The URL of the file to download
     * @param targetPath The local file path where the file should be saved (can be relative)
     * @param done Callback function that receives the final file path on success, or null on failure
     */
    public function download(url:String, targetPath:String, done:String->Void):Void {

        if (!Path.isAbsolute(targetPath)) {
            var basePath = app.backend.info.storageDirectory();
            if (basePath == null) {
                log.warning('Cannot download $url at path $targetPath because there is no storage directory');
                done(null);
                return;
            }
            targetPath = Path.join([basePath, targetPath]);
        }

        var tmpTargetPath = targetPath + '.tmpdl';

        #if ios

        IosHttp.download({ url: url }, targetPath, function(fullPath) {
            if (fullPath == null) {
                log.error('Failed to download $url at path $targetPath');
            }
            done(fullPath);
        });
        return;

        #elseif android

        AndroidHttp.download({ url: url }, targetPath, function(fullPath) {
            if (fullPath == null) {
                log.error('Failed to download $url at path $targetPath');
            }
            done(fullPath);
        });
        return;

        #elseif (cpp || cs || sys || nodejs || hxnodejs || node)

        // Ensure we can write the file at the desired location
        if (FileSystem.exists(tmpTargetPath)) {
            if (FileSystem.isDirectory(tmpTargetPath)) {
                log.error('Cannot overwrite directory named $tmpTargetPath');
                done(null);
                return;
            }
            FileSystem.deleteFile(tmpTargetPath);
        }
        var dir = Path.directory(tmpTargetPath);
        if (!FileSystem.exists(dir)) {
            FileSystem.createDirectory(dir);
        }
        else if (!FileSystem.isDirectory(dir)) {
            log.error('Target directory $dir should be a directory, but it is a file');
            done(null);
            return;
        }

        function finishDownload() {

            if (FileSystem.exists(tmpTargetPath)) {
                if (FileSystem.exists(targetPath)) {
                    if (FileSystem.isDirectory(targetPath)) {
                        log.error('Cannot overwrite directory named $targetPath');
                        done(null);
                        return;
                    }
                    FileSystem.deleteFile(targetPath);
                }
                FileSystem.rename(tmpTargetPath, targetPath);
                if (FileSystem.exists(targetPath) && !FileSystem.isDirectory(targetPath)) {
                    log.success('Downloaded file from url $url at path $targetPath');
                    done(targetPath);
                    return;
                }
                else {
                    log.error('Error when copying $tmpTargetPath to $targetPath');
                    done(null);
                    return;
                }
            }
            else {
                log.error('Failed to download $url at path $targetPath. No downloaded file.');
                done(null);
                return;
            }

        }

        #if (mac || linux)

        // Use built-in curl on mac & linux, that's the easiest!
        Runner.runInBackground(function() {
            Sys.command('curl', ['-sS', '-L', url, '--output', tmpTargetPath]);
            Runner.runInMain(finishDownload);
        });
        return;

        #elseif windows

        // Use curl through powershell on windows
        Runner.runInBackground(function() {
            var escapedArgs = [];
            for (arg in ['-sS', '-L' , url, '--output', tmpTargetPath]) {
                escapedArgs.push(haxe.SysTools.quoteWinArg(arg, true));
            }

            Sys.command('powershell', ['-command', escapedArgs.join(' ')]);
            Runner.runInMain(finishDownload);
        });
        return;

        #elseif (cs && unity)

        var requestId = nextRequestId;
        nextRequestId = (nextRequestId + 1) % 999999999;

        var webRequest = new UnityWebRequest();
        webRequest.url = url;
        webRequest.method = untyped __cs__('UnityEngine.Networking.UnityWebRequest.kHttpVerbGET');
        webRequest.downloadHandler = untyped __cs__('new UnityEngine.Networking.DownloadHandlerFile({0})', tmpTargetPath);
        webRequest.disposeDownloadHandlerOnDispose = true;

        requestCallbacks.set(requestId, function(downloadHandler) {

            if (webRequest != null)
                webRequest.Dispose();
            if (downloadHandler != null)
                downloadHandler.Dispose();

            finishDownload();

        });

        var monoBehaviour = Main.monoBehaviour;
        untyped __cs__('{0}.StartCoroutine(unityRunWebRequest({1}, {2}))', monoBehaviour, requestId, webRequest);

        #elseif (nodejs || hxnodejs || node)

        var isSSL = url.startsWith('https');
        var http = isSSL ? js.Node.require('https') : js.Node.require('http');
        var fs = js.Node.require('fs');
        var responded = false;

        var request = http.get(url, function(response:Dynamic) {

            // Check if the request was successful
            if (response.statusCode != 200) {
                log.error('Failed to download $url at path $targetPath. Status code: ${response.statusCode}');
                done(null);
                return;
            }

            // Create a writable stream to save the file
            var fileStream:Dynamic = fs.createWriteStream(tmpTargetPath);
            response.pipe(fileStream);

            fileStream.on('finish', function() {
                fileStream.close();
                if (!responded) {
                    responded = true;
                    finishDownload();
                }
            });

            fileStream.on('error', function(error:Dynamic) {
                if (!responded) {
                    responded = true;
                    log.error('Failed to download $url at path $targetPath. Stream error: $error');
                    done(null);
                    fs.unlink(tmpTargetPath, () -> {});
                }
            });

            response.on('error', function(error:Dynamic) {
                if (!responded) {
                    responded = true;
                    log.error('Failed to download $url at path $targetPath. Response error: $error');
                    done(null);
                    fs.unlink(tmpTargetPath, () -> {});
                }
            });

        });
        return;

        #end

        #end

        // Too bad
        log.error('Cannot download $url at path $targetPath because download is not supported on this target');
        done(null);

    }

}
