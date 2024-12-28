package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

#if plugin_ase
import ase.Ase;
#end

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

    #if plugin_ase

    var asepriteData:AsepriteData = null;

    var asepritePostPack:()->Void = null;

    #end

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('sprite', name, variant, options #if ceramic_debug_entity_allocs , pos #end);
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

        #if plugin_ase
        if (path != null && (path.toLowerCase().endsWith('.aseprite') || path.toLowerCase().endsWith('.ase'))) {
            loadAse();
        }
        else {
        #end
            loadSpriteSheet();
        #if plugin_ase
        }
        #end

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

    #if plugin_ase

    function loadAse() {

        var assetReloadedCount = Assets.getReloadCount(Assets.realAssetPath(path, runtimeAssets));
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.binaries.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        app.backend.binaries.load(realPath, options, function(bytes) {

            if (bytes != null) {

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

                    var prevAsepriteData = this.asepriteData;

                    if (prevAsepriteData != null) {
                        if (prevAsepriteData.atlasPacker != null) {
                            prevAsepriteData.atlasPacker.removeRegionsWithPrefix(false, prevAsepriteData.prefix + '#');
                        }
                    }

                    var ase:Ase = Ase.fromBytes(bytes);
                    var newAsepriteData = AsepriteParser.parseAse(ase, path + (assetReloadedCount > 0 ? '?hot='+assetReloadedCount : ''), atlasPacker);
                    newAsepriteData.id = 'sprite:' + path;

                    if (asepritePostPack != null) {
                        atlasPacker.offFinishPack(asepritePostPack);
                    }
                    asepritePostPack = function() {
                        if (!newAsepriteData.destroyed && this.asepriteData == newAsepriteData) {
                            // We need to pack texture atlas before computing
                            // the final sprite sheet because we need valid regions
                            this.sheet = AsepriteParser.parseSheetFromAsepriteData(this.asepriteData);
                            @:privateAccess this.asepriteData.destroySheet();
                            @:privateAccess this.asepriteData.sheet = this.sheet;
                        }

                        if (prevAsepriteData != null) {

                            // Set asset to null because we don't want it
                            // to be destroyed when destroying the aseprite data.
                            prevAsepriteData.spriteAsset = null;

                            // Destroy previous aseprite data
                            // (will remove regions from atlas packer as well)
                            prevAsepriteData.destroy();
                            prevAsepriteData = null;
                        }
                    };
                    atlasPacker.onFinishPack(this, asepritePostPack);

                    // Link the aseprite data to this asset so that
                    // destroying one will destroy the other
                    newAsepriteData.spriteAsset = this;

                    // Do the actual replacement
                    this.asepriteData = newAsepriteData;

                    if (atlasPacker.hasPendingRegions()) {
                        if (assetReloadedCount == 0 && owner != null) {
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
                        asepritePostPack();
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

    }

    #end

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

        if (newTime != previousTime) {
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

        #if plugin_ase

        if (asepriteData != null) {
            asepriteData.destroy();
            asepriteData = null;
        }

        #end

    }

}
