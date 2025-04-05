package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import loreline.Loreline;

using StringTools;

class LorelineAsset extends Asset {

/// Properties

    @observe public var lorelineScript:loreline.Script = null;

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
