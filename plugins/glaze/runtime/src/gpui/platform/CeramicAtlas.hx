// Ported from gpui-pre 0.3.10: src/platform.rs (PlatformAtlas, AtlasState),
// gpui-pre-wgpu 0.3.10: src/wgpu_atlas.rs (texture pages per kind),
// gpui-pre-apple 0.3.10: src/metal_atlas.rs (polychrome pages: sizes, etagere allocation)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.platform;

import gpui.*;
import ceramic.Texture;
import ceramic.UInt8Array;
import gpui.AtlasTile;
import gpui.PlatformAtlas;
import haxe.io.Bytes;
import ttf.atlas.ShelfAllocator;

/**
 * The sprite atlas of the Ceramic platform: tiles are packed into pages,
 * one page per Ceramic `Texture`.
 *
 * - Monochrome pages store coverage, packed on shelves
 *   (`ttf.atlas.ShelfAllocator`) with a 1 pixel padding. They are uploaded
 *   as white premultiplied pixels with the coverage in every channel, so the
 *   scene renderer reads it from the alpha channel.
 * - Polychrome pages are those of GPUI's Metal atlas: straight alpha pixels
 *   (BGRA tiles, swapped to RGBA when inserted), packed without padding by
 *   etagere's `BucketedAtlasAllocator`, pages of at least `pageSize` (1024
 *   by default, like GPUI) in each dimension. Tiles land where GPUI puts
 *   them, so the texels around a tile (which bilinear filtering reads at the
 *   sprite edges) are the same as in GPUI. `SceneRenderable` draws them with
 *   straight alpha blending (`isStraightAlpha()`).
 *
 * Textures are indexed like GPUI's `AtlasTextureId.index`, across kinds:
 * `textures[tile.textureId.index]` is the texture of a tile, and the array
 * can be given as is to `SceneRenderable.atlasTextures`.
 *
 * New tiles are written to the CPU copy of their page and only the
 * modified area of each page is uploaded (`Texture.submitPixelsRegion()`),
 * by `upload()`. When created with `autoUpload` (the default), `upload()`
 * runs before every draw.
 *
 * Like GPUI's atlases, tiles are never evicted: pages are added as needed.
 * `clear()` drops every tile and page content.
 */
class CeramicAtlas extends ceramic.Entity implements PlatformAtlas {

    public final state:AtlasState<CeramicAtlasBackend>;

    /** `Texture.index` of the polychrome pages (straight alpha) of every atlas */
    @:allow(gpui.platform.CeramicAtlasBackend)
    static final straightAlphaTextures:Map<Int, Bool> = new Map();

    /**
     * Whether `texture` is a polychrome page of a `CeramicAtlas`: its pixels
     * have straight alpha (other textures are premultiplied, like every
     * Ceramic texture).
     */
    public static inline function isStraightAlpha(texture:Texture):Bool {
        return straightAlphaTextures.exists(texture.index);
    }

    /** Page textures, by texture index */
    public var textures(get, never):Array<Texture>;
    inline function get_textures():Array<Texture> {
        return state.backend.textures;
    }

    /**
     * Called when a texture is added (`textures` changed). A renderable using
     * these textures must refresh its used textures.
     */
    public var onTexturesChange(get, set):Null<Void->Void>;
    inline function get_onTexturesChange():Null<Void->Void> {
        return state.backend.onTexturesChange;
    }
    inline function set_onTexturesChange(value:Null<Void->Void>):Null<Void->Void> {
        return state.backend.onTexturesChange = value;
    }

    /**
     * @param pageSize Width and height of pages, in pixels
     * @param createTextures False to keep pages on the CPU only (tests)
     * @param autoUpload Upload modified areas before every draw
     */
    public function new(pageSize:Int = 1024, createTextures:Bool = true, autoUpload:Bool = true) {
        super();
        state = new AtlasState(new CeramicAtlasBackend(pageSize, createTextures));
        if (createTextures && autoUpload) {
            ceramic.App.app.onBeginDraw(this, upload);
        }
    }

    override function destroy():Void {
        super.destroy();
        state.backend.dispose();
    }

    public function getOrInsertWith(key:AtlasKey, build:() -> Null<AtlasTileSource>):Null<AtlasTile> {
        // Path masks (a Ceramic addition: GPUI does not put paths in its
        // atlas) get pages of their own, so they never push glyphs and
        // images to another page: the scene sorts sprites by page, like
        // GPUI, and the draw order of text must stay GPUI's.
        final backend = state.backend;
        final previous = backend.insertingPath;
        backend.insertingPath = key.match(AtlasKey.Path(_) | AtlasKey.PathCurves(_));
        final tile = state.getOrInsertWith(key, build);
        backend.insertingPath = previous;
        return tile;
    }

    public inline function getGlyph(params:RenderGlyphParams):Null<AtlasTile> {
        return state.getGlyph(params);
    }

    public function remove(key:AtlasKey):Void {
        state.remove(key);
    }

    public function contains(key:AtlasKey):Bool {
        return state.contains(key);
    }

    /** Drops every tile (pages and textures are kept, cleared). */
    public function clear():Void {
        state.clear(backend -> backend.reset());
    }

    /** Uploads the modified area of every page to its texture. */
    public function upload():Void {
        state.backend.upload();
    }

    /** CPU copy of a page (1 byte per pixel for monochrome pages, 4 otherwise). */
    public function pageData(textureIndex:Int):Bytes {
        return state.backend.pages[textureIndex].data;
    }

}

/**
 * A page of the atlas (one texture).
 */
class CeramicAtlasPage {

    public final index:Int;

    public final kind:AtlasTextureKind;

    public final width:Int;

    public final height:Int;

    /** Bytes per pixel: 1 (coverage) or 4 (RGBA) */
    public final bytesPerPixel:Int;

    public final data:Bytes;

    /** Allocator of monochrome pages (tiles padded by `CeramicAtlasBackend.PADDING`) */
    public final allocator:Null<ShelfAllocator>;

    /** Allocator of polychrome pages (unpadded tiles, like GPUI's Metal atlas) */
    public final bucketedAllocator:Null<BucketedAtlasAllocator>;

    public var dirtyMinX:Int = 0;
    public var dirtyMinY:Int = 0;
    public var dirtyMaxX:Int = 0;
    public var dirtyMaxY:Int = 0;

    public var texture:Null<Texture> = null;

    /** Whether this page holds path masks (see `CeramicAtlas.getOrInsertWith`). */
    public var forPaths:Bool = false;

    public function new(index:Int, kind:AtlasTextureKind, width:Int, height:Int) {
        this.index = index;
        this.kind = kind;
        this.width = width;
        this.height = height;
        bytesPerPixel = kind == Monochrome ? 1 : 4;
        data = Bytes.alloc(width * height * bytesPerPixel);
        data.fill(0, data.length, 0);
        if (kind == Polychrome) {
            allocator = null;
            bucketedAllocator = new BucketedAtlasAllocator(width, height);
        }
        else {
            allocator = new ShelfAllocator(width, height);
            bucketedAllocator = null;
        }
    }

    public inline function isDirty():Bool {
        return dirtyMaxX > dirtyMinX && dirtyMaxY > dirtyMinY;
    }

    public function markDirty(x:Int, y:Int, w:Int, h:Int):Void {
        if (!isDirty()) {
            dirtyMinX = x;
            dirtyMinY = y;
            dirtyMaxX = x + w;
            dirtyMaxY = y + h;
        }
        else {
            if (x < dirtyMinX) dirtyMinX = x;
            if (y < dirtyMinY) dirtyMinY = y;
            if (x + w > dirtyMaxX) dirtyMaxX = x + w;
            if (y + h > dirtyMaxY) dirtyMaxY = y + h;
        }
    }

    public inline function clearDirty():Void {
        dirtyMinX = dirtyMinY = dirtyMaxX = dirtyMaxY = 0;
    }

}

/**
 * Atlas backend storing tiles in `CeramicAtlasPage`s.
 */
class CeramicAtlasBackend implements AtlasBackend {

    /**
     * Padding around monochrome tiles, so that sampling never reads a
     * neighbour (polychrome tiles are not padded, like GPUI's)
     */
    public static inline final PADDING:Int = 1;

