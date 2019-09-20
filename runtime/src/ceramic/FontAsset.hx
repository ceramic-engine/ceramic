package ceramic;

import ceramic.Shortcuts.*;

class FontAsset extends Asset {

/// Events

    @event function replaceFont(newFont:BitmapFont, prevFont:BitmapFont);

/// Properties

    public var fontData:BitmapFontData = null;

    public var pages:Map<String,Texture> = null;

    @observe public var font:BitmapFont = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('font', name, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

        assets = new Assets();

    } //name

    override public function load() {

        // Create array of assets to destroy after load
        var toDestroy:Array<Asset> = [];
        for (asset in assets) {
            toDestroy.push(asset);
        }

        // Load font data
        status = LOADING;

        if (path == null) {
            warning('Cannot load font asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load font $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;
        
        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = path;
        assets.addAsset(asset);
        assets.onceComplete(this, function(success) {

            var text = asset.text;

            if (text != null) {

                try {
                    fontData = BitmapFontParser.parse(text);

                    // Load pages
                    var pages = new Map();
                    var assetList:Array<ImageAsset> = [];

                    for (page in fontData.pages) {

                        var pathInfo = Assets.decodePath(page.file);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at font level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;
                        assets.addAsset(asset);
                        assetList.push(asset);
                        
                    }

                    assets.onceComplete(this, function(success) {

                        if (success) {
                            // Fill pages mapping
                            for (asset in assetList) {
                                pages.set(asset.path, asset.texture);
                            }

                            // Create bitmap font
                            var prevFont = this.font;
                            var newFont = new BitmapFont(fontData, pages);
                            newFont.id = 'font:' + path;

                            // Link the font to this asset so that
                            // destroying one will destroy the other
                            newFont.asset = this;

                            // Do the actual font replacement
                            this.font = newFont;

                            if (prevFont != null) {

                                // When replacing the font, emit an event to notify about it
                                emitReplaceFont(this.font, prevFont);

                                // Is this app's default font?
                                if (prevFont == app.defaultFont) {
                                    // Yes, then replace it with new one
                                    @:privateAccess app.defaultFont = this.font;
                                }

                                // Font was reloaded. Update related visuals
                                for (visual in [].concat(app.visuals)) {
                                    if (Std.is(visual, Text)) {
                                        var text:Text = cast visual;
                                        if (text.font == prevFont) {
                                            text.font = this.font;
                                        }
                                    }
                                }

                                // Set asset to null because we don't want it
                                // to be destroyed when destroying the font.
                                prevFont.asset = null;
                                // Destroy texture
                                prevFont.destroy();
                            }

                            // Destroy unused assets
                            for (asset in toDestroy) {
                                if (Std.is(asset, ImageAsset)) {
                                    // When it's an image, ensure we don't use it for the updated font, still.
                                    var imageAsset:ImageAsset = cast asset;
                                    if (assetList.indexOf(imageAsset) == -1) {
                                        asset.destroy();
                                    }
                                } else {
                                    asset.destroy();
                                }
                            }

                            status = READY;
                            emitComplete(true);
                            if (handleTexturesDensityChange) {
                                checkTexturesDensity();
                            }

                        }
                        else {
                            status = BROKEN;
                            error('Failed to load textures for font at path: $path');
                            emitComplete(false);
                        }

                    });

                    assets.load();

                } catch (e:Dynamic) {
                    status = BROKEN;
                    error('Failed to decode font data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                error('Failed to load font data at path: $path');
                emitComplete(false);
            }
        });

        assets.load();

    } //load

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log('Reload font ($prevPath -> $path)');
            load();
        }

    } //checkTexturesDensity

    override function destroy():Void {

        super.destroy();

        if (font != null) {
            font.destroy();
            font = null;
        }

        if (pages != null) {
            for (key in pages.keys()) {
                var texture = pages.get(key);
                texture.destroy();
            }
            pages = null;
        }

    } //destroy

} //FontAsset
