// Ported from gpui-pre 0.3.10: src/platform.rs (PlatformAtlas, AtlasState),
// gpui-pre-wgpu 0.3.10: src/wgpu_atlas.rs (texture pages per kind),
// gpui-pre-apple 0.3.10: src/metal_atlas.rs (polychrome pages: sizes, etagere allocation)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.platform;

import glaze.*;
import ceramic.Texture;
import ceramic.UInt8Array;
import glaze.AtlasTile;
import glaze.PlatformAtlas;
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
    @:allow(glaze.platform.CeramicAtlasBackend)
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
    public var onTexturesChange(get, set):Null<() -> Void>;
    inline function get_onTexturesChange():Null<() -> Void> {
        return state.backend.onTexturesChange;
    }
    inline function set_onTexturesChange(value:Null<() -> Void>):Null<() -> Void> {
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
        state.backend.onEvictPage = state.forgetTexture;
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
        final isPath = key.match(AtlasKey.Path(_) | AtlasKey.PathCurves(_));
        backend.insertingPath = isPath;
        final tile = state.getOrInsertWith(key, build);
        backend.insertingPath = previous;
        if (isPath && tile != null) {
            // Painted in the frame being drawn
            backend.markPageUsed(tile.textureId.index, backend.drawIndex + 1);
        }
        return tile;
    }

    /**
     * Records the path pages used by `scene`, the scene of a frame that was
     * just drawn with this atlas (see `SceneRenderable.atlas`): a path page
     * none of the last `PATH_PAGE_KEEP_FRAMES` frames used can be emptied
     * and reused when the path pages are full, instead of adding a page.
     */
    public function markSceneUsed(scene:glaze.scene.Scene):Void {
        final backend = state.backend;
        backend.drawIndex++;
        final paths = scene.paths;
        for (i in 0...paths.length) {
            backend.markPageUsed(paths[i].textureIndex, backend.drawIndex);
        }
    }

    /**
     * Count of the times tiles were released (removed, evicted path pages,
     * atlas cleared): their room can then hold other pixels under the same
     * tile coordinates (see `SceneDamage`).
     */
    public var releaseCount(get, never):Int;
    inline function get_releaseCount():Int {
        return state.backend.releaseCount;
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

    /**
     * Modified areas not uploaded yet: `x, y, width, height` per area, at
     * most `MAX_DIRTY_RECTS` areas (see `markDirty()`).
     */
    public final dirtyRects:Array<Int> = [];

    /** Most areas uploaded separately; more are merged */
    public static inline final MAX_DIRTY_RECTS:Int = 8;

    public var texture:Null<Texture> = null;

    /** Whether this page holds path masks (see `CeramicAtlas.getOrInsertWith`). */
    public var forPaths:Bool = false;

    /** Last frame (`CeramicAtlasBackend.drawIndex`) using a path tile of this page */
    public var lastUsed:Int = 0;

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
        return dirtyRects.length > 0;
    }

    /**
     * Adds a modified area. Areas that overlap or touch an existing one are
     * merged into it, when the merged area wastes no more than the pixels of
     * both; past `MAX_DIRTY_RECTS` areas, the new one is merged into the
     * area it grows the least.
     */
    public function markDirty(x:Int, y:Int, w:Int, h:Int):Void {
        if (w <= 0 || h <= 0)
            return;
        // The area is uploaded before the next drawn frame (`upload()`, a listener
        // of Ceramic's begin draw event): ask for that frame (`settings.renderOnDemand`)
        ceramic.App.app.requestRender();
        final rects = dirtyRects;
        var i = 0;
        while (i < rects.length) {
            final rx = rects[i];
            final ry = rects[i + 1];
            final rw = rects[i + 2];
            final rh = rects[i + 3];
            final ux = x < rx ? x : rx;
            final uy = y < ry ? y : ry;
            final ur = x + w > rx + rw ? x + w : rx + rw;
            final ub = y + h > ry + rh ? y + h : ry + rh;
            final touching = x <= rx + rw && rx <= x + w && y <= ry + rh && ry <= y + h;
            if (touching && (ur - ux) * (ub - uy) <= w * h + rw * rh) {
                rects.splice(i, 4);
                // The merged area may now touch others: add it again
                markDirty(ux, uy, ur - ux, ub - uy);
                return;
            }
            i += 4;
        }
        if (rects.length < MAX_DIRTY_RECTS * 4) {
            rects.push(x);
            rects.push(y);
            rects.push(w);
            rects.push(h);
            return;
        }
        var best = 0;
        var bestGrowth = -1;
        i = 0;
        while (i < rects.length) {
            final rx = rects[i];
            final ry = rects[i + 1];
            final rw = rects[i + 2];
            final rh = rects[i + 3];
            final ux = x < rx ? x : rx;
            final uy = y < ry ? y : ry;
            final ur = x + w > rx + rw ? x + w : rx + rw;
            final ub = y + h > ry + rh ? y + h : ry + rh;
            final growth = (ur - ux) * (ub - uy) - rw * rh;
            if (bestGrowth < 0 || growth < bestGrowth) {
                bestGrowth = growth;
                best = i;
            }
            i += 4;
        }
        final rx = rects[best];
        final ry = rects[best + 1];
        final rw = rects[best + 2];
        final rh = rects[best + 3];
        final ux = x < rx ? x : rx;
        final uy = y < ry ? y : ry;
        final ur = x + w > rx + rw ? x + w : rx + rw;
        final ub = y + h > ry + rh ? y + h : ry + rh;
        rects.splice(best, 4);
        markDirty(ux, uy, ur - ux, ub - uy);
    }

    public inline function clearDirty():Void {
        dirtyRects.resize(0);
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

    public var onTexturesChange:Null<() -> Void> = null;

    /** Called with the texture index of a path page emptied for reuse */
    public var onEvictPage:Null<(Int) -> Void> = null;

    /**
     * Frames a path page stays untouched when no frame uses it anymore.
     * Path tiles are cached by shape (see `PathRasterizer.cacheKey()`), a
     * changing shape (an animated chart) adds new tiles at every frame.
     */
    public static inline final PATH_PAGE_KEEP_FRAMES:Int = 60;

    /** Frames drawn with this atlas (see `CeramicAtlas.markSceneUsed()`) */
    public var drawIndex:Int = 0;

    /** See `CeramicAtlas.releaseCount` */
    public var releaseCount:Int = 0;

    var nextTileId:Int = 0;

    /** Whether the tile being inserted is a path mask, which gets its own pages. */
    public var insertingPath:Bool = false;

    /** Upload buffer (`stagingBytes` and `staging` share their memory) */
    var stagingBytes:Bytes = null;
    var staging:UInt8Array = null;
    #if js
    var stagingWords:js.lib.Int32Array = null;
    #end

    public function new(pageSize:Int, createTextures:Bool) {
        this.pageSize = pageSize;
        this.createTextures = createTextures;
    }

    public inline function markPageUsed(index:Int, frame:Int):Void {
        final page = index >= 0 && index < pages.length ? pages[index] : null;
        if (page != null && page.forPaths && page.lastUsed < frame) {
            page.lastUsed = frame;
        }
    }

    /**
     * A path page of `kind` that no frame used for `PATH_PAGE_KEEP_FRAMES`
     * frames, emptied (its tiles forgotten) and ready for new tiles, or null.
     */
    function evictPathPage(kind:AtlasTextureKind, width:Int, height:Int):Null<CeramicAtlasPage> {
        var oldest:CeramicAtlasPage = null;
        for (page in pages) {
            if (page != null && page.forPaths && page.kind == kind && page.width >= width && page.height >= height
                && page.lastUsed < drawIndex - PATH_PAGE_KEEP_FRAMES && (oldest == null || page.lastUsed < oldest.lastUsed)) {
                oldest = page;
            }
        }
        if (oldest == null)
            return null;
        releaseCount++;
        if (onEvictPage != null)
            onEvictPage(oldest.index);
        if (oldest.allocator != null)
            oldest.allocator.reset();
        if (oldest.bucketedAllocator != null)
            oldest.bucketedAllocator.clear();
        oldest.data.fill(0, oldest.data.length, 0);
        oldest.clearDirty();
        oldest.markDirty(0, 0, oldest.width, oldest.height);
        oldest.lastUsed = drawIndex + 1;
        return oldest;
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
            if (page == null && insertingPath) {
                page = evictPathPage(kind, width, height);
                if (page != null && !page.bucketedAllocator.allocate(width, height))
                    page = null;
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
            if (page == null && insertingPath) {
                page = evictPathPage(kind, paddedWidth, paddedHeight);
                if (page != null && !page.allocator.allocate(paddedWidth, paddedHeight))
                    page = null;
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
        releaseCount++;
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
        page.lastUsed = drawIndex + 1;
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
        releaseCount++;
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

            final rects = page.dirtyRects;
            var r = 0;
            while (r < rects.length) {
                uploadRect(page, texture, rects[r], rects[r + 1], rects[r + 2], rects[r + 3]);
                r += 4;
            }
            page.clearDirty();
        }
    }

    function uploadRect(page:CeramicAtlasPage, texture:Texture, x0:Int, y0:Int, w:Int, h:Int):Void {
        final size = w * h * 4;
        if (stagingBytes == null || stagingBytes.length < size) {
            stagingBytes = Bytes.alloc(size);
            #if cs
            // On C# targets ceramic.UInt8Array is the byte[] of the Bytes itself
            staging = stagingBytes.getData();
            #else
            staging = UInt8Array.fromBytes(stagingBytes);
            #end
            #if js
            stagingWords = new js.lib.Int32Array(stagingBytes.getData());
            #end
        }

        final data = page.data;
        final out = stagingBytes;
        if (page.bytesPerPixel == 1) {
            // White premultiplied pixels with coverage as alpha: the 4 bytes
            // of a pixel are equal, one 32 bit write each
            #if js
            // (a typed array view: `Bytes.setInt32` goes through a DataView)
            final words = stagingWords;
            var n = 0;
            for (y in y0...y0 + h) {
                final p = y * page.width + x0;
                for (x in 0...w) {
                    final a = data.get(p + x);
                    words[n++] = (a << 24) | (a << 16) | (a << 8) | a;
                }
            }
            #else
            var n = 0;
            for (y in y0...y0 + h) {
                final p = y * page.width + x0;
                for (x in 0...w) {
                    final a = data.get(p + x);
                    out.setInt32(n, (a << 24) | (a << 16) | (a << 8) | a);
                    n += 4;
                }
            }
            #end
        }
        else {
            // Rows of RGBA pixels
            final rowBytes = w * 4;
            var n = 0;
            for (y in y0...y0 + h) {
                out.blit(n, data, (y * page.width + x0) * 4, rowBytes);
                n += rowBytes;
            }
        }

        #if cs
        // Unity's submitTexturePixelsRegion reads w * h * 4 bytes from offset 0
        texture.submitPixelsRegion(x0, y0, w, h, staging);
        #else
        texture.submitPixelsRegion(x0, y0, w, h, size == stagingBytes.length ? staging : UInt8Array.fromBytes(stagingBytes, 0, size));
        #end
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
