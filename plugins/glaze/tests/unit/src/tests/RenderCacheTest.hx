package tests;

import glaze.AtlasKey;
import glaze.AtlasTile.AtlasTileSource;
import glaze.Path;
import glaze.PathBuilder;
import glaze.PathRasterizer;
import glaze.platform.CeramicAtlas;
import glaze.scene.Scene;
import testing.TestCase;
import glaze.Prelude.*;

/**
 * Caches of the rendering path: the path tile key (`PathRasterizer.cacheKey`),
 * the reuse of unused path pages and the dirty areas of `CeramicAtlas`.
 */
class RenderCacheTest extends TestCase {

    /** A star (fill polygons) at (`dx`, `dy`) logical pixels. */
    static function star(dx:Float, dy:Float):Path {
        final b = PathBuilder.fill();
        for (k in 0...5) {
            final angle = -Math.PI / 2 + k * 4 * Math.PI / 5;
            final p = point(px(dx + 60 + 45 * Math.cos(angle)), px(dy + 60 + 45 * Math.sin(angle)));
            if (k == 0)
                b.moveTo(p);
            else
                b.lineTo(p);
        }
        b.close();
        return b.build();
    }

    /** Triangles with a Loop-Blinn curve triangle at (`dx`, `dy`). */
    static function curves(dx:Float, dy:Float):Path {
        final path = new Path(point(px(dx), px(dy)));
        path.pushTriangle(point(px(dx + 10), px(dy + 10)), point(px(dx + 70), px(dy + 15)), point(px(dx + 30), px(dy + 60)));
        path.pushTriangle(point(px(dx + 10), px(dy + 10)), point(px(dx + 70), px(dy + 15)), point(px(dx + 50), px(dy - 20)), 0, 0, 1, 1, 0.5, 0);
        return path;
    }

    /** The device rectangle of `Window.paintPath()` (no content mask). */
    static function tileRect(path:Path, sf:Float):Array<Float> {
        final bounds = path.bounds;
        final x0 = Math.ffloor(bounds.origin.x * sf) - 1;
        final y0 = Math.ffloor(bounds.origin.y * sf) - 1;
        final x1 = Math.fceil((bounds.origin.x + bounds.size.width) * sf) + 1;
        final y1 = Math.fceil((bounds.origin.y + bounds.size.height) * sf) + 1;
        return [x0, y0, x1 - x0, y1 - y0];
    }

    function checkKeyMatchesRaster(build:(Float, Float) -> Path, curved:Bool) {
        final sf = 2.0;
        final viewport = 2048;
        final rasters:Map<String, haxe.io.Bytes> = new Map();
        var hits = 0;
        var keys = 0;
        // Whole and fractional device pixel moves, near and far from the origin
        for (i in 0...40) {
            final dx = i * 7.25 + (i % 3) * 0.13;
            final dy = i * 3.5;
            final path = build(dx, dy);
            final r = tileRect(path, sf);
            final w = Std.int(r[2]);
            final h = Std.int(r[3]);
            final key = PathRasterizer.cacheKey(path, sf, r[0], r[1], w, h, viewport, viewport);
            final source = curved
                ? PathRasterizer.rasterizeCurves(path, sf, r[0], r[1], w, h, viewport, viewport)
                : PathRasterizer.rasterize(path, sf, r[0], r[1], w, h, viewport, viewport);
            final existing = rasters.get(key);
            if (existing != null) {
                hits++;
                // Equal keys: equal tiles, byte for byte
                assertEquals(0, existing.compare(source.bytes), 'raster of key $key at $dx,$dy');
            }
            else {
                keys++;
                rasters.set(key, source.bytes);
            }
        }
        // The key ignores whole pixel moves: many placements share a tile
        assertTrue(hits > 0, 'some placements reuse a tile ($hits hits, $keys keys)');
        // and fractional offsets give other tiles
        assertTrue(keys > 1, 'fractional offsets give other keys ($keys keys)');
    }

    function testPathKeyMatchesRasterOfFills() {
        checkKeyMatchesRaster(star, false);
    }

    function testPathKeyMatchesRasterOfCurves() {
        checkKeyMatchesRaster(curves, true);
    }

