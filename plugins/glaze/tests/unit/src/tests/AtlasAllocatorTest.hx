// Ported from etagere 0.2.15: src/bucketed.rs (tests atlas_basic, test_coalesce_shelves)
// Original code Copyright 2020 Nicolas Silva, licensed under MIT or Apache-2.0 (at your option).
// Modified: translated from Rust to Haxe for Ceramic, with tests of the port's
// polychrome atlas and straight alpha image decoding added. See NOTICE.md.
package tests;

import glaze.AtlasKey;
import glaze.AtlasTile.AtlasTileSource;
import glaze.ImageAssetLoader;
import glaze.platform.BucketedAtlasAllocator;
import glaze.platform.CeramicAtlas;
import haxe.io.Bytes;
import testing.TestCase;

class AtlasAllocatorTest extends TestCase {

    function alloc(atlas:BucketedAtlasAllocator, w:Int, h:Int):Int {
        assertTrue(atlas.allocate(w, h), 'allocate ${w}x$h');
        return atlas.allocationId;
    }

    function testAtlasBasic() {
        final atlas = new BucketedAtlasAllocator(1000, 1000);

        final full = alloc(atlas, 1000, 1000);
        assertFalse(atlas.allocate(1, 1));

        atlas.deallocate(full);
        final a = alloc(atlas, 10, 10);
        final b = alloc(atlas, 50, 30);
        final c = alloc(atlas, 12, 45);
        final d = alloc(atlas, 60, 45);
        final e = alloc(atlas, 1, 1);
        final f = alloc(atlas, 128, 128);
        final g = alloc(atlas, 256, 256);

        atlas.deallocate(b);
        atlas.deallocate(f);
        atlas.deallocate(c);
        atlas.deallocate(e);
        final h = alloc(atlas, 500, 200);
        atlas.deallocate(a);
        final i = alloc(atlas, 500, 200);
        atlas.deallocate(g);
        atlas.deallocate(h);
        atlas.deallocate(d);
        atlas.deallocate(i);

        final full2 = alloc(atlas, 1000, 1000);
        assertFalse(atlas.allocate(1, 1));
        atlas.deallocate(full2);
    }

    function testCoalesceShelves() {
        final atlas = new BucketedAtlasAllocator(256, 256);

        // Allocate 7 shelves (leaving 32px of remaining space on top).
        final ids = [];
        for (_ in 0...7) {
            for (_ in 0...8) {
                ids.push(alloc(atlas, 32, 32));
            }
        }

        // Free the first shelf.
        for (i in 0...8)
            atlas.deallocate(ids[i]);

        // Free the 3rd and 4th shelf.
        for (i in 16...32)
            atlas.deallocate(ids[i]);

        // Not enough space left in existing shelves and above,
        // even coalescing is not sufficient.
        assertFalse(atlas.allocate(70, 70));

        // The 3rd and 4th row can be coalesced to fit this allocation, though.
        final id = alloc(atlas, 64, 64);

        // Deallocate everything
        for (i in 8...16)
            atlas.deallocate(ids[i]);

        atlas.deallocate(id);

        for (i in 32...56)
            atlas.deallocate(ids[i]);

        assertTrue(atlas.isEmpty());
        assertEquals(0, atlas.getAllocatedSpace());
    }

    /**
     * The tiles of the `images` golden scenario land where GPUI's Metal atlas
     * puts them (`gpui/images.json`): the 64x48 PNG at 512,0 (tile id 4097),
     * the 48x48 SVG image next to it at 576,0 (tile id 8193), unpadded.
     */
    function testPolychromePlacementMatchesGpui() {
        final atlas = new CeramicAtlas(1024, false, false);
        final image = atlas.getOrInsertWith(AtlasKey.Image(1, 0), () -> straight(64, 48));
        final svg = atlas.getOrInsertWith(AtlasKey.Image(2, 0), () -> straight(48, 48));
        assertEquals(0, image.padding);
        assertFloatEquals(512, image.bounds.origin.x, 0);
        assertFloatEquals(0, image.bounds.origin.y, 0);
        assertEquals(4097, image.tileId);
        assertFloatEquals(576, svg.bounds.origin.x, 0);
        assertFloatEquals(0, svg.bounds.origin.y, 0);
        assertEquals(8193, svg.tileId);
        assertEquals(image.textureId.index, svg.textureId.index);
        atlas.destroy();
    }

    /** Straight alpha tiles are stored as is (BGRA swapped to RGBA), not premultiplied. */
    function testPolychromeTilesKeepStraightAlpha() {
        final atlas = new CeramicAtlas(1024, false, false);
        final source = straight(1, 1);
        source.bytes.set(0, 10); // B
        source.bytes.set(1, 20); // G
        source.bytes.set(2, 200); // R
        source.bytes.set(3, 51); // A
        final tile = atlas.getOrInsertWith(AtlasKey.Image(1, 0), () -> source);
        final page = atlas.pageData(tile.textureId.index);
        final p = (Std.int(tile.bounds.origin.y) * 1024 + Std.int(tile.bounds.origin.x)) * 4;
        assertEquals(200, page.get(p));
        assertEquals(20, page.get(p + 1));
        assertEquals(10, page.get(p + 2));
        assertEquals(51, page.get(p + 3));
        atlas.destroy();
    }

    /** PNGs decode to the exact straight alpha BGRA bytes they hold. */
    function testDecodePngStraightBgra() {
        final width = 5;
        final height = 3;
        final bgra = Bytes.alloc(width * height * 4);
        for (i in 0...width * height) {
            bgra.set(i * 4, (i * 37) & 0xFF);
            bgra.set(i * 4 + 1, (i * 91 + 7) & 0xFF);
            bgra.set(i * 4 + 2, (i * 53 + 11) & 0xFF);
            bgra.set(i * 4 + 3, (i * 17) & 0xFF);
        }
        final out = new haxe.io.BytesOutput();
        new format.png.Writer(out).write(format.png.Tools.build32BGRA(width, height, bgra));
        final image = ImageAssetLoader.decodePng(out.getBytes());
        assertTrue(image != null, 'decoded');
        assertFloatEquals(width, image.size(0).width, 0);
        assertFloatEquals(height, image.size(0).height, 0);
        final decoded = image.asBytes(0);
        assertEquals(0, decoded.compare(bgra));
    }

    static function straight(width:Int, height:Int):AtlasTileSource {
        final source = new AtlasTileSource(width, height, Bytes.alloc(width * height * 4));
        source.straightAlpha = true;
        return source;
    }

}
