// Ported from gpui-pre 0.3.10: src/asset_cache.rs (Resource)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Where a resource (an image of `img()`) comes from.
 */
@:using(gpui.Resource.ResourceTools)
enum Resource {

    /** This resource is at a given URI */
    Uri(uri:String);

    /** This resource is at a given path in the file system */
    Path(path:String);

    /** This resource is embedded in the application (loaded from the app's `AssetSource`) */
    Embedded(path:String);

}

class ResourceTools {

    /**
     * A string identifying the resource (Rust hashes it with `hash()`).
     */
    public static function key(self:Resource):String {
        return switch self {
            case Uri(uri): 'uri:' + uri;
            case Path(path): 'path:' + path;
            case Embedded(path): 'embedded:' + path;
        }
    }

    /**
     * Rust `url::Url::from_str(uri).is_ok()`: an absolute URL starts with a scheme
     * (a letter, then letters, digits, `+`, `-` or `.`) followed by `:`.
     */
    public static function isUri(value:String):Bool {
        final colon = value.indexOf(':');
        if (colon <= 0)
            return false;
        for (i in 0...colon) {
            final c = StringTools.fastCodeAt(value, i);
            final letter = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
            if (i == 0) {
                if (!letter)
                    return false;
            }
            else if (!letter && !(c >= '0'.code && c <= '9'.code) && c != '+'.code && c != '-'.code && c != '.'.code) {
                return false;
            }
        }
        return true;
    }

}
