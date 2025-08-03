package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import loreline.Loreline;

using StringTools;

/**
 * Asset class for loading and managing Loreline script files.
 * 
 * Loreline is a scripting language for narrative content, dialogue trees,
 * and interactive storytelling. This asset type handles:
 * - Loading Loreline script files (.lor, .loreline)
 * - Parsing scripts with import resolution
 * - Hot-reloading when script files change
 * - Managing script dependencies
 * 
 * Example usage:
 * ```haxe
 * assets.add('loreline:dialogue/intro');
 * assets.onceComplete(this, success -> {
 *     var script = assets.loreline('dialogue/intro');
 *     // Use the parsed Loreline script
 * });
 * ```
 * 
 * @see loreline.Loreline
 */
class LorelineAsset extends Asset {

/// Properties

    /**
     * The parsed Loreline script object.
     * Contains the dialogue nodes, conditions, and flow logic.
     * Observable to track when the script is loaded or reloaded.
     */
    @observe public var lorelineScript:loreline.Script = null;

    /**
     * List of imported file paths used by this script.
     * Used for hot-reload detection of dependencies.
     */
    var importedFiles:Array<String> = null;

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('loreline', name, variant, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = false; // Not relevant

        assets = new Assets();

    }

    override public function load() {

        if (owner != null) {
            assets.inheritRuntimeAssetsFromAssets(owner);
            assets.loadMethod = owner.loadMethod;
            assets.scheduleMethod = owner.scheduleMethod;
            assets.delayBetweenXAssets = owner.delayBetweenXAssets;
        }

        // Reset imported file list
        importedFiles = [];

        // Create array of assets to destroy after load
        var toDestroy:Array<Asset> = [];
        for (asset in assets) {
            toDestroy.push(asset);
        }

        // Load loreline data
        status = LOADING;

        if (path == null) {
            log.warning('Cannot load loreline asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        // Here, actual path is just path
        var actualPath = path;

        log.info('Load loreline $actualPath');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = actualPath;
        assets.addAsset(asset);
        assets.onceComplete(this, function(success) {

            var text = asset.text;
            var relativeLorelinePath = Path.directory(actualPath);
            if (relativeLorelinePath == '') relativeLorelinePath = '.';

            if (text != null) {

                try {

                    Loreline.parse(
                        text, actualPath,
                        (importPath, importCallback) -> {
                            loadImported(assets, importPath, importCallback);
                        },
                        script -> {

                            if (script != null) {
                                // Assign script
                                this.lorelineScript = script;

                                // Text asset not needed anymore
                                toDestroy.push(asset);

                                // Destroy unused assets
                                for (asset in toDestroy) {
                                    asset.destroy();
                                }

                                status = READY;
                                emitComplete(true);
                            }
                            else {
                                status = BROKEN;
                                log.error('Failed to decode loreline data at path: $path');
                                emitComplete(false);
                            }
                        }
                    );

                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to decode loreline data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load loreline data at path: $path');
                emitComplete(false);
            }
        });

        assets.load();

    }

    /**
     * Loads an imported Loreline file referenced by the main script.
     * @param assets The assets instance to use for loading
     * @param importPath Path to the imported file
     * @param importCallback Callback with the loaded text content
     */
    function loadImported(assets:Assets, importPath:String, importCallback:(data:String)->Void) {

        final asset = new TextAsset(importPath);
        asset.path = importPath;
        assets.addAsset(asset);
        asset.onceComplete(this, success -> {
            try {
                if (success) {
                    importCallback(asset.text);
                }
                else {
                    importCallback(null);
                }
            }
            catch (e:Dynamic) {
                status = BROKEN;
                log.error('Failed to import loreline file: $importPath');
                emitComplete(false);
            }
            asset.destroy();
        });
        assets.load();

    }

    /**
     * Handles file change detection for hot-reloading.
     * Monitors both the main script file and any imported files.
     * Triggers a reload when any monitored file changes.
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath())
            return;

        var toCheck = [path].concat(importedFiles != null ? importedFiles : []);
        var shouldReload = false;

        for (filePath in toCheck) {

            var previousTime:Float = -1;
            if (previousFiles.exists(filePath)) {
                previousTime = previousFiles.get(filePath);
            }

            var newTime:Float = -1;
            if (newFiles.exists(filePath)) {
                newTime = newFiles.get(filePath);
            }

            if (newTime != previousTime) {
                shouldReload = true;
                break;
            }
        }

        if (shouldReload) {
            log.info('Reload loreline (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (lorelineScript != null) {
            lorelineScript = null;
        }

    }

}
