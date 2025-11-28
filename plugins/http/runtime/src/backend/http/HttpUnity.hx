package backend.http;

#if (cs && unity)

import ceramic.Shortcuts.*;
import haxe.io.Bytes;
import sys.FileSystem;
import unityengine.networking.DownloadHandler;
import unityengine.networking.UnityWebRequest;

class HttpUnity {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void, http:backend.Http):Void {

        var requestId = http.nextRequestId;
        http.nextRequestId = (http.nextRequestId + 1) % 999999999;

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
                var i = 0;
                while (i < options.headers.length) {
                    var key = options.headers[i];
                    var value = options.headers[i + 1];
                    if (key.toLowerCase() != 'content-length') {
                        webRequest.SetRequestHeader(key, value);
                    }
                    i += 2;
                }
            }

            http.requestCallbacks.set(requestId, function(downloadHandler) {

                var resStatus = Std.int(webRequest.responseCode);
                var resHeaders:Array<String> = [];

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
                    resHeaders.push(headerName);
                    resHeaders.push(headerValue);
                    untyped __cs__('}');

                    var resContentType:String = null;
                    var i = 0;
                    while (i < resHeaders.length) {
                        if (resContentType == null && resHeaders[i].toLowerCase() == 'content-type') {
                            resContentType = resHeaders[i + 1];
                        }
                        i += 2;
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
            untyped __cs__('{0}.StartCoroutine({1}.unityRunWebRequest({2}, {3}))', monoBehaviour, http, requestId, webRequest);

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
                headers: [],
                error: 'Error: ' + e
            });
        }

    }

    public static function download(url:String, tmpTargetPath:String, targetPath:String, done:String->Void, http:backend.Http):Void {

        var requestId = http.nextRequestId;
        http.nextRequestId = (http.nextRequestId + 1) % 999999999;

        var webRequest = new UnityWebRequest();
        webRequest.url = url;
        webRequest.method = untyped __cs__('UnityEngine.Networking.UnityWebRequest.kHttpVerbGET');
        webRequest.downloadHandler = untyped __cs__('new UnityEngine.Networking.DownloadHandlerFile({0})', tmpTargetPath);
        webRequest.disposeDownloadHandlerOnDispose = true;

        http.requestCallbacks.set(requestId, function(downloadHandler) {

            if (webRequest != null)
                webRequest.Dispose();
            if (downloadHandler != null)
                downloadHandler.Dispose();

            finishDownload(tmpTargetPath, targetPath, url, done);

        });

        var monoBehaviour = Main.monoBehaviour;
        untyped __cs__('{0}.StartCoroutine({1}.unityRunWebRequest({2}, {3}))', monoBehaviour, http, requestId, webRequest);

    }

    static function finishDownload(tmpTargetPath:String, targetPath:String, url:String, done:String->Void):Void {

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

}

#end
