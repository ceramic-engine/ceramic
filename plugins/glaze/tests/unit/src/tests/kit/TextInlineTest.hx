// Ported from gpui-kit 0.8.1: crates/base/src/text/inline.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.Canvas;
import gpui.Context;
import gpui.FontId;
import gpui.FontMetrics;
import gpui.FontRun;
import gpui.FontWeight;
import gpui.GlyphId;
import gpui.HighlightStyle;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.LineLayout;
import gpui.Model;
import gpui.PlatformTextSystem;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.RenderGlyphParams;
import gpui.ShapedGlyph;
import gpui.ShapedRun;
import gpui.Size;
import gpui.SizeOf;
import gpui.StrikethroughStyle;
import gpui.StyleBuilder;
import gpui.StyledText;
import gpui.TestDispatcher;
import gpui.TextAlign;
import gpui.TextLayout;
import gpui.TextRenderingMode;
import gpui.TextStyle;
import gpui.TextSystem;
import gpui.UnderlineStyle;
import gpui.Window;
import gpui.base.TextSelection;
import gpui.base.text.Inline;
import gpui.base.text.Inline.GlyphBox;
import gpui.base.text.Inline.PaintedSelectionLayout;
import gpui.base.text.InlineHighlight;
import gpui.base.text.RangedFade;
import gpui.base.text.RangedHighlight;
import gpui.util.Utf8;
import haxe.io.Bytes;
import testing.InteractionScript;
import testing.TestCase;

using gpui.AbsoluteLengthTools;

/**
 * The tests of inline.rs: `fade_highlights_tests`, `line_bounds_tests`,
 * `range_highlight_tests`, `tests` and `retained_layout_tests` (with the
 * `test_draw` and `test_fonts` helpers below, shared with the inline flow
 * and inline object tests).
 *
 * Not ported from `retained_layout_tests`:
 * `a_sweep_on_another_thread_leaves_this_threads_dead_layouts_to_it` and
 * `a_background_drop_releases_layouts_without_another_hand_over` check the
 * thread-local table, its per-thread sweep and the drop notifications of
 * `InlineState`, none of which exist in the single threaded port (the
 * retained layout is a slot of its `InlineState`, released with it).
 */
@:access(gpui.base.text.Inline)
@:access(gpui.base.text.InlineHighlight)
class TextInlineTest extends TestCase {

    static function bodyStyle(fontSize:Float):TextStyle {
        final style = new TextStyle();
        style.fontFamily = TextTestFonts.BODY;
        style.fontSize = gpui.AbsoluteLength.Pixels(fontSize);
        return style;
    }

    static function highlight(?style:HighlightStyle, ?fontFamily:String, ?fontSizeScale:Float, ?codeStyle:gpui.StyleRefinement):InlineHighlight {
        return new InlineHighlight(style, fontFamily, fontSizeScale, codeStyle);
    }

    static function ranges(items:Array<RangedHighlight>):String {
        return [for (item in items) item.range.start + '..' + item.range.end].join(', ');
    }

    /** Lays `text` out as a root element at `wrapWidth`, at `origin`; returns its layout. */
    static function layOut(text:String, style:TextStyle, wrapWidth:Float, origin:Point, window:Window, cx:App):TextLayout {
        final runs = InlineHighlight.textRuns(Utf8.byteLength(text), style, []);
        final styled = new StyledText(text).withRuns(runs);
        final layout = styled.layout();
        final element = styled.intoAnyElement();
        element.layoutAsRoot(new SizeOf<AvailableSpace>(Definite(wrapWidth), MinContent), window, cx);
        element.prepaintAt(origin, window, cx);
        return layout;
    }

/// fade_highlights_tests

    function testFadesTextAndBackgroundOnlyInsideTheRange() {
        final code = InlineHighlight.fromStyle(new HighlightStyle(null, null, null, gpui.Prelude.red()));
        final combined = InlineHighlight.fadeHighlights([new RangedHighlight(new Range(0, 4), code)], [new RangedFade(new Range(2, 6), 0.5)]);

        assertEquals('0..2, 2..4, 4..6', ranges(combined));

        final untouched = combined[0].highlight;
        assertEquals(null, untouched.style.fadeOut);
        assertEquals(1.0, untouched.style.backgroundColor.a);

        final fadedCode = combined[1].highlight;
        assertEquals(0.5, fadedCode.style.fadeOut);
        assertEquals(0.5, fadedCode.style.backgroundColor.a);

        final fadedText = combined[2].highlight;
        assertEquals(0.5, fadedText.style.fadeOut);
        assertTrue(fadedText.style.backgroundColor == null);
    }

