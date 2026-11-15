package tests;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Font;
import glaze.FontRun;
import glaze.IntoElement;
import glaze.LineLayoutCache;
import glaze.NoopTextSystem;
import glaze.StyleRefinementOps;
import glaze.StyledText;
import glaze.TestDispatcher;
import glaze.TextLayout;
import glaze.TextRun;
import glaze.TextStyle;
import glaze.TextStyleRefinement;
import glaze.TextSystem;
import glaze.Window;
import glaze.WindowTextSystem;
import testing.TestCase;
import tests.TextElementTest.TextTestView;

import glaze.Prelude.*;

/**
 * Port addition (no GPUI equivalent): letter spacing (`TextStyle.letterSpacing`,
 * `trackingWide()`..., `letterSpacing(len)`, `TextRun.letterSpacing`).
 *
 * The expected values are written by hand from the CSS rule (the spacing is
 * added after each character, the last one included): with GPUI's test text
 * system (`NoopTextSystem`) every character advances by 0.6 em, 9.6 px at
 * 16 px; with the real fonts, the unspaced layout (checked against GPUI by
 * `LineLayoutTest`) plus the spacings.
 */
class LetterSpacingTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    static function noop():WindowTextSystem {
        return new WindowTextSystem(new TextSystem(new NoopTextSystem()));
    }

    static function run(len:Int, spacing:Float = 0.0):TextRun {
        final run = new TextRun(len, Font.of('.ZedMono'));
        run.letterSpacing = spacing;
        return run;
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):Void {
        window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
            final view:Entity<TextTestView> = cx.newEntity((_:Context<TextTestView>) -> new TextTestView(render));
            return view;
        });
        window.draw();
    }

