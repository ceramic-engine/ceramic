package ceramic;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/phoenix/BitmapFont.hx)

import ceramic.Path;

using ceramic.Extensions;

/**
 * A bitmap font implementation that handles both regular bitmap fonts and MSDF (Multi-channel Signed Distance Field) fonts.
 * This class manages font textures, character data, kerning, and optional pre-rendering of characters.
 * It supports multiple texture pages and custom shaders, particularly useful for MSDF fonts.
 */
class BitmapFont extends Entity {

    /**
     * Maps texture page IDs to their corresponding textures.
     * A bitmap font can span multiple texture pages to accommodate large character sets.
     */
    public var pages:IntMap<Texture> = new IntMap(16, 0.5, true);

    /**
     * The core data structure containing all font information including
     * character metrics, kerning data, and texture coordinates.
     */
    private var fontData(default, set):BitmapFontData;

    /**
     * Updates font data and initializes special characters like space and no-break space.
     * @param fontData The new font data to set
     * @return The updated font data
     */
    function set_fontData(fontData:BitmapFontData) {

        this.fontData = fontData;

        if (fontData != null) {
            spaceChar = fontData.chars.get(32);

            // Use regular space glyph data as no-break space
            // if there is no explicit no-break space glyph in data.
            if (fontData.chars.get(160) == null) {
                fontData.chars.set(160, spaceChar);
            }
        }

        return fontData;

    }

    /**
     * The font face name (e.g. "Arial", "Roboto").
     * This is metadata from the font file.
     */
    public var face(get,set):String;
    inline function get_face():String { return fontData.face; }
    inline function set_face(face:String):String { return fontData.face = face; }

    /**
     * The point size the font was generated at.
     * This is the reference size for all metrics in the font data.
     */
    public var pointSize(get,set):Float;
    inline function get_pointSize():Float { return fontData.pointSize; }
    inline function set_pointSize(pointSize:Float):Float { return fontData.pointSize = pointSize; }

    /**
     * The base size used during font generation.
     * Often the same as pointSize but can differ based on the font tool used.
     */
    public var baseSize(get,set):Float;
    inline function get_baseSize():Float { return fontData.baseSize; }
    inline function set_baseSize(baseSize:Float):Float { return fontData.baseSize = baseSize; }

    /**
     * Map of character codes to their corresponding glyph data.
     * Each character contains texture coordinates, size, and offset information.
     */
    public var chars(get,set):IntMap<BitmapFontCharacter>;
    inline function get_chars():IntMap<BitmapFontCharacter> { return fontData.chars; }
    inline function set_chars(chars:IntMap<BitmapFontCharacter>):IntMap<BitmapFontCharacter> { return fontData.chars = chars; }

    /**
     * Total number of characters defined in this font.
     * Useful for statistics and validation.
     */
    public var charCount(get,set):Int;
    inline function get_charCount():Int { return fontData.charCount; }
    inline function set_charCount(charCount:Int):Int { return fontData.charCount = charCount; }

    /**
     * The recommended line height for this font in pixels.
     * Used for vertical spacing between lines of text.
     */
    public var lineHeight(get,set):Float;
    inline function get_lineHeight():Float { return fontData.lineHeight; }
    inline function set_lineHeight(lineHeight:Float):Float { return fontData.lineHeight = lineHeight; }

    /**
     * Kerning data for character pairs.
     * First level maps from first character to second character to kerning amount.
     * Kerning adjusts spacing between specific character pairs for better appearance.
     */
    public var kernings(get,set):IntMap<IntFloatMap>;
    inline function get_kernings():IntMap<IntFloatMap> { return fontData.kernings; }
    inline function set_kernings(kernings:IntMap<IntFloatMap>):IntMap<IntFloatMap> { return fontData.kernings = kernings; }

    /**
     * Indicates if this font is an MSDF (Multi-channel Signed Distance Field) font.
     * MSDF fonts provide superior scaling quality compared to regular bitmap fonts.
     */
    public var msdf(get,never):Bool;
    inline function get_msdf():Bool { return fontData.distanceField != null && fontData.distanceField.fieldType == 'msdf'; }

    /**
     * Cached reference to the space character (ASCII 32).
     * Used for efficient spacing calculations in text rendering.
     */
    public var spaceChar:BitmapFontCharacter;

    /**
     * Custom shaders used for rendering characters, stored per texture page.
     * Automatically set up for MSDF fonts using ceramic's MSDF shader.
     */
    public var pageShaders:Map<Int,Shader> = null;

    /**
     * Pre-rendered textures for different font sizes, stored per page and size.
     * Used to optimize rendering performance by caching commonly used sizes.
     */
    public var preRenderedPages:Map<Int,Map<Int,Texture>> = null;

    /**
     * Internal tracking of ongoing pre-render operations.
     * Prevents duplicate rendering requests for the same texture.
     */
    var _preRenderingPages:Map<Int,Map<Int,Array<Void->Void>>> = null;

    /**
     * Reference to the asset that created this font.
     * Used for proper resource management.
     */
    public var asset:Asset;

/// Lifecycle

    /**
     * Creates a new BitmapFont instance.
     * @param fontData The font data containing metrics and character information
     * @param pages A map of texture file paths to their corresponding textures
     * @throws String if fontData or pages are null
     */
    public function new(fontData:BitmapFontData, pages:Map<String,Texture>) {

        super();

        this.fontData = fontData;

        if (fontData == null) {
            throw 'BitmapFont: fontData is null';
        }
        if (pages == null) {
            throw 'BitmapFont: pages is null';
        }

        if (fontData.distanceField != null) {
            this.pageShaders = new Map();
        }

        for (pageInfo in fontData.pages) {
            var pageFile = pageInfo.file;
            if (fontData.path != null && fontData.path.length > 0 && fontData.path != '.') {
                pageFile = Path.join([fontData.path, pageInfo.file]);
            }

            var texture = pages.get(pageFile);

            if (texture == null) {
                throw 'BitmapFont: missing texture for file ' + pageInfo.file;
            }

            // Set texture filter based on font's smooth setting or distance field
            // Distance field fonts always need LINEAR filtering to render correctly
            texture.filter = (fontData.smooth || fontData.distanceField != null) ? LINEAR : NEAREST;

            this.pages.set(pageInfo.id, texture);

            if (fontData.distanceField != null) {
                var shader = ceramic.App.app.assets.shader(shaders.Msdf).clone();
                shader.setFloat('pxRange', fontData.distanceField.distanceRange);
                shader.setVec2('texSize', texture.width * texture.density, texture.height * texture.density);
                this.pageShaders.set(pageInfo.id, shader);
            }
        }

    }

    /**
     * Cleans up all resources associated with this font including textures,
     * shaders, and pre-rendered pages.
     */
    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        if (pages != null) {
            var iterableKeys = pages.iterableKeys;
            var len = iterableKeys.length;
            for (i in 0...len) {
                var texture = pages.get(iterableKeys.unsafeGet(i));
                texture.destroy();
            }
            pages = null;
        }

        if (pageShaders != null) {
            for (shader in pageShaders) {
                shader.destroy();
            }
            pageShaders = null;
        }

        if (preRenderedPages != null) {
            for (renderedForSize in preRenderedPages) {
                for (texture in renderedForSize) {
                    texture.destroy();
                }
            }
            preRenderedPages = null;
        }

    }