    function testFadesExplicitDecorationColorsWithTheText() {
        final link = InlineHighlight.fromStyle(new HighlightStyle(null, null, null, null, new UnderlineStyle(0, gpui.Prelude.blue()),
            new StrikethroughStyle(0, gpui.Prelude.red())));
        final combined = InlineHighlight.fadeHighlights([new RangedHighlight(new Range(0, 4), link)], [new RangedFade(new Range(0, 4), 0.75)]);

        final faded = combined[0].highlight;
        assertEquals(0.25, faded.style.underline.color.a);
        assertEquals(0.25, faded.style.strikethrough.color.a);
    }

    function testFadesInlineCodeStyleBackgroundAndBorder() {
        final code = highlight(new HighlightStyle(null, null, null, gpui.Prelude.red()), null, null,
            StyleBuilder.build(s -> s.bg(gpui.Prelude.red()).borderColor(gpui.Prelude.blue())));
        final combined = InlineHighlight.fadeHighlights([new RangedHighlight(new Range(0, 4), code)], [new RangedFade(new Range(0, 4), 0.75)]);

        final faded = combined[0].highlight;
        assertEquals(0.25, faded.style.backgroundColor.a);
        assertEquals(0.25, faded.codeStyle.background.asSolid().a);
        assertEquals(0.25, faded.codeStyle.borderColor.a);
    }

    function testNoFadesLeaveHighlightsUntouched() {
        final bold = InlineHighlight.fromStyle(new HighlightStyle(null, FontWeight.BOLD));
        final highlights = [new RangedHighlight(new Range(1, 3), bold)];
        final result = InlineHighlight.fadeHighlights(highlights, []);
        assertEquals(1, result.length);
        assertTrue(result[0].range.equals(highlights[0].range) && result[0].highlight.equals(highlights[0].highlight));
    }

/// line_bounds_tests

    /**
     * The character walk this replaced, kept as the oracle: one box per
     * character from `positionForIndex`, unioned per row.
     */
    static function byCharacter(text:String, textLayout:TextLayout, lineHeight:Float, maskBounds:Bounds):Array<Bounds> {
        final lineBounds:Array<Bounds> = [];
        var currentLineY:Null<Float> = null;
        var currentBounds:Null<Bounds> = null;
        final decoded = new gpui.util.Utf8.Utf8Text(text);
        for (k in 0...decoded.count) {
            final offset = decoded.byteOffsets[k];
            final nextOffset = offset + Utf8.codePointLength(decoded.codePoints[k]);
            final pos = textLayout.positionForIndex(offset);
            if (pos == null) {
                continue;
            }
            var charWidth = TextTestFonts.f32(lineHeight / 2);
            final nextPos = textLayout.positionForIndex(nextOffset);
            if (nextPos != null && nextPos.y == pos.y) {
                charWidth = TextTestFonts.f32(nextPos.x - pos.x);
            }
            final bounds = Bounds.fromCorners(pos, new Point(TextTestFonts.f32(pos.x + charWidth), TextTestFonts.f32(pos.y + lineHeight))).intersect(maskBounds);
            if (bounds.size.width > 0 && bounds.size.height > 0) {
                if (currentLineY == pos.y) {
                    if (currentBounds != null) {
                        currentBounds = currentBounds.union(bounds);
                    }
                }
                else {
                    if (currentBounds != null) {
                        lineBounds.push(currentBounds);
                    }
                    currentLineY = pos.y;
                    currentBounds = bounds;
                }
            }
        }
        if (currentBounds != null) {
            lineBounds.push(currentBounds);
        }
        return lineBounds;
    }

