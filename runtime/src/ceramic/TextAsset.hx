package ceramic;

import ceramic.Shortcuts.*;

/**
 * Asset type for loading text files.
 *
 * Loads any text-based file format like:
 * - Plain text files (.txt)
 * - JSON files (.json)
 * - XML files (.xml)
 * - Configuration files (.cfg, .ini, etc.)
 * - Any UTF-8 encoded text content
 *
 * Features:
 * - UTF-8 encoding support
 * - Hot reload for live content updates
 * - Suitable for loading game data, configurations, or localization files
 *
 * @example
 * ```haxe
 * var assets = new Assets();
 * assets.addText('config.json');
 * assets.addText('dialogue/intro.txt');
 * assets.load();
 *
 * // Access loaded text
 * var configJson = assets.text('config');
 * var config = Json.parse(configJson);
 * ```
 */
class TextAsset extends Asset {

    /**
     * The loaded text content.
     * Observable property that updates when the text is loaded or reloaded.
     * Null until the asset is successfully loaded.
     */
    @observe public var text:String = null;

    /**
     * Create a new text asset.
     * @param name Text file name (with or without extension)
     * @param variant Optional variant suffix
     * @param options Loading options (backend-specific)
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('text', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Load the text file content.
     * The file is loaded as UTF-8 encoded text.
     * Emits complete event when finished.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load text asset if path is undefined.');
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
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load text $backendPath');
        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text != null) {
                this.text = text;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load text at path: $path');
                emitComplete(false);
            }

        });

    }

    /**
     * Handle file system changes for hot reload.
     * Automatically reloads the text when the source file is modified.
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath())
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
            log.info('Reload text (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        text = null;

    }

}
