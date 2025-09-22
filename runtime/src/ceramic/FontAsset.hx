package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

using StringTools;

/**
 * Asset type for loading bitmap fonts.
 * 
 * Supports loading:
 * - AngelCode BMFont format (.fnt files)
 * - TrueType/OpenType fonts (.ttf/.otf) that have been pre-converted to bitmap fonts
 * 
 * A bitmap font consists of:
 * - Font data file (.fnt) describing character metrics
 * - One or more texture pages containing the rendered glyphs
 * 
 * Features:
 * - Multi-page font support
 * - Automatic density selection for font textures
 * - Hot reload support
 * - Automatic Text visual updates when font is replaced
 * 
 * ```haxe
 * var assets = new Assets();
 * assets.addFont('arial.fnt');
 * assets.addFont('roboto.ttf'); // Assumes roboto.fnt exists
 * assets.load();
 * 
 * // Use loaded font
 * var text = new Text();
 * text.font = assets.font('arial');
 * ```
 */
class FontAsset extends Asset {

/// Events

    /**
     * Emitted when the font is replaced (e.g., during hot reload).
     * All Text visuals using the previous font are automatically updated.
     * @param newFont The newly loaded font
     * @param prevFont The previous font being replaced
     */
    @event function replaceFont(newFont:BitmapFont, prevFont:BitmapFont);

/// Properties

    /**
     * The parsed font data containing character metrics and layout information.
     * Available after successful loading.
     */
    public var fontData:BitmapFontData = null;

    /**
     * Map of texture page paths to loaded textures.
     * Bitmap fonts can use multiple texture pages for large character sets.
     */
    public var pages:Map<String,Texture> = null;

    /**
     * The loaded BitmapFont instance.
     * Observable property that updates when the font is loaded or replaced.
     * Null until the asset is successfully loaded.
     */
    @observe public var font:BitmapFont = null;

    var transformedPath:String = null;

/// Lifecycle

    /**
     * Create a new font asset.
     * @param name Font file name (.fnt, .ttf, or .otf)
     * @param variant Optional variant suffix
     * @param options Loading options (font-specific options depend on backend)
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('font', name, variant, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

        assets = new Assets();

    }

    /**
     * Load the font data and associated texture pages.
     * For TTF/OTF fonts, looks for pre-converted .fnt files.
     * Handles multi-page fonts by loading all required textures.
     * Emits complete event when finished.
     */
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

        // Load font data
        status = LOADING;

        if (path == null) {
            log.warning('Cannot load font asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        // TTF/OTF fonts don't exist at runtime, so if the name is that,
        // we resolve the converted bitmap font .fnt path instead
        var actualPath = path;

        var lowerCasePath = actualPath.toLowerCase();
        if (lowerCasePath.endsWith('.ttf') || lowerCasePath.endsWith('.otf')) {
            actualPath = actualPath.substring(0, actualPath.length - 4) + '.fnt';
        }

        log.info('Load font $actualPath');
        if (transformedPath != null) {
            actualPath = Path.join([transformedPath, actualPath]);
        }

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = actualPath;
        assets.addAsset(asset);
        assets.onceComplete(this, function(success) {

            var text = asset.text;
            var relativeFontPath = Path.directory(actualPath);
            if (relativeFontPath == '') relativeFontPath = '.';

            if (text != null) {

                try {
                    // Parse the font data - for Construct 3 fonts, we'll re-parse after loading images
                    var imagePath = Path.withoutExtension(Path.withoutDirectory(actualPath)) + '.png';
                    fontData = BitmapFontParser.parse(text, imagePath);
                    fontData.path = relativeFontPath;

                    // Load pages
                    var pages = new Map();
                    var assetList:Array<ImageAsset> = [];

                    for (page in fontData.pages) {

                        var pageFile = page.file;
                        if (relativeFontPath != '') {
                            pageFile = Path.join([relativeFontPath, pageFile]);
                        }

                        var pathInfo = Assets.decodePath(pageFile);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at font level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;

                        assets.addAsset(asset);
                        assetList.push(asset);

                    }

                    assets.onceComplete(this, function(success) {

                        if (success) {
                            // Check if we need to re-parse for Construct 3 fonts
                            if (fontData.needsReparsing && fontData.rawFontData != null && assetList.length > 0) {
                                // Get the width of the first image
                                var firstTexture = assetList[0].texture;
                                if (firstTexture != null) {
                                    // Re-parse with the actual image width
                                    var imageWidth = Math.round(firstTexture.width);
                                    var imagePath = Path.withoutExtension(Path.withoutDirectory(actualPath)) + '.png';
                                    
                                    try {
                                        fontData = BitmapFontParser.parse(fontData.rawFontData, imagePath, imageWidth);
                                        fontData.path = relativeFontPath;
                                    }
                                    catch (e:Dynamic) {
                                        log.error('Failed to re-parse Construct 3 font with image width: ' + e);
                                    }
                                }
                            }
                            
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
                                    if (!visual.destroyed && Std.isOfType(visual, Text)) {
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
                                if (Std.isOfType(asset, ImageAsset)) {
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
                            log.error('Failed to load textures for font at path: $path');
                            emitComplete(false);
                        }

                    });

                    assets.load();

                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to decode font data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load font data at path: $path');
                emitComplete(false);
            }
        });

        assets.load();

    }

    /**
     * Handle screen density changes by reloading the font at appropriate resolution.
     * This ensures text remains crisp when display density changes.
     */
    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    function checkTexturesDensity():Void {

        if (owner == null || !owner.reloadOnTextureDensityChange)
            return;

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload font ($prevPath -> $path)');
            load();
        }

    }

    /**
     * Handle file system changes for hot reload.
     * Monitors both the font data file and texture pages for changes.
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
            log.info('Reload font (file has changed)');

            var lowerCasePath = path.toLowerCase();
            if (owner?.runtimeAssets != null && lowerCasePath.endsWith('.ttf') || lowerCasePath.endsWith('.otf')) {
                var actualPath = path;
                owner.runtimeAssets.requestTransformedDir(transformedDir -> {
                    Platform.runCeramic([
                        'assets',
                        '--filter', path,
                        '--from', owner.runtimeAssets.path,
                        '--to', transformedDir,
                        '--list-changed'
                    ],
                    (code, out, err) -> {
                        if (code == 0) {
                            transformedPath = transformedDir;
                            var changed:Array<String> = Json.parse(out.trim());
                            for (absolutePath in changed) {
                                log.debug('Updated on the fly: $absolutePath');
                                Assets.incrementReloadCount(absolutePath);
                            }
                            load();
                        }
                    });
                });
            }
            else {
                load();
            }

        }

    }

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

    }

}
