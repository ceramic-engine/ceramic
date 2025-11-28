package backend.http;

#if ios

import ceramic.Shortcuts.*;
import haxe.io.Bytes;
import ios.Http as IosHttp;

class HttpIos {

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

        trace('IOS HTTP SEND HTTP REQUEST');
        IosHttp.sendHTTPRequest(requestOptions, function(rawResponse) {
            var useContent = rawResponse.status >= 200 && rawResponse.status < 300;
            var headers:Array<String> = [];
            if (rawResponse.headers != null) {
                // rawResponse.headers comes back as array from Objective-C
                var rawHeaders:Array<String> = rawResponse.headers;
                headers = rawHeaders;
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

    }

    public static function download(url:String, targetPath:String, done:String->Void):Void {

        IosHttp.download({ url: url }, targetPath, function(fullPath) {
            if (fullPath == null) {
                log.error('Failed to download $url at path $targetPath');
            }
            done(fullPath);
        });

    }

}

#end
