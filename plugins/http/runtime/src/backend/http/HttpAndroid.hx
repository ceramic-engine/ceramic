package backend.http;

#if android

import android.Http as AndroidHttp;
import haxe.crypto.Base64;
import haxe.io.Bytes;

class HttpAndroid {

    public static function request(options:HttpRequestOptions, done:HttpResponse->Void):Void {

        var requestOptions:Dynamic = {};
        requestOptions.url = options.url;
        requestOptions.method = options.method != null ? options.method : 'GET';
        if (options.headers != null) {
            // Pass headers as array [key, value, key, value, ...]
            requestOptions.headers = options.headers;
        }
        if (options.content != null) {
            requestOptions.content = options.content;
        }

        if (options.timeout != null && options.timeout > 0) {
            requestOptions.timeout = options.timeout;
        }

        AndroidHttp.sendHttpRequest(requestOptions, function(rawResponse) {
            var useContent = rawResponse.status >= 200 && rawResponse.status < 300;
            var headers:Array<String> = [];
            if (rawResponse.headers != null) {
                // rawResponse.headers comes back as array from Java
                var rawHeaders:Array<String> = rawResponse.headers;
                headers = rawHeaders;
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

    }

    public static function download(url:String, targetPath:String, done:String->Void):Void {

        AndroidHttp.download({url: url}, targetPath, function(fullPath) {
            if (fullPath == null) {
                log.error('Failed to download $url at path $targetPath');
            }
            done(fullPath);
        });

    }

}

#end