/// Public API

    /**
     * Checks if the font needs to be pre-rendered at a specific pixel size.
     * @param pixelSize The target size in pixels
     * @return True if pre-rendering is needed, false otherwise
     */
    public function needsToPreRenderAtSize(pixelSize:Int):Bool {

        if (preRenderedPages == null || !preRenderedPages.exists(pixelSize))
            return true;

        var preRenderedForSize = preRenderedPages.get(pixelSize);
        for (id in pages.iterableKeys) {
            if (!preRenderedForSize.exists(id))
                return true;
        }

        return false;

    }

    /**
     * Pre-renders the font at a specific pixel size.
     * Useful for optimizing rendering performance for frequently used sizes.
     * @param pixelSize The target size in pixels
     * @param done Callback function called when pre-rendering is complete
     */
    public function preRenderAtSize(pixelSize:Int, done:Void->Void):Void {

        var numPending = 0;

        for (id in pages.iterableKeys) {
            numPending++;

            preRenderPage(id, pixelSize, () -> {
                numPending--;
                if (numPending == 0) {
                    done();
                    done = null;
                }
            });
        }

    }

    /**
     * Internal method to pre-render a specific texture page at given size.
     * @param id The texture page ID
     * @param pixelsSize The target size in pixels
     * @param done Callback function called when pre-rendering is complete
     */
    function preRenderPage(id:Int, pixelsSize:Int, done:Void->Void):Void {

        if (preRenderedPages == null) {
            preRenderedPages = new Map();
        }

        // If already rendering this page, just wait until finished
        if (_preRenderingPages != null) {
            var _renderingForSize = _preRenderingPages.get(pixelsSize);
            if (_renderingForSize != null) {
                var _renderingPage = _renderingForSize.get(id);
                if (_renderingPage != null) {
                    _renderingPage.push(done);
                }
                return;
            }
        }

        // Expose rendering callback list
        if (_preRenderingPages == null)
            _preRenderingPages = new Map();
        var _renderingForSize = _preRenderingPages.get(pixelsSize);
        if (_renderingForSize == null) {
            _renderingForSize = new Map();
            _preRenderingPages.set(pixelsSize, _renderingForSize);
        }
        var _renderingPage = _renderingForSize.get(id);
        if (_renderingPage == null) {
            _renderingPage = [];
            _renderingForSize.set(id, _renderingPage);
        }

        // Start rendering
        var renderedForSize = preRenderedPages.get(pixelsSize);

        var originalTexture = pages.get(id);
        if (originalTexture == null)
            throw 'Invalid bitmap font page with id $id';

        var sizeFactor = pixelsSize / pointSize;
        var scaledWidth = Math.ceil((originalTexture.width * originalTexture.density) * sizeFactor);
        var scaledHeight = Math.ceil((originalTexture.width * originalTexture.density) * sizeFactor);

        var renderTexture = new RenderTexture(scaledWidth, scaledHeight, 1);
        renderTexture.clearOnRender = true;
        renderTexture.autoRender = false;

        var quad = new Quad();
        quad.texture = originalTexture;
        quad.size(scaledWidth, scaledHeight);
        quad.shader = pageShaders != null ? pageShaders.get(id) : null;
        quad.visible = false;

        if (renderedForSize != null && renderedForSize.exists(id)) {
            renderedForSize.get(id).destroy();
        }

        renderTexture.stamp(quad, () -> {

            quad.destroy();
            quad = null;

            if (renderedForSize == null) {
                renderedForSize = new Map();
                preRenderedPages.set(pixelsSize, renderedForSize);
            }

            // Not used, but we keep that snippet around
            // var pixels = renderTexture.fetchPixels();
            // var finalTexture = Texture.fromPixels(
            //     renderTexture.width, renderTexture.height,
            //     pixels, renderTexture.density
            // );
            // renderTexture.destroy();

            renderedForSize.set(id, renderTexture);

            done();
            done = null;

            _renderingForSize.remove(id);
            while (_renderingPage.length > 0) {
                var cb = _renderingPage.shift();
                cb();
                cb = null;
            }

        });

    }

    /**
     * Gets the kerning amount between two characters.
     * Kerning improves text appearance by adjusting the space between specific character pairs.
     * @param first The character code of the first glyph
     * @param second The character code of the second glyph
     * @return The kerning amount (0 if no kerning is defined)
     */
    public inline function kerning(first:Int, second:Int) {

        var map = fontData.kernings.get(first);

        if (map != null && map.exists(second)) {
            return map.get(second);
        }

        return 0;

    }

}
