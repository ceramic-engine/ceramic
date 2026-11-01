// Ported from gpui-kit 0.8.1: crates/base/src/text/text_view.rs (the tests drawn with `TestApp`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Bounds;
import gpui.Entity;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.base.Base;
import gpui.base.TextSelectionLayer;
import gpui.base.text.TextView;
import gpui.base.text.TextViewState;
import gpui.base.text.TextViewStyle;
import gpui.base.theme.Theme;
import tests.kit.TextInlineTest.TextTestDraw;
import tests.kit.TextInlineTest.TextTestFonts;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * The `TextView` tests of Rust `text/text_view.rs` that draw with a
 * `TestApp` of their own (the wide-mono test text system of `inline.rs`).
 */
@:access(gpui.base.text)
class TextViewLayoutTest extends TestCase {

    final windows:Array<Window> = [];

    override function teardown() {
        for (window in windows) window.destroy();
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    static function initApp(app:App, mono:Bool):Void {
        app.update(cx -> {
            Base.init(cx);
            if (mono) Theme.globalMut(cx).tokens.typography.mono = TextTestFonts.MONO;
        });
    }

    function open(app:App, render:() -> IntoElement):Window {
        final window = TextTestDraw.openWindow(app, (_, _) -> render());
        windows.push(window);
        return window;
    }

    static function settle(app:App, window:Window):Void {
        app.update(_ -> window.draw());
        app.backgroundExecutor().runUntilParked();
        app.update(_ -> window.draw());
    }

    static function markdown(app:App, text:String):Entity<TextViewState> {
        return app.update(cx -> cx.newEntity(cx -> TextViewState.markdown(text, cx)));
    }

    static function quadsOf(window:Window, color:Hsla):Array<gpui.scene.Quad> {
        return [for (quad in window.renderedScene().quads) if (quad.backgroundTag == 0
            && Math.abs(quad.backgroundSolidH - color.h) < 1e-6 && Math.abs(quad.backgroundSolidS - color.s) < 1e-6
            && Math.abs(quad.backgroundSolidL - color.l) < 1e-6 && Math.abs(quad.backgroundSolidA - color.a) < 1e-6) quad];
    }

    static function quadBounds(quad:gpui.scene.Quad):Bounds {
        return new Bounds(new gpui.Point(quad.boundsX, quad.boundsY), new gpui.Size(quad.boundsWidth, quad.boundsHeight));
    }

    function testInlineCodeHeadingReservesPaintedWrappedLinesAndListBaseline() {
        final source = "The same words with inline code.\n\nThe same words with `inline code`.\n\n- The same words with inline code.\n- The same words with `inline code`.\n\n# Heading with inline code\n# Heading with `inline code`\n\nthis is a test";
        final app = TextTestDraw.wideMonoApp();
        initApp(app, true);
        for (c in [{name: "default-16px", width: 600., zoom: 1.}, {name: "narrow-16px", width: 320., zoom: 1.}, {name: "zoom-1.25", width: 600., zoom: 1.25}]) {
            final state = markdown(app, source);
            final window = open(app, () -> div()
                .w(px(c.width))
                // Preview zoom changes TextView's inherited text size, not the
                // window rem size.
                .textSize(rems(c.zoom))
                .child(new TextSelectionLayer())
                .child(TextView.create(state).selectable(true)));
            settle(app, window);
            app.update(cx -> state.update(cx, (state, cx) -> state.selectAll(cx)));
            app.update(_ -> window.draw());
            final current = state.read(app);
            final viewBounds = current.bounds();
            final textBounds = current.selectionAdapter.textBounds();
            final selected = current.selectedText();
            assertTrue(textBounds.length > 8, '${c.name}: expected all markdown fragments');
            assertEquals("The same words with inline code.\nThe same words with inline code.\nThe same words with inline code.\nThe same words with inline code.\nHeading with inline code\nHeading with inline code\nthis is a test",
                StringTools.trim(selected), '${c.name}: wrapped inline-code text was lost or duplicated');
            final following = textBounds[textBounds.length - 1];
            var paintedBottom = Math.NEGATIVE_INFINITY;
            for (b in textBounds) paintedBottom = Math.max(paintedBottom, b.bottom());
            for (i in 0...textBounds.length - 1) {
                assertTrue(textBounds[i].bottom() <= following.top(), '${c.name}: heading/list text painted through the following paragraph');
            }
            assertTrue(paintedBottom <= viewBounds.bottom(), '${c.name}: TextView height did not reserve its painted text');
        }
    }

    function testOrderedMarkdownListStartReachesLayoutMarker() {
        function shapedMarkers(html:Bool, source:String):String {
            final recorded = TextTestFonts.recordShapedLines(() -> {
                final app = TextTestDraw.wideMonoApp();
                initApp(app, false);
                final state = app.update(cx -> cx.newEntity(cx -> html ? TextViewState.html(source, cx) : TextViewState.markdown(source, cx)));
                final window = open(app, () -> div().w(px(400.)).child(TextView.create(state)));
                settle(app, window);
                return true;
            });
            final markers:Array<String> = [];
            for (line in recorded.shapedLines) {
                if (line.length <= 3 && StringTools.endsWith(line, '.') && (markers.length == 0 || markers[markers.length - 1] != line)) {
                    markers.push(line);
                }
            }
            return markers.join(',');
        }

        assertEquals("1.,2.", shapedMarkers(false, "1. one\n2. two"));
        assertEquals("1.,2.", shapedMarkers(true, "<ol><li>one</li><li>two</li></ol>"));
        assertEquals("3.,4.", shapedMarkers(false, "3. hello\n4. world"));
        assertEquals("1.,D.,E.", shapedMarkers(false, "1. outer\n\n   4. nested\n   5. again"));
        assertEquals("1.,0.", shapedMarkers(false, "1. outer\n\n   0. zero"));
    }

    /**
     * A line with inline code takes `InlineFlow` and a plain line takes the
     * ordinary text path; both must be the same height.
     */
    function testInlineCodeLineIsAsTallAsAPlainLine() {
        final app = TextTestDraw.wideMonoApp();
        initApp(app, true);
        for (scaleFactor in [1.6, 2.]) {
            for (zoom in [1., 1.25]) {
                final plain = markdown(app, "plain body words");
                final code = markdown(app, "plain `code` words");
                final window = open(app, () -> div()
                    .w(px(600.))
                    .textSize(rems(zoom))
                    .child(TextView.create(plain))
                    .child(TextView.create(code)));
                window.setScaleFactor(scaleFactor);
                settle(app, window);
                assertEquals(plain.read(app).bounds().size.height, code.read(app).bounds().size.height, 'scale $scaleFactor, zoom $zoom');
            }
        }
    }

    /**
     * The code-bearing list item takes `InlineFlow`; the plain item takes the
     * ordinary text path. Their first body glyphs must begin at the same row
     * position relative to their own TextView origins.
     */
    function testInlineCodeListBodyPaintOriginMatchesPlainListItem() {
        final app = TextTestDraw.wideMonoApp();
        initApp(app, true);
        for (c in [{name: "16px", zoom: 1.}, {name: "zoom-1.25", zoom: 1.25}, {name: "zoom-1.5", zoom: 1.5}]) {
            final plain = markdown(app, "- plain body words");
            final code = markdown(app, "- plain `code` words");
            final window = open(app, () -> div()
                .w(px(600.))
                .textSize(rems(c.zoom))
                .child(new TextSelectionLayer())
                .child(TextView.create(plain).selectable(true))
                .child(TextView.create(code).selectable(true)));
            settle(app, window);
            function firstBodyLineTop(view:Entity<TextViewState>):Float {
                final state = view.read(app);
                return state.selectionAdapter.textBounds()[0].top() - state.bounds().top();
            }
            assertEquals(firstBodyLineTop(plain), firstBodyLineTop(code), '${c.name}: code list body paint origin must match plain');
        }
    }

    function testInlineCodeFragmentDoesNotPaintPastItsReservedRow() {
        final textBackground = rgb(0x20f0b0).toHsla();
        final app = TextTestDraw.wideMonoApp();
        initApp(app, true);
        final state = markdown(app, "`main` starts the paragraph");
        final window = open(app, () -> div()
            .w(px(640.))
            .textSize(px(17.9))
            .textBg(textBackground)
            .child(TextView.create(state)));
        settle(app, window);

        final viewBounds = state.read(app).bounds().scale(window.scaleFactor());
        final painted = [for (quad in quadsOf(window, textBackground)) quadBounds(quad)];
        assertTrue(painted.length > 0, 'the inherited text background must make actual text paint observable');
        for (b in painted) {
            assertTrue(b.bottom() <= viewBounds.bottom(), 'an inline-code fragment wrapped a second time after InlineFlow reserved one row');
        }
    }

    function testTableRowBackgroundsFollowTheFrameCornerRadius() {
        final headBackground = rgb(0x11aa77).toHsla();
        final radius = 8.;
        for (scroll in [false, true]) {
            final mode = scroll ? "scroll" : "wrap";
            final app = TextTestDraw.testApp();
            initApp(app, false);
            final state = markdown(app, "| a | b |\n| --- | --- |\n| 1 | 2 |");
            final window = open(app, () -> {
                final table = new StyleRefinement();
                table.cornerRadiusTopLeft = gpui.AbsoluteLength.Pixels(radius);
                table.cornerRadiusTopRight = gpui.AbsoluteLength.Pixels(radius);
                table.cornerRadiusBottomLeft = gpui.AbsoluteLength.Pixels(radius);
                table.cornerRadiusBottomRight = gpui.AbsoluteLength.Pixels(radius);
                if (scroll) table.overflowX = Scroll;
                final style = TextViewStyle.defaultValue().withCodeBackground(headBackground).withTable(table);
                return div().w(px(400.)).child(TextView.create(state).withStyle(style));
            });
            settle(app, window);

            final quads = quadsOf(window, headBackground);
            assertTrue(quads.length > 0, '$mode: the header background quad is painted');
            final quad = quads[0];
            final scale = window.scaleFactor();
            // GPUI clips children with a rectangular mask, so the header fill
            // must carry the frame radius itself, inset by the 1px border.
            final expected = (radius - 1.) * scale;
            assertEquals(expected, quad.cornerRadiusTopLeft, '$mode: top left');
            assertEquals(expected, quad.cornerRadiusTopRight, '$mode: top right');
            assertEquals(0., quad.cornerRadiusBottomLeft, '$mode: bottom left');
            assertEquals(0., quad.cornerRadiusBottomRight, '$mode: bottom right');
        }
    }

    /**
     * A table wider than its frame shrinks its widest column. A narrower column
     * keeps its content width rather than shrinking by the same ratio.
     */
    function testTableKeepsNarrowColumnsOnOneLineWhileWideOnesWrap() {
        final cellBackground = rgb(0x11aa77).toHsla();
        final short = "Operating revenue (USD)";
        final source = '| $short | Note |\n| --- | --- |\n| $short | x |\n| 1 | ${[for (_ in 0...30) "word "].join("")} |';
        // Heights of the first column's cells, top to bottom.
        function firstColumn(width:Float, style:TextViewStyle):Array<Float> {
            final app = TextTestDraw.wideMonoApp();
            initApp(app, false);
            final cell = style.tableCell().clone();
            cell.background = new gpui.Background(Solid, Srgb, cellBackground);
            final styled = style.withTableCell(cell);
            final state = markdown(app, source);
            final window = open(app, () -> div().w(px(width)).child(TextView.create(state).withStyle(styled)));
            settle(app, window);
            final cells = [for (quad in quadsOf(window, cellBackground)) quadBounds(quad)];
            var left = Math.POSITIVE_INFINITY;
            for (b in cells) left = Math.min(left, b.origin.x);
            final column = cells.filter(b -> b.origin.x == left);
            column.sort((a, b) -> a.origin.y < b.origin.y ? -1 : (a.origin.y > b.origin.y ? 1 : 0));
            return [for (b in column) b.size.height];
        }
        function scroll():TextViewStyle {
            final table = new StyleRefinement();
            table.overflowX = Scroll;
            return TextViewStyle.defaultValue().withTable(table);
        }

        for (layout in [{name: "wrap", style: TextViewStyle.defaultValue()}, {name: "scroll", style: scroll()}]) {
            final fits = firstColumn(4000., layout.style);
            final narrow = firstColumn(700., layout.style);
            assertEquals(3, fits.length, '${layout.name}: three rows');
            assertEquals(fits[0], fits[2], '${layout.name}: the header fits on one line');
            assertEquals(fits.slice(0, 2).join(','), narrow.slice(0, 2).join(','), '${layout.name}: the short column wraps');
        }

        final singleLine = firstColumn(4000., TextViewStyle.defaultValue())[0];
        final padding = new StyleRefinement();
        padding.paddingLeft = gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Rems(1.));
        padding.paddingRight = gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Rems(1.));
        assertEquals(singleLine, firstColumn(4000., TextViewStyle.defaultValue().withTableCell(padding))[0], 'the cell padding refinement leaves the text its measured width');
        final bold = new StyleRefinement();
        bold.text = new gpui.TextStyleRefinement();
        bold.text.fontWeight = gpui.FontWeight.BOLD;
        assertEquals(singleLine, firstColumn(4000., TextViewStyle.defaultValue().withTable(bold))[0], 'the table text refinement is measured');
    }

}
