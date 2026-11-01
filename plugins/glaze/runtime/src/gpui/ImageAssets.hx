// Ported from gpui-pre 0.3.10: src/app.rs (asset_entry, fetch_asset, remove_asset, has_asset), src/window.rs (use_asset, get_asset)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ImageLoadResult;

/**
 * The asset cache of an app for images (GPUI keeps one cache of `Asset`
 * loads per app, keyed by asset type and source hash). Entries are keyed by
 * a string: the loader (`resource:` for `ImageAssetLoader`, `image:` for
 * `ImageDecoder`) and the source.
 *
 * Differences with GPUI: only image assets go through it; it lives next to
 * the app (`ImageAssets.of(cx)`) instead of in `App`.
 */
class ImageAssets {

    static final byApp:haxe.ds.ObjectMap<App, ImageAssets> = new haxe.ds.ObjectMap();

    final entries:Map<String, CachedLoad<ImageLoadResult>> = new Map();

    function new() {}

    /** The image asset cache of the given app. */
    public static function of(cx:App):ImageAssets {
        var assets = byApp.get(cx);
        if (assets == null) {
            assets = new ImageAssets();
            byApp.set(cx, assets);
        }
        return assets;
    }

    /** Rust `asset_entry`: the entry of `key`, starting `load` if it does not exist. */
    public function entry(key:String, load:App->Task<ImageLoadResult>, cx:App):CachedLoad<ImageLoadResult> {
        var entry = entries.get(key);
        if (entry == null) {
            entry = new CachedLoad(logErrors(load(cx)), cx);
            entries.set(key, entry);
        }
        return entry;
    }

    /** Rust `fetch_asset` / `Window.get_asset`: the result, or `null` while loading (no notification). */
    public inline function fetch(key:String, load:App->Task<ImageLoadResult>, cx:App):Null<ImageLoadResult> {
        return entry(key, load, cx).get();
    }

    /** Rust `Window.use_asset`: the result, or `null` while loading, in which case the current view is notified when it is ready. */
    public inline function use(key:String, load:App->Task<ImageLoadResult>, window:Window, cx:App):Null<ImageLoadResult> {
        return entry(key, load, cx).useBy(window.currentView());
    }

    /** Rust `remove_asset`: removes the entry (a pending load is cancelled). */
    public function remove(key:String):Void {
        final entry = entries.get(key);
        if (entry != null) {
            entries.remove(key);
            entry.cancel();
        }
    }

    /** Rust `has_asset`: whether the entry exists (loading or loaded). */
    public inline function has(key:String):Bool {
        return entries.exists(key);
    }

    /** Rust `AssetLogger`: logs the error of a failed load. */
    public static function logErrors(task:Task<ImageLoadResult>):Task<ImageLoadResult> {
        return task.map(result -> {
            switch result {
                case Failed(error):
                    ceramic.Shortcuts.log.error('Failed to load asset: ' + error.toString());
                case Loaded(_):
            }
            return result;
        });
    }

}
