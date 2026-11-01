package tests;

import gpui.scene.BoundsTree;
import gpui.scene.PrimitiveKind;
import gpui.scene.Scene;
import gpui.TextPainter;
import testing.TestCase;

/**
 * Tests for `BoundsTree` (ported from the tests of gpui-pre 0.3.10:
 * src/bounds_tree.rs) and for scene batching.
 */
class SceneTest extends TestCase {

    function testBoundsTreeInsert() {

        final tree = new BoundsTree();

        // Overlapping bounds get increasing orders
        assertEquals(1, tree.insert(0, 0, 10, 10));
        assertEquals(2, tree.insert(5, 5, 10, 10));
        assertEquals(3, tree.insert(10, 10, 10, 10));

        // Non-overlapping bounds can reuse orders
        assertEquals(1, tree.insert(20, 20, 10, 10));
        assertEquals(1, tree.insert(40, 40, 10, 10));
        assertEquals(2, tree.insert(25, 25, 10, 10));

    }

    function testBoundsTreeRandomIterations() {

        // Same scenario as GPUI's test_random_iterations, with a deterministic LCG
        // instead of rand::StdRng (the exact random values don't matter, the brute
        // force reference ordering does)
        var state = 1;
        inline function nextRandom():Float {
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
            return state / 0x7FFFFFFF;
        }

        for (seed in 1...1001) {
            state = seed;
            final tree = new BoundsTree();
            final xs:Array<Float> = [];
            final ys:Array<Float> = [];
            final ws:Array<Float> = [];
            final hs:Array<Float> = [];
            final orders:Array<Int> = [];

            final numBounds = 1 + Std.int(nextRandom() * 100);
            for (_ in 0...numBounds) {
                final x = -100 + nextRandom() * 200;
                final y = -100 + nextRandom() * 200;
                final w = nextRandom() * 50;
                final h = nextRandom() * 50;

                var expected = 0;
                for (i in 0...xs.length) {
                    if (x < xs[i] + ws[i] && x + w > xs[i] && y < ys[i] + hs[i] && y + h > ys[i]) {
                        if (orders[i] > expected) expected = orders[i];
                    }
                }
                expected++;

                xs.push(x);
                ys.push(y);
                ws.push(w);
                hs.push(h);
                orders.push(expected);

                final actual = tree.insert(x, y, w, h);
                if (actual != expected) {
                    fail('seed $seed: expected order $expected but got $actual');
                    return;
                }
            }
        }
        assertTrue(true);

    }

    function testClippedPrimitivesAreDropped() {

        final scene = new Scene();

        final visible = scene.nextQuad();
        visible.setBounds(0, 0, 10, 10);
        visible.setContentMask(0, 0, 100, 100);
        scene.commitQuad(visible);

        final clipped = scene.nextQuad();
        clipped.setBounds(200, 200, 10, 10);
        clipped.setContentMask(0, 0, 100, 100);
        scene.commitQuad(clipped);

        assertEquals(1, scene.quads.length);
        assertEquals(1, scene.len());

    }

    function testBatchesFollowPainterOrder() {

        final scene = new Scene();

        inline function addQuad(x:Float):Void {
            final q = scene.nextQuad();
            q.setBounds(x, 0, 10, 10);
            q.setContentMask(0, 0, 1000, 1000);
            scene.commitQuad(q);
        }

        inline function addShadow(x:Float):Void {
            final s = scene.nextShadow();
            s.setBounds(x, 0, 10, 10);
            s.setContentMask(0, 0, 1000, 1000);
            scene.commitShadow(s);
        }

        // Two disjoint quads (order 1), then a shadow over the first quad (order 2),
        // then a quad over that shadow (order 3)
        addQuad(0);
        addQuad(100);
        addShadow(0);
        addQuad(0);

        scene.finish();

        final kinds:Array<Int> = [];
        final lengths:Array<Int> = [];
        var batch = scene.nextBatch();
        while (batch != null) {
            kinds.push(batch.kind);
            lengths.push(batch.length());
            batch = scene.nextBatch();
        }

        assertEquals(3, kinds.length);
        assertEquals((PrimitiveKind.Quad:Int), kinds[0]);
        assertEquals(2, lengths[0]);
        assertEquals((PrimitiveKind.Shadow:Int), kinds[1]);
        assertEquals(1, lengths[1]);
        assertEquals((PrimitiveKind.Quad:Int), kinds[2]);
        assertEquals(1, lengths[2]);

    }

    function testSpriteBatchesSplitPerTexture() {

        final scene = new Scene();

        for (i in 0...4) {
            final s = scene.nextMonochromeSprite();
            s.setBounds(i * 20, 0, 10, 10);
            s.setContentMask(0, 0, 1000, 1000);
            s.setTile(i % 2, 0, 0, 10, 10);
            scene.commitMonochromeSprite(s);
        }

        scene.finish();

        final textures:Array<Int> = [];
        var batch = scene.nextBatch();
        while (batch != null) {
            textures.push(batch.textureIndex);
            assertEquals(2, batch.length());
            batch = scene.nextBatch();
        }
        assertEquals('0,1', textures.join(','));

    }

    function testPooledPrimitivesAreReset() {

        final scene = new Scene();
        final q = scene.nextQuad();
        q.setBounds(0, 0, 10, 10);
        q.setContentMask(0, 0, 100, 100);
        q.setBorderWidths(1, 2, 3, 4);
        scene.commitQuad(q);

        scene.clear();

        final reused = scene.nextQuad();
        assertTrue(reused == q, 'quad objects are pooled');
        assertEquals(0.0, reused.borderWidthTop);
        assertEquals(0.0, reused.boundsWidth);

    }

    function testLayerCoverBoundsInF32() {

        // A text line layer (`paint_layer`) at x 66.4000015 with a width of
        // 54.6000023 (both f32 values, scale 2) ends at 121.0 in f32, so it covers the
        // device columns up to 242 and a caret drawn at 242 does not overlap
        // it. In f64 the right edge is 121.0000038 and ceils to 243 (the
        // kit-editor-completion caret got order 5 instead of GPUI's 3).
        final scene = new Scene();
        final x = 66.4000015258789;
        final width = 54.60000228881836;
        assertEquals(x, gpui.SpringMath.f32(x));
        assertEquals(width, gpui.SpringMath.f32(width));
        assertTrue(x + width > 121, 'the f64 sum is above 121');
        assertTrue(TextPainter.pushCoverLayer(scene, x, 41, width, 20, 0, 0, 512, 512, 2));
        scene.popLayer();

        final caret = scene.nextQuad();
        caret.setBounds(242, 85, 2, 34);
        caret.setContentMask(0, 0, 1024, 1024);
        scene.commitQuad(caret);
        assertEquals(1, caret.order);

        // The covered columns still overlap at 241
        final glyph = scene.nextQuad();
        glyph.setBounds(240, 85, 2, 34);
        glyph.setContentMask(0, 0, 1024, 1024);
        scene.commitQuad(glyph);
        assertEquals(2, glyph.order);

        // Bounds clipped away by the mask push no layer
        assertFalse(TextPainter.pushCoverLayer(scene, 600, 0, 10, 10, 0, 0, 512, 512, 2));

    }

}
