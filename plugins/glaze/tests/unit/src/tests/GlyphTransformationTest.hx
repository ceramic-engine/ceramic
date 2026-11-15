package tests;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Font;
import glaze.FontId;
import glaze.FontRun;
import glaze.GlyphId;
import glaze.HeadlessAtlas;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Point;
import glaze.RenderGlyphParams;
import glaze.TestDispatcher;
import glaze.TextPainter;
import glaze.TextSystem;
import glaze.Transformation;
import glaze.TransformationMatrix;
import glaze.Window;
import glaze.scene.MonochromeSprite;
import glaze.scene.Scene;
import glaze.util.Utf8;
import testing.InteractionScript.ScriptView;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): a glyph painted with a transformation
 * (`Window.paintGlyph(origin, fontId, glyphId, fontSize, color, transformation)`,
 * `paintEmoji`), checked on the fields of the emitted sprite.
 *
 * The expected matrices are written by hand: the renderer draws a corner p
 * of the sprite at `M * p + t` in device pixels, and a transformation
 * around the glyph origin o is `p' = o + L * (p - o) + translation`, so
 * `M = L` and `t = o + translation - L * o` (the windows and painters have a
 * scale factor of 2).
 */
class GlyphTransformationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) window.destroy();
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    /** Paints with `paint` in a canvas of a 400x300 window and returns its monochrome sprites. */
    function sprites(paint:(Window, FontId, GlyphId) -> Void, ?wrap:(glaze.Div) -> glaze.Div):Array<MonochromeSprite> {
        final ts = TextFixtures.textSystem();
        final fontId = ts.resolveFont(Font.of('Inter'));
        final glyphId:GlyphId = ts.platformTextSystem.glyphForChar(fontId, 'a'.code);
        final root:glaze.AnyView = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> {
            final holder = div().absolute().left(px(0)).top(px(0)).w(px(400)).h(px(300));
            return div().relative().w(px(400)).h(px(300)).child((wrap != null ? wrap(holder) : holder).child(
                canvas((_, _, _) -> 0, (_, _, window, _) -> paint(window, fontId, glyphId)).w(px(10)).h(px(10))));
        }));
        final window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, active: false, bindInput: false}, (_, _) -> root);
        windows.push(window);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
        return window.renderedScene().monochromeSprites;
    }

    static function matrix(sprite:MonochromeSprite):String {
        inline function r(v:Float):Float return Math.fround(v * 1e6) / 1e6 + 0.0;
        return '${r(sprite.transformM00)},${r(sprite.transformM01)},${r(sprite.transformM10)},${r(sprite.transformM11)} ${r(sprite.transformTx)},${r(sprite.transformTy)}';
    }

    function testWithoutATransformationTheSpriteIsTheUsualOne() {
        final plain = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black()));
        final explicitNull = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black(), null));
        final unit = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black(), TransformationMatrix.unit()));
        assertEquals(1, plain.length);
        assertFalse(plain[0].hasTransformation());
        for (other in [explicitNull[0], unit[0]]) {
            assertFalse(other.hasTransformation());
            assertEquals(plain[0].boundsX, other.boundsX);
            assertEquals(plain[0].boundsY, other.boundsY);
            assertEquals(plain[0].boundsWidth, other.boundsWidth);
            assertEquals(plain[0].tileX, other.tileX);
        }
    }

    function testTranslationScaleAndRotationAroundTheOrigin() {
        final plain = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black()))[0];
        function painted(m:TransformationMatrix):MonochromeSprite {
            final sprite = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black(), m))[0];
            // The sprite itself is the usual one: same raster, same place
            assertEquals(plain.boundsX, sprite.boundsX);
            assertEquals(plain.boundsY, sprite.boundsY);
            assertEquals(plain.boundsWidth, sprite.boundsWidth);
            assertEquals(plain.boundsHeight, sprite.boundsHeight);
            assertEquals(plain.tileWidth, sprite.tileWidth);
            return sprite;
        }
        // The origin (50, 60) is (100, 120) in device pixels
        // A translation of (3, 5) logical pixels: (6, 10) device pixels
        assertEquals('1,0,0,1 6,10', matrix(painted(TransformationMatrix.unit().translate(3, 5))));
        // A scale of 2 around the origin: t = o - 2 o
        assertEquals('2,0,0,2 -100,-120', matrix(painted(TransformationMatrix.unit().scale(2, 2))));
        // A quarter turn clockwise: L = [[0, -1], [1, 0]], t = o - L o = (100 + 120, 120 - 100)
        assertEquals('0,-1,1,0 220,20', matrix(painted(TransformationMatrix.unit().rotate(Math.PI / 2))));
        // One degree, like a rumble animation
        final degree = Math.PI / 180;
        final c = Math.cos(degree);
        final s = Math.sin(degree);
        final rumble = painted(TransformationMatrix.unit().rotate(degree));
        assertFloatEquals(c, rumble.transformM00, 1e-12);
        assertFloatEquals(-s, rumble.transformM01, 1e-12);
        assertFloatEquals(s, rumble.transformM10, 1e-12);
        assertFloatEquals(c, rumble.transformM11, 1e-12);
        assertFloatEquals(100 - (c * 100 - s * 120), rumble.transformTx, 1e-9);
        assertFloatEquals(120 - (s * 100 + c * 120), rumble.transformTy, 1e-9);
        // The origin stays in place: M * o + t = o
        assertFloatEquals(100, rumble.transformM00 * 100 + rumble.transformM01 * 120 + rumble.transformTx, 1e-9);
        assertFloatEquals(120, rumble.transformM10 * 100 + rumble.transformM11 * 120 + rumble.transformTy, 1e-9);
        // Rotation then translation
        assertEquals('0,-1,1,0 226,30', matrix(painted(TransformationMatrix.unit().translate(3, 5).rotate(Math.PI / 2))));
    }

    function testInsideAnElementTransformation() {
        // The element is moved by (10, 0): the origin is (60, 60), (120, 120) in device pixels
        final moved = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black(), TransformationMatrix.unit().rotate(Math.PI / 2)),
            el -> el.transformation(Transformation.translated(point(px(10), px(0)))))[0];
        // t = o - L o = (120 + 120, 120 - 120)
        assertEquals('0,-1,1,0 240,0', matrix(moved));

        // The element is doubled around its corner (0, 0): the origin is (100, 120),
        // (200, 240) in device pixels, the glyph is rasterized twice as large and the
        // translation of the glyph is doubled: t = (12, 20)
        final plain = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black()))[0];
        final scaled = sprites((window, fontId, glyphId) -> window.paintGlyph(point(50, 60), fontId, glyphId, 16, Hsla.black(), TransformationMatrix.unit().translate(3, 5)),
            el -> el.transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0)))[0];
        assertEquals('1,0,0,1 12,20', matrix(scaled));
        assertTrue(Math.abs(scaled.boundsWidth - 2 * plain.boundsWidth) <= 2);
        assertTrue(Math.abs(scaled.boundsX - 2 * plain.boundsX) <= 2);
    }

    function testEmojiMoveAndStretch() {
        final platform = @:privateAccess BundledEmojiFontTest.platform();
        final ts = new TextSystem(platform);
        final text = '😀';
        final line = platform.layoutLine(text, 16, [new FontRun(Utf8.byteLength(text), platform.fontId(Font.of('Inter')))]);
        final run = line.runs[0];
        final glyph = run.glyphs[0];
        assertTrue(glyph.isEmoji);
        final atlas = new HeadlessAtlas();
        final scene = new Scene();
        final params = new RenderGlyphParams();
        function emit(m:Null<TransformationMatrix>):glaze.scene.PolychromeSprite {
            scene.clear();
            assertTrue(TextPainter.emitEmojiTransformed(scene, atlas, ts, params, 2.0, 1.0, 0, 0, 1000, 1000, 50, 60, run.fontId, glyph.id, 16, 1.0, 1.0, 0.0, 0.0, m));
            assertEquals(1, scene.polychromeSprites.length);
            return scene.polychromeSprites[0];
        }
        final plain = emit(null);
        final px0 = plain.boundsX, py0 = plain.boundsY, w0 = plain.boundsWidth, h0 = plain.boundsHeight;
        assertTrue(w0 > 0 && h0 > 0);
        // A translation of (3, 5) logical pixels: (6, 10) device pixels
        final moved = emit(TransformationMatrix.unit().translate(3, 5));
        assertEquals(px0 + 6, moved.boundsX);
        assertEquals(py0 + 10, moved.boundsY);
        assertEquals(w0, moved.boundsWidth);
        // A rotation is ignored: the plain sprite
        final turned = emit(TransformationMatrix.unit().rotate(0.5));
        assertEquals(px0, turned.boundsX);
        assertEquals(w0, turned.boundsWidth);
        // A scale of 1.1 stretches the sprite around the origin (100, 120)
        final stretched = emit(TransformationMatrix.unit().scale(1.1, 1.1));
        assertFloatEquals(w0 * 1.1, stretched.boundsWidth, 1e-9);
        assertFloatEquals(h0 * 1.1, stretched.boundsHeight, 1e-9);
        assertFloatEquals(100 + (px0 - 100) * 1.1, stretched.boundsX, 1e-9);
        assertFloatEquals(120 + (py0 - 120) * 1.1, stretched.boundsY, 1e-9);
    }

}
