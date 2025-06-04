package tools;

import haxe.Http;

class UrlRequest {

    public static function requestUrl(url:String):Null<String> {

        var h = new Http(url);

        h.setHeader('User-Agent', 'request');

        // Add GitHub token if available and URL is for GitHub API
        var githubToken = Sys.getEnv("GITHUB_TOKEN");
        if (githubToken != null && githubToken.length > 0 && (url.indexOf("https://github.com/") == 0 || url.indexOf("https://api.github.com/") == 0)) {
            h.setHeader("Authorization", "token " + githubToken);
        }

        h.onError = err -> {
            throw 'Http error: ' + err;
        };
        h.request();

        return h.responseData;

    }

}