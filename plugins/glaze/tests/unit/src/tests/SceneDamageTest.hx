package tests;

import gpui.platform.SceneDamage;
import gpui.scene.Scene;
import testing.TestCase;

/**
 * Tests for `SceneDamage`, the changed region of the partial rendering of
 * `SceneRenderable` (the pixel equality with a full redraw is checked by the
 * golden harness, see `GPUI_GOLDEN_PARTIAL_OUT` in test/golden).
 */
class SceneDamageTest extends TestCase {

    static inline final W = 200;
    static inline final H = 100;

    static function quad(scene:Scene, x:Float, y:Float, w:Float, h:Float, hue:Float = 0.5, ?mask:Array<Float>):Void {
        final q = scene.nextQuad();
        q.setBounds(x, y, w, h);
        if (mask != null) q.setContentMask(mask[0], mask[1], mask[2], mask[3]);
        else q.setContentMask(0, 0, W, H);
        q.backgroundSolidH = hue;
        q.backgroundSolidA = 1;
        scene.commitQuad(q);
    }

    static function sceneOf(build:Scene->Void):Scene {
        final scene = new Scene();
        build(scene);
        scene.finish();
        return scene;
    }

    function region(damage:SceneDamage):String {
        return damage.full ? 'full' : '${damage.x0},${damage.y0},${damage.x1},${damage.y1}';
    }

    function step(damage:SceneDamage, scene:Null<Scene>, ?textures:Array<ceramic.Texture>, releaseCount:Int = 0):String {
        damage.record(scene, textures != null ? textures : [], releaseCount);
        damage.diff(W, H);
        return region(damage);
    }

    function testFirstSceneIsDrawnEntirely() {

        final damage = new SceneDamage();
        assertEquals('full', step(damage, sceneOf(s -> quad(s, 10, 10, 20, 20))));

    }