    function testRowWalkMatchesTheCharacterWalk() {
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            final style = bodyStyle(16.);
            final origin = new Point(7., 11.);
            final mask = new Bounds(new Point(0., 0.), new Size(1000., 1000.));
            final clipped = new Bounds(new Point(20., 30.), new Size(50., 60.));
            for (text in [
                "",
                "one row",
                "a long paragraph that wraps onto several rows of eight pixel glyphs",
                "first line\nsecond line that also wraps around\n\nfourth",
                "中文与 English 混排的一段文字也会换行",
                "trailing newline\n",
            ]) {
                for (wrapWidth in [40., 100., 1000.]) {
                    final layout = layOut(text, style, wrapWidth, origin, window, cx);
                    final lineHeight = layout.lineHeight();
                    final paintedLayout = new PaintedSelectionLayout(layout);
                    for (mask in [mask, clipped]) {
                        final expected = byCharacter(text, layout, lineHeight, mask);
                        final actual = Inline.textLineBounds(paintedLayout, lineHeight, mask);
                        final context = '"$text" at ${wrapWidth}px in $mask';
                        // The character walk placed a wrapped row's first
                        // character at the end of the row before it: that row's
                        // box started one glyph in, and a row holding only that
                        // one glyph had no box at all. The row walk covers every
                        // row from its start, so it may see more rows, never
                        // fewer, and agrees on every row the walk could see.
                        assertTrue(actual.length >= expected.length, 'rows of $context: ${actual.length} < ${expected.length}');
                        for (row in 0...expected.length) {
                            final expectedRow = expected[row];
                            var found:Null<Bounds> = null;
                            for (a in actual) {
                                if (a.top() == expectedRow.top()) {
                                    found = a;
                                    break;
                                }
                            }
                            if (found == null) {
                                fail('row $row of $context is missing');
                                continue;
                            }
                            assertEquals(expectedRow.bottom(), found.bottom(), 'row $row of $context');
                            assertEquals(expectedRow.right(), found.right(), 'row $row of $context');
                            assertTrue(found.left() <= expectedRow.left(), 'row $row of $context starts at ${found.left()}, after ${expectedRow.left()}');
                        }
                        for (a in actual) {
                            assertEquals(Math.max(origin.x, mask.left()), a.left(), 'left of $context');
                        }
                    }
                }
            }
            return null;
        });
    }

