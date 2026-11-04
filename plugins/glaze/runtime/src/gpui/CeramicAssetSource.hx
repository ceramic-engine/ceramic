// Original code (not a port), written for ceramic-gpui.
// MIT License, see Ceramic's LICENSE file.
package gpui;

import haxe.io.Bytes;

using StringTools;

/**
 * The default `AssetSource` of an `App`.
 *
 * Paths are relative to the assets of the Ceramic project (`icons/x.svg` is
 * `assets/icons/x.svg`). `load()` returns, in this order:
 *
 * - bytes registered with `add()`;
 * - bytes preloaded with `preload()` (Ceramic binary assets, works on every
 *   target, the way to go on the web);
 * - on targets with a file system, the file read synchronously from the
 *   assets directory, then cached; on Unity, the resource of the asset
 *   (loaded synchronously), then cached.
 *
 * A path that resolves to nothing is remembered as missing until the assets
 * change (`add()`, a completed `preload()` or `invalidate()`): GPUI asks the
 * asset source for a missing SVG on every frame it paints it
 * (`svg_renderer.rs` `render_alpha_mask`, nothing is cached by the sprite
 * atlas when the build returns `None`), so the miss has to stay cheap (on
 * the web under Electron, a file check is a synchronous IPC).
 */
class CeramicAssetSource implements AssetSource {

    final entries:Map<String, Bytes> = new Map();

    /** Paths (as given to `load()`) known to resolve to nothing */
    final missing:Map<String, Bool> = new Map();

    /**
     * How many times `load()` resolved a path not cached yet (present or
     * missing). For tests.
     */
    public var resolutions(default, null):Int = 0;

    public function new() {}

    /**
     * Forgets the paths known to be missing (call it when files were added to
     * the assets directory at run time).
     */
    public function invalidate():Void {
        missing.clear();
    }

    /**
     * Registers the bytes of an asset path.
     */
    public function add(path:String, bytes:Bytes):Void {
        entries.set(normalize(path), bytes);
        invalidate();
    }

    /**
     * Loads the given asset paths (as Ceramic binary assets), then calls `done`
     * with `true` if all of them were loaded.
     */
    public function preload(paths:Array<String>, done:(Bool) -> Void):Void {
        final assets = new ceramic.Assets();
        final pending:Array<{path:String, asset:ceramic.BinaryAsset}> = [];
        for (path in paths) {
            final normalized = normalize(path);
            if (entries.exists(normalized))
                continue;
            final asset = new ceramic.BinaryAsset('gpui-asset:' + normalized);
            asset.path = normalized;
            assets.addAsset(asset);
            pending.push({path: normalized, asset: asset});
        }
        if (pending.length == 0) {
            done(true);
            return;
        }
        assets.onceComplete(null, success -> {
            for (entry in pending) {
                if (entry.asset.bytes != null)
                    entries.set(entry.path, entry.asset.bytes);
            }
            invalidate();
            done(success);
        });
        assets.load();
    }

    public function load(path:String):Null<Bytes> {
        if (missing.exists(path))
            return null;
        final normalized = normalize(path);
        // An empty path (an `Icon.empty()`) or a folder names no asset
        if (normalized.length == 0 || normalized.endsWith('/'))
            return null;
        final bytes = entries.get(normalized);
        if (bytes != null)
            return bytes;
        resolutions++;
        #if unity
        // Unity: the assets are resources of the Unity project (no file);
        // a resource loads synchronously, with the exact bytes of the file
        // (`.txt` / `.bytes` copies, `unity_raw_image_bytes` for images)
        final read = loadUnityResource(normalized);
        if (read != null) {
            entries.set(normalized, read);
            return read;
        }
        #elseif (sys || (web && ceramic_use_electron))
        final fullPath = ceramic.Path.join([ceramic.App.app.settings.assetsPath, normalized]);
        if (ceramic.Files.exists(fullPath)) {
            final read = ceramic.Files.getBytes(fullPath);
            if (read != null) {
                entries.set(normalized, read);
                return read;
            }
        }
        #end
        missing.set(path, true);
        return null;
    }

    #if unity
    static function loadUnityResource(path:String):Null<Bytes> {
        final resourcePath = ceramic.Path.join([ceramic.App.app.settings.assetsPath, path]);
        final asset:unityengine.TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>({0})', resourcePath);
        if (asset == null)
            return null;
        final bytes = Bytes.ofData(asset.bytes);
        untyped __cs__('UnityEngine.Resources.UnloadAsset({0})', asset);
        return bytes;
    }
    #end

    public function list(path:String):Array<String> {
        final prefix = normalize(path);
        return [for (key in entries.keys()) if (key.startsWith(prefix)) key];
    }

    static function normalize(path:String):String {
        var result = path.replace('\\', '/');
        while (result.startsWith('./'))
            result = result.substr(2);
        while (result.startsWith('/'))
            result = result.substr(1);
        return result;
    }

}
