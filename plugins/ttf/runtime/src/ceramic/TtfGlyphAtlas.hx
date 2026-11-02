package ceramic;

import ceramic.Shortcuts.*;
import ttf.GlyphRasterizer;
import ttf.GlyphRasterizer.GlyphBitmap;
import ttf.atlas.AtlasPage;
import ttf.atlas.AtlasRegion;
import ttf.atlas.GlyphAtlas;

/**
 * A glyph rendered into a `TtfGlyphAtlas`.
 * Sizes and positions are in texture pixels.
 */
class TtfAtlasGlyph {

    /** Atlas page (and texture) index. */
    public var page:Int = 0;

    /** Page generation when the glyph was rendered (see `TtfGlyphAtlas.isValid()`). */
    public var generation:Int = 0;

    /** Position of the glyph image in the page. */
    public var x:Int = 0;

    public var y:Int = 0;

    /** Size of the glyph image, 0 for empty glyphs (spaces). */
    public var width:Int = 0;

    public var height:Int = 0;

    /** Placement of the image relative to the glyph origin (x right, y up). */
    public var left:Int = 0;

    public var top:Int = 0;

    public function new() {}

}

/**
 * Dynamic glyph atlas: glyph coverage bitmaps rasterized on demand into
 * pages, each page being a Ceramic `Texture` (white premultiplied RGBA,
 * alpha being the glyph coverage, so that quads tint it with their color).
 *
 * Glyphs are packed on shelves (`ttf.atlas.ShelfAllocator`). Modified page
 * areas are uploaded before drawing with partial texture updates
 * (`Texture.submitPixelsRegion()`), so adding a glyph only uploads its
 * own rectangle.
 *
 * Eviction policy: pages are added until `maxPages` is reached (0 means no
 * limit). After that, the least recently used page (pages are marked as
 * used when a glyph is looked up with `glyph()`) is cleared and reused, and
 * `pageEvicted` is emitted: visuals using glyphs of that page must lay out
 * their content again. `DynamicBitmapFont` uses an atlas without limit
 * (its glyphs are referenced by `BitmapFont.chars` and must stay valid).
 */
class TtfGlyphAtlas extends Entity {

    /**
     * Emitted when a page has been cleared to make room for new glyphs.
     */
    @event function pageEvicted(page:Int);

    static var _shared:TtfGlyphAtlas = null;

    /**
     * A shared atlas (1024x1024 pages, 4 pages at most), used by `TtfText`.
     */
    public static var shared(get, never):TtfGlyphAtlas;
    static function get_shared():TtfGlyphAtlas {
        if (_shared == null || _shared.destroyed)
            _shared = new TtfGlyphAtlas(1024, 4, ceramic.App.app.screen.texturesDensity);
        return _shared;
    }

    /**
     * The CPU side atlas (coverage pages and allocation).
     */
    public var atlas(default, null):GlyphAtlas;

    /**
     * One texture per page.
     */
    public var textures(default, null):Array<Texture> = [];

    /**
     * Texture filter of the pages. `NEAREST` is the right choice when glyphs
     * are drawn at their rasterized size on whole device pixels.
     */
    public var filter(default, set):TextureFilter = NEAREST;
    function set_filter(filter:TextureFilter):TextureFilter {
        if (this.filter == filter) return filter;
        this.filter = filter;
        for (texture in textures)
            texture.filter = filter;
        return filter;
    }

    /**
     * Density of the page textures (physical pixels per logical unit).
     */
    public var density(default, null):Float;

    var rasterizer:GlyphRasterizer = new GlyphRasterizer();

    var bitmap:GlyphBitmap = new GlyphBitmap();

    var region:AtlasRegion = new AtlasRegion();

    var staging:UInt8Array = null;

    /** Glyph caches by font, then by size (1/64 px), then by glyph and subpixel variant. */
    var caches:Map<ttf.Font, IntMap<IntMap<TtfAtlasGlyph>>> = new Map();

    public function new(pageSize:Int = 1024, maxPages:Int = 0, density:Float = 1) {

        super();

        this.density = density;
        atlas = new GlyphAtlas(pageSize, pageSize, maxPages, 1);
        atlas.onPageCreated = handlePageCreated;
        atlas.onPageEvicted = handlePageEvicted;

        app.onBeginDraw(this, upload);

    }

    override function destroy():Void {

        super.destroy();

        for (texture in textures) {
            if (!texture.destroyed)
                texture.destroy();
        }
        textures = [];
        caches = null;

    }

