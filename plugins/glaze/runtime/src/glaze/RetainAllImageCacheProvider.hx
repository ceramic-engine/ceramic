// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import glaze.ImageLoadResult;

/**
 * A provider struct for creating a retain-all image cache inline, kept in
 * the element state of the given id (see `Prelude.retainAll`).
 */
class RetainAllImageCacheProvider implements ImageCacheProvider {

    final id:ElementIdArg;

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public function provide(window:Window, cx:App):AnyImageCache {
        final cache = window.withGlobalId(id, (globalId, window) -> {
            return window.withElementState(globalId, RetainAllImageCache, (state, _) -> {
                if (state.value == null) {
                    state.value = RetainAllImageCache.create(cx);
                }
                return state.value;
            });
        });
        return new AnyImageCache(cache);
    }

}
