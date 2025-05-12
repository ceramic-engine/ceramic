package tools;

import haxe.Json;
import tools.Helpers.*;

class Github {

    public static function resolveLatestRelease(owner:String, repo:String):Dynamic {

        try {
            return Json.parse(UrlRequest.requestUrl('https://api.github.com/repos/$owner/$repo/releases/latest'));
        }
        catch (e:Dynamic) {
            fail('Failed to resolve latest $repo version! Try again later?');
            return null;
        }

    }

    public static function resolveReleaseForTag(owner:String, repo:String, tag:String):Dynamic {

        try {
            var release:Dynamic = Json.parse(UrlRequest.requestUrl('https://api.github.com/repos/$owner/$repo/releases/tags/$tag'));
            return release;
        }
        catch (e:Dynamic) {
            fail('Failed to resolve $repo release with tag $tag! Error: ${e}');
            return null;
        }

    }

}