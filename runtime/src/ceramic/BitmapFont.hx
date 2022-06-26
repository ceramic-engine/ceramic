package ceramic;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/phoenix/BitmapFont.hx)

import ceramic.Path;

using ceramic.Extensions;

class BitmapFont extends Entity {

    /**
     * The map of font texture pages to their id.
     */
    public var pages:IntMap<Texture> = new IntMap(16, 0.5, true);

    /**
     * The bitmap font fontData.
     */
    private var fontData(default, set):BitmapFontData;
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

    public var face(get,set):String;
    inline function get_face():String { return fontData.face; }
    inline function set_face(face:String):String { return fontData.face = face; }

    public var pointSize(get,set):Float;
    inline function get_pointSize():Float { return fontData.pointSize; }
    inline function set_pointSize(pointSize:Float):Float { return fontData.pointSize = pointSize; }

    public var baseSize(get,set):Float;
    inline function get_baseSize():Float { return fontData.baseSize; }
    inline function set_baseSize(baseSize:Float):Float { return fontData.baseSize = baseSize; }

    public var chars(get,set):IntMap<BitmapFontCharacter>;
    inline function get_chars():IntMap<BitmapFontCharacter> { return fontData.chars; }
    inline function set_chars(chars:IntMap<BitmapFontCharacter>):IntMap<BitmapFontCharacter> { return fontData.chars = chars; }

    public var charCount(get,set):Int;
    inline function get_charCount():Int { return fontData.charCount; }
    inline function set_charCount(charCount:Int):Int { return fontData.charCount = charCount; }

    public var lineHeight(get,set):Float;
    inline function get_lineHeight():Float { return fontData.lineHeight; }
    inline function set_lineHeight(lineHeight:Float):Float { return fontData.lineHeight = lineHeight; }

    public var kernings(get,set):IntMap<IntFloatMap>;
    inline function get_kernings():IntMap<IntFloatMap> { return fontData.kernings; }
    inline function set_kernings(kernings:IntMap<IntFloatMap>):IntMap<IntFloatMap> { return fontData.kernings = kernings; }

    public var msdf(get,never):Bool;
    inline function get_msdf():Bool { return fontData.distanceField != null && fontData.distanceField.fieldType == 'msdf'; }

    /**
     * Cached reference of the ' '(32) character, for sizing on tabs/spaces
     */
    public var spaceChar:BitmapFontCharacter;

    /**
     * Shaders used to render the characters. If null, uses default shader.
     * When loading MSDF fonts, ceramic's MSDF shader will be assigned here.
     * Stored per page
     */
    public var pageShaders:Map<Int,Shader> = null;

    /**
     * When using MSDF fonts, or fonts with custom shaders, it is possible to pre-render characters
     * onto a RenderTexture to use it like a regular texture later with default shader.
     * Useful in some situations to reduce draw calls.
     */
    public var preRenderedPages:Map<Int,Map<Int,Texture>> = null;

    /**
     * When a page is being pre-rendered, it will be referenced here, until the rendering is finished.
     * This is needed to prevent parallel renders of the same requested texture, giving us unexpected duplicate textures
     */
    var _preRenderingPages:Map<Int,Map<Int,Array<Void->Void>>> = null;

    public var asset:Asset;

/// Lifecycle

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
            this.pages.set(pageInfo.id, texture);

            if (fontData.distanceField != null) {
                var shader = ceramic.App.app.assets.shader('shader:msdf').clone();
                shader.setFloat('pxRange', fontData.distanceField.distanceRange);
                shader.setVec2('texSize', texture.width * texture.density, texture.height * texture.density);
                this.pageShaders.set(pageInfo.id, shader);
            }
        }

    }

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
     * Returns the kerning between two glyphs, or 0 if none.
     * A glyph int id is the value from 'c'.charCodeAt(0)
     */
    public inline function kerning(first:Int, second:Int) {

        var map = fontData.kernings.get(first);

        if (map != null && map.exists(second)) {
            return map.get(second);
        }

        return 0;

    }

}
