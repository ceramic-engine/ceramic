// Ported from gpui-pre 0.3.10: src/elements/img.rs (impl From<...> for ImageSource)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * Rust `impl Into<ImageSource>`.
 */
abstract IntoImageSource(ImageSource) from ImageSource to ImageSource {

    inline function new(source:ImageSource) {
        this = source;
    }

    /** A URI if the string has a scheme, otherwise an embedded resource (asset source path). */
    @:from public static function fromString(value:String):IntoImageSource {
        return new IntoImageSource(ImageSource.Resource(glaze.Resource.ResourceTools.isUri(value) ? glaze.Resource.Uri(value) : glaze.Resource.Embedded(value)));
    }

    @:from public static inline function fromResource(resource:glaze.Resource):IntoImageSource {
        return new IntoImageSource(ImageSource.Resource(resource));
    }

    @:from public static inline function fromRenderImage(image:RenderImage):IntoImageSource {
        return new IntoImageSource(ImageSource.Render(image));
    }

    @:from public static inline function fromImage(image:glaze.Image):IntoImageSource {
        return new IntoImageSource(ImageSource.Image(image));
    }

    @:from public static inline function fromTexture(texture:ceramic.Texture):IntoImageSource {
        return new IntoImageSource(ImageSource.Texture(texture));
    }

    @:from public static inline function fromFunction(load:(Window, App) -> Null<ImageLoadResult>):IntoImageSource {
        return new IntoImageSource(ImageSource.Custom(load));
    }

    public inline function toImageSource():ImageSource {
        return this;
    }

}
