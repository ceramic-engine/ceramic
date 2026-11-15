package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.StyledText;
import glaze.TestDispatcher;
import glaze.TextLayout;
import glaze.Transformation;
import glaze.TransformationMatrix;
import glaze.Window;
import glaze.platform.CeramicWindowOperations;
import glaze.scene.MonochromeSprite;
import glaze.scene.Quad;
import glaze.scene.Scene;
import testing.InteractionScript.ScriptView;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): an element and its children drawn
 * moved and scaled (`div().transformation(...)`,
 * `Window.withElementTransform`), without change of the layout.
 *
 * The expected rectangles are computed by hand from the layout of the test
 * trees (fixed sizes, absolute positions) and the definition of the
 * transformation (CSS `transform`: x' = pivot + scale * (x - pivot) +
 * translation), in device pixels (the windows have a scale factor of 2).
 */
class ElementTransformTest extends TestCase {

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

    function open(render:(Window, Context<Dynamic>) -> IntoElement, viewCaching:Bool = false):Window {
        final root:AnyView = app.newEntity((_:Context<ScriptView>) -> new ScriptView(render));
        return openRoot(root, viewCaching);
    }

    function openRoot(root:AnyView, viewCaching:Bool = false):Window {
        final window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, active: false, bindInput: false, viewCaching: viewCaching},
            (_, _) -> root);
        windows.push(window);
        app.update(_ -> window.draw());
        ceramic.App.app.flushImmediate();
        return window;
    }

    function frame():Void {
        ceramic.App.app.flushImmediate();
        for (window in windows) app.update(_ -> window.drawIfDirty());
    }

    /** The quad filled with the hue `h` (0..1), as `x,y wxh` in device pixels. */
    static function quad(window:Window, h:Float):String {
        final found = findQuad(window, h);
        return found == null ? 'none' : '${found.boundsX},${found.boundsY} ${found.boundsWidth}x${found.boundsHeight}';
    }

    static function findQuad(window:Window, h:Float):Null<Quad> {
        for (quad in window.renderedScene().quads) {
            if (quad.backgroundSolidA > 0 && Math.abs(quad.backgroundSolidH - h) < 1e-6)
                return quad;
        }
        return null;
    }

    static function mask(quad:Quad):String {
        return '${quad.contentMaskX},${quad.contentMaskY} ${quad.contentMaskWidth}x${quad.contentMaskHeight}';
    }

    static function box(h:Float, left:Float, top:Float, width:Float, height:Float):glaze.Div {
        return div().absolute().left(px(left)).top(px(top)).w(px(width)).h(px(height)).bg(hsla(h, 1, 0.5, 1));
    }

    static function root():glaze.Div {
        return div().relative().w(px(400)).h(px(300));
    }

    function click(window:Window, x:Float, y:Float):Void {
        app.update(cx -> {
            window.dispatchEvent(new MouseMoveEvent(new Point(x, y), null, Modifiers.none()), cx);
            window.dispatchEvent(new MouseDownEvent(Left, new Point(x, y), Modifiers.none(), 1, false), cx);
            window.dispatchEvent(new MouseUpEvent(Left, new Point(x, y), Modifiers.none(), 1), cx);
        });
        frame();
    }

