// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs (ImageCache, ImageCacheProvider, AnyImageCache, ImageCacheItem)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An object that can handle the caching and unloading of images.
 * Implementations should ensure that images are removed from all windows
 * when they are no longer needed. In GPUI an image cache is an entity:
 * implement it on a `Model`, and `AnyImageCache` runs `load` as an update
 * of that entity.
 */
interface ImageCache {

    /**
     * Load an image given a resource. Returns the result of loading the image
     * if it has finished loading, or `null` if it is still loading.
     */
    function load(resource:Resource, window:Window, cx:App):Null<ImageLoadResult>;

}
