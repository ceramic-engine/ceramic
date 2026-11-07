// Ported from gpui-pre 0.3.10: src/elements/img.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Rust `Result<Arc<RenderImage>, ImageCacheError>`: the result of loading an
 * image. `null` (Rust `None`) means it is still loading.
 */
@:using(glaze.ImageLoadResult.ImageLoadResultTools)
enum ImageLoadResult {

    /** The image is loaded */
    Loaded(image:RenderImage);

    /** The image could not be loaded */
    Failed(error:ImageCacheError);

}

class ImageLoadResultTools {

    /** The image, or `null` if loading failed or is not finished (Rust `.and_then(|r| r.ok())`). */
    public static function okOrNull(self:Null<ImageLoadResult>):Null<RenderImage> {
        if (self == null)
            return null;
        return switch self {
            case Loaded(image): image;
            case Failed(_): null;
        }
    }

}
