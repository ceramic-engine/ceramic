// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * An object that can create an `ImageCache` during the render phase.
 */
interface ImageCacheProvider {

    /** Called during the request_layout phase to create an ImageCache. */
    function provide(window:Window, cx:App):AnyImageCache;

}
