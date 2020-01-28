package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

/** A cross-platform and high level HTTP request utility */
class Http {

    public static function request(
        options:ceramic.HttpRequestOptions,
        done:ceramic.HttpResponse->Void):Void {

        inline function formatHeaderKey(key:String) {

            var formatKey = [];
            for (part in key.split('-')) {
                formatKey.push(part.charAt(0).toUpperCase() + part.substring(1));
            }
            return formatKey.join('-');

        }

        // Compute headers
        var headers = new Map<String,String>();
        if (options.headers != null) {
            for (key in options.headers.keys()) {
                headers.set(formatHeaderKey(key), options.headers.get(key));
            }
        }

        if (!headers.exists('Content-Type')) {
            headers.set('Content-Type', 'application/x-www-form-urlencoded');
        }

        // Compute method
        var method:HttpMethod = options.method != null ? options.method : GET;

        // Get content
        var content:String = options.content;

        // Get url
        var url = options.url;

        // Get timeout
        var timeout = options.timeout;

        // Encode parameters
        if (options.params != null) {
            var buff = new StringBuf();
            var i = 0;
            for (key in options.params.keys()) {
                var val = options.params.get(key);
                if (i > 0) buff.add('&');
                buff.add(key.urlEncode());
                buff.add('=');
                buff.add(val.urlEncode());
                i++;
            }
            var encoded = buff.toString();

            if (method == GET) {
                var questionMarkIndex = url.indexOf('?');
                if (questionMarkIndex != -1) {
                    url = url.substring(0, questionMarkIndex) + '?' + encoded;
                } else {
                    url = url + '?' + encoded;
                }
            }
            else if (method == POST) {
                content = encoded;
            }
            else {
                log.warning('HTTP request params were ignored with method: $method');
            }
        }

        // Content length
        if (content != null) {
            headers.set('Content-Length', '' + content.length);
        }

        // Perform request
        var backendOptions:backend.HttpRequestOptions = {
            url: url,
            method: method,
            headers: headers,
            content: content,
            timeout: timeout
        };

        app.backend.http.request(backendOptions, function(backendResponse) {
            var resHeaders = new Map<String,String>();
            if (backendResponse.headers != null) {
                for (key in backendResponse.headers.keys()) {
                    resHeaders.set(formatHeaderKey(key), backendResponse.headers.get(key));
                }
            }

            // Remove any trailing line break (which may be inconsistent between implementations)
            if (backendResponse.content != null && backendResponse.content.endsWith("\n")) {
                backendResponse.content = backendResponse.content.substring(0, backendResponse.content.length - 1);
                if (backendResponse.content != null && backendResponse.content.endsWith("\r")) {
                    backendResponse.content = backendResponse.content.substring(0, backendResponse.content.length - 1);
                }
            }

            done({
                status: backendResponse.status,
                content: backendResponse.content,
                error: backendResponse.error,
                headers: resHeaders
            });
        });

    }

}