    /** Largest polychrome page (`MAX_ATLAS_SIZE` of GPUI's Metal atlas) */
    public static inline final MAX_PAGE_SIZE:Int = 16384;

    public final pageSize:Int;

    public final createTextures:Bool;

    public final pages:Array<CeramicAtlasPage> = [];

    public final textures:Array<Texture> = [];

    /** Textures of `insertTexture()` tiles (not owned, never destroyed here) */
    final externalTextures:Array<Texture> = [];

    public var onTexturesChange:Null<Void->Void> = null;

    var nextTileId:Int = 0;

    /** Whether the tile being inserted is a path mask, which gets its own pages. */
    public var insertingPath:Bool = false;

    var staging:UInt8Array = null;

    public function new(pageSize:Int, createTextures:Bool) {
        this.pageSize = pageSize;
        this.createTextures = createTextures;
    }

    public function insert(kind:AtlasTextureKind, width:Int, height:Int, bytes:Bytes):AtlasTile {
        if (kind == Subpixel)
            throw 'Subpixel atlas tiles are not supported';

        var page:CeramicAtlasPage = null;
        var x = 0;
        var y = 0;
        var padding = 0;
        var tileId = 0;

        if (kind == Polychrome) {
            // MetalAtlasTextures::allocate(): last pages first, then a new page
            var i = pages.length - 1;
            while (i >= 0) {
                final candidate = pages[i];
                if (candidate != null && candidate.kind == kind && candidate.forPaths == insertingPath && candidate.bucketedAllocator.allocate(width, height)) {
                    page = candidate;
                    break;
                }
                i--;
            }
            if (page == null) {
                // MetalAtlasTextures::push_texture(): min_size.min(MAX).max(DEFAULT)
                final pageWidth = Std.int(Math.max(Math.min(width, MAX_PAGE_SIZE), pageSize));
                final pageHeight = Std.int(Math.max(Math.min(height, MAX_PAGE_SIZE), pageSize));
                page = addPage(kind, pageWidth, pageHeight);
                if (!page.bucketedAllocator.allocate(width, height))
                    throw 'Could not allocate a ${width}x$height atlas tile';
            }
            x = page.bucketedAllocator.allocationX;
            y = page.bucketedAllocator.allocationY;
            tileId = page.bucketedAllocator.allocationId;
        }
        else {
            final paddedWidth = width + PADDING * 2;
            final paddedHeight = height + PADDING * 2;

            var i = pages.length - 1;
            while (i >= 0) {
                final candidate = pages[i];
                if (candidate != null && candidate.kind == kind && candidate.forPaths == insertingPath && candidate.allocator.allocate(paddedWidth, paddedHeight)) {
                    page = candidate;
                    break;
                }
                i--;
            }
            if (page == null) {
                var size = pageSize;
                while (paddedWidth > size || paddedHeight > size)
                    size *= 2;
                page = addPage(kind, size, size);
                if (!page.allocator.allocate(paddedWidth, paddedHeight))
                    throw 'Could not allocate a ${width}x$height atlas tile';
            }

            x = page.allocator.x + PADDING;
            y = page.allocator.y + PADDING;
            padding = PADDING;
            nextTileId++;
            tileId = nextTileId;
        }

        final bpp = page.bytesPerPixel;
        final rowBytes = width * bpp;
        if (bytes != null && bytes.length >= rowBytes * height) {
            for (row in 0...height) {
                page.data.blit(((y + row) * page.width + x) * bpp, bytes, row * rowBytes, rowBytes);
            }
            if (bpp == 4) {
                // BGRA to RGBA
                for (row in 0...height) {
                    var p = ((y + row) * page.width + x) * 4;
                    for (_ in 0...width) {
                        final b = page.data.get(p);
                        page.data.set(p, page.data.get(p + 2));
                        page.data.set(p + 2, b);
                        p += 4;
                    }
                }
            }
        }
        page.markDirty(x, y, width, height);

        return new AtlasTile(new AtlasTextureId(page.index, kind), tileId, padding, new Bounds(new Point(x, y), new Size(width, height)));
    }

    /**
     * A tile covering a whole external texture (not owned by the atlas):
     * the texture gets its own texture index, and no page is created.
     */
    public function insertTexture(kind:AtlasTextureKind, width:Int, height:Int, texture:Texture):AtlasTile {
        final index = textures.length;
        pages.push(null);
        textures.push(texture);
        externalTextures.push(texture);
        if (onTexturesChange != null)
            onTexturesChange();
        nextTileId++;
        return new AtlasTile(new AtlasTextureId(index, kind), nextTileId, 0, new Bounds(new Point(0, 0), new Size(width, height)));
    }

    public function remove(tile:AtlasTile):Void {
        final index = tile.textureId.index;
        if (index >= 0 && index < textures.length && pages[index] == null && textures[index] != null) {
            // External texture: release its slot
            externalTextures.remove(textures[index]);
            textures[index] = null;
            if (onTexturesChange != null)
                onTexturesChange();
            return;
        }
        final page = index >= 0 && index < pages.length ? pages[index] : null;
        if (page != null && page.bucketedAllocator != null) {
            // Like MetalAtlasTextures::remove() (the page itself is kept)
            page.bucketedAllocator.deallocate(tile.tileId);
        }
        // Monochrome shelf allocation doesn't free single tiles: they stay until the atlas is cleared
    }

    function addPage(kind:AtlasTextureKind, width:Int, height:Int):CeramicAtlasPage {
        final page = new CeramicAtlasPage(pages.length, kind, width, height);
        page.forPaths = insertingPath;
        pages.push(page);
        if (createTextures) {
            final pixels = new UInt8Array(width * height * 4);
            for (i in 0...pixels.length)
                pixels[i] = 0;
            final texture = Texture.fromPixels(width, height, pixels, 1);
            if (kind == Polychrome)
                CeramicAtlas.straightAlphaTextures.set(texture.index, true);
            // Linear like GPUI's atlas sampler: SVG tiles are rendered at twice their
            // size and sampled down (glyph tiles are drawn 1:1, where it makes no difference)
            texture.filter = LINEAR;
            page.texture = texture;
            textures.push(texture);
        }
        else {
            textures.push(null);
        }
        if (onTexturesChange != null)
            onTexturesChange();
        return page;
    }

    public function reset():Void {
        for (page in pages) {
            if (page == null) continue;
            if (page.allocator != null)
                page.allocator.reset();
            if (page.bucketedAllocator != null)
                page.bucketedAllocator.clear();
            page.data.fill(0, page.data.length, 0);
            page.markDirty(0, 0, page.width, page.height);
        }
    }

    public function upload():Void {
        for (page in pages) {
            if (page == null || !page.isDirty())
                continue;
            final texture = page.texture;
            if (texture == null || texture.destroyed) {
                page.clearDirty();
                continue;
            }

            final x0 = page.dirtyMinX;
            final y0 = page.dirtyMinY;
            final w = page.dirtyMaxX - x0;
            final h = page.dirtyMaxY - y0;
            final size = w * h * 4;
            if (staging == null || staging.length < size)
                staging = new UInt8Array(size);

            final data = page.data;
            var n = 0;
            if (page.bytesPerPixel == 1) {
                // White premultiplied pixels with coverage as alpha
                for (y in y0...y0 + h) {
                    final p = y * page.width + x0;
                    for (x in 0...w) {
                        final a = data.get(p + x);
                        staging[n] = a;
                        staging[n + 1] = a;
                        staging[n + 2] = a;
                        staging[n + 3] = a;
                        n += 4;
                    }
                }
            }
            else {
                for (y in y0...y0 + h) {
                    final p = (y * page.width + x0) * 4;
                    for (x in 0...w * 4) {
                        staging[n++] = data.get(p + x);
                    }
                }
            }

            texture.submitPixelsRegion(x0, y0, w, h, staging);
            page.clearDirty();
        }
    }

    public function dispose():Void {
        for (texture in textures) {
            if (texture != null)
                CeramicAtlas.straightAlphaTextures.remove(texture.index);
            if (texture != null && !texture.destroyed && externalTextures.indexOf(texture) == -1)
                texture.destroy();
        }
        externalTextures.resize(0);
        textures.resize(0);
        pages.resize(0);
    }

}