/// Shaping

    function testWidthAndGlyphPositions() {
        final text = noop();
        final plain = text.layoutLine('abcd', 16, [run(4)]);
        assertFloatEquals(38.4, plain.width, 1e-9);

        final spaced = text.layoutLine('abcd', 16, [run(4, 2)]);
        // 4 characters of 9.6 px, 2 px after each
        assertFloatEquals(46.4, spaced.width, 1e-9);
        final glyphs = spaced.runs[0].glyphs;
        assertEquals(4, glyphs.length);
        assertFloatEquals(0.0, glyphs[0].position.x, 1e-9);
        assertFloatEquals(11.6, glyphs[1].position.x, 1e-9);
        assertFloatEquals(23.2, glyphs[2].position.x, 1e-9);
        assertFloatEquals(34.8, glyphs[3].position.x, 1e-9);
        // Ascent, descent, length and indices are the unspaced ones
        assertEquals(plain.ascent, spaced.ascent);
        assertEquals(plain.descent, spaced.descent);
        assertEquals(4, spaced.len);
        assertEquals(3, glyphs[3].index);
    }

    function testNegativeSpacingTightens() {
        final spaced = noop().layoutLine('abcd', 16, [run(4, -1)]);
        assertFloatEquals(34.4, spaced.width, 1e-9);
        assertFloatEquals(8.6, spaced.runs[0].glyphs[1].position.x, 1e-9);
    }

    function testTheUnspacedLayoutIsNotChanged() {
        final text = noop();
        final before = text.layoutLine('abcd', 16, [run(4)]);
        final x1 = before.runs[0].glyphs[1].position.x;
        final spaced = text.layoutLine('abcd', 16, [run(4, 3)]);
        assertTrue(spaced != before, 'another layout (another cache key)');
        final after = text.layoutLine('abcd', 16, [run(4)]);
        assertTrue(after == before, 'the unspaced layout is still cached');
        assertEquals(x1, after.runs[0].glyphs[1].position.x);
        assertFloatEquals(38.4, after.width, 1e-9);
        // The same spacing again: the cached spaced layout; another one: another layout
        assertTrue(text.layoutLine('abcd', 16, [run(4, 3)]) == spaced);
        final wider = text.layoutLine('abcd', 16, [run(4, 4)]);
        assertTrue(wider != spaced);
        assertFloatEquals(54.4, wider.width, 1e-9);
    }

    function testSpacingPerRun() {
        // "ab" without spacing, "cd" with 5 px: a 0, b 9.6, c 19.2, d 19.2 + 9.6 + 5
        final layout = noop().layoutLine('abcd', 16, [run(2), run(2, 5)]);
        final xs = [for (r in layout.runs) for (g in r.glyphs) g.position.x];
        assertEquals(4, xs.length);
        assertFloatEquals(0.0, xs[0], 1e-9);
        assertFloatEquals(9.6, xs[1], 1e-9);
        assertFloatEquals(19.2, xs[2], 1e-9);
        assertFloatEquals(33.8, xs[3], 1e-9);
        assertFloatEquals(48.4, layout.width, 1e-9);

        // Runs of one font and decoration with different spacings are not merged
        final other = noop().layoutLine('abcd', 16, [run(2, 5), run(2)]);
        final ox = [for (r in other.runs) for (g in r.glyphs) g.position.x];
        assertFloatEquals(14.6, ox[1], 1e-9);
        assertFloatEquals(29.2, ox[2], 1e-9);
        assertFloatEquals(38.8, ox[3], 1e-9);
        assertFloatEquals(48.4, other.width, 1e-9);
    }

    function testGlyphsOfOneCharacterMoveTogether() {
        // Two glyphs with the same byte index (a base and its mark), then another character
        final shaped = new glaze.LineLayout(16, 20, 12, 4, [new glaze.ShapedRun(0, [
            new glaze.ShapedGlyph(1, point(0, 0), 0),
            new glaze.ShapedGlyph(2, point(3, 0), 0),
            new glaze.ShapedGlyph(1, point(10, 0), 3)
        ])], 4);
        final spaced = LineLayoutCache.withLetterSpacing(shaped, [new FontRun(4, 0, 2)]);
        final glyphs = spaced.runs[0].glyphs;
        assertEquals(0.0, glyphs[0].position.x);
        assertEquals(3.0, glyphs[1].position.x);
        assertEquals(12.0, glyphs[2].position.x);
        assertEquals(24.0, spaced.width);
        // The source is untouched
        assertEquals(10.0, shaped.runs[0].glyphs[2].position.x);
        assertEquals(20.0, shaped.width);
    }

    function testIndexMapping() {
        final layout = noop().layoutLine('abcd', 16, [run(4, 2)]);
        // The caret after a character sits after its spacing
        assertFloatEquals(0.0, layout.xForIndex(0), 1e-9);
        assertFloatEquals(11.6, layout.xForIndex(1), 1e-9);
        assertFloatEquals(34.8, layout.xForIndex(3), 1e-9);
        assertFloatEquals(46.4, layout.xForIndex(4), 1e-9);
        // A position in the space after a character belongs to it
        assertEquals(0, layout.indexForX(5));
        assertEquals(0, layout.indexForX(10.5));
        assertEquals(1, layout.indexForX(11.6));
        assertEquals(3, layout.indexForX(46.0));
        assertNull(layout.indexForX(46.4));
        // Closest boundary: the middle of "b" (11.6 to 23.2) is 17.4
        assertEquals(1, layout.closestIndexForX(17.0));
        assertEquals(2, layout.closestIndexForX(18.0));
        assertEquals(4, layout.closestIndexForX(100));
    }

    function testWrappingCountsTheSpacing() {
        final text = noop();
        // 14 characters of 9.6 px = 134.4 px: one line in 140 px
        final plain = text.shapeText('aaaa bbbb cccc', 16, [run(14)], 140);
        assertEquals(0, plain[0].layout.wrapBoundaries.length);
        // With 2 px after each: 162.4 px, "aaaa bbbb " is 116 px and fits,
        // "cccc" goes to a second line
        final spaced = text.shapeText('aaaa bbbb cccc', 16, [run(14, 2)], 140);
        assertEquals(1, spaced[0].layout.wrapBoundaries.length);
        final boundary = spaced[0].layout.wrapBoundaries[0];
        assertEquals(10, spaced[0].layout.unwrappedLayout.runs[boundary.runIx].glyphs[boundary.glyphIx].index);
        assertFloatEquals(162.4, spaced[0].layout.unwrappedLayout.width, 1e-9);
    }

/// Line wrapper (truncation and the wrapping of the kit's inline text)

    function testLineWrapperWidths() {
        final system = new TextSystem(new NoopTextSystem());
        final plain = system.lineWrapper(Font.of('.ZedMono'), 16);
        final spaced = system.lineWrapper(Font.of('.ZedMono'), 16, 2);
        assertTrue(plain != spaced);
        assertTrue(spaced == system.lineWrapper(Font.of('.ZedMono'), 16, 2), 'one wrapper per font, size and spacing');
        assertTrue(plain == system.lineWrapper(Font.of('.ZedMono'), 16));
        assertEquals(0.0, plain.letterSpacing);
        assertEquals(2.0, spaced.letterSpacing);
        assertFloatEquals(9.6, plain.widthForChar('a'.code), 1e-9);
        assertFloatEquals(11.6, spaced.widthForChar('a'.code), 1e-9);
        assertFloatEquals(11.6, spaced.widthForChar(0xE9), 1e-9);
        // The plain wrapper is not affected by the spaced one
        assertFloatEquals(9.6, plain.widthForChar('a'.code), 1e-9);

        // Wrapping: characters of 12 px (9.6 + 2.4) in 75 px wrap where
        // characters of 9.6 px wrap in 60 px (6.25 characters per line both
        // ways), by the wrapper's own rule (Rust `test_wrap_line` covers it)
        final wide = system.lineWrapper(Font.of('.ZedMono'), 16, 2.4);
        final line = 'aa bbb cccc ddddd eeee';
        final expected = [for (b in plain.wrapLine([Text(line)], 60)) '${b.ix}:${b.nextIndent}'].join(' ');
        assertEquals(expected, [for (b in wide.wrapLine([Text(line)], 75)) '${b.ix}:${b.nextIndent}'].join(' '));
        assertEquals('7:0 12:0 18:0', [for (b in plain.wrapLine([Text(line)], 75)) '${b.ix}:${b.nextIndent}'].join(' '));
        assertTrue(expected != '7:0 12:0 18:0', expected);
    }

    function testTruncationCountsTheSpacing() {
        final system = new TextSystem(new NoopTextSystem());
        final runs = [run(10)];
        // 10 characters: 96 px fit in 100 px, 116 px with 2 px after each do not
        final plain = system.lineWrapper(Font.of('.ZedMono'), 16).truncateLine('aaaaaaaaaa', 100, '…', runs, End);
        assertEquals('aaaaaaaaaa', plain.text);
        final spaced = system.lineWrapper(Font.of('.ZedMono'), 16, 2).truncateLine('aaaaaaaaaa', 100, '…', [run(10, 2)], End);
        // 7 characters and the ellipsis: 8 x 11.6 = 92.8 px (8 and the ellipsis would be 104.4 px)
        assertEquals('aaaaaaa…', spaced.text);
        assertEquals(2.0, spaced.runs[0].letterSpacing);
    }

/// Styles

    function testStyleFieldsAndRefinement() {
        final style = new TextStyle();
        assertNull(style.letterSpacing);
        assertEquals(0.0, style.letterSpacingInPixels(16));
        assertEquals(0.0, style.toRun(3).letterSpacing);

        final refinement = new TextStyleRefinement();
        assertFalse(refinement.isSome());
        refinement.letterSpacing = relative(0.05);
        assertTrue(refinement.isSome());
        style.refine(refinement);
        // The default font size is 1 rem
        assertFloatEquals(0.8, style.letterSpacingInPixels(16), 1e-9);
        assertFloatEquals(1.0, style.letterSpacingInPixels(20), 1e-9);
        assertFloatEquals(0.8, style.toRun(3).letterSpacing, 1e-9);
        assertFloatEquals(1.0, style.toRun(3, 20).letterSpacing, 1e-9);

        style.fontSize = Pixels(10);
        assertFloatEquals(0.5, style.letterSpacingInPixels(16), 1e-9);
        style.letterSpacing = Absolute(Pixels(3));
        assertEquals(3.0, style.letterSpacingInPixels(16));
        style.letterSpacing = Absolute(Rems(0.25));
        assertEquals(4.0, style.letterSpacingInPixels(16));

        // Clone and equality
        final copy = style.clone();
        assertTrue(copy.equals(style));
        copy.letterSpacing = Absolute(Pixels(1));
        assertFalse(copy.equals(style));
        copy.letterSpacing = null;
        assertFalse(copy.equals(style));

        // Refinements: equality, clone, superset, subtract
        final a = new TextStyleRefinement();
        a.letterSpacing = relative(0.05);
        final b = a.clone();
        assertTrue(a.equals(b));
        b.letterSpacing = relative(0.1);
        assertFalse(a.equals(b));
        assertFalse(a.equals(new TextStyleRefinement()));
        assertTrue(StyleRefinementOps.textIsSupersetOf(a, new TextStyleRefinement()));
        assertFalse(StyleRefinementOps.textIsSupersetOf(new TextStyleRefinement(), a));
        assertFalse(StyleRefinementOps.textIsSupersetOf(a, b));
        assertNull(StyleRefinementOps.textSubtract(a, a.clone()).letterSpacing);
        assertTrue(StyleRefinementOps.textSubtract(a, b).letterSpacing != null);
        // A later refinement without spacing keeps the inherited one
        final base = new TextStyle();
        base.refine(a);
        base.refine(new TextStyleRefinement());
        assertTrue(base.letterSpacing != null);

        // Runs
        final r = run(3, 2);
        assertEquals(2.0, r.clone().letterSpacing);
        assertEquals(2.0, r.withLen(1).letterSpacing);
        assertEquals(4.0, r.withLetterSpacing(4).letterSpacing);
        assertFalse(r.equals(run(3)));
        assertTrue(r.equals(run(3, 2)));
    }

    function testTrackingMethods() {
        function spacingOf(el:glaze.Div):Float {
            final style = new TextStyle();
            style.fontSize = Pixels(20);
            style.refine(el.style().textStyle());
            return style.letterSpacingInPixels(16);
        }
        // Tailwind: -0.05, -0.025, 0, 0.025, 0.05 and 0.1 em
        assertFloatEquals(-1.0, spacingOf(div().trackingTighter()), 1e-9);
        assertFloatEquals(-0.5, spacingOf(div().trackingTight()), 1e-9);
        assertFloatEquals(0.0, spacingOf(div().trackingNormal()), 1e-9);
        assertFloatEquals(0.5, spacingOf(div().trackingWide()), 1e-9);
        assertFloatEquals(1.0, spacingOf(div().trackingWider()), 1e-9);
        assertFloatEquals(2.0, spacingOf(div().trackingWidest()), 1e-9);
        assertFloatEquals(3.0, spacingOf(div().letterSpacing(px(3))), 1e-9);
        assertFloatEquals(8.0, spacingOf(div().letterSpacing(rems(0.5))), 1e-9);
        assertFloatEquals(4.0, spacingOf(div().letterSpacing(relative(0.2))), 1e-9);
        assertNull(div().style().textStyle().letterSpacing);
    }

