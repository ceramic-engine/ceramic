package tests;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Path;
import gpui.PathBuilder;
import gpui.SvgRenderer;
import gpui.TestDispatcher;
import gpui.Window;
import haxe.io.Bytes;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests of `svg()` / `SvgRenderer` (svg_renderer.rs, svg.rs) and of paths
 * (`Path`, `PathBuilder`, `Window.paintPath()`).
 */
class SvgPathTest extends TestCase {

    static final HEART = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5" /></svg>';

    var app:App;

    var window:Window;

    override function setup() {
        app = new App(new TestDispatcher());
        app.setTextSystem(TextFixtures.textSystem());
        final assets = new gpui.CeramicAssetSource();
        assets.add('icons/heart.svg', Bytes.ofString(HEART));
        app.setAssetSource(assets);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):Void {
        window = Window.open(app, {width: 200, height: 200, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
            return cx.newEntity((_:Context<TextElementTest.TextTestView>) -> new TextElementTest.TextTestView(render));
        });
    }

    /** Rust `renders_parsed_svg_at_requested_size` */
    function testRendersParsedSvgAtRequestedSize() {
        final renderer = new SvgRenderer(app.assetSource());
        final svg = renderer.parseSvg(Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="24pt" height="12pt"></svg>'));
        final image = renderer.renderParsed(svg, ExactSize(24, 12));
        assertEquals(24.0, image.size(0).width);
        assertEquals(12.0, image.size(0).height);
    }

    /** Rust `preserves_aspect_ratio_for_width_constrained_size` */
    function testPreservesAspectRatioForWidthConstrainedSize() {
        final renderer = new SvgRenderer(app.assetSource());
        final svg = renderer.parseSvg(Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="24pt" height="12pt"></svg>'));
        final image = renderer.renderParsed(svg, Size(24, 24));
        assertEquals(24.0, image.size(0).width);
        assertEquals(12.0, image.size(0).height);
    }

    function testAlphaMaskIsRenderedAtTwiceTheSize() {
        final source = app.svgRenderer().renderAlphaMask(new gpui.RenderSvgParams('icons/heart.svg', 48, 48), null);
        assertEquals(48, source.width);
        assertEquals(48, source.height);
        var covered = 0;
        for (i in 0...source.bytes.length)
            if (source.bytes.get(i) > 0) covered++;
        assertTrue(covered > 100 && covered < 48 * 48 / 2, 'covered $covered');
        // Missing asset
        assertEquals(null, app.svgRenderer().renderAlphaMask(new gpui.RenderSvgParams('icons/missing.svg', 48, 48), null));
    }

    function testSvgTextUsesTheFontsOfTheTextSystem() {
        final renderer = app.svgRenderer();
        final source = renderer.renderAlphaMask(new gpui.RenderSvgParams('text', 100, 30), Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="30"><text x="2" y="20" font-family="Inter" font-size="16">Hello</text></svg>'));
        var covered = 0;
        for (i in 0...source.bytes.length)
            if (source.bytes.get(i) > 0) covered++;
        assertTrue(covered > 50, 'covered $covered');
    }

    function testSvgIsTintedByItsOwnTextColor() {
        open((window, cx) -> div().textColor(blue()).child(svg().path('icons/heart.svg').size(px(24)).textColor(red()))
            .child(svg().path('icons/heart.svg').size(px(24))));
        window.draw();
        final sprites = window.renderedScene().monochromeSprites;
        // The second svg has no text color of its own: not painted (like GPUI)
        assertEquals(1, sprites.length);
        final sprite = sprites[0];
        assertEquals(0.0, sprite.colorH);
        assertEquals(1.0, sprite.colorS);
        assertEquals(0.0, sprite.boundsX);
        assertEquals(48.0, sprite.boundsWidth);
        assertEquals(48.0, sprite.boundsHeight);
        assertFalse(sprite.hasTransformation());
    }

    function testSvgTransformationRotatesAroundItsCenter() {
        open((window, cx) -> div().p(px(10)).child(svg().path('icons/heart.svg').size(px(20)).textColor(red())
            .withTransformation(gpui.Svg.Transformation.rotated(Math.PI / 2))));
        window.draw();
        final sprite = window.renderedScene().monochromeSprites[0];
        assertTrue(sprite.hasTransformation());
        // A quarter turn around the center (40, 40) in scaled pixels
        assertTrue(Math.abs(sprite.transformM00) < 1e-6);
        assertTrue(Math.abs(sprite.transformM01 + 1) < 1e-6);
        assertTrue(Math.abs(sprite.transformM10 - 1) < 1e-6);
        assertTrue(Math.abs(sprite.transformTx - 80) < 1e-6);
        assertTrue(Math.abs(sprite.transformTy - 0) < 1e-6);
    }

    function testPathBuilderFillBounds() {
        final builder = PathBuilder.fill();
        builder.moveTo(point(10, 20));
        builder.lineTo(point(50, 20));
        builder.lineTo(point(30, 60));
        builder.close();
        final path = builder.build();
        assertEquals(10.0, path.bounds.origin.x);
        assertEquals(20.0, path.bounds.origin.y);
        assertEquals(40.0, path.bounds.size.width);
        assertEquals(40.0, path.bounds.size.height);
        assertTrue(path.fillPolygons != null);
        assertEquals(null, path.stroke);
    }

    function testPathBuilderStrokeBoundsIncludeTheLineWidth() {
        final builder = PathBuilder.stroke(px(4));
        builder.moveTo(point(10, 20));
        builder.lineTo(point(50, 20));
        final path = builder.build();
        // Butt caps: no extension along the line, half the width across
        assertEquals(10.0, path.bounds.origin.x);
        assertEquals(18.0, path.bounds.origin.y);
        assertEquals(40.0, path.bounds.size.width);
        assertEquals(4.0, path.bounds.size.height);
    }

    function testPathBuilderTransform() {
        final builder = PathBuilder.fill();
        builder.addPolygon([point(0, 0), point(10, 0), point(10, 10)], true);
        builder.scale(2);
        builder.translate(point(5, 5));
        final path = builder.build();
        assertEquals(5.0, path.bounds.origin.x);
        assertEquals(25.0, path.bounds.origin.x + path.bounds.size.width);
    }

    function testDashArrayIsRepeatedWhenOdd() {
        final builder = PathBuilder.stroke(px(2)).dashArray([px(5), px(3), px(2)]);
        builder.moveTo(point(0, 0));
        builder.lineTo(point(100, 0));
        final path = builder.build();
        assertTrue(path.stroke != null);
        assertTrue(path.vertices.length > 0);
        assertEquals(0.0, path.bounds.origin.x);
    }

    function testPaintPathRasterizesCoverage() {
        open((window, cx) -> canvas((_, _, _) -> null, (bounds, _, window, cx) -> {
            final builder = PathBuilder.fill();
            builder.addPolygon([point(10, 10), point(60, 10), point(60, 40), point(10, 40)], true);
            window.paintPath(builder.build(), red());
            final triangles = new Path(point(100, 10));
            triangles.lineTo(point(140, 10));
            triangles.lineTo(point(120, 50));
            window.paintPath(triangles, blue());
        }).sizeFull());
        window.draw();
        final paths = window.renderedScene().paths;
        assertEquals(2, paths.length);
        final rect = paths[0];
        assertEquals(20.0, rect.boundsX);
        assertEquals(20.0, rect.boundsY);
        assertEquals(100.0, rect.boundsWidth);
        assertEquals(60.0, rect.boundsHeight);
        // Tile: device rectangle plus one pixel of margin
        assertEquals(102.0, rect.tileWidth);
        assertEquals(62.0, rect.tileHeight);
        assertEquals(0.0, rect.colorH);
        assertEquals(3, paths[1].vertexCount);
        assertEquals(200.0, paths[1].boundsX);
    }

}