/// range_highlight_tests

    /**
     * Lays `text` out at `wrapWidth` and returns the highlight boxes of
     * `range` with rows aligned by `align`: the left and right edges past
     * the text's origin, and the row.
     */
    static function boxes(text:String, wrapWidth:Float, align:TextAlign, range:Range):Array<Array<Float>> {
        final app = TextTestDraw.wideMonoApp();
        return TextTestDraw.inPrepaint(app, (window, cx) -> {
            final style = bodyStyle(16.);
            final layout = layOut(text, style, wrapWidth, new Point(7., 11.), window, cx);
            final glyphs = Inline.glyphBoxes(layout, align, layout.bounds().size.width);
            return [for (box in Inline.rangeBoxes(glyphs, range)) [box.left, box.right, box.row]];
        });
    }

    /**
     * The selection fast paths decide a whole inline from this extent, so it
     * must start exactly at the first row the per-character walk tests and
     * reach at least the bottom of the last one.
     */
    function testTextRowsExtentMatchesTheCharacterWalk() {
        final app = TextTestDraw.wideMonoApp();
        TextTestDraw.inPrepaint(app, (window, cx) -> {
            final style = bodyStyle(16.);
            final origin = new Point(7., 11.3);
            for (text in [
                "one row",
                "a long paragraph that wraps onto several rows of eight pixel glyphs",
                "first line\nsecond line that also wraps around\n\nfourth",
                "中文与 English 混排的一段文字也会换行",
                "trailing newline\n",
            ]) {
                for (wrapWidth in [40., 100., 1000.]) {
                    final layout = layOut(text, style, wrapWidth, origin, window, cx);
                    // Taller than the layout's rows, as a window line height
                    // may be.
                    final lineHeight = TextTestFonts.f32(layout.lineHeight() + 3.);
                    var top = gpui.Pixels.MAX;
                    var bottom = gpui.Pixels.MIN;
                    final decoded = new gpui.util.Utf8.Utf8Text(text);
                    for (k in 0...decoded.count) {
                        final position = layout.positionForIndex(decoded.byteOffsets[k]);
                        if (position != null) {
                            top = Math.min(top, position.y);
                            bottom = Math.max(bottom, position.y);
                        }
                    }
                    bottom = TextTestFonts.f32(bottom + lineHeight);

                    final extent = TextSelection.textRowsExtent(layout, lineHeight);
                    final context = '"$text" at ${wrapWidth}px';
                    assertEquals(top, extent.top, 'top of $context');
                    assertTrue(extent.bottom >= bottom, 'bottom of $context');
                }
            }
            return null;
        });
    }

    function testAHighlightStartingAWrappedRowPaintsOnlyThatRow() {
        // Three rows of "aaaa ", "bbbb ", "cccc".
        final text = "aaaa bbbb cccc";
        final rows = boxes(text, 45., Left, new Range(0, text.length));
        assertEquals(3, rows.length, '$rows');

        final bbbb = text.indexOf("bbbb");
        final highlight = boxes(text, 45., Left, new Range(bbbb, bbbb + 4));
        assertEquals(1, highlight.length, '$highlight');
        assertEquals(0., highlight[0][0]);
        assertEquals(1., highlight[0][2]);

        // Across the wrap, each row only as far as its text.
        final across = boxes(text, 45., Left, new Range(2, 7));
        assertEquals(2, across.length, '$across');
        assertEquals(rows[0][1], across[0][1]);
        assertEquals(0., across[1][0]);
        assertEquals(1., across[1][2]);
    }

    function testHighlightsAfterAHardLineBreakStartOnItsRow() {
        // Rows "aa", "bbb cc": the break is one byte of the text, not a glyph.
        final text = "aa\nbbb cc";
        final bbb = text.indexOf("bbb");
        final aa = boxes(text, 1000., Left, new Range(0, 2));
        final highlight = boxes(text, 1000., Left, new Range(bbb, bbb + 3));
        assertEquals(1, highlight.length, '$highlight');
        assertEquals(0., highlight[0][0]);
        assertEquals(1., highlight[0][2]);
        // Three glyphs as wide as the two of "aa" and a half.
        assertEquals(TextTestFonts.f32(TextTestFonts.f32(aa[0][1] - aa[0][0]) * 1.5), highlight[0][1]);
    }

    function testHighlightsFollowCenteredAndRightAlignedRows() {
        // Rows "aaaa ", "bbbb ", "cc": the last is narrower than the text, so
        // alignment moves it.
        final text = "aaaa bbbb cc";
        final cc = new Range(text.indexOf("cc"), text.length);
        final widest = boxes(text, 45., Left, new Range(0, 5))[0][1];
        final left = boxes(text, 45., Left, cc)[0];
        final center = boxes(text, 45., Center, cc)[0];
        final right = boxes(text, 45., Right, cc)[0];
        final width = TextTestFonts.f32(left[1] - left[0]);
        assertTrue(width > 0 && width < widest, '$left in $widest');
        // GPUI aligns each row in the width of the laid-out text, the wrap
        // width here.
        final alignWidth = 45.;
        assertEquals(0., left[0]);
        assertEquals('${[TextTestFonts.f32(TextTestFonts.f32(alignWidth - width) / 2.), TextTestFonts.f32(TextTestFonts.f32(alignWidth + width) / 2.), left[2]]}', '$center');
        assertEquals('${[TextTestFonts.f32(alignWidth - width), alignWidth, left[2]]}', '$right');
    }