/// Values

    function testMatrixHelpers() {
        final m = new TransformationMatrix(2, 0, 0, 4, 10, 20);
        assertTrue(m.isAxisAligned());
        assertFalse(TransformationMatrix.unit().rotate(0.3).isAxisAligned());
        final inverse = m.inverse();
        assertEquals(0.5, inverse.m00);
        assertEquals(0.25, inverse.m11);
        assertEquals(-5.0, inverse.tx);
        assertEquals(-5.0, inverse.ty);
        // inverse(m)(m(p)) = p
        final p = inverse.apply(m.apply(new Point(3, 7)));
        assertFloatEquals(3, p.x, 1e-12);
        assertFloatEquals(7, p.y, 1e-12);
        assertTrue(m.compose(inverse).equals(TransformationMatrix.unit()));
        assertNull(new TransformationMatrix(0, 0, 0, 1, 0, 0).inverse());
        // A rotation of a quarter turn: (x, y) -> (-y, x), back with the inverse
        final quarter = TransformationMatrix.unit().rotate(Math.PI / 2);
        final back = quarter.inverse().apply(quarter.apply(new Point(3, 7)));
        assertFloatEquals(3, back.x, 1e-12);
        assertFloatEquals(7, back.y, 1e-12);

        // Bounds: (1, 2) 10x20 scaled by (2, 4), moved by (10, 20)
        final mapped = m.mapBounds(new Bounds(new Point(1, 2), size(10, 20)));
        assertEquals('12,28 20x80', '${mapped.origin.x},${mapped.origin.y} ${mapped.size.width}x${mapped.size.height}');
        // A quarter turn of (0, 0) 10x20 holds x in -20..0 and y in 0..10
        final turned = quarter.mapBounds(new Bounds(new Point(0, 0), size(10, 20)));
        assertFloatEquals(-20, turned.origin.x, 1e-12);
        assertFloatEquals(0, turned.origin.y, 1e-12);
        assertFloatEquals(20, turned.size.width, 1e-12);
        assertFloatEquals(10, turned.size.height, 1e-12);
    }

    function testTransformationValue() {
        final t = Transformation.scaled(size(2, 3)).withTranslation(point(px(5), px(7)));
        assertEquals(0.5, t.originX);
        assertEquals(0.5, t.originY);
        // Around the center of (10, 20) 100x50, which is (60, 45): x' = 60 + 2 (x - 60) + 5
        final bounds = new Bounds(new Point(10, 20), size(100, 50));
        final centered = t.intoElementMatrix(bounds);
        assertEquals('2,0,0,3 -55,-83', '${centered.m00},${centered.m01},${centered.m10},${centered.m11} ${centered.tx},${centered.ty}');
        // Around the top left corner: x' = 10 + 2 (x - 10) + 5
        final corner = t.withOrigin(0, 0).intoElementMatrix(bounds);
        assertEquals('-5,-33', '${corner.tx},${corner.ty}');
        assertEquals(0.0, t.withOrigin(0, 0).originX);
        // The origin is kept by the other builders
        final kept = t.withOrigin(1, 0).withScaling(size(4, 4)).withTranslation(point(px(0), px(0))).withRotation(0.5);
        assertEquals(1.0, kept.originX);
        assertEquals(0.0, kept.originY);
        assertTrue(t.equals(Transformation.scaled(size(2, 3)).withTranslation(point(px(5), px(7)))));
        assertFalse(t.equals(t.withOrigin(0, 0)));
        assertTrue(new Transformation().isIdentity());
        assertFalse(t.isIdentity());

        // From a motion value of the kit
        final motion = new glaze.kit.base.motion.MotionTransform(new Point(3, 4), new Point(1.5, 0.5), 0.25, 0.8);
        final from = Transformation.fromMotion(motion);
        assertEquals(1.5, from.scale.width);
        assertEquals(0.5, from.scale.height);
        assertEquals(3.0, from.translate.x);
        assertEquals(4.0, from.translate.y);
        assertEquals(0.25, (from.rotate:Float));
    }

