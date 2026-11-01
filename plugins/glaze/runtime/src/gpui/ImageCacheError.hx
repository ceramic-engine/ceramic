// Ported from gpui-pre 0.3.10: src/elements/img.rs (ImageCacheError)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An error that can occur when interacting with the image cache.
 */
@:using(gpui.ImageCacheError.ImageCacheErrorTools)
enum ImageCacheError {

    /** Some other kind of error occurred */
    Other(message:String);

    /** An error that occurred while reading the image from disk. */
    Io(message:String);

    /** Unexpected http status (Rust `BadStatus`) */
    BadStatus(uri:String, status:Int, body:String);

    /** An error that occurred while processing an asset. */
    Asset(message:String);

    /** An error that occurred while processing an image. */
    Image(message:String);

    /** An error that occurred while processing an SVG. */
    Usvg(message:String);

}

class ImageCacheErrorTools {

    public static function toString(self:ImageCacheError):String {
        return switch self {
            case Other(message): 'error: $message';
            case Io(message): 'IO error: $message';
            case BadStatus(uri, status, body): 'unexpected http status for $uri: $status, body: $body';
            case Asset(message): 'asset error: $message';
            case Image(message): 'image error: $message';
            case Usvg(message): 'svg error: $message';
        }
    }

}
