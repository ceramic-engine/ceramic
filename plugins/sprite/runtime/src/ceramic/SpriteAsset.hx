package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

class SpriteAsset extends Asset {

/// Properties

    @observe public var sheet:SpriteSheet = null;

    @observe public var text:String = null;

/// Internal

    var atlasAsset:AtlasAsset = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('sprite', name, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = false; // Handled at atlas level

        assets = new Assets();

    }

    override public function load() {

        if (owner != null) {
            assets.inheritRuntimeAssetsFromAssets(owner);
            assets.loadMethod = owner.loadMethod;
            assets.scheduleMethod = owner.scheduleMethod;
            assets.delayBetweenXAssets = owner.delayBetweenXAssets;
        }

        // Create array of assets to destroy after load
        var toDestroy:Array<Asset> = [];
        for (asset in assets) {
            toDestroy.push(asset);
        }

        // Load atlas data
        status = LOADING;

        if (path == null) {
            log.warning('Cannot load sprite asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log.info('Load sprite $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        var atlasAsset = new AtlasAsset(name);
        atlasAsset.path = path;

        // We provide a custom atlas parsing method to the atlas asset
        // so that it can parse sprite sheet data
        @:privateAccess atlasAsset.parseAtlas = parseAtlas;
        @:privateAccess atlasAsset.customExtensions = ['sprite'];

        assets.addAsset(atlasAsset);
        assets.onceComplete(this, function(success) {

            var atlas = atlasAsset.atlas;

            if (atlas != null) {

                try {
                    text = atlasAsset.text;
                    var newSheet = SpriteSheetParser.parseSheet(text, atlas);
                    newSheet.id = 'sprite:' + path;

                    var prevSheet = this.sheet;

                    // Link the sheet to this asset so that
                    // destroying one will destroy the other
                    newSheet.asset = this;

                    // Do the actual atlas replacement
                    this.sheet = newSheet;

                    if (prevSheet != null) {

                        // Set asset to null because we don't want it
                        // to be destroyed when destroying the sheet.
                        prevSheet.asset = null;
                        // Destroy previous sheet
                        prevSheet.destroy();
                    }

                    status = READY;
                    emitComplete(true);

                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to decode sprite data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load sprite data at path: $path');
                emitComplete(false);
            }
        });

        assets.load();

    }

    function parseAtlas(text:String):TextureAtlas {

        return SpriteSheetParser.parseAtlas(text);

    }

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

        if (newTime > previousTime) {
            log.info('Reload sprite (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (sheet != null) {
            sheet.destroy();
            sheet = null;
        }

    }

}