    function testSameSceneDamagesNothing() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10, 10, 20, 20);
        }));
        assertEquals('0,0,0,0', step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10, 10, 20, 20);
        })));

    }

    function testChangedPrimitiveDamagesItsPixelsPlusOne() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10.5, 10.25, 20, 20, 0.5);
            quad(s, 100, 50, 20, 20, 0.7);
        }));
        // Only the color of the middle quad changes: its rectangle rounded
        // out to whole pixels, plus one pixel of margin
        assertEquals('9,9,32,32', step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10.5, 10.25, 20, 20, 0.6);
            quad(s, 100, 50, 20, 20, 0.7);
        })));

    }

    function testMovedPrimitiveDamagesBothPlaces() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10, 10, 10, 10);
        }));
        assertEquals('9,9,51,21', step(damage, sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 40, 10, 10, 10);
        })));

    }

    function testAddedAndRemovedPrimitives() {

        final damage = new SceneDamage();
        final base = (s:Scene) -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 150, 60, 10, 10, 0.3);
        };
        step(damage, sceneOf(base));
        // A caret appears, then disappears
        assertEquals('49,19,52,41', step(damage, sceneOf(s -> {
            base(s);
            quad(s, 50, 20, 1, 20, 0.9);
        })));
        assertEquals('49,19,52,41', step(damage, sceneOf(base)));

    }

    function testDistantChangesInDrawOrderKeepWhatIsBetween() {

        final damage = new SceneDamage();
        // A row of cards: background quads first, then their badges (a
        // higher draw order), so that the background and the badge of the
        // first card are far apart in draw order, with the backgrounds of
        // the other cards between them
        final cards = (backgroundHue:Float, badgeHue:Float) -> sceneOf(s -> {
            for (i in 0...8) quad(s, i * 25, 0, 20, 20, i == 0 ? backgroundHue : 0.1);
            for (i in 0...8) quad(s, i * 25 + 5, 5, 10, 10, i == 0 ? badgeHue : 0.2);
        });
        step(damage, cards(0.1, 0.2));
        // The badge of the first card changes: only its pixels
        assertEquals('4,4,16,16', step(damage, cards(0.1, 0.3)));
        // The background and the badge of the first card: only that card,
        // not the cards drawn between them
        assertEquals('0,0,21,21', step(damage, cards(0.5, 0.4)));

    }

    function testInsertedPrimitivesAmongEqualOnes() {

        final damage = new SceneDamage();
        final row = (extra:Bool) -> sceneOf(s -> {
            for (i in 0...6) {
                quad(s, i * 30, 50, 10, 10, 0.1);
                if (extra && i == 2) quad(s, i * 30, 70, 10, 10, 0.2);
            }
        });
        step(damage, row(false));
        assertEquals('59,69,71,81', step(damage, row(true)));
        assertEquals('59,69,71,81', step(damage, row(false)));

    }

    function testContentMaskLimitsTheDamage() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> quad(s, 0, 0, 10, 10)));
        // Clipped to 0..60 x 0..30: the part of the quad outside never changes
        assertEquals('0,0,61,31', step(damage, sceneOf(s -> quad(s, 0, 0, 150, 90, 0.5, [0, 0, 60, 30]))));

    }

    function testShadowDamageIncludesItsBlur() {

        final damage = new SceneDamage();
        final scene = new Scene();
        final shadow = scene.nextShadow();
        shadow.setBounds(50, 40, 20, 10);
        shadow.setContentMask(0, 0, W, H);
        shadow.blurRadius = 4;
        shadow.colorA = 0.5;
        scene.commitShadow(shadow);
        scene.finish();
        step(damage, sceneOf(_ -> {}));
        // 3 times the blur radius on each side, like the drawn geometry
        assertEquals('37,27,83,63', step(damage, scene));

    }

    function testEverythingChangedIsFull() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> quad(s, 0, 0, W, H, 0.1)));
        assertEquals('full', step(damage, sceneOf(s -> quad(s, 0, 0, W, H, 0.2))));

    }

    function testNaNDamagesEverything() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> quad(s, 10, 10, 10, 10)));
        assertEquals('full', step(damage, sceneOf(s -> quad(s, 10, 10, Math.NaN, 10))));

    }

    function testAtlasChangesRedrawEverything() {

        final damage = new SceneDamage();
        final scene = () -> sceneOf(s -> quad(s, 10, 10, 10, 10));
        step(damage, scene(), [], 3);
        assertEquals('0,0,0,0', step(damage, scene(), [], 3));
        // A tile released: its room may hold other pixels under equal records
        assertEquals('full', step(damage, scene(), [], 4));
        assertEquals('0,0,0,0', step(damage, scene(), [], 4));
        // Unknown release count
        assertEquals('full', step(damage, scene(), [], -1));

    }

    function testInvalidateRedrawsEverything() {

        final damage = new SceneDamage();
        final scene = () -> sceneOf(s -> quad(s, 10, 10, 10, 10));
        step(damage, scene());
        damage.invalidate();
        assertEquals('full', step(damage, scene()));

    }

    function rectsOf(damage:SceneDamage):String {
        final order = [for (r in 0...damage.rectCount) r];
        order.sort((a, b) -> damage.rectX0(a) != damage.rectX0(b) ? damage.rectX0(a) - damage.rectX0(b) : damage.rectY0(a) - damage.rectY0(b));
        return [for (r in order) '${damage.rectX0(r)},${damage.rectY0(r)},${damage.rectX1(r)},${damage.rectY1(r)}'].join(' ');
    }

    function testDistantChangesGiveSeveralRectangles() {

        final damage = new SceneDamage();
        // A caret at the top left and a status bar item at the bottom right
        final editor = (caret:Bool, status:Float) -> sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            if (caret) quad(s, 10, 10, 1, 10, 0.9);
            quad(s, 150, 85, 40, 10, status);
        });
        step(damage, editor(false, 0.2));
        assertEquals('9,9,191,96', step(damage, editor(true, 0.3)));
        assertEquals(2, damage.rectCount);
        assertEquals('9,9,12,21 149,84,191,96', rectsOf(damage));

    }

    function testOverlappingAndTouchingRectanglesMerge() {

        final damage = new SceneDamage();
        final two = (hue:Float, x2:Float) -> sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10, 10, 20, 20, hue);
            quad(s, x2, 10, 20, 20, hue);
        });
        // Overlapping: 9..31 and 24..46
        step(damage, two(0.2, 25));
        step(damage, two(0.3, 25));
        assertEquals('9,9,46,31', rectsOf(damage));
        // Touching: 9..31 and 31..53
        step(damage, two(0.2, 32));
        step(damage, two(0.3, 32));
        assertEquals('9,9,53,31', rectsOf(damage));

    }

    function testCloseRectanglesMergeWhenLittleRoomIsWasted() {

        final damage = new SceneDamage();
        // Two 12x12 rectangles 20 pixels apart: their bounds waste 240
        // pixels, below `MERGE_SLACK`
        final two = (hue:Float) -> sceneOf(s -> {
            quad(s, 0, 0, W, H, 0.1);
            quad(s, 10, 10, 10, 10, hue);
            quad(s, 40, 10, 10, 10, hue);
        });
        step(damage, two(0.2));
        step(damage, two(0.3));
        assertEquals('9,9,51,21', rectsOf(damage));

    }

    /** A step on a texture of `width` x `height` pixels */
    function stepSized(damage:SceneDamage, scene:Scene, width:Int, height:Int):Void {
        damage.record(scene, [], 0);
        damage.diff(width, height);
    }

    function testMergeCascades() {

        final damage = new SceneDamage();
        final mask = [0.0, 0, 400, 400];
        // Two far apart dots, then a quad overlapping both: in the diff the
        // dots (drawn last) are found first, then the quad merges them all
        final three = (hue:Float) -> sceneOf(s -> {
            quad(s, 0, 0, 400, 400, 0.1, mask);
            quad(s, 12, 12, 288, 288, hue, mask);
            quad(s, 10, 10, 2, 2, hue, mask);
            quad(s, 300, 300, 3, 3, hue, mask);
        });
        stepSized(damage, three(0.2), 400, 400);
        stepSized(damage, three(0.3), 400, 400);
        assertFalse(damage.full);
        assertEquals('9,9,304,304', rectsOf(damage));

    }

    function testRectangleGrownInPlaceMergesWhatItReaches() {

        final damage = new SceneDamage();
        final mask = [0.0, 0, 2000, 2000];
        // A square far to the right, then 200 touching columns drawn left
        // to right (too many edits for the diff's search: added in scene
        // order). The columns grow one rectangle in place until it reaches
        // the square: both end up in one rectangle, none overlapping
        final scene = (hue:Float) -> sceneOf(s -> {
            quad(s, 0, 0, 2000, 2000, 0.1, mask);
            quad(s, 1500, 500, 40, 40, hue, mask);
            for (i in 0...200) quad(s, i * 8, 500, 8, 40, hue, mask);
        });
        stepSized(damage, scene(0.2), 2000, 2000);
        stepSized(damage, scene(0.3), 2000, 2000);
        assertEquals('0,499,1601,541', rectsOf(damage));

    }

    function testManyChangesSplitAgainOnlyWhenItSavedRoom() {

        final damage = new SceneDamage();
        final mask = [0.0, 0, 2000, 2000];
        // Rows of 60 touching quads, all changed at every frame: more edits
        // than the diff searches
        final rows = (hue:Float, two:Bool) -> sceneOf(s -> {
            quad(s, 0, 0, 2000, 2000, 0.1, mask);
            for (i in 0...60) quad(s, i * 10, 100, 10, 20, hue, mask);
            if (two) for (i in 0...60) quad(s, i * 10, 1500, 10, 20, hue, mask);
        });
        stepSized(damage, rows(0.2, false), 2000, 2000);
        // One row: the split gives one rectangle, its bounds (saved nothing)
        stepSized(damage, rows(0.3, false), 2000, 2000);
        assertEquals('0,99,601,121', rectsOf(damage));
        // Two far rows: their bounds for the next frames
        var hue = 0.4;
        for (frame in 0...SceneDamage.SPLIT_RETRY - 1) {
            stepSized(damage, rows(hue, true), 2000, 2000);
            hue = 0.9 - hue;
            assertEquals('0,99,601,1521', rectsOf(damage), 'frame $frame');
        }
        // Then split again: it saves room, so every next frame splits
        for (frame in 0...3) {
            stepSized(damage, rows(hue, true), 2000, 2000);
            hue = 0.9 - hue;
            assertEquals('0,99,601,121 0,1499,601,1521', rectsOf(damage), 'split frame $frame');
        }

    }

    function testRectangleCountIsCapped() {

        final damage = new SceneDamage();
        final mask = [0.0, 0, 2000, 2000];
        // A grid of 4 x 3 squares 400 and 600 pixels apart (no pair wastes
        // little enough room to be merged by the slack rule): the pairs
        // wasting the least room are merged down to `MAX_RECTS`
        final squares = (hue:Float) -> sceneOf(s -> {
            quad(s, 0, 0, 2000, 2000, 0.1, mask);
            for (j in 0...3) for (i in 0...4) quad(s, 100 + i * 400, 100 + j * 600, 20, 20, hue, mask);
        });
        stepSized(damage, squares(0.2), 2000, 2000);
        stepSized(damage, squares(0.3), 2000, 2000);
        assertFalse(damage.full);
        assertEquals(SceneDamage.MAX_RECTS, damage.rectCount);
        // Every square is inside a rectangle
        for (j in 0...3) for (i in 0...4) {
            final x = 100 + i * 400;
            final y = 100 + j * 600;
            var inside = false;
            for (r in 0...damage.rectCount) {
                if (x - 1 >= damage.rectX0(r) && y - 1 >= damage.rectY0(r) && x + 21 <= damage.rectX1(r) && y + 21 <= damage.rectY1(r)) inside = true;
            }
            assertTrue(inside, 'square $i,$j');
        }
        // Horizontal neighbours (closer) are merged, never vertical ones
        for (r in 0...damage.rectCount) {
            assertEquals(22, damage.rectY1(r) - damage.rectY0(r));
        }

    }

    function testSeparateRectanglesAreFasterThanTheirBounds() {

        // Partial draws of a caret and a far status bar: two small passes
        // instead of the bounds of both (most of the texture)
        final damage = new SceneDamage();
        final mask = [0.0, 0, 1000, 800];
        final editor = (caret:Bool) -> sceneOf(s -> {
            quad(s, 0, 0, 1000, 800, 0.1, mask);
            if (caret) quad(s, 100, 100, 2, 18, 0.9, mask);
            quad(s, 900, 780, 60, 16, caret ? 0.3 : 0.2, mask);
        });
        stepSized(damage, editor(false), 1000, 800);
        stepSized(damage, editor(true), 1000, 800);
        assertEquals('99,99,103,119 899,779,961,797', rectsOf(damage));

    }

    /**
     * Random scenes: the damage rectangles stay within the texture, at most
     * `MAX_RECTS`, pairwise disjoint (overlapping ones are merged), and
     * contain the clamped rectangle of every changed primitive.
     */
    function testRandomDamageCoversEveryChange() {

        randomRounds(12345, 30, 5);

    }

    /**
     * Same with many primitives, most of them changed and many along or
     * across the texture edges: more edits than the diff searches, so the
     * rectangles of every primitive of the middle section are added in
     * scene order (`addPrimitives()`).
     */
    function testRandomManyChangesCoverEveryChange() {

        randomRounds(777, 400, 1);

    }

    function randomRounds(initialSeed:Int, maxCount:Int, keepOdds:Int) {

        var seed = initialSeed;
        final rand = (n:Int) -> {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            return seed % n;
        };
        final damage = new SceneDamage();
        var previous:Array<Array<Float>> = [];
        for (round in 0...300) {
            final count = 1 + rand(maxCount);
            final quads:Array<Array<Float>> = [];
            for (i in 0...count) {
                // Keep most of the previous quads, change a few
                if (i < previous.length && rand(keepOdds) != 0) {
                    quads.push(previous[i]);
                }
                else {
                    quads.push([rand(W + 20) - 10, rand(H + 20) - 10, 1 + rand(40), 1 + rand(30), rand(10) / 10]);
                }
            }
            step(damage, sceneOf(s -> for (q in quads) quad(s, q[0], q[1], q[2], q[3], q[4])));
            if (round == 0 || damage.full) {
                previous = quads;
                continue;
            }
            assertTrue(damage.rectCount <= SceneDamage.MAX_RECTS);
            for (r in 0...damage.rectCount) {
                assertTrue(damage.rectX0(r) >= 0 && damage.rectY0(r) >= 0 && damage.rectX1(r) <= W && damage.rectY1(r) <= H);
                assertTrue(damage.rectX1(r) > damage.rectX0(r) && damage.rectY1(r) > damage.rectY0(r));
                for (o in r + 1...damage.rectCount) {
                    final overlap = damage.rectX0(r) < damage.rectX1(o) && damage.rectX0(o) < damage.rectX1(r)
                        && damage.rectY0(r) < damage.rectY1(o) && damage.rectY0(o) < damage.rectY1(r);
                    assertTrue(!overlap);
                }
            }
            // A quad present in one scene only was removed or added: the
            // damage must contain it
            for (q in previous.concat(quads)) {
                if (occurrences(q, previous) + occurrences(q, quads) == 1 && !covered(damage, q)) {
                    fail('round $round: quad $q not covered by ${rectsOf(damage)}');
                }
            }
            previous = quads;
        }

    }

    static function occurrences(q:Array<Float>, quads:Array<Array<Float>>):Int {
        var n = 0;
        for (o in quads) {
            if (o[0] == q[0] && o[1] == q[1] && o[2] == q[2] && o[3] == q[3] && o[4] == q[4]) n++;
        }
        return n;
    }

    static function covered(damage:SceneDamage, q:Array<Float>):Bool {
        // Clipped by the content mask (the texture) first: no pixel when empty
        final cx0 = Math.max(q[0], 0);
        final cy0 = Math.max(q[1], 0);
        final cx1 = Math.min(q[0] + q[2], W);
        final cy1 = Math.min(q[1] + q[3], H);
        if (cx1 <= cx0 || cy1 <= cy0) return true;
        var x0 = Std.int(Math.ffloor(cx0)) - SceneDamage.MARGIN;
        var y0 = Std.int(Math.ffloor(cy0)) - SceneDamage.MARGIN;
        var x1 = Std.int(Math.fceil(cx1)) + SceneDamage.MARGIN;
        var y1 = Std.int(Math.fceil(cy1)) + SceneDamage.MARGIN;
        if (x0 < 0) x0 = 0;
        if (y0 < 0) y0 = 0;
        if (x1 > W) x1 = W;
        if (y1 > H) y1 = H;
        if (x1 <= x0 || y1 <= y0) return true;
        for (r in 0...damage.rectCount) {
            if (x0 >= damage.rectX0(r) && y0 >= damage.rectY0(r) && x1 <= damage.rectX1(r) && y1 <= damage.rectY1(r)) return true;
        }
        return false;
    }

    function testEmptyScene() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> quad(s, 10, 10, 10, 10)));
        assertEquals('9,9,21,21', step(damage, null));
        assertEquals('0,0,0,0', step(damage, new Scene()));

    }

}
