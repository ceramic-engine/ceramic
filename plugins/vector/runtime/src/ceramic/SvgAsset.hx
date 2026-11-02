// Original code (not a port), written for the Ceramic vector plugin.
// The texture replacement loop of `replaceTextureInVisuals()` is adapted from
// ceramic.ImageAsset (Ceramic, MIT License, Copyright (c) 2018 Jeremy Faivre).
// MIT License, see Ceramic's LICENSE file.
package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

/**
 * Asset loading an SVG file (`.svg`) and parsing it into a lunasvg `Document`.
 *
 * The SVG source is kept in `text`. `document` is the parsed document, shared
 * by every user of the asset: attributes changed on it (`setAttribute()`) are
 * seen by all of them. Use `createDocument()` to get an independent copy.
 *
 * Textures:
 * - `texture(width, height)` returns a texture rasterized at that logical size
 *   and `screen.texturesDensity`, cached and owned by the asset. It is rendered
 *   again when the texture density changes (the new texture replaces the old
 *   one on every quad and mesh using it, like `ImageAsset` does) or when the
 *   file is hot reloaded. Call `updateTextures()` after changing `document`.
 * - `createTexture(width, height, density)` rasterizes into a new texture that
 *   the caller owns (not updated automatically).
 * - `SvgQuad` displays an SVG at the size of the quad.
 *
 * ```haxe
 * assets.add('svg:icons/heart');
 * assets.onceComplete(this, success -> {
 *     var quad = new Quad();
 *     quad.texture = assets.svgAsset('icons/heart').texture(48, 48);
 *     add(quad);
 * });
 * ```
 */
class SvgAsset extends Asset {

/// Events

    /**
     * Emitted when a cached texture (see `texture()`) is replaced by a new one,
     * after a texture density change.
     */
    @event function replaceTexture(newTexture:Texture, prevTexture:Texture);

/// Properties

    /**
     * The SVG source.
     */
    @observe public var text:String = null;

    /**
     * The parsed document (shared by every user of this asset).
     * Replaced by a new document when the file is hot reloaded.
     */
    @observe public var document:lunasvg.Document = null;

    /**
     * Textures created by `texture()`, by logical size.
     */
    var textures:Map<String, Texture> = null;

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('svg', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

        handleTexturesDensityChange = true;

    }

    /**
     * Loads the SVG file as text and parses it.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load svg asset if path is undefined.');
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

        var realPath = Assets.realAssetPath(path, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load svg $path');

        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text == null) {
                status = BROKEN;
                log.error('Failed to load svg at path: $path');
                emitComplete(false);
                return;
            }

            var newDocument = lunasvg.Document.loadFromData(text);
            if (newDocument == null) {
                status = BROKEN;
                log.error('Failed to parse svg at path: $path');
                emitComplete(false);
                return;
            }

            this.text = text;
            this.document = newDocument;

            // Hot reload: render the cached textures again
            updateTextures();

            status = READY;
            emitComplete(true);

        });

    }

    /**
     * Creates an asset from SVG source already in memory (not managed by `Assets`).
     * Returns null if the source cannot be parsed.
     */
    public static function fromText(name:String, text:String):SvgAsset {

        var newDocument = lunasvg.Document.loadFromData(text);
        if (newDocument == null)
            return null;

        var asset = new SvgAsset(name);
        asset.text = text;
        asset.document = newDocument;
        asset.status = READY;
        return asset;

    }

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY && (owner == null || owner.reloadOnTextureDensityChange)) {
            updateTextures();
        }

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
            log.info('Reload svg (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (textures != null) {
            var toDestroy = textures;
            textures = null;
            for (texture in toDestroy) {
                texture.destroy();
            }
        }

        document = null;
        text = null;

    }