    function handlePageCreated(page:AtlasPage):Void {

        var size = page.width * page.height * 4;
        var pixels = new UInt8Array(size);
        for (i in 0...size)
            pixels[i] = 0;
        var texture = Texture.fromPixels(page.width / density, page.height / density, pixels, density);
        texture.filter = filter;
        textures.push(texture);
        page.clearDirty();

    }

    function handlePageEvicted(page:AtlasPage):Void {

        emitPageEvicted(page.index);

    }

    /**
     * Returns false if the page of `glyph` has been cleared since it was rendered.
     */
    public inline function isValid(glyph:TtfAtlasGlyph):Bool {
        return glyph.width == 0 || atlas.pages[glyph.page].generation == glyph.generation;
    }

    /**
     * Returns the atlas glyph of `gid` rendered at `fontSize` (device pixels per em)
     * with a horizontal subpixel offset of `subpixelVariant / 4` pixel,
     * rasterizing it if needed.
     */
    public function glyph(font:ttf.Font, gid:Int, fontSize:Float, subpixelVariant:Int = 0):TtfAtlasGlyph {

        var bySize = caches.get(font);
        if (bySize == null) {
            bySize = new IntMap();
            caches.set(font, bySize);
        }
        var sizeKey = Math.round(fontSize * 64);
        var glyphs = bySize.get(sizeKey);
        if (glyphs == null) {
            glyphs = new IntMap();
            bySize.set(sizeKey, glyphs);
        }
        var key = gid * GlyphRasterizer.SUBPIXEL_VARIANTS_X + subpixelVariant;
        var entry = glyphs.get(key);
        if (entry != null) {
            if (entry.width == 0)
                return entry;
            var page = atlas.pages[entry.page];
            if (page.generation == entry.generation) {
                atlas.touch(page);
                return entry;
            }
        }
        else {
            entry = new TtfAtlasGlyph();
            glyphs.set(key, entry);
        }

        render(font, gid, fontSize, subpixelVariant / GlyphRasterizer.SUBPIXEL_VARIANTS_X, entry);
        return entry;

    }

    /**
     * Rasterizes a glyph into the atlas and fills `entry` with its location.
     * Empty glyphs get a zero size and use no atlas space.
     */
    public function render(font:ttf.Font, gid:Int, fontSize:Float, subpixelX:Float, entry:TtfAtlasGlyph):TtfAtlasGlyph {

        var bounds = rasterizer.rasterBounds(font, gid, fontSize, subpixelX, 0, bitmap);
        entry.left = bounds.left;
        entry.top = bounds.top;
        entry.width = 0;
        entry.height = 0;
        entry.x = 0;
        entry.y = 0;
        entry.page = 0;
        if (bounds.width <= 0 || bounds.height <= 0)
            return entry;

        var r = atlas.allocate(bounds.width, bounds.height, region);
        if (r == null) {
            log.warning('Glyph $gid at size $fontSize is too large for the atlas');
            return entry;
        }

        var page = r.page;
        rasterizer.renderInto(font, gid, fontSize, subpixelX, 0, bounds.left, bounds.top,
            page.data, r.y * page.width + r.x, page.width, r.width, r.height);
        page.markDirty(r.x, r.y, r.width, r.height);

        entry.page = page.index;
        entry.generation = page.generation;
        entry.x = r.x;
        entry.y = r.y;
        entry.width = r.width;
        entry.height = r.height;
        return entry;

    }

    /**
     * Uploads the modified area of every page to its texture.
     * Called automatically before drawing.
     */
    public function upload():Void {

        atlas.frame++;

        var pages = atlas.pages;
        for (i in 0...pages.length) {
            var page = pages[i];
            if (!page.isDirty())
                continue;
            var texture = textures[i];
            if (texture == null || texture.destroyed) {
                page.clearDirty();
                continue;
            }

            var x0 = page.dirtyMinX;
            var y0 = page.dirtyMinY;
            var w = page.dirtyMaxX - x0;
            var h = page.dirtyMaxY - y0;
            var size = w * h * 4;
            if (staging == null || staging.length < size)
                staging = new UInt8Array(size);

            // White premultiplied pixels with coverage as alpha
            var data = page.data;
            var n = 0;
            for (y in y0...y0 + h) {
                var p = y * page.width + x0;
                for (x in 0...w) {
                    var a = data.get(p + x);
                    staging[n] = a;
                    staging[n + 1] = a;
                    staging[n + 2] = a;
                    staging[n + 3] = a;
                    n += 4;
                }
            }

            texture.submitPixelsRegion(x0, y0, w, h, staging);
            page.clearDirty();
        }

    }

}
