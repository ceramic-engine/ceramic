// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * A dynamically typed image cache. Implements `ImageCacheProvider` (it
 * provides itself).
 */
class AnyImageCache implements ImageCacheProvider {

    /** The image cache (an entity in GPUI) */
    public final imageCache:ImageCache;

    public function new(imageCache:ImageCache) {
        this.imageCache = imageCache;
    }

    /**
     * Load an image given a resource. Returns the result of loading the image
     * if it has finished loading, or `null` if it is still loading. When the
     * cache is a `Model`, runs as an update of that entity.
     */
    public function load(resource:Resource, window:Window, cx:App):Null<ImageLoadResult> {
        final cache = imageCache;
        if (Std.isOfType(cache, Model)) {
            return cx.updateEntity((cast cache : Model), (_, _) -> cache.load(resource, window, cx));
        }
        return cache.load(resource, window, cx);
    }

    public function provide(window:Window, cx:App):AnyImageCache {
        return this;
    }

}
