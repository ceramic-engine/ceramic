// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ImageLoadResult;

/**
 * Owns an image load and its cached result.
 *
 * Dropping the entry (`cancel()`) cancels a pending load. Image caches must
 * remove loaded images from windows before discarding the entry.
 */
class ImageCacheItem {

    final cached:CachedLoad<ImageLoadResult>;

    /** Starts loading an image into a new cache entry. */
    public function new(source:Resource, cx:App) {
        cached = new CachedLoad(ImageAssets.logErrors(ImageAssetLoader.load(source, cx)), cx);
    }

    /** Returns the cached result without subscribing to completion notifications. */
    public inline function get():Null<ImageLoadResult> {
        return cached.get();
    }

    /** Returns the cached result or subscribes the current view to completion. */
    public inline function useImage(window:Window):Null<ImageLoadResult> {
        return cached.useBy(window.currentView());
    }

    /** Cancels a pending load. */
    public inline function cancel():Void {
        cached.cancel();
    }

    /**
     * Rust `cx.drop_image(image, window)`: removes the image from the sprite
     * atlas of `window` and of every other window of the app (then releases
     * the texture of an image decoded by `ImageAssetLoader`).
     */
    public static function dropImage(image:RenderImage, window:Null<Window>, cx:App):Void {
        for (other in Window.windows) {
            if (other.app == cx && !other.isDestroyed())
                other.dropImage(image);
        }
        if (window != null && !window.isDestroyed() && window.app != cx)
            window.dropImage(image);
        ImageAssetLoader.release(image);
    }

}
