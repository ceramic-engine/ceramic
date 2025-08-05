package ceramic;

import ceramic.Shortcuts.*;
import haxe.io.Bytes;

/**
 * Asset for loading binary files as raw bytes.
 * 
 * BinaryAsset loads any file as raw binary data, making it useful for:
 * - Custom file formats
 * - Binary protocols
 * - Compressed data
 * - Non-text resources
 * 
 * The loaded data is provided as haxe.io.Bytes, which can be processed
 * as needed by your application.
 * 
 * Features:
 * - Hot-reload support for binary files
 * - Asynchronous loading
 * - Memory-efficient byte handling
 * 
 * ```haxe
 * // Load a binary file
 * var binaryAsset = new BinaryAsset('data');
 * binaryAsset.path = 'data/level.dat';
 * binaryAsset.onComplete(this, success -> {
 *     if (success) {
 *         // Access the raw bytes
 *         var bytes = binaryAsset.bytes;
 *         trace('Loaded ${bytes.length} bytes');
 *         
 *         // Process the binary data
 *         var input = new haxe.io.BytesInput(bytes);
 *         var version = input.readInt32();
 *         // ... read more data
 *     }
 * });
 * assets.addAsset(binaryAsset);
 * assets.load();
 * ```
 * 
 * @see Asset
 * @see haxe.io.Bytes
 */
class BinaryAsset extends Asset {

    /**
     * The loaded binary data as raw bytes.
     * Will be null until the asset is successfully loaded.
     * 
     * Use haxe.io APIs to read and process the binary data:
     * - BytesInput for reading
     * - BytesOutput for writing
     * - BytesBuffer for building
     */
    @observe public var bytes:Bytes = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('binary', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Loads the binary file from the specified path.
     * 
     * The loading is asynchronous and will emit a complete event when finished.
     * On success, the bytes property will contain the loaded data.
     * 
     * Supports hot-reload on platforms that allow it - the file will be
     * automatically reloaded when it changes on disk.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load binary asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.binaries.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load binary $backendPath');
        app.backend.binaries.load(realPath, loadOptions, function(bytes) {

            if (bytes != null) {
                this.bytes = bytes;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load binary at path: $path');
                emitComplete(false);
            }

        });

    }

    /**
     * Called when asset files change on disk (hot-reload support).
     * Automatically reloads the binary file if it has been modified.
     * @param newFiles Map of current files and their modification times
     * @param previousFiles Map of previous files and their modification times
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.binaries.supportsHotReloadPath())
            return;

        var previousTime:Float = -1;
        if (previousFiles.exists(path)) {
            previousTime = previousFiles.get(path);
        }
        var newTime:Float = -1;
        if (newFiles.exists(path)) {
            newTime = newFiles.get(path);
        }

        if (newTime != previousTime) {
            log.info('Reload binary (file has changed)');
            load();
        }

    }

    /**
     * Destroys the binary asset and releases the loaded bytes from memory.
     */
    override function destroy():Void {

        super.destroy();

        bytes = null;

    }

}