/// Drawing

    function testTranslationMovesTheDrawingNotTheLayout() {
        final plain = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50)).child(div().w(px(30)).h(px(30)).bg(hsla(0.6, 1, 0.5, 1))));
        assertEquals('20,40 200x100', quad(plain, 0.1));
        assertEquals('0,0 60x60', quad(plain, 0.6));

        // 4 px down: 8 device pixels
        final moved = open((_, _) -> root()
            .child(box(0.1, 10, 20, 100, 50).transformation(Transformation.translated(point(px(0), px(4)))))
            .child(div().w(px(30)).h(px(30)).bg(hsla(0.6, 1, 0.5, 1))));
        assertEquals('20,48 200x100', quad(moved, 0.1));
        assertEquals('0,0 60x60', quad(moved, 0.6));
    }

    function testScaleAroundTheCenterAndAroundACorner() {
        // (10, 20) 100x50 doubled around its center (60, 45): (-40, -5) 200x100
        final centered = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50).transformation(Transformation.scaled(size(2, 2)))));
        assertEquals('-80,-10 400x200', quad(centered, 0.1));
        // Around its top left corner: (10, 20) 200x100
        final corner = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))));
        assertEquals('20,40 400x200', quad(corner, 0.1));
        // Two scales: 1.5 x 0.5 around the bottom right corner (110, 70): x 110 - 150, y 70 - 25
        final corner2 = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50).transformation(Transformation.scaled(size(1.5, 0.5)).withOrigin(1, 1))));
        assertEquals('-80,90 300x50', quad(corner2, 0.1));
    }

    function testChildrenRadiiAndBordersFollow() {
        final window = open((_, _) -> root().child(
            box(0.1, 0, 0, 100, 100).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                .child(box(0.3, 10, 10, 20, 20).rounded(px(4)))
                .child(div().absolute().left(px(50)).top(px(10)).w(px(20)).h(px(20)).border1().borderColor(hsla(0, 0, 0, 1)))));
        assertEquals('0,0 400x400', quad(window, 0.1));
        // The child: (10, 10) 20x20 becomes (20, 20) 40x40, in device pixels x 2
        assertEquals('40,40 80x80', quad(window, 0.3));
        final child = findQuad(window, 0.3);
        // A radius of 4 px is 8 px, 16 device pixels
        assertEquals(16.0, child.cornerRadiusTopLeft);
        assertEquals(16.0, child.cornerRadiusBottomRight);
        // A border of 1 px is 2 px, 4 device pixels, around (100, 20) 40x40
        var border:Null<Quad> = null;
        for (quad in window.renderedScene().quads) {
            if (quad.borderWidthTop > 0) border = quad;
        }
        assertNotNull(border);
        assertEquals('200,40 80x80', '${border.boundsX},${border.boundsY} ${border.boundsWidth}x${border.boundsHeight}');
        assertEquals(4.0, border.borderWidthTop);
        assertEquals(4.0, border.borderWidthLeft);
        assertEquals(4.0, border.borderWidthRight);
        assertEquals(4.0, border.borderWidthBottom);
    }

    function testNestedTransformationsCompose() {
        // Parent (0, 0) 200x100 moved by (10, 0); child (20, 10) 50x20 doubled
        // around its corner: (20, 10) 100x40, then moved: (30, 10) 100x40
        final window = open((_, _) -> root().child(
            box(0.1, 0, 0, 200, 100).transformation(Transformation.translated(point(px(10), px(0))))
                .child(box(0.3, 20, 10, 50, 20).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                    .child(box(0.5, 5, 5, 10, 10)))));
        assertEquals('20,0 400x200', quad(window, 0.1));
        assertEquals('60,20 200x80', quad(window, 0.3));
        // The grandchild (25, 15) 10x10 in the layout: child scale (20 + 2 * 5, 10 + 2 * 5) 20x20, then + 10
        assertEquals('80,40 40x40', quad(window, 0.5));
    }

    function testContentMasksStayUpright() {
        // A clipping parent, doubled around its corner: its mask is doubled too
        final inner = open((_, _) -> root().child(
            box(0.1, 0, 0, 100, 100).overflowHidden().transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                .child(box(0.3, 50, 50, 100, 100))));
        final child = findQuad(inner, 0.3);
        assertEquals('200,200 400x400', '${child.boundsX},${child.boundsY} ${child.boundsWidth}x${child.boundsHeight}');
        assertEquals('0,0 400x400', mask(child));

        // A clipping container around a scaled element: the mask of the container is not scaled
        final outer = open((_, _) -> root().child(
            box(0.1, 0, 0, 150, 150).overflowHidden()
                .child(box(0.3, 0, 0, 100, 100).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                    .child(box(0.5, 10, 10, 20, 20)))));
        final scaled = findQuad(outer, 0.3);
        assertEquals('0,0 400x400', '${scaled.boundsX},${scaled.boundsY} ${scaled.boundsWidth}x${scaled.boundsHeight}');
        assertEquals('0,0 300x300', mask(scaled));
        assertEquals('0,0 300x300', mask(findQuad(outer, 0.5)));

        // Both: container (0, 0) 150x150, scaled clipping child (0, 0) 100x100 x 2:
        // the mask is the intersection, (0, 0) 150x150 (300 device pixels)
        final both = open((_, _) -> root().child(
            box(0.1, 0, 0, 150, 150).overflowHidden()
                .child(box(0.3, 0, 0, 100, 100).overflowHidden().transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                    .child(box(0.5, 10, 10, 20, 20)))));
        assertEquals('0,0 300x300', mask(findQuad(both, 0.5)));
        // and a scaled clipping child smaller than the container: (20, 20) 30x30 x 2 = (20, 20) 60x60
        final small = open((_, _) -> root().child(
            box(0.1, 0, 0, 150, 150).overflowHidden()
                .child(box(0.3, 20, 20, 30, 30).overflowHidden().transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                    .child(box(0.5, 0, 0, 100, 100)))));
        assertEquals('40,40 120x120', mask(findQuad(small, 0.5)));
    }

    function testShadowsFollow() {
        final plain = open((_, _) -> root().child(box(0.1, 50, 50, 40, 40).shadow([
            new glaze.BoxShadow(px(2), px(4), hsla(0, 0, 0, 0.5)).withBlurRadius(px(6))])));
        final scaled = open((_, _) -> root().child(box(0.1, 50, 50, 40, 40).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0)).shadow([
            new glaze.BoxShadow(px(2), px(4), hsla(0, 0, 0, 0.5)).withBlurRadius(px(6))])));
        final a = plain.renderedScene().shadows[0];
        final b = scaled.renderedScene().shadows[0];
        // (52, 54) 40x40 in device pixels, blur 12; scaled: the element at (50, 50) 80x80, offset (4, 8), blur 24
        assertEquals('104,108 80x80 12', '${a.boundsX},${a.boundsY} ${a.boundsWidth}x${a.boundsHeight} ${a.blurRadius}');
        assertEquals('108,116 160x160 24', '${b.boundsX},${b.boundsY} ${b.boundsWidth}x${b.boundsHeight} ${b.blurRadius}');
    }

    function testARotationOfAnElementIsIgnored() {
        final window = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50).transformation(Transformation.rotated(0.5))));
        assertEquals('20,40 200x100', quad(window, 0.1));
        // The scale and the translation given with it still apply
        final mixed = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50)
            .transformation(Transformation.rotated(0.5).withTranslation(point(px(5), px(0))))));
        assertEquals('30,40 200x100', quad(mixed, 0.1));
    }

    function testWithElementTransformForCustomElements() {
        var current:String = '';
        var inside:String = '';
        final window = open((_, _) -> root().child(canvas((_, _, _) -> 0, (bounds, _, window, _) -> {
            current = window.currentElementTransform().toString();
            window.withElementTransform(new TransformationMatrix(2, 0, 0, 3, 10, 20), w -> {
                inside = w.currentElementTransform().toString();
                w.paintQuad(fill(new Bounds(new Point(5, 5), size(10, 10)), hsla(0.1, 1, 0.5, 1)));
                // Nested: the inner one applies first
                w.withElementTransform(new TransformationMatrix(1, 0, 0, 1, 100, 0), w -> {
                    w.paintQuad(fill(new Bounds(new Point(5, 5), size(10, 10)), hsla(0.3, 1, 0.5, 1)));
                    return null;
                });
                // A matrix with a rotation is ignored
                w.withElementTransform(TransformationMatrix.unit().rotate(0.5), w -> {
                    w.paintQuad(fill(new Bounds(new Point(50, 5), size(10, 10)), hsla(0.5, 1, 0.5, 1)));
                    return null;
                });
                return null;
            });
            window.paintQuad(fill(new Bounds(new Point(5, 5), size(10, 10)), hsla(0.7, 1, 0.5, 1)));
        }).w(px(10)).h(px(10))));
        assertEquals(TransformationMatrix.unit().toString(), current);
        assertEquals(new TransformationMatrix(2, 0, 0, 3, 10, 20).toString(), inside);
        // (5, 5) 10x10: x 2 * 5 + 10 = 20, y 3 * 5 + 20 = 35, 20x30
        assertEquals('40,70 40x60', quad(window, 0.1));
        // moved by 100 first: x 2 * 105 + 10 = 220
        assertEquals('440,70 40x60', quad(window, 0.3));
        // rotation ignored, the outer transformation stays: x 2 * 50 + 10 = 110
        assertEquals('220,70 40x60', quad(window, 0.5));
        assertEquals('10,10 20x20', quad(window, 0.7));
    }

    function testAZeroScaleDrawsNothing() {
        var clicks = 0;
        final window = open((_, _) -> root().child(box(0.1, 10, 20, 100, 50).id('zero').onClick((_, _, _) -> clicks++)
            .transformation(Transformation.scaled(size(0, 0))).child(box(0.3, 0, 0, 10, 10))));
        assertEquals('none', quad(window, 0.1));
        assertEquals('none', quad(window, 0.3));
        click(window, 60, 45);
        assertEquals(0, clicks);
    }

/// Text, icons

    function testTextIsDrawnAtTheScaledSize() {
        function sprites(scale:Float):Array<MonochromeSprite> {
            final window = open((_, _) -> root().child(div().absolute().left(px(0)).top(px(0)).w(px(200)).h(px(20))
                .fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).textColor(hsla(0, 0, 0, 1))
                .transformation(Transformation.scaled(size(scale, scale)).withOrigin(0, 0)).child('Hello')));
            return window.renderedScene().monochromeSprites.copy();
        }
        final plain = sprites(1);
        final doubled = sprites(2);
        assertEquals(5, plain.length);
        assertEquals(5, doubled.length);
        for (i in 0...5) {
            // Rasterized at twice the size (not stretched): about twice as large, at twice the position
            assertTrue(Math.abs(doubled[i].boundsWidth - 2 * plain[i].boundsWidth) <= 2, 'width of glyph $i: ${doubled[i].boundsWidth} for ${plain[i].boundsWidth}');
            assertTrue(Math.abs(doubled[i].boundsHeight - 2 * plain[i].boundsHeight) <= 2, 'height of glyph $i');
            assertTrue(Math.abs(doubled[i].boundsX - 2 * plain[i].boundsX) <= 2, 'x of glyph $i: ${doubled[i].boundsX} for ${plain[i].boundsX}');
            assertTrue(Math.abs(doubled[i].boundsY - 2 * plain[i].boundsY) <= 2, 'y of glyph $i');
            assertEquals(doubled[i].boundsWidth, doubled[i].tileWidth, 'a tile at the scaled size');
            assertFalse(doubled[i].hasTransformation());
        }
        // A small scale (a press pulse of 1.02) keeps the glyphs of the text
        // at rest and stretches them: same tiles, bounds 1.02 times larger
        final pulse = sprites(1.02);
        for (i in 0...5) {
            // (the subpixel variant of a glyph may differ: a tile one pixel wider or narrower)
            assertTrue(Math.abs(plain[i].tileWidth - pulse[i].tileWidth) <= 1, 'tile of glyph $i');
            assertEquals(plain[i].tileHeight, pulse[i].tileHeight);
            assertFloatEquals(pulse[i].tileWidth * 1.02, pulse[i].boundsWidth, 1e-9);
            assertFloatEquals(pulse[i].tileHeight * 1.02, pulse[i].boundsHeight, 1e-9);
        }
        // A translation alone keeps the plain path: the same sprites, moved
        final moved = open((_, _) -> root().child(div().absolute().left(px(0)).top(px(0)).w(px(200)).h(px(20))
            .fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).textColor(hsla(0, 0, 0, 1))
            .transformation(Transformation.translated(point(px(3), px(4)))).child('Hello'))).renderedScene().monochromeSprites;
        for (i in 0...5) {
            assertEquals(plain[i].boundsX + 6, moved[i].boundsX);
            assertEquals(plain[i].boundsY + 8, moved[i].boundsY);
            assertEquals(plain[i].boundsWidth, moved[i].boundsWidth);
        }
    }

    function testGlyphRasterScaleSteps() {
        assertEquals(1.0, glaze.TextPainter.glyphRasterScale(1.02));
        assertEquals(1.0, glaze.TextPainter.glyphRasterScale(0.9));
        assertEquals(1.25, glaze.TextPainter.glyphRasterScale(1.3));
        assertEquals(0.75, glaze.TextPainter.glyphRasterScale(0.7));
        assertEquals(2.0, glaze.TextPainter.glyphRasterScale(2));
        assertEquals(0.25, glaze.TextPainter.glyphRasterScale(0.05));
    }

    function testTextPositionsInAScaledElement() {
        // The mouse position given to a listener inside is in the layout of the element
        var layout:TextLayout = null;
        final seen:Array<String> = [];
        final window = open((_, _) -> {
            final styled = new StyledText('Hello world');
            layout = styled.layout();
            return root().child(div().id('text').absolute().left(px(20)).top(px(10))
                .fontFamily('Inter').textSize(px(16)).lineHeight(px(20))
                .transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                .onMouseDown(Left, (event, window, _) -> {
                    final same = window.mousePosition().equals(event.position);
                    seen.push(switch layout.indexForPosition(event.position) {
                        case Ok(index): 'index $index $same';
                        case Err(index): 'outside $index $same';
                    });
                })
                .child(styled));
        });
        final line = layout.lineLayouts()[0].unwrappedLayout;
        // The element is drawn from (20, 10), twice as large: the character
        // of index 6 ("w") starts at 20 + 2 * x(6)
        final x6:Float = line.xForIndex(6);
        final x2:Float = line.xForIndex(2);
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, new Point(20 + 2 * x6 + 1, 10 + 20), Modifiers.none(), 1, false), cx));
        // and the one of index 2 at 20 + 2 * x(2)
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, new Point(20 + 2 * x2 + 1, 10 + 30), Modifiers.none(), 1, false), cx));
        assertEquals('index 6 true,index 2 true', seen.join(','));
        // Outside of a listener and of the drawing, the window position
        assertEquals(20 + 2 * x2 + 1, (window.mousePosition().x:Float));
    }

    function testIconsKeepTheirTileAndGetAMatrix() {
        final path = 'M2 2h20v20h-20z';
        final data = haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="$path"/></svg>');
        function sprite(build:(glaze.Div) -> glaze.Div):MonochromeSprite {
            final window = open((_, _) -> root().child(build(div().absolute().left(px(100)).top(px(100)))
                .child(svg().data(data).w(px(24)).h(px(24)).textColor(hsla(0, 0, 0, 1)))));
            final sprites = window.renderedScene().monochromeSprites;
            assertEquals(1, sprites.length);
            return sprites[0];
        }
        final plain = sprite(el -> el);
        assertFalse(plain.hasTransformation());
        // Doubled around the corner (100, 100) of its parent
        final scaled = sprite(el -> el.w(px(24)).h(px(24)).transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0)));
        assertEquals(plain.boundsX, scaled.boundsX);
        assertEquals(plain.tileWidth, scaled.tileWidth);
        assertTrue(scaled.hasTransformation());
        // x' = 100 + 2 (x - 100) in logical pixels: 2 x - 200 in device pixels
        assertEquals('2,0,0,2 -200,-200', '${scaled.transformM00},${scaled.transformM01},${scaled.transformM10},${scaled.transformM11} ${scaled.transformTx},${scaled.transformTy}');
    }

    /**
     * Fix of an original defect: a sprite with a transformation is ordered
     * and culled from the bounds it is drawn in.
     */
    function testATransformedSpriteIsCulledFromItsDrawnBounds() {
        function commit(x:Float, y:Float, m00:Float, tx:Float):Int {
            final scene = new Scene();
            final sprite = scene.nextMonochromeSprite();
            sprite.setBounds(x, y, 10, 10);
            sprite.setContentMask(15, 15, 100, 100);
            sprite.setColor(0, 0, 0, 1);
            sprite.setTile(0, 0, 0, 10, 10);
            sprite.setTransformation(m00, 0, 0, m00, tx, tx);
            scene.commitMonochromeSprite(sprite);
            return scene.monochromeSprites.length;
        }
        // (0, 0) 10x10 is outside the mask from (15, 15); three times larger it reaches (30, 30)
        assertEquals(1, commit(0, 0, 3, 0));
        // Without transformation it is clipped, as before
        assertEquals(0, commit(0, 0, 1, 0));
        // (20, 20) 10x10 is inside the mask; moved by 200 it is outside of it
        assertEquals(1, commit(20, 20, 1, 0));
        assertEquals(0, commit(20, 20, 1, 200));
    }

