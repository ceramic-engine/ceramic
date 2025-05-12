package tools;

import haxe.Http;

class UrlRequest {

    public static function requestUrl(url:String):Null<String> {

        var h = new Http(url);

        h.setHeader('User-Agent', 'request');
        h.onError = err -> {
            throw 'Http error: ' + err;
        };
        h.request();

        return h.responseData;

    }

}