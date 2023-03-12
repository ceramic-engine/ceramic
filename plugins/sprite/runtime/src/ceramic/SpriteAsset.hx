package ceramic;

import ase.Ase;
import ceramic.Path;
import ceramic.Shortcuts.*;

using StringTools;

class SpriteAsset extends Asset {

/// Properties

    @observe public var sheet:SpriteSheet = null;

    @observe public var text:String = null;

    public var atlas(get,never):TextureAtlas;
    function get_atlas():TextureAtlas {
        return atlasAsset != null ? atlasAsset.atlas : null;
    }

/// Internal

    var atlasAsset:AtlasAsset = null;

    var aseAsset:BinaryAsset = null;

    var asepriteData:AsepriteData = null;

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

        if (path != null && (path.toLowerCase().endsWith('.aseprite') || path.toLowerCase().endsWith('.ase'))) {
            loadAse();
        }
        else {
            loadSpriteSheet();
        }

    }

    function loadSpriteSheet() {

        atlasAsset = new AtlasAsset(name);
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

                    // Do the actual replacement
                    this.sheet = newSheet;

                    if (prevSheet != null) {

                        // Set asset to null because we don't want it
                        // to be destroyed when destroying the sheet.
                        prevSheet.asset = null;

                        // Destroy atlas as well
                        var prevAtlas = prevSheet.atlas;
                        if (prevAtlas != null) {
                            prevAtlas.destroy();
                        }

                        // Destroy previous sheet
                        prevSheet.destroy();
                    }

                    status = READY;
                    emitComplete(true);

                }
                catch (e:Dynamic) {
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

    function loadAse() {

        aseAsset = new BinaryAsset(name);
        aseAsset.path = path;

        assets.addAsset(aseAsset);
        assets.onceComplete(this, function(success) {

            if (aseAsset.bytes != null) {

                try {
                    var atlasPacker:TextureAtlasPacker = null;
                    if (owner != null) {
                        atlasPacker = owner.atlasPacker;
                    }
                    if (atlasPacker == null) {
                        atlasPacker = new TextureAtlasPacker();
                        atlasPacker.spacing = 0;
                        atlasPacker.filter = NEAREST;
                        if (owner != null) {
                            owner.atlasPacker = atlasPacker;
                        }
                    }

                    var ase:Ase = Ase.fromBytes(aseAsset.bytes);
                    var newAsepriteData = AsepriteParser.parseAse(ase, path, atlasPacker);
                    newAsepriteData.id = 'sprite:' + path;

                    var prevAsepriteData = this.asepriteData;

                    // Link the aseprite data to this asset so that
                    // destroying one will destroy the other
                    newAsepriteData.asset = this;

                    // Do the actual replacement
                    this.asepriteData = newAsepriteData;

                    if (prevAsepriteData != null) {

                        // Set asset to null because we don't want it
                        // to be destroyed when destroying the aseprite data.
                        prevAsepriteData.asset = null;

                        // Destroy atlas as well
                        var prevAtlas = prevAsepriteData.atlas;
                        if (prevAtlas != null) {
                            prevAtlas.destroy();
                        }

                        // Destroy previous aseprite data
                        // (will remove regions from atlas packer as well)
                        prevAsepriteData.destroy();
                    }

                    if (atlasPacker.hasPendingRegions()) {
                        if (owner != null) {
                            owner.addPendingAtlasPacker(atlasPacker);
                            status = READY;
                            emitComplete(true);
                        }
                        else {
                            atlasPacker.pack(atlas -> {
                                status = READY;
                                emitComplete(true);
                            });
                        }
                    }
                    else {
                        status = READY;
                        emitComplete(true);
                    }
                }
                catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to decode ase data at path: $path');
                    emitComplete(false);
                }

            }
            else {
                status = BROKEN;
                log.error('Failed to load ase data at path: $path');
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