    function testPathKeyIgnoresWholePixelMoves() {
        final sf = 2.0;
        final a = star(10, 10);
        final b = star(40, 25);
        final ra = tileRect(a, sf);
        final rb = tileRect(b, sf);
        assertEquals(
            PathRasterizer.cacheKey(a, sf, ra[0], ra[1], Std.int(ra[2]), Std.int(ra[3]), 2560, 2048),
            PathRasterizer.cacheKey(b, sf, rb[0], rb[1], Std.int(rb[2]), Std.int(rb[3]), 2560, 2048)
        );
        // A different shape has another key
        final c = star(10, 10.25);
        final rc = tileRect(c, sf);
        assertTrue(PathRasterizer.cacheKey(a, sf, ra[0], ra[1], Std.int(ra[2]), Std.int(ra[3]), 2560, 2048)
            != PathRasterizer.cacheKey(c, sf, rc[0], rc[1], Std.int(rc[2]), Std.int(rc[3]), 2560, 2048));
    }

    static function mask(width:Int, height:Int):AtlasTileSource {
        final bytes = haxe.io.Bytes.alloc(width * height);
        bytes.fill(0, bytes.length, 255);
        return new AtlasTileSource(width, height, bytes);
    }

    /**
     * Path pages that no frame used for a while are emptied and reused when
     * the path pages are full, instead of adding pages forever.
     */
    function testUnusedPathPagesAreReused() {
        final atlas = new CeramicAtlas(256, false, false);
        final empty = new Scene();
        // 4 tiles of 120x120 (122 with padding) fill a 256 page
        for (i in 0...4) {
            assertTrue(atlas.getOrInsertWith(AtlasKey.Path('a$i'), () -> mask(120, 120)) != null);
        }
        final pages = atlas.textures.length;
        // The page is used by the frames that follow: a new tile adds a page
        atlas.markSceneUsed(empty);
        final extra = atlas.getOrInsertWith(AtlasKey.Path('b'), () -> mask(120, 120));
        assertEquals(pages + 1, atlas.textures.length);
        // Fill the second page too
        for (i in 1...4) {
            atlas.getOrInsertWith(AtlasKey.Path('b$i'), () -> mask(120, 120));
        }
        assertEquals(pages + 1, atlas.textures.length);
        // Frames that use only the second page
        final scene = new Scene();
        final sprite = scene.nextPath();
        sprite.setTile(extra.textureId.index, 0, 0, 1, 1);
        scene.commitPath(sprite);
        for (_ in 0...CeramicAtlasBackend.PATH_PAGE_KEEP_FRAMES + 2) {
            atlas.markSceneUsed(scene);
        }
        // The first page is emptied and reused: no new page, its tiles forgotten
        final reused = atlas.getOrInsertWith(AtlasKey.Path('c'), () -> mask(120, 120));
        assertEquals(pages + 1, atlas.textures.length);
        assertTrue(reused.textureId.index != extra.textureId.index);
        assertFalse(atlas.contains(AtlasKey.Path('a0')));
        assertFalse(atlas.contains(AtlasKey.Path('a3')));
        assertTrue(atlas.contains(AtlasKey.Path('b')));
        // Glyph and image pages are never reused
        assertTrue(atlas.getOrInsertWith(AtlasKey.Svg('x', 120, 120), () -> mask(120, 120)) != null);
        assertEquals(pages + 2, atlas.textures.length);
        atlas.destroy();
    }

    function testDirtyAreasMergeWhenClose() {
        final page = new CeramicAtlasPage(0, Monochrome, 1024, 1024);
        page.markDirty(0, 0, 10, 10);
        page.markDirty(10, 0, 10, 10);
        // Adjacent: one area
        assertEquals(4, page.dirtyRects.length);
        assertEquals(20, page.dirtyRects[2]);
        // Far away: a second area
        page.markDirty(900, 900, 10, 10);
        assertEquals(8, page.dirtyRects.length);
        // Past the limit, merged into the closest area
        for (i in 0...20) {
            page.markDirty(100 + i * 40, 500, 10, 10);
        }
        assertTrue(page.dirtyRects.length <= CeramicAtlasPage.MAX_DIRTY_RECTS * 4);
        // Every marked pixel is covered
        function covered(x:Int, y:Int):Bool {
            var i = 0;
            while (i < page.dirtyRects.length) {
                final r = page.dirtyRects;
                if (x >= r[i] && y >= r[i + 1] && x < r[i] + r[i + 2] && y < r[i + 1] + r[i + 3])
                    return true;
                i += 4;
            }
            return false;
        }
        assertTrue(covered(5, 5));
        assertTrue(covered(15, 9));
        assertTrue(covered(905, 905));
        for (i in 0...20) {
            assertTrue(covered(100 + i * 40 + 9, 509));
        }
        page.clearDirty();
        assertFalse(page.isDirty());
    }

}