/// Mouse

    function testAScaledButtonIsClickedWhereItIsDrawn() {
        final positions:Array<String> = [];
        var hovered = false;
        final window = open((window, _) -> root().child(
            box(0.1, 100, 100, 40, 20).id('button')
                .transformation(Transformation.scaled(size(2, 2)))
                .hover(s -> s.opacity(0.5))
                .onClick((event, _, _) -> positions.push('${event.position().x},${event.position().y}'))));
        // Drawn around its center (120, 110): (80, 90) 80x40
        assertEquals('160,180 160x80', quad(window, 0.1));
        // Inside the drawing, outside of the layout bounds
        click(window, 85, 95);
        assertEquals(1, positions.length);
        // The position in the layout of the button: 120 + (85 - 120) / 2, 110 + (95 - 110) / 2
        assertEquals('102.5,102.5', positions[0]);
        // The hover style follows the drawing
        assertEquals(0.5, findQuad(window, 0.1).backgroundSolidA);
        // Outside of the drawing
        click(window, 170, 100);
        assertEquals(1, positions.length);
        assertEquals(1.0, findQuad(window, 0.1).backgroundSolidA);
        // Inside the layout bounds, still inside the drawing
        click(window, 110, 105);
        assertEquals(2, positions.length);
        assertEquals('115,107.5', positions[1]);
    }

    function testOcclusionFollowsTheDrawing() {
        var under = 0;
        // A blocking element (200, 0) 50x50 moved by -150: it covers (50, 0) 50x50
        final window = open((_, _) -> root()
            .child(box(0.1, 50, 0, 50, 50).id('under').onClick((_, _, _) -> under++))
            .child(box(0.3, 200, 0, 50, 50).occlude().transformation(Transformation.translated(point(px(-150), px(0))))));
        click(window, 60, 10);
        assertEquals(0, under, 'the moved element blocks the mouse where it is drawn');
        final plain = open((_, _) -> root()
            .child(box(0.1, 50, 0, 50, 50).id('under').onClick((_, _, _) -> under++))
            .child(box(0.3, 200, 0, 50, 50).occlude()));
        click(plain, 60, 10);
        assertEquals(1, under);
    }

    function testDragRegionsFollowTheDrawing() {
        // A drag bar (0, 0) 400x40 moved 10 px down with a button (100, 8) 60x24
        final window = open((_, _) -> root().child(
            div().id('bar').absolute().left(px(0)).top(px(0)).w(px(400)).h(px(40)).windowControlArea(Drag)
                .transformation(Transformation.translated(point(px(0), px(10))))
                .child(box(0.1, 100, 8, 60, 24).id('button').onClick((_, _, _) -> {}))));
        final flat = app.update(_ -> CeramicWindowOperations.hitRegions(window, new ceramic.Point()));
        assertEquals('0,10,400,40,1,100,18,60,24,0', flat.join(','));
    }

/// View cache

    function testAViewInsideATransformationFollowsIt() {
        var innerRenders = 0;
        var siblingRenders = 0;
        final offset = new TransformOffset();
        final inner:Entity<ScriptView> = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> {
            innerRenders++;
            return box(0.3, 10, 10, 20, 20);
        }));
        final sibling:Entity<ScriptView> = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) -> {
            siblingRenders++;
            return box(0.5, 300, 200, 20, 20);
        }));
        // The check of the view cache is on (the runner fails the test on a difference)
        final window = open((_, _) -> root()
            .child(div().absolute().left(px(0)).top(px(0)).w(px(100)).h(px(100))
                .transformation(Transformation.translated(point(px(offset.x), px(0))))
                .child(inner))
            .child(sibling)
            .child(div().child('${offset.other}')), true);
        assertEquals('20,20 40x40', quad(window, 0.3));
        assertEquals('600,400 40x40', quad(window, 0.5));

        // The transformation changes (an animation frame): the view inside is drawn with it
        for (step in 1...4) {
            offset.x = step * 5.0;
            frame();
            assertEquals('${20 + step * 10},20 40x40', quad(window, 0.3), 'step $step');
            assertEquals('600,400 40x40', quad(window, 0.5));
        }

        // Another change of the parent: the transformation is the same, the view inside is reused
        #if glaze_verify_cache
        Window.verifyCache = false;
        #end
        final before = innerRenders;
        final siblingBefore = siblingRenders;
        offset.other = 1;
        frame();
        assertEquals(before, innerRenders, 'reused with the same transformation');
        assertEquals('50,20 40x40', quad(window, 0.3));
        // and a change of the transformation draws it again, not the view outside of it
        offset.x = 40;
        frame();
        assertEquals(before + 1, innerRenders);
        assertEquals(siblingBefore, siblingRenders);
        assertEquals('100,20 40x40', quad(window, 0.3));
        assertEquals('600,400 40x40', quad(window, 0.5));
    }

    function testAViewRenderedInPlaceKeepsItsTransformation() {
        final toggle = new TransformOffset();
        var clicks = 0;
        final inner:Entity<ScriptView> = app.newEntity((_:Context<ScriptView>) -> new ScriptView((_, _) ->
            box(toggle.other == 0 ? 0.3 : 0.4, 10, 10, 20, 20).id('inner').onClick((_, _, _) -> clicks++)));
        final window = open((_, _) -> root()
            .child(div().absolute().left(px(0)).top(px(0)).w(px(100)).h(px(100))
                .transformation(Transformation.scaled(size(2, 2)).withOrigin(0, 0))
                .child(inner)), true);
        assertEquals('40,40 80x80', quad(window, 0.3));
        final framesInPlace = Window.inPlaceFramesDrawn;
        // Only the inner view changes: it renders alone, in the transformation it was drawn in
        // (the check compares the frame with a full one)
        toggle.other = 1;
        frame();
        assertEquals('none', quad(window, 0.3));
        assertEquals('40,40 80x80', quad(window, 0.4));
        assertTrue(Window.inPlaceFramesDrawn > framesInPlace, 'drawn in place');
        // and its hitbox is still where it is drawn: (20, 20) 40x40
        click(window, 55, 55);
        assertEquals(1, clicks);
        click(window, 15, 15);
        assertEquals(1, clicks);
    }

}

class TransformOffset extends Model {

    @observe public var x:Float = 0;

    @observe public var other:Int = 0;

    public function new() {
        super();
    }

}
