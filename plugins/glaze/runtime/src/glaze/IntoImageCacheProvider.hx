// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * Rust `impl ImageCacheProvider`: an `ImageCacheProvider`, or an image cache
 * itself (Rust `impl<T: ImageCache> ImageCacheProvider for Entity<T>`).
 */
abstract IntoImageCacheProvider(ImageCacheProvider) from ImageCacheProvider to ImageCacheProvider {

    inline function new(provider:ImageCacheProvider) {
        this = provider;
    }

    @:from static inline function fromImageCache(cache:ImageCache):IntoImageCacheProvider {
        return new IntoImageCacheProvider(new AnyImageCache(cache));
    }

    @:from static inline function fromEntity<T:Model & ImageCache>(entity:Entity<T>):IntoImageCacheProvider {
        return new IntoImageCacheProvider(new AnyImageCache((entity : T)));
    }

}
