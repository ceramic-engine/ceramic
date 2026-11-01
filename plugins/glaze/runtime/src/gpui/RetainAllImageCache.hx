// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs (RetainAllImageCache, RetainAllImageCacheProvider)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An image cache that keeps every image it loads until it is cleared or
 * released (then its images are dropped from the windows).
 */
class RetainAllImageCache extends Model implements ImageCache {

    final items:Map<String, ImageCacheItem> = new Map();

    var count:Int = 0;

    /** Use `RetainAllImageCache.create(cx)`. */
    public function new() {
        super();
    }

    /** Create a new image cache (Rust `RetainAllImageCache::new`). */
    public static function create(cx:App):Entity<RetainAllImageCache> {
        final entity:Entity<RetainAllImageCache> = cx.newEntity(_ -> new RetainAllImageCache());
        cx.observeRelease(entity, (imageCache, cx) -> {
            final items = imageCache.takeItems();
            for (item in items) {
                final image = item.get().okOrNull();
                if (image != null) {
                    ImageCacheItem.dropImage(image, null, cx);
                }
                else {
                    item.cancel();
                }
            }
        });
        return entity;
    }

    function takeItems():Array<ImageCacheItem> {
        final result = [for (item in items) item];
        items.clear();
        count = 0;
        return result;
    }

    /**
     * Load an image from the given source. Returns `null` if the image is loading.
     */
    public function load(source:Resource, window:Window, cx:App):Null<ImageLoadResult> {
        final key = source.key();
        var item = items.get(key);
        if (item == null) {
            item = new ImageCacheItem(source, cx);
            items.set(key, item);
            count++;
        }
        return item.useImage(window);
    }

    /** Clear the image cache. */
    public function clear(window:Window, cx:App):Void {
        for (item in takeItems()) {
            final image = item.get().okOrNull();
            if (image != null) {
                ImageCacheItem.dropImage(image, window, cx);
            }
            else {
                item.cancel();
            }
        }
    }

    /** Remove the image from the cache by the given source. */
    public function remove(source:Resource, window:Window, cx:App):Void {
        final key = source.key();
        final item = items.get(key);
        if (item != null) {
            items.remove(key);
            count--;
            final image = item.get().okOrNull();
            if (image != null) {
                ImageCacheItem.dropImage(image, window, cx);
            }
            else {
                item.cancel();
            }
        }
    }

    /** Returns the number of images in the cache. */
    public inline function len():Int {
        return count;
    }

    /** Returns true if the cache is empty. */
    public inline function isEmpty():Bool {
        return count == 0;
    }

}
