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

    function testEmptyScene() {

        final damage = new SceneDamage();
        step(damage, sceneOf(s -> quad(s, 10, 10, 10, 10)));
        assertEquals('9,9,21,21', step(damage, null));
        assertEquals('0,0,0,0', step(damage, new Scene()));

    }

}