/// tests

    static function mono(style:HighlightStyle):InlineHighlight {
        return highlight(style, "Mono");
    }

    function testTextRunsShapeACodeHighlightInItsFontFamily() {
        final style = new TextStyle();
        style.fontFamily = "Body";
        final highlights = [new RangedHighlight(new Range(4, 8), mono(new HighlightStyle()))];

        final runs = InlineHighlight.textRuns(12, style, highlights);

        final families = [for (run in runs) '(${run.len}, ${run.font.family})'].join(', ');
        assertEquals('(4, Body), (4, Mono), (4, Body)', families);
    }

    function testRowsAlignTheWayGpuiPaintsThem() {
        final width = 100.;
        assertEquals(0., Inline.alignedRowLeft(Left, width, 40.));
        assertEquals(30., Inline.alignedRowLeft(Center, width, 40.));
        assertEquals(60., Inline.alignedRowLeft(Right, width, 40.));
    }

    static function glyph(start:Int, end:Int, row:Int, left:Float, right:Float):GlyphBox {
        return new GlyphBox(new Range(start, end), row, left, right);
    }

    static function rangeBoxes(glyphs:Array<GlyphBox>, start:Int, end:Int):String {
        return [for (box in Inline.rangeBoxes(glyphs, new Range(start, end))) '(${box.row}, ${box.left}, ${box.right})'].join(' ');
    }

    function testRangeBoxesJoinTheGlyphsOfARangeOnEachRow() {
        // "ab cd" wrapped after the space, glyphs 8px wide.
        final glyphs = [
            glyph(0, 1, 0, 0., 8.),
            glyph(1, 2, 0, 8., 16.),
            glyph(2, 3, 0, 16., 24.),
            glyph(3, 4, 1, 0., 8.),
            glyph(4, 5, 1, 8., 16.),
        ];
        assertEquals('(0, 8, 16)', rangeBoxes(glyphs, 1, 2));
        assertEquals('(0, 0, 24) (1, 0, 16)', rangeBoxes(glyphs, 0, 5));
        // Starting at the wrap paints the next row only.
        assertEquals('(1, 0, 16)', rangeBoxes(glyphs, 3, 5));
        assertEquals('', rangeBoxes(glyphs, 2, 2));
    }

    function testRangeBoxesFollowRightToLeftGlyphs() {
        // Three two-byte letters painted right to left: the first letter's
        // glyph is the rightmost.
        final glyphs = [glyph(0, 2, 0, 16., 24.), glyph(2, 4, 0, 8., 16.), glyph(4, 6, 0, 0., 8.)];
        assertEquals('(0, 16, 24)', rangeBoxes(glyphs, 0, 2));
        assertEquals('(0, 0, 16)', rangeBoxes(glyphs, 2, 6));
    }

    function testRangeBoxesCoverAGlyphDrawingPartOfTheRange() {
        // A ligature drawing "fi" in one glyph.
        final glyphs = [glyph(0, 2, 0, 0., 10.), glyph(2, 3, 0, 10., 15.)];
        assertEquals('(0, 0, 10)', rangeBoxes(glyphs, 1, 2));
    }

    function testCombineHighlightsCutsABoldSpanAtTheCodeBoundary() {
        // `**bold `code`**`: the bold mark spans the code mark, so the
        // combined list carries the weight on both sides and the family on
        // the code side only.
        final bold = InlineHighlight.fromStyle(new HighlightStyle(null, FontWeight.BOLD));
        final combined = InlineHighlight.combineHighlights([new RangedHighlight(new Range(0, 10), bold)],
            [new RangedHighlight(new Range(6, 10), mono(new HighlightStyle()))]);

        assertEquals(2, combined.length);
        assertTrue(combined[0].range.equals(new Range(0, 6)));
        assertEquals(FontWeight.BOLD, combined[0].highlight.style.fontWeight);
        assertEquals(null, combined[0].highlight.fontFamily);
        assertTrue(combined[1].range.equals(new Range(6, 10)));
        assertEquals(FontWeight.BOLD, combined[1].highlight.style.fontWeight);
        assertEquals("Mono", combined[1].highlight.fontFamily);
    }

    function testPointInTextSelection() {
        final lineHeight = 20.;
        final charWidth = 10.;
        final start = new Point(50., 50.);
        final end = new Point(150., 150.);
        inline function check(x:Float, y:Float):Bool {
            return Inline.pointInTextSelection(new Point(x, y), charWidth, start, end, lineHeight);
        }

        // First line but haft line height, true
        assertTrue(check(50., 40.));
        // First line in selection, true
        assertTrue(check(50., 50.));
        // First line, but left out of selection, false
        assertFalse(check(40., 50.));
        // First line but right out of selection, true
        assertTrue(check(160., 50.));

        // Middle line in selection, true
        assertTrue(check(100., 70.));
        // Middle line, but left out of selection, true
        assertTrue(check(40., 70.));
        // Middle line, but right out of selection, true
        assertTrue(check(160., 70.));

        // Last line in selection, true
        assertTrue(check(100., 140.));
        // Last line, but left out of selection, true
        assertTrue(check(40., 140.));
        // Last line, but right out of selection, false
        assertFalse(check(160., 140.));

        // Out of vertical bounds (top), false
        assertFalse(check(100., 20.));
        // Out of vertical bounds (bottom), false
        assertFalse(check(100., 160.));
    }

    function testPointInTextSelectionReversedDragDirection() {
        final lineHeight = 20.;
        final charWidth = 10.;

        // Mouse down on lower line then drag upward to x=150.
        // Top line should follow current mouse x, bottom line should keep anchor x.
        final start = new Point(80., 150.);
        final end = new Point(150., 50.);

        // On top line, selection starts from top cursor x (150), so x=140 should be excluded.
        assertFalse(Inline.pointInTextSelection(new Point(140., 50.), charWidth, start, end, lineHeight));
        assertTrue(Inline.pointInTextSelection(new Point(150., 50.), charWidth, start, end, lineHeight));

        // On bottom line, selection ends at anchor x (80), so x=90 should be excluded.
        assertTrue(Inline.pointInTextSelection(new Point(75., 140.), charWidth, start, end, lineHeight));
        assertFalse(Inline.pointInTextSelection(new Point(80., 140.), charWidth, start, end, lineHeight));
    }

    function testPointInTextSelectionSameVisualLineWithDifferentY() {
        final lineHeight = 20.;
        final charWidth = 10.;
        final start = new Point(100., 55.);
        final end = new Point(60., 58.);

        assertFalse(Inline.pointInTextSelection(new Point(40., 50.), charWidth, start, end, lineHeight));
        assertTrue(Inline.pointInTextSelection(new Point(70., 50.), charWidth, start, end, lineHeight));
        assertFalse(Inline.pointInTextSelection(new Point(110., 50.), charWidth, start, end, lineHeight));
    }

    function testPointInTextSelectionSameVisualLineWithReversedY() {
        final lineHeight = 20.;
        final charWidth = 10.;
        final start = new Point(60., 58.);
        final end = new Point(100., 55.);

        assertFalse(Inline.pointInTextSelection(new Point(40., 50.), charWidth, start, end, lineHeight));
        assertTrue(Inline.pointInTextSelection(new Point(70., 50.), charWidth, start, end, lineHeight));
        assertFalse(Inline.pointInTextSelection(new Point(110., 50.), charWidth, start, end, lineHeight));
    }

/// retained_layout_tests

    /** Opens a window whose view shows `copies` text views of a Markdown state, 300px wide. */
    static function openTextViews(source:String, copies:Int):{cx:testing.VisualTestContext, view:gpui.Entity<TextViewHost>} {
        final dispatcher = new TestDispatcher();
        final app = InteractionScript.testApp(dispatcher);
        // `TestAppContext` runs on the test platform's `NoopTextSystem`.
        app.setTextSystem(new TextSystem(new gpui.NoopTextSystem()));
        app.update(cx -> gpui.base.Base.init(cx));
        final opened = testing.VisualTestContext.addWindowView(app, dispatcher, (window, cx) -> {
            final state = cx.newEntity(cx -> gpui.base.text.TextViewState.markdown(source, cx));
            return new TextViewHost(state, 300., copies);
        });
        opened.cx.runUntilParked();
        return opened;
    }

    static function draw(cx:testing.VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /**
     * Without the hand-over rule the second copy's prepaint replaced the
     * first copy's entry, and the first copy painted with the second's
     * layout, at the second's bounds.
     */
    function testTheSameParagraphRenderedTwiceInAFrameKeepsOneLayoutAndPaintsBoth() {
        Inline.retainedLayoutCount = 0;
        final opened = openTextViews("First paragraph.\n\nSecond **paragraph**.", 2);
        final cx = opened.cx;
        // Frame 1 fills the table, frame 2 reuses it; neither may lose the
        // shaped text of either copy.
        for (_ in 0...3) {
            draw(cx);
        }
        assertEquals(2, Inline.retainedLayoutCount, "one layout per paragraph state");
        cx.destroy();
    }

    /**
     * A paragraph with a code span is laid out by `InlineFlow`, as one
     * `Inline` per wrapped fragment. The fragments' states have to outlive
     * the frame, or every frame shapes the fragments again and leaves a
     * layout nobody will take.
     */
    function testInlineFlowFragmentsKeepTheirLayoutsAcrossFrames() {
        Inline.retainedLayoutCount = 0;
        final opened = openTextViews("Call `foo` now.", 1);
        final cx = opened.cx;
        for (_ in 0...3) {
            draw(cx);
        }
        // "Call ", "foo" and " now.": three fragments on one line.
        assertEquals(3, Inline.retainedLayoutCount, "one layout per fragment");
        cx.destroy();
    }

    // Not ported: `shortening_an_inline_flow_releases_obsolete_fragment_layouts`,
    // `dropping_a_text_view_releases_its_layouts` and
    // `closing_the_last_text_view_releases_its_layouts` count the live
    // entries left in the table after states were dropped (the sweep).
    // A retained layout is a slot of its state here, released by the
    // garbage collector with it; nothing is left to observe.

}