/// Text elements

    function measure(build:(glaze.Div) -> glaze.Div, text:String):TextLayout {
        if (window != null) {
            window.destroy();
            window = null;
        }
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText(text);
            layout = styled.layout();
            return div().flex().child(build(div().fontFamily('Inter').textSize(px(16)).lineHeight(px(20))).child(styled));
        });
        return layout;
    }

    function testTextElementWidthAndHitTesting() {
        final plain = measure(el -> el, 'HELLO');
        final plainLine = plain.lineLayouts()[0].unwrappedLayout;
        // 0.05 em at 16 px: 0.8 px after each of the 5 characters
        final spaced = measure(el -> el.trackingWider(), 'HELLO');
        final spacedLine = spaced.lineLayouts()[0].unwrappedLayout;
        assertFloatEquals(plainLine.width + 4.0, spacedLine.width, 1e-9);
        assertEquals(Math.fceil(plainLine.width + 4.0), spaced.bounds().size.width);
        for (i in 0...6) {
            assertFloatEquals(plainLine.xForIndex(i) + 0.8 * i, spacedLine.xForIndex(i), 1e-9, 'x of index $i');
        }
        // Positions map back to the same indices
        final origin = spaced.bounds().origin;
        for (i in 0...5) {
            final x = origin.x + spacedLine.xForIndex(i) + 0.5;
            assertTrue(spaced.indexForPosition(point(x, origin.y + 10)).match(Ok(_ == i => true)), 'index at $x');
        }
        // Pixels and rems
        assertFloatEquals(plainLine.width + 10.0, measure(el -> el.letterSpacing(px(2)), 'HELLO').lineLayouts()[0].unwrappedLayout.width, 1e-9);
        assertFloatEquals(plainLine.width + 20.0, measure(el -> el.letterSpacing(rems(0.25)), 'HELLO').lineLayouts()[0].unwrappedLayout.width, 1e-9);
        // Inherited from an ancestor, reset by trackingNormal()
        var inner:TextLayout = null;
        window.destroy();
        window = null;
        open((window, cx) -> {
            final styled = new StyledText('HELLO');
            inner = styled.layout();
            return div().flex().fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).trackingWidest().child(div().child(div().child(styled)));
        });
        assertFloatEquals(plainLine.width + 8.0, inner.lineLayouts()[0].unwrappedLayout.width, 1e-9);
        assertFloatEquals(plainLine.width, measure(el -> el.trackingNormal(), 'HELLO').lineLayouts()[0].unwrappedLayout.width, 1e-9);
    }

    function testTextElementWrapsAndTruncatesWithSpacing() {
        final text = 'The quick brown fox jumps over the lazy dog.';
        // The width of the unspaced text, then a box a little wider: one line
        final width = measure(el -> el, text).lineLayouts()[0].unwrappedLayout.width;
        final box = Math.fceil(width) + 4;
        final plain = measure(el -> el.w(px(box)), text);
        assertEquals(1, plain.wrappedText().split('\n').length);
        // 44 characters with 1 px after each need 44 px more: two lines
        final spaced = measure(el -> el.w(px(box)).letterSpacing(px(1)), text);
        assertEquals(2, spaced.wrappedText().split('\n').length);
        assertEquals(40.0, spaced.bounds().size.height);
        // Truncated instead of wrapped
        final truncated = measure(el -> el.w(px(box)).truncate().letterSpacing(px(1)), text);
        assertTrue(StringTools.endsWith(truncated.text(), '…'), truncated.text());
        assertEquals(20.0, truncated.bounds().size.height);
        assertTrue(truncated.lineLayouts()[0].unwrappedLayout.width <= box);
        // Without spacing the same box does not truncate
        assertEquals(text, measure(el -> el.w(px(box)).truncate(), text).text());
    }

    function testHighlightedRunsKeepTheSpacing() {
        final plain = measure(el -> el, 'Hello world').lineLayouts()[0].unwrappedLayout.width;
        if (window != null) {
            window.destroy();
            window = null;
        }
        var layout:TextLayout = null;
        open((window, cx) -> {
            final styled = new StyledText('Hello world').withHighlights([
                new glaze.HighlightStyle.TextHighlight(0, 5, glaze.HighlightStyle.ofColor(red()))
            ]);
            layout = styled.layout();
            return div().flex().child(div().fontFamily('Inter').textSize(px(16)).lineHeight(px(20)).letterSpacing(px(2)).child(styled));
        });
        assertFloatEquals(plain + 22.0, layout.lineLayouts()[0].unwrappedLayout.width, 1e-6);
    }

}
