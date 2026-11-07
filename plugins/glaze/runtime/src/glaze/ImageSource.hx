// Ported from gpui-pre 0.3.10: src/elements/img.rs (ImageSource)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * A source of image content.
 *
 * `img()` takes an `IntoImageSource`: a `String` (a URI if it has a scheme,
 * otherwise a path in the app's asset source), a `Resource`, a
 * `RenderImage`, an `Image`, a `ceramic.Texture` or a custom loading function.
 */
@:using(glaze.ImageSource.ImageSourceTools)
enum ImageSource {

    /** The image content will be loaded from some resource location */
    Resource(resource:glaze.Resource);

    /** Cached image data */
    Render(image:RenderImage);

    /** Cached image data (encoded, decoded through the asset cache) */
    Image(image:glaze.Image);

    /** A custom loading function to use (`null`: still loading) */
    Custom(load:(Window, App) -> Null<ImageLoadResult>);

    /**
     * A Ceramic texture, drawn directly (not owned; when it is destroyed, its
     * image is dropped from the windows). Specific to the Haxe port.
     */
    Texture(texture:ceramic.Texture);

}

class ImageSourceTools {

    static inline function resourceKey(resource:glaze.Resource):String {
        return 'resource:' + resource.key();
    }

    static inline function imageKey(image:glaze.Image):String {
        return 'image:' + image.id;
    }

    /**
     * The data of this source, or `null` while it is loading (the current view
     * is then notified when it is ready). `cache` replaces the app's asset
     * cache for resources.
     */
    public static function useData(self:ImageSource, cache:Null<AnyImageCache>, window:Window, cx:App):Null<ImageLoadResult> {
        return switch self {
            case Resource(resource):
                if (cache != null) {
                    cache.load(resource, window, cx);
                }
                else {
                    ImageAssets.of(cx).use(resourceKey(resource), cx -> ImageAssetLoader.load(resource, cx), window, cx);
                }
            case Custom(load):
                load(window, cx);
            case Render(image):
                Loaded(image);
            case Image(image):
                ImageAssets.of(cx).use(imageKey(image), cx -> ImageAssetLoader.loadImage(image, cx), window, cx);
            case Texture(texture):
                Loaded(textureImage(texture));
        }
    }

    /** Like `useData`, without notifying the view when the load completes. */
    public static function getData(self:ImageSource, cache:Null<AnyImageCache>, window:Window, cx:App):Null<ImageLoadResult> {
        return switch self {
            case Resource(resource):
                if (cache != null) {
                    cache.load(resource, window, cx);
                }
                else {
                    ImageAssets.of(cx).fetch(resourceKey(resource), cx -> ImageAssetLoader.load(resource, cx), cx);
                }
            case Custom(load):
                load(window, cx);
            case Render(image):
                Loaded(image);
            case Image(image):
                ImageAssets.of(cx).fetch(imageKey(image), cx -> ImageAssetLoader.loadImage(image, cx), cx);
            case Texture(texture):
                Loaded(textureImage(texture));
        }
    }

    /** Remove this image source from the asset system */
    public static function removeAsset(self:ImageSource, cx:App):Void {
        switch self {
            case Resource(resource):
                ImageAssets.of(cx).remove(resourceKey(resource));
            case Image(image):
                ImageAssets.of(cx).remove(imageKey(image));
            case Custom(_) | Render(_) | Texture(_):
        }
    }

    /** Check whether this image source is present in the asset system (loading or loaded), without fetching it. */
    public static function isAssetCached(self:ImageSource, cx:App):Bool {
        return switch self {
            case Resource(resource): ImageAssets.of(cx).has(resourceKey(resource));
            case Image(image): ImageAssets.of(cx).has(imageKey(image));
            case Custom(_) | Render(_) | Texture(_): false;
        }
    }

    static final textureImages:haxe.ds.ObjectMap<ceramic.Texture, RenderImage> = new haxe.ds.ObjectMap();

    /**
     * The `RenderImage` of a texture, the same one as long as the texture
     * lives (so it keeps its atlas tile). Dropped from every window when the
     * texture is destroyed.
     */
    public static function textureImage(texture:ceramic.Texture):RenderImage {
        var image = textureImages.get(texture);
        if (image == null) {
            final created = RenderImage.fromTexture(texture);
            image = created;
            textureImages.set(texture, created);
            texture.onDestroy(null, _ -> {
                textureImages.remove(texture);
                for (window in Window.windows) {
                    if (!window.isDestroyed())
                        window.dropImage(created);
                }
            });
        }
        return image;
    }

}