/// Public API

    /**
     * Parses the SVG source again into a new document, independent from
     * `document` (attributes can be changed without affecting other users).
     */
    public function createDocument():lunasvg.Document {

        if (text == null)
            return null;
        return lunasvg.Document.loadFromData(text);

    }

    /**
     * Intrinsic width of the document (from its `width` attribute or `viewBox`).
     */
    public var intrinsicWidth(get, never):Float;
    function get_intrinsicWidth():Float {
        return document != null ? document.width() : 0;
    }

    /**
     * Intrinsic height of the document (from its `height` attribute or `viewBox`).
     */
    public var intrinsicHeight(get, never):Float;
    function get_intrinsicHeight():Float {
        return document != null ? document.height() : 0;
    }

    /**
     * Returns a texture of the document rasterized at `width` x `height` logical
     * units and `screen.texturesDensity`. Use -1 for a size computed from the
     * intrinsic size. The texture is cached and owned by this asset: do not
     * destroy it. It follows texture density changes and hot reloads, and is
     * rendered again by `updateTextures()`.
     */
    public function texture(width:Float = -1, height:Float = -1):Texture {

        if (document == null)
            return null;

        var key = width + 'x' + height;
        if (textures == null)
            textures = new Map();

        var existing = textures.get(key);
        if (existing != null && !existing.destroyed)
            return existing;

        var newTexture = VectorTextures.textureFromSvg(document, width, height, screen.texturesDensity);
        if (newTexture != null) {
            newTexture.id = 'svg:' + name + ':' + key;
            textures.set(key, newTexture);
        }
        return newTexture;

    }

    /**
     * Rasterizes the document into a new texture owned by the caller
     * (see `VectorTextures.textureFromSvg()`).
     * @param width Logical width (-1 for automatic)
     * @param height Logical height (-1 for automatic)
     * @param density Pixels per logical unit (-1 for `screen.texturesDensity`)
     */
    public function createTexture(width:Float = -1, height:Float = -1, density:Float = -1):Texture {

        if (document == null)
            return null;
        return VectorTextures.textureFromSvg(document, width, height, density);

    }

    /**
     * Renders the cached textures (see `texture()`) again, for instance after
     * changing attributes of `document`. Textures keep their identity unless
     * their pixel size changed (texture density change): they are then replaced
     * on every quad and mesh using them and `replaceTexture` is emitted.
     */
    public function updateTextures():Void {

        if (textures == null || document == null)
            return;

        var density = screen.texturesDensity;
        for (key => prevTexture in [for (k => t in textures) k => t]) {

            if (prevTexture.destroyed) {
                textures.remove(key);
                continue;
            }

            var parts = key.split('x');
            var width = Std.parseFloat(parts[0]);
            var height = Std.parseFloat(parts[1]);

            var newTexture = VectorTextures.textureFromSvg(document, width, height, density, prevTexture);
            if (newTexture == null || newTexture == prevTexture)
                continue;

            newTexture.id = prevTexture.id;
            newTexture.filter = prevTexture.filter;
            textures.set(key, newTexture);

            emitReplaceTexture(newTexture, prevTexture);
            replaceTextureInVisuals(newTexture, prevTexture);
            prevTexture.destroy();
        }

    }

/// Internal

    /**
     * Assigns `newTexture` to every quad and mesh displaying `prevTexture`
     * (adapted from `ImageAsset.load()`).
     */
    static function replaceTextureInVisuals(newTexture:Texture, prevTexture:Texture):Void {

        for (visual in [].concat(app.allVisuals)) {
            if (visual.destroyed)
                continue;
            if (visual.asQuad != null) {
                var quad = visual.asQuad;
                if (quad.texture == prevTexture) {
                    // Keep the same size and frame (in logical units)
                    var width = quad.width;
                    var height = quad.height;
                    var frameX = quad.frameX;
                    var frameY = quad.frameY;
                    var frameWidth = quad.frameWidth;
                    var frameHeight = quad.frameHeight;
                    quad.texture = newTexture;
                    quad.frameX = frameX;
                    quad.frameY = frameY;
                    quad.frameWidth = frameWidth;
                    quad.frameHeight = frameHeight;
                    quad.size(width, height);
                }
            }
            else if (visual.asMesh != null) {
                var mesh = visual.asMesh;
                if (mesh.texture == prevTexture) {
                    mesh.texture = newTexture;
                }
            }
        }

    }

}
