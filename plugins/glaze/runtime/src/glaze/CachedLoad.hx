// Ported from gpui-pre 0.3.10: src/asset_cache.rs (CachedLoad)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An asynchronous load and its cached result. Views that read it while it is
 * loading (`useBy`) are notified when it completes.
 */
class CachedLoad<T> {

    var loaded:Bool = false;

    var result:Null<T> = null;

    var views:Array<Int> = [];

    final task:Task<Unit>;

    public function new(load:Task<T>, cx:App) {
        task = load.then(value -> {
            result = value;
            loaded = true;
            final notified = views;
            views = [];
            if (notified.length > 0) {
                cx.update(cx -> {
                    for (view in notified) {
                        cx.notify(view);
                    }
                });
            }
        });
    }

    /** The result once loaded, `null` while loading. */
    public function get():Null<T> {
        return loaded ? result : null;
    }

    /** The result once loaded, otherwise subscribes `view` (an entity id) to the completion and returns `null`. */
    public function useBy(view:Int):Null<T> {
        if (loaded)
            return result;
        if (views.indexOf(view) == -1)
            views.push(view);
        return null;
    }

    /** Whether the load completed. */
    public inline function isLoaded():Bool {
        return loaded;
    }

    /** Cancels a pending load (Rust: dropping the entry). */
    public function cancel():Void {
        if (!loaded)
            task.cancel();
    }

}