/**
 * Rust `test_draw`: runs a function inside a real prepaint pass.
 *
 * Measuring an inline object lays its GPUI element out through the window,
 * which GPUI only permits while a frame is being drawn, so a test that
 * builds a real element cannot call the measurement helpers straight from
 * a window update.
 */
class TextTestDraw {

    /** Rust `TestApp::with_text_system(Arc::new(WideMonoTextSystem))`. */
    public static function wideMonoApp():App {
        final app = InteractionScript.testApp(new TestDispatcher());
        app.setTextSystem(new TextSystem(new WideMonoTextSystem()));
        return app;
    }

    /** Rust `TestApp::new()`: the test platform's text system. */
    public static function testApp():App {
        final app = InteractionScript.testApp(new TestDispatcher());
        app.setTextSystem(new TextSystem(new gpui.NoopTextSystem()));
        return app;
    }

    /** Rust `TestApp::open_window`: a maximized window of the test display, at scale factor 2. */
    public static function openWindow(app:App, render:(Window, Context<Dynamic>) -> IntoElement):Window {
        var window:Window = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 1920, height: 1080, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                return cx.newEntity(_ -> new testing.InteractionScript.ScriptView(render));
            });
        });
        return window;
    }

    /** Runs `f` inside a real prepaint pass and returns its value. */
    public static function inPrepaint<R>(app:App, f:(Window, App) -> R):R {
        var slot:Null<R> = null;
        var ran = false;
        var body:Null<(Window, App) -> R> = f;
        final window = openWindow(app, (_, _) -> {
            final run = body;
            body = null;
            return gpui.Prelude.canvas((_, window, cx) -> {
                if (run != null) {
                    slot = run(window, cx);
                    ran = true;
                }
                return null;
            }, (_, _, _, _) -> {}).w(gpui.Prelude.px(1000.)).h(gpui.Prelude.px(1000.));
        });
        app.update(_ -> window.draw());
        window.destroy();
        if (!ran) {
            throw 'prepaint probe did not run';
        }
        return slot;
    }

}

/**
 * Rust `test_fonts`: a platform text system for tests where the `Mono`
 * family shapes twice as wide as every other family, so a measurement that
 * ignores the family of a run comes out visibly short.
 */
class TextTestFonts {

    public static inline final BODY = "Body";
    public static inline final MONO = "Mono";

    /** Rust `f32` arithmetic. */
    public static inline function f32(value:Float):Float {
        return taffy.util.F32.fround(value);
    }

    /** Width of `text` shaped entirely in `family` at `fontSize`. */
    public static function widthOf(text:String, family:String, fontSize:Float):Float {
        final fontId = family == MONO ? WideMonoTextSystem.MONO_ID : WideMonoTextSystem.BODY_ID;
        return f32(f32(fontSize * f32(WideMonoTextSystem.advanceUnits(fontId) / WideMonoTextSystem.UNITS_PER_EM)) * new gpui.util.Utf8.Utf8Text(text).count);
    }

    /** Text submitted to `layoutLine` while recording (Rust `record_shaped_lines`). */
    public static var shapedLineRecorder:Null<Array<String>> = null;

    public static function recordShapedLines<R>(f:() -> R):{result:R, shapedLines:Array<String>} {
        shapedLineRecorder = [];
        try {
            final result = f();
            final lines = shapedLineRecorder;
            shapedLineRecorder = null;
            return {result: result, shapedLines: lines};
        }
        catch (e:haxe.Exception) {
            shapedLineRecorder = null;
            throw e;
        }
    }

}

class WideMonoTextSystem implements PlatformTextSystem {

    public static inline final BODY_ID:Int = 1;
    public static inline final MONO_ID:Int = 2;
    public static inline final BOLD_BODY_ID:Int = 3;
    public static inline final BOLD_MONO_ID:Int = 4;
    public static inline final UNITS_PER_EM:Float = 1000.;

    public function new() {}

    /** Advance of one glyph in `fontId`, in em units. */
    public static function advanceUnits(fontId:Int):Float {
        return switch fontId {
            case MONO_ID: 1000.;
            case BOLD_MONO_ID: 1250.;
            case BODY_ID: 500.;
            case BOLD_BODY_ID: 750.;
            case _: 500.;
        }
    }

    public function addFonts(fonts:Array<Bytes>):Void {}

    public function allFontNames():Array<String> {
        return [TextTestFonts.BODY, TextTestFonts.MONO];
    }

    public function fontId(descriptor:gpui.Font):FontId {
        final mono = descriptor.family == TextTestFonts.MONO;
        final bold = descriptor.weight == FontWeight.BOLD;
        return mono ? (bold ? BOLD_MONO_ID : MONO_ID) : (bold ? BOLD_BODY_ID : BODY_ID);
    }

    public function fontMetrics(fontId:FontId):FontMetrics {
        return new FontMetrics(Std.int(UNITS_PER_EM), 800., -200., 0., -100., 50., 700., 500., new Bounds(new Point(0., -200.), new Size(1000., 1000.)));
    }

    public function typographicBounds(fontId:FontId, glyphId:GlyphId):Bounds {
        return new Bounds(new Point(0., 0.), new Size(advanceUnits(fontId), 700.));
    }

    public function advance(fontId:FontId, glyphId:GlyphId):Size {
        return new Size(advanceUnits(fontId), 0.);
    }

    public function glyphForChar(fontId:FontId, ch:Int):Null<GlyphId> {
        return ch;
    }

    public function glyphRasterBounds(params:RenderGlyphParams):Bounds {
        return new Bounds();
    }

    public function rasterizeGlyph(params:RenderGlyphParams, rasterBounds:Bounds):Bytes {
        return Bytes.alloc(0);
    }

    public function layoutLine(text:String, fontSize:gpui.Pixels, runs:Array<FontRun>):LineLayout {
        if (TextTestFonts.shapedLineRecorder != null) {
            TextTestFonts.shapedLineRecorder.push(text);
        }

        var position:Float = 0.;
        final shapedRuns:Array<ShapedRun> = [];
        var runStart = 0;
        final decoded = new gpui.util.Utf8.Utf8Text(text);
        var k = 0;
        for (run in runs) {
            final advance = TextTestFonts.f32(fontSize * TextTestFonts.f32(advanceUnits(run.fontId) / UNITS_PER_EM));
            final glyphs:Array<ShapedGlyph> = [];
            while (k < decoded.count && decoded.byteOffsets[k] < runStart + run.len) {
                glyphs.push(new ShapedGlyph(decoded.codePoints[k], new Point(position, 0.), decoded.byteOffsets[k], false));
                position = TextTestFonts.f32(position + advance);
                k++;
            }
            shapedRuns.push(new ShapedRun(run.fontId, glyphs));
            runStart += run.len;
        }
        final metrics = fontMetrics(BODY_ID);
        return new LineLayout(fontSize, position, TextTestFonts.f32(fontSize * TextTestFonts.f32(metrics.ascent / UNITS_PER_EM)),
            // Native backends normalize the signed font metric for shaped lines.
            TextTestFonts.f32(fontSize * TextTestFonts.f32(-metrics.descent / UNITS_PER_EM)), shapedRuns, Utf8.byteLength(text));
    }

    public function recommendedRenderingMode(fontId:FontId, fontSize:gpui.Pixels):TextRenderingMode {
        return Grayscale;
    }

    public function glyphDilationForColor(color:Hsla):Int {
        return 0;
    }

}

/** The test views of `retained_layout_tests` and of the inline flow `frames` tests. */
class TextViewHost extends Model implements Render {

    public var state:gpui.Entity<gpui.base.text.TextViewState>;

    public var width:Float;

    final copies:Int;

    public function new(state:gpui.Entity<gpui.base.text.TextViewState>, width:Float, copies:Int) {
        super();
        this.state = state;
        this.width = width;
        this.copies = copies;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final root = gpui.Prelude.div().w(gpui.Prelude.px(width));
        for (_ in 0...copies) {
            root.child(gpui.base.text.TextView.create(state));
        }
        return root;
    }

}
