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
 *   assets directory, then cached.
 */
class CeramicAssetSource implements AssetSource {

    final entries:Map<String, Bytes> = new Map();

    public function new() {}

    /**
     * Registers the bytes of an asset path.
     */
    public function add(path:String, bytes:Bytes):Void {
        entries.set(normalize(path), bytes);
    }

    /**
     * Loads the given asset paths (as Ceramic binary assets), then calls `done`
     * with `true` if all of them were loaded.
     */
    public function preload(paths:Array<String>, done:Bool->Void):Void {
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
            done(success);
        });
        assets.load();
    }

    public function load(path:String):Null<Bytes> {
        final normalized = normalize(path);
        // An empty path (an `Icon.empty()`) or a folder names no asset
        if (normalized.length == 0 || normalized.endsWith('/'))
            return null;
        final bytes = entries.get(normalized);
        if (bytes != null)
            return bytes;
        #if (sys || (web && ceramic_use_electron))
        final fullPath = ceramic.Path.join([ceramic.App.app.settings.assetsPath, normalized]);
        if (ceramic.Files.exists(fullPath)) {
            final read = ceramic.Files.getBytes(fullPath);
            if (read != null) {
                entries.set(normalized, read);
                return read;
            }
        }
        #end
        return null;
    }

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
