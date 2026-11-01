// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ListAlignment;
import gpui.ListOffset;
import gpui.ListState;
import gpui.MouseButton;
import gpui.ScrollEvent;
import gpui.ScrollHandle;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.Base;
import gpui.base.ScrollBounce;
import gpui.base.Scrollbar;
import gpui.base.input.CursorId;
import gpui.base.input.CursorSelection;
import gpui.base.input.EditorScrollbarContext;
import gpui.base.input.EditorState;
import gpui.base.input.FoldRange;
import gpui.base.input.InputActions.Redo;
import gpui.base.input.InputActions.Undo;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputState;
import gpui.base.input.RangeDecoration;
import gpui.base.input.TextareaState;
import testing.InteractionScript.ScriptView;
import testing.VisualTestContext;
import gpui.Bounds;
import gpui.CornersOf;
import gpui.Edges;
import gpui.FontStyle;
import gpui.HighlightStyle;
import gpui.Point;
import gpui.Range;
import gpui.Size;
import gpui.TextRun;
import gpui.TextStyle;
import gpui.UnderlineStyle;
import gpui.base.input.ColorSwatch;
import gpui.base.input.EditorScrollbarSnapshot.EditorScrollbarLayout;
import gpui.base.input.StyledRange;
import gpui.base.input.TextDecoration;
import gpui.base.input.TextElement;
import gpui.util.Utf8;
import ropey.Rope;

import gpui.Prelude.*;

using gpui.base.input.InputDecorationsExt;
using StringTools;

/**
 * Tests of `gpui.base.input.TextElement` (Rust `input/base/element.rs`).
 */
@:access(gpui.base.input.TextElement)
@:access(gpui.base.input.InputBaseState)
class InputTextElementTest extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    function openView(width:Float, height:Float, build:(Window, Context<ScriptView>) -> ((Window, Context<Dynamic>) -> IntoElement)):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx) -> new ScriptView(build(window, cx)), width, height);
        contexts.push(opened.cx);
        return opened.cx;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static inline function base(entity:Entity<Dynamic>):Entity<InputBaseState> {
        return cast entity;
    }

    /** Rust `decoration_editor`: a 240x140 window with a folding editor holding `text`. */
    function decorationEditor(text:String, wrap:Bool):{editor:Entity<EditorState>, cx:VisualTestContext} {
        app.update(cx -> Base.init(cx));
        var editor:Entity<EditorState> = null;
        final cx = openView(240., 140., (window, cx) -> {
            editor = cx.newEntity(cx -> new EditorState(window, cx).withSoftWrap(wrap).folding(true).defaultValue(text));
            return (_, _) -> div().sizeFull().child(editor);
        });
        return {editor: editor, cx: cx};
    }

    static function lines(from:Int, to:Int):String {
        return [for (line in from...to) 'line $line'].join('\n');
    }

    static function corners(left:Float, top:Float, right:Float, bottom:Float):CornersOf<Point> {
        return new CornersOf<Point>(new Point(left, top), new Point(right, top), new Point(right, bottom), new Point(left, bottom));
    }

    function assertPoints(expected:Array<Point>, actual:Array<Point>, ?pos:haxe.PosInfos) {
        assertEquals(expected.length, actual.length, null, pos);
        for (i in 0...expected.length) {
            assertFloatEquals(expected[i].x, actual[i].x, 1e-5, 'x of point $i', pos);
            assertFloatEquals(expected[i].y, actual[i].y, 1e-5, 'y of point $i', pos);
        }
    }

    function assertBounds(expected:Bounds, actual:Bounds, ?pos:haxe.PosInfos) {
        assertTrue(expected.equals(actual), 'expected $expected, got $actual', pos);
    }

    static function runOfLen(len:Int, ?color:gpui.Hsla):TextRun {
        return new TextRun(len, gpui.Font.of('.SystemUIFont'), color != null ? color : black(), null, null, null);
    }

    static function lens(runs:Array<TextRun>):Array<Int> {
        return [for (run in runs) run.len];
    }

    function testLineNumberColumnStaysAtThreeDigitsThenGrowsUpToSeven() {
        assertEquals(3, TextElement.lineNumberLen(1));
        assertEquals(3, TextElement.lineNumberLen(9));
        assertEquals(3, TextElement.lineNumberLen(10));
        assertEquals(3, TextElement.lineNumberLen(999));
        assertEquals(4, TextElement.lineNumberLen(1000));
        assertEquals(6, TextElement.lineNumberLen(999999));
        assertEquals(7, TextElement.lineNumberLen(9999999));
        assertEquals(7, TextElement.lineNumberLen(10000000));
    }

    function testDisplayedLineNumberStaysWithinSevenDigits() {
        assertEquals(42, TextElement.displayedLineNumber(42));
        assertEquals(9999999, TextElement.displayedLineNumber(9999999));
        assertEquals(9999999, TextElement.displayedLineNumber(10000000));
    }

    function testFrameOutlineIsContinuousAcrossDifferentLineWidths() {
        final corners = [corners(2., 0., 20., 10.), corners(0., 10., 12., 20.)];

        assertPoints([
            new Point(2., 0.),
            new Point(20., 0.),
            new Point(20., 10.),
            new Point(12., 10.),
            new Point(12., 20.),
            new Point(0., 20.),
            new Point(0., 10.),
            new Point(2., 10.),
            new Point(2., 0.),
        ], TextElement.frameOutlinePoints(corners));
    }

    function testFrameOutlineKeepsHorizontalSpaceBetweenTheStrokeAndText() {
        final corners = [corners(2., 0., 20., 10.)];

        final padded = TextElement.padFrameCorners(corners, 1.);
        assertEquals(1, padded.length);
        assertPoints([new Point(1., 0.), new Point(21., 0.), new Point(21., 10.), new Point(1., 10.)],
            [padded[0].topLeft, padded[0].topRight, padded[0].bottomRight, padded[0].bottomLeft]);

        final points = TextElement.frameOutlinePoints(corners);
        assertTrue(points[0].equals(points[points.length - 1]));
    }

    function testFrameOutlineStrokeIsAlignedToPhysicalPixelsAtEachScaleFactor() {
        final points = [new Point(0.2, 1.8), new Point(10.7, 20.3)];

        for (entry in [
            {scale: 1., width: 1., points: [new Point(0.5, 1.5), new Point(10.5, 20.5)]},
            {scale: 1.5, width: 2. / 3., points: [new Point(1. / 3., 5. / 3.), new Point(11., 61. / 3.)]},
            {scale: 2., width: 1., points: [new Point(0., 2.), new Point(10.5, 20.5)]},
        ]) {
            final snapped = TextElement.snapFrameOutline(points, 1., entry.scale);
            assertFloatEquals(entry.width, snapped.strokeWidth);
            assertPoints(entry.points, snapped.points);
        }
    }

    function testFrameOutlineKeepsItsVerticalEdgesInsideTheContentMask() {
        final points = [
            new Point(9.5, 2.5),
            new Point(20.5, 2.5),
            new Point(20.5, 10.5),
            new Point(9.5, 10.5),
            new Point(9.5, 2.5),
        ];
        final mask = new Bounds(new Point(10., 0.), new Size(10., 20.));

        assertPoints([
            new Point(10.5, 2.5),
            new Point(19.5, 2.5),
            new Point(19.5, 10.5),
            new Point(10.5, 10.5),
            new Point(10.5, 2.5),
        ], TextElement.clampFrameToContentMask(points, 1., mask));
    }

    function testPlainTextDecorationsIncludeUnstyledGaps() {
        final decoration = new HighlightStyle();
        decoration.backgroundColor = red();
        final styles = TextElement.composeDecorations([], [new StyledRange(new Range(2, 5), decoration)], new Range(0, 10));

        assertEquals('0..2,2..5,5..10', [for (s in styles) '${s.range.start}..${s.range.end}'].join(','));
        assertTrue(styles[0].style.equals(new HighlightStyle()));
        assertTrue(red().equals(styles[1].style.backgroundColor));
        assertTrue(styles[2].style.equals(new HighlightStyle()));
    }

    function testFirstDecorationCollectionHasPrecedence() {
        final redStyle = new HighlightStyle();
        redStyle.backgroundColor = red();
        final blueStyle = new HighlightStyle();
        blueStyle.backgroundColor = blue();
        final first = [new TextDecoration(new Range(0, 4), redStyle)];
        final second = [new TextDecoration(new Range(0, 4), blueStyle)];

        final styles = TextElement.composeDecorationCollections([], [first, second], new Range(0, 4));

        assertEquals(1, styles.length);
        assertTrue(red().equals(styles[0].style.backgroundColor));
    }

    function testDecorationsOverrideSyntaxHighlights() {
        final syntax = [new StyledRange(new Range(0, 8), HighlightStyle.ofColor(blue()))];
        final decoration = new HighlightStyle();
        decoration.color = red();
        decoration.fontStyle = FontStyle.Italic;

        final styles = TextElement.composeDecorations(syntax, [new StyledRange(new Range(2, 6), decoration)], new Range(0, 8));

        assertTrue(styles[1].range.equals(new Range(2, 6)));
        assertTrue(red().equals(styles[1].style.color));
        assertEquals(FontStyle.Italic, styles[1].style.fontStyle);
    }

    function testEditorScrollbarLayoutUsesCurrentScrollSize() {
        final inputBounds = new Bounds(new Point(10., 20.), new Size(300., 80.));
        final paddings = new Edges(2., 3., 5., 7.);

        final layout = EditorScrollbarLayout.create(inputBounds, 40., new Size(1000., 200.), paddings);

        assertBounds(new Bounds(new Point(51., 18.), new Size(262., 87.)), layout.bounds);
        assertTrue(layout.scrollSize.equals(new Size(972., 200.)));
        assertTrue(layout.scrollViewportSize.equals(new Size(262., 80.)));

        final layoutWithoutGutter = EditorScrollbarLayout.create(inputBounds, 0., new Size(500., 120.), paddings);

        assertBounds(new Bounds(new Point(10., 18.), new Size(303., 87.)), layoutWithoutGutter.bounds);
        assertTrue(layoutWithoutGutter.scrollSize.equals(new Size(513., 120.)));
        assertTrue(layoutWithoutGutter.scrollViewportSize.equals(new Size(303., 80.)));
    }

    function testEditorGutterCoversTheCompleteFixedColumn() {
        final inputBounds = new Bounds(new Point(10., 20.), new Size(300., 80.));

        assertBounds(new Bounds(new Point(3., 18.), new Size(55., 103.)), TextElement.editorGutterBounds(inputBounds, 48., 16., new Edges(2., 3., 5., 7.)));
    }

    function testVerticalScrollOffsetIsClampedToCurrentViewport() {
        assertEquals(-180., TextElement.clampVerticalScrollOffset(-260., 340., 160.));
        assertEquals(-40., TextElement.clampVerticalScrollOffset(-40., 340., 160.));
        assertEquals(0., TextElement.clampVerticalScrollOffset(20., 340., 160.));
        assertEquals(0., TextElement.clampVerticalScrollOffset(-40., 100., 160.));
    }

    function testRunsForRange() {
        // use hello this-is-test
        final runs = [
            // use
            runOfLen(3),
            // \s
            runOfLen(1),
            // hello
            runOfLen(5),
            // \s
            runOfLen(1),
            // this-is-test
            runOfLen(12),
        ];

        function assertRuns(actual:Array<TextRun>, expected:Array<Int>, ?pos:haxe.PosInfos) {
            assertEquals(expected.join(','), lens(actual).join(','), null, pos);
        }

        assertRuns(TextElement.runsForRange(runs, 0, new Range(0, 0)), []);
        assertRuns(TextElement.runsForRange(runs, 0, new Range(0, 100)), [3, 1, 5, 1, 12]);

        assertRuns(TextElement.runsForRange(runs, 0, new Range(0, 6)), [3, 1, 2]);
        assertRuns(TextElement.runsForRange(runs, 0, new Range(1, 6)), [2, 1, 2]);
        assertRuns(TextElement.runsForRange(runs, 0, new Range(3, 10)), [1, 5, 1]);
        assertRuns(TextElement.runsForRange(runs, 0, new Range(5, 8)), [3]);
        assertRuns(TextElement.runsForRange(runs, 3, new Range(0, 3)), [1, 2]);
        assertRuns(TextElement.runsForRange(runs, 3, new Range(2, 10)), [4, 1, 3]);
        assertRuns(TextElement.runsForRange(runs, 9, new Range(0, 8)), [1, 7]);
    }

    static function underlineDescription(runs:Array<TextRun>):String {
        return [for (run in runs) '(${run.len}, ${run.underline != null})'].join(',');
    }

    function testSplitRunsPreserveImeUnderlineAcrossHighlightBoundaries() {
        final underline = new UnderlineStyle(1., black(), false);

        final runs:Array<TextRun> = [];
        for (range in [new Range(0, 4), new Range(4, 10)]) {
            for (run in TextElement.splitRunForImeUnderline(new TextStyle().toRun(range.end - range.start), range, new Range(2, 7), underline)) {
                runs.push(run);
            }
        }

        assertEquals('(2, false),(2, true),(3, true),(3, false)', underlineDescription(runs));
    }

    function testSplitRunAppliesImeUnderlineWithoutHighlighting() {
        final underline = new UnderlineStyle(1., black(), false);

        final runs = TextElement.splitRunForImeUnderline(new TextStyle().toRun(10), new Range(0, 10), new Range(2, 7), underline);

        assertEquals('(2, false),(5, true),(3, false)', underlineDescription(runs));
        assertEquals(0, TextElement.splitRunForImeUnderline(new TextStyle().toRun(0), new Range(0, 0), null, null).length);
    }

    function testMaskedImeUnderlineSplitsOnMaskCharBoundaries() {
        final underline = new UnderlineStyle(1., black(), false);
        final text = Rope.fromStr('abcdef');
        final maskLen = Utf8.codePointLength(TextElement.MASK_CHAR);

        assertTrue(new Range(4, 6).equals(TextElement.imeMarkedDisplayRange(text, new Range(4, 6), false)));
        assertNull(TextElement.imeMarkedDisplayRange(text, null, true));
        assertTrue(new Range(4 * maskLen, 6 * maskLen).equals(TextElement.imeMarkedDisplayRange(text, new Range(4, 6), true)));

        final displayText = StringTools.lpad('', Utf8.fromCodePoint(TextElement.MASK_CHAR), text.lenChars());
        final displayLen = Utf8.byteLength(displayText);
        final runs = TextElement.splitRunForImeUnderline(new TextStyle().toRun(displayLen), new Range(0, displayLen),
            TextElement.imeMarkedDisplayRange(text, new Range(4, 6), true), underline);

        var offset = 0;
        for (run in runs) {
            assertTrue(Utf8.isCharBoundary(displayText, offset));
            offset += run.len;
        }
        assertEquals(displayLen, offset);
    }

    function testPlaceholderLineRuns() {
        final runs = [runOfLen(2), runOfLen(2), runOfLen(1)];

        final placeholderRuns = TextElement.placeholderLineRuns('ab\n\nc', runs);

        assertEquals('ab||c', [for (entry in placeholderRuns) entry.line].join('|'));
        assertEquals('[2],[],[1]', [for (entry in placeholderRuns) '[' + lens(entry.runs).join(',') + ']'].join(','));
    }

    function testAlignRunsToCharBoundaries() {
        function runs(lens:Array<Int>):Array<TextRun> {
            return [for (len in lens) runOfLen(len, blue())];
        }

        // "你好，世界" is 15 bytes; boundaries at 0, 3, 6, 9, 12, 15.
        final text = '你好，世界';

        // Aligned runs pass through untouched.
        assertNull(TextElement.alignRunsToCharBoundaries(text, runs([3, 12])));

        // A mid-char boundary (4) snaps up to the next boundary (6).
        assertEquals('6,9', lens(TextElement.alignRunsToCharBoundaries(text, runs([4, 11]))).join(','));

        // Several boundaries inside the same char collapse into one run.
        assertEquals('3,12', lens(TextElement.alignRunsToCharBoundaries(text, runs([1, 1, 13]))).join(','));

        // Overshooting runs are capped at the text length.
        assertEquals('3,12', lens(TextElement.alignRunsToCharBoundaries(text, runs([3, 20]))).join(','));

        // Undershooting runs keep the shortfall (the tail is left unshaped,
        // matching `runsForRange` clipping).
        assertNull(TextElement.alignRunsToCharBoundaries(text, runs([3, 3])));
    }

    function testClipStylesToRanges() {
        final style = new HighlightStyle();
        final styles = [
            new StyledRange(new Range(0, 4), style),
            new StyledRange(new Range(4, 10), style),
            new StyledRange(new Range(12, 20), style)
        ];
        function ranges(styles:Array<StyledRange>):String {
            return [for (s in styles) '${s.range.start}..${s.range.end}'].join(',');
        }

        // Ranges with a gap (a folded region) drop the gap coverage and split
        // styles that span a range edge.
        assertEquals('2..4,4..6,14..18', ranges(TextElement.clipStylesToRanges(styles, [new Range(2, 6), new Range(14, 18)])));

        // Styles fully inside the ranges are unchanged.
        assertEquals('0..4,4..10,12..20', ranges(TextElement.clipStylesToRanges(styles, [new Range(0, 20)])));

        // A single style spanning several ranges splits into one piece per range.
        assertEquals('5..10,20..25',
            ranges(TextElement.clipStylesToRanges([new StyledRange(new Range(0, 30), style)], [new Range(5, 10), new Range(20, 25)])));

        assertEquals(0, TextElement.clipStylesToRanges(styles, []).length);
    }

    function testSplitRunsByBgSegments() {
        final runs = [runOfLen(5, blue()), runOfLen(7, blue()), runOfLen(24, blue())];

        final bgSegments = [new ColorSwatch(new Range(8, 12), red()), new ColorSwatch(new Range(12, 18), blue())];
        final result = TextElement.splitRunsByBgSegments(5, runs, bgSegments);
        assertEquals('3,2,2,5,1,23', lens(result).join(','));
        assertTrue(blue().equals(result[0].color));
        assertTrue(black().equals(result[1].color));
        assertTrue(black().equals(result[2].color));
        assertTrue(black().equals(result[3].color));
        assertTrue(black().equals(result[4].color));
        assertTrue(blue().equals(result[5].color));
    }

    function testEmptyBottomHeightOutsideCodeEditor() {
        // Single-line / plain-text / auto-grow modes never reserve empty
        // bottom space, regardless of any override.
        for (overrideRows in ([null, 0, 3, 99] : Array<Null<Int>>)) {
            assertEquals(0., TextElement.emptyBottomHeight(false, overrideRows, 800., 20.));
        }
    }

    function testEmptyBottomHeightCodeEditorDefault() {
        // `null`: roughly half the viewport, floored at
        // `BOTTOM_MARGIN_ROWS * lineHeight` so the empty area never
        // collapses to "less than a few lines" on tiny viewports.
        final lineHeight = 20.;

        // Viewport much taller than the floor: half-viewport wins.
        assertEquals(400., TextElement.emptyBottomHeight(true, null, 800., lineHeight));

        // Viewport shorter than 2 x floor: floor wins.
        final floor = TextElement.BOTTOM_MARGIN_ROWS * lineHeight;
        assertEquals(floor, TextElement.emptyBottomHeight(true, null, 40., lineHeight));
    }

    function testEmptyBottomHeightExplicitRowCount() {
        // `n`: exactly `n` line-heights. Caller fully controls
        // the trailing empty space; viewport size doesn't amplify it.
        final lineHeight = 20.;

        for (rows in [0, 1, 3, 8, 64]) {
            final expected = rows * lineHeight;
            assertEquals(expected, TextElement.emptyBottomHeight(true, rows, 800., lineHeight));
            // Tiny viewport: still exactly `n x lineHeight`, no floor
            // applied when caller supplied an explicit count.
            assertEquals(expected, TextElement.emptyBottomHeight(true, rows, 20., lineHeight));
        }
    }

    function testRowRevealContainsTheWholeRowAndHasAStableOffset() {
        final lineHeight = 20.;
        final rowTop = 1000.;
        for (viewportHeight in [20., 30., 600.]) {
            for (autoGrow in [false, true]) {
                for (surrounding in ([null, 0, 50] : Array<Null<Int>>)) {
                    final padding = TextElement.cursorSurroundingPadding(autoGrow, surrounding, TextElement.viewportVisibleLines(viewportHeight, lineHeight),
                        lineHeight);
                    for (previous in [-1500., -1000., 0.]) {
                        final offset = TextElement.revealRow(previous, rowTop, lineHeight, viewportHeight, padding);
                        assertTrue(rowTop + offset >= 0.);
                        assertTrue(rowTop + offset + lineHeight <= viewportHeight);
                        assertEquals(offset, TextElement.revealRow(offset, rowTop, lineHeight, viewportHeight, padding), 'unchanged caret must not oscillate');
                    }
                }
            }
        }
    }

    function testUndersizedRowRevealAlignsTheStartWithoutOscillating() {
        final offset = TextElement.revealRow(0., 80., 20., 10., 60.);
        assertEquals(0., 80. + offset);
        assertEquals(offset, TextElement.revealRow(offset, 80., 20., 10., 60.));
    }

/// Tests with a window

    function testFocusedInputAsksItsScrollContainerToRevealIt() {
        app.update(cx -> Base.init(cx));
        // A list as tall as the window, whose second item is an input that
        // starts 180 px down, so its bottom is cut off by the window's edge.
        final listState = new ListState(2, ListAlignment.Top, 0.);
        var input:Entity<InputState> = null;
        var showInput = true;
        var view:Null<Context<ScriptView>> = null;
        final cx = openView(240., 200., (window, viewCx) -> {
            input = viewCx.newEntity(cx -> new InputState(window, cx));
            view = viewCx;
            return (_, _) -> list(listState, (ix, _, _) -> {
                if (ix == 0) {
                    return div().h(px(180.));
                }
                else {
                    final item = div();
                    if (showInput)
                        item.child(input);
                    return item;
                }
            }).sizeFull();
        });
        cx.update((window, _) -> window.setActive(true));
        cx.runUntilParked();
        function draw(cx:VisualTestContext) {
            cx.update((window, _) -> {
                window.refresh();
                window.draw();
            });
        }
        function revealed(cx:VisualTestContext):Bool {
            return cx.update((window, app) -> {
                final bounds = input.read(app).inputBounds;
                return bounds.top() >= 0. && bounds.bottom() <= window.viewportSize().height;
            });
        }
        function atTop():Bool {
            return listState.logicalScrollTop().itemIx == 0 && listState.logicalScrollTop().offsetInItem == 0.;
        }

        draw(cx);
        assertTrue(atTop());
        assertFalse(revealed(cx));

        // Gaining focus reveals the input.
        cx.update((window, app) -> input.update(app, (state, cx) -> state.focus(window, cast cx)));
        draw(cx);
        draw(cx);
        assertFalse(atTop());
        assertTrue(revealed(cx));

        // Scrolling away while focused is left alone.
        listState.scrollTo(new ListOffset());
        draw(cx);
        draw(cx);
        assertTrue(atTop());

        // A temporarily unmounted input does not prepaint while unfocused.
        // Its blur event must still reset the reveal cache before remounting.
        cx.update((window, app) -> {
            showInput = false;
            window.blur(app);
            view.notify();
        });
        draw(cx);
        assertNull(input.read(app).revealedViewport);
        cx.update((window, app) -> {
            showInput = true;
            input.update(app, (state, cx) -> state.focus(window, cast cx));
            view.notify();
        });
        draw(cx);
        draw(cx);
        assertFalse(atTop());
        assertTrue(revealed(cx));

        listState.scrollTo(new ListOffset());
        draw(cx);
        draw(cx);
        assertTrue(atTop());

        // A smaller visible area (an on-screen keyboard) reveals it again.
        cx.update((window, _) -> window.resize(240., 195.));
        draw(cx);
        draw(cx);
        assertFalse(atTop());
        assertTrue(revealed(cx));
    }

    function testScrollBounceKeepsTheScrollbarViewportFixed() {
        final opened = decorationEditor(lines(0, 60), false);
        final editor = opened.editor;
        final cx = opened.cx;
        cx.update((window, app) -> {
            window.draw();
            final viewport = editor.read(app).editorScrollbarSnapshot.layout.bounds;
            final textOrigin = editor.read(app).lastBounds.origin;
            editor.update(app, (state, cx) -> {
                state.setScrollBounce(true, cast cx);
                state.onScrollWheel(new ScrollEvent(new Point(), Pixels(new Point(0., 60.)), null, Started), window, cast cx);
            });
            window.draw();
            final state = editor.read(app);
            final stretch = state.overscroll.offset();
            assertTrue(stretch > 0.);
            assertBounds(viewport, state.editorScrollbarSnapshot.layout.bounds);
            assertFloatEquals(textOrigin.y + stretch, state.lastBounds.origin.y);
            return null;
        });
    }

    /**
     * A scrollbar supplied through `setScrollbarRenderer` gets the editor's own
     * scroll range through the standard ScrollbarHandle contract, so a
     * scrollbar can drag to the same end as wheel scrolling.
     */
    function testScrollbarRendererReceivesTheEditorsScrollRange() {
        final opened = decorationEditor(lines(0, 60), true);
        final editor = opened.editor;
        final cx = opened.cx;
        var presented:Null<EditorScrollbarContext> = null;
        cx.update((window, app) -> {
            editor.update(app, (state, cx) -> {
                state.setScrollBounce(false, cast cx);
                state.setEditorPaddings(new Edges(10., 0., 10., 0.));
                state.setScrollbarRenderer((context, _, _) -> {
                    presented = context;
                    return Scrollbar.vertical(context).mode(Always).intoAnyElement();
                });
            });
            window.draw();
            editor.update(app, (state, cx) -> {
                state.onScrollWheel(new ScrollEvent(new Point(), Pixels(new Point(0., -10000.)), null, Moved), window, cast cx);
            });
            window.draw();
            return null;
        });

        final context = presented;
        assertNotNull(context);
        final track = context.viewportBounds();
        final wheelEnd = context.offset();
        assertTrue(wheelEnd.y < 0.);
        assertFloatEquals(20., track.size.height - context.scrollViewportSize().height);
        cx.update((window, _) -> {
            context.setOffset(new Point());
            window.refresh();
            window.draw();
        });

        final grab = new Point(track.right() - 5., track.top() + 10.);
        final end = new Point(grab.x, track.bottom() - 1.);
        cx.simulateMouseDown(grab, Left);
        draw(cx);
        cx.simulateMouseMove(end, Left);
        draw(cx);
        cx.simulateMouseUp(end, Left);

        assertTrue(wheelEnd.equals(editor.read(app).scrollOffset()), 'expected $wheelEnd, got ${editor.read(app).scrollOffset()}');
        assertFloatEquals(-wheelEnd.y, context.contentSize().height - track.size.height);
    }

    function testATextareaKeepsItsScrollFromTheAreaAroundIt() {
        app.update(cx -> Base.init(cx));
        final text = lines(1, 41);
        final outer = new ScrollHandle();
        var textarea:Entity<TextareaState> = null;
        final cx = openView(240., 400., (window, cx) -> {
            textarea = cx.newEntity(cx -> new TextareaState(window, cx).defaultValue(text));
            // A textarea 100 px down a taller bouncing scroll area.
            return (_, _) -> new ScrollBounce('outer', outer, div()
                .id('outer-viewport')
                .w(px(240.))
                .h(px(300.))
                .overflowYScroll()
                .trackScroll(outer)
                .child(div().h(px(100.)))
                .child(div().h(px(120.)).child(textarea))
                .child(div().h(px(600.))))
                .enabled(true);
        });
        draw(cx);
        function swipe(cx:VisualTestContext, y:Float) {
            cx.simulateEvent(new ScrollEvent(new Point(100., y), Pixels(new Point(0., -40.)), null, Moved));
            draw(cx);
        }
        swipe(cx, 160.);
        final scrolled = textarea.read(app).scrollHandle.offset().y;
        assertTrue(scrolled < 0., 'the textarea scrolls');
        assertEquals(0., outer.offset().y, 'the area around it does not');
        swipe(cx, 40.);
        assertEquals(-40., outer.offset().y, 'outside the textarea it does');
    }

    function testSetScrollOffsetPastTheEndIsClamped() {
        app.update(cx -> Base.init(cx));
        final text = lines(1, 41);
        var textarea:Entity<TextareaState> = null;
        final cx = openView(240., 400., (window, cx) -> {
            textarea = cx.newEntity(cx -> new TextareaState(window, cx).defaultValue(text));
            return (_, _) -> div().sizeFull().child(textarea);
        });
        cx.update((window, app) -> {
            window.draw();
            textarea.update(app, (state, cx) -> state.setScrollOffset(new Point(0., -10000.), cast cx));
            window.draw();

            final state = textarea.read(app);
            final painted = state.editorScrollbarSnapshot.cursorScrollOffset;
            final furthest = Math.min(state.inputBounds.size.height - state.scrollSize.height, 0.);
            assertTrue(furthest < 0.);
            assertFloatEquals(furthest, painted.y);

            final layout = state.lastLayout;
            final rows = TextElement.viewportVisibleLines(state.inputBounds.size.height, layout.lineHeight);
            assertTrue(layout.visibleRange.end - layout.visibleRange.start >= rows);
            return null;
        });
    }

    function testSetScrollOffsetPastTheEndIsClampedInACodeEditor() {
        final opened = decorationEditor(lines(1, 41), false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            editor.update(app, (state, cx) -> state.setScrollOffset(new Point(0., -10000.), cast cx));
            window.draw();

            final state = editor.read(app);
            final painted = state.editorScrollbarSnapshot.cursorScrollOffset;
            // The furthest offset includes the room below the last line.
            final furthest = state.inputBounds.size.height - state.scrollSize.height;
            assertTrue(-furthest > state.inputBounds.size.height);
            assertFloatEquals(furthest, painted.y);
            return null;
        });
    }

    function testSelectionPathsFollowTheInputAndItsMenuFocus() {
        final opened = decorationEditor('alpha beta', false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            final menuFocus = app.focusHandle();
            final otherFocus = app.focusHandle();
            editor.update(app, (state, cx) -> {
                state.setSelectedRange(new Range(0, 5), cast cx);
                state.focus(window, cast cx);
            });

            function selectionPaths():Int {
                window.draw();
                final state = editor.read(app);
                final layout = state.lastLayout.clone();
                final bounds = state.inputBounds;
                return new TextElement(base(editor)).layoutSelections(layout, bounds, window, app).length;
            }
            final focusedPaths = selectionPaths();
            assertTrue(focusedPaths > 0);

            editor.update(app, (state, cx) -> state.setSelectionFocus(menuFocus, cast cx));
            menuFocus.focus(window, app);
            assertFalse(editor.read(app).focusHandle.isFocused(window));
            assertEquals(focusedPaths, selectionPaths());
            // The opening frame can still use the input's old focus. Check
            // another frame with the menu already focused as well.
            assertEquals(focusedPaths, selectionPaths());

            otherFocus.focus(window, app);
            assertEquals(0, selectionPaths());
            assertTrue(new Range(0, 5).equals(editor.read(app).selectedRange()));

            menuFocus.focus(window, app);
            editor.update(app, (state, cx) -> state.setSelectionFocus(null, cast cx));
            assertEquals(0, selectionPaths());
            editor.update(app, (state, cx) -> state.focus(window, cast cx));
            assertEquals(focusedPaths, selectionPaths());

            // Not ported: "retaining the input must not keep a removed menu
            // alive" drops the last strong focus handle and checks the weak
            // one no longer upgrades, which the garbage collected port cannot
            // trigger deterministically.
            return null;
        });
    }

    function testHorizontalScrollIsClampedBeforeTextAndCaretLayout() {
        final opened = decorationEditor('short text', false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final state = editor.read(app);
            final layout = state.lastLayout.clone();
            final inputBounds = state.inputBounds;
            final scrollSize = inputBounds.size;
            final element = new TextElement(base(editor));
            final baseline = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;

            // Both a stale offset after deletion and a deferred scroll target must
            // be limited before either text or carets are positioned this frame.
            for (deferred in ([null, new Point(-80., 0.)] : Array<Null<Point>>)) {
                editor.update(app, (state, _) -> {
                    state.scrollHandle.setOffset(new Point(-40., 0.));
                    state.deferredScrollOffset = deferred;
                });
                final result = element.layoutCursors(layout, inputBounds, scrollSize, window, app);
                final offset = result.scrollOffset;
                assertEquals(0., offset.x);
                assertEquals(inputBounds.origin.x, result.bounds.origin.x);
                assertEquals(baseline.length, result.cursorInfos.length);
                for (i in 0...baseline.length) {
                    assertEquals(baseline[i].bounds.origin.x, result.cursorInfos[i].bounds.origin.x);
                }
                editor.update(app, (state, cx) -> {
                    state.scrollSize = scrollSize;
                    state.updateScrollOffset(offset, cast cx);
                    assertEquals(offset.x, state.scrollHandle.offset().x);
                });
            }
            return null;
        });
    }

    /**
     * Scroll to the far right and assert the caret at `end` lands inside the
     * viewport, so the line ending there can be revealed completely.
     */
    function assertHorizontalScrollReachesLineEnd(editor:Entity<EditorState>, end:Int, window:Window, app:App, ?pos:haxe.PosInfos) {
        final state = editor.read(app);
        final layout = state.lastLayout.clone();
        final inputBounds = state.inputBounds;
        final scrollSize = state.scrollSize;

        editor.update(app, (state, cx) -> {
            state.setSelectedRange(new Range(end, end), cast cx);
            state.deferredScrollOffset = new Point(-1000000., 0.);
        });

        final element = new TextElement(base(editor));
        final result = element.layoutCursors(layout, inputBounds, scrollSize, window, app);
        assertTrue(result.cursorInfos.length > 0, 'a caret', pos);
        final caret = result.cursorInfos[0].bounds;
        assertTrue(caret.left() <= inputBounds.right() + 1.,
            'scrolling to the end (${result.scrollOffset}) leaves the caret at $caret past ${inputBounds.right()}', pos);
    }

    function testHorizontalScrollExtentExcludesPlaceholder() {
        final opened = decorationEditor('', false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final emptyWidth = editor.read(app).scrollSize.width;

            for (placeholder in [''.lpad('W', 300), 'Short hint']) {
                editor.update(app, (state, cx) -> state.setPlaceholder(placeholder, window, cast cx));
                window.draw();
                assertEquals(emptyWidth, editor.read(app).scrollSize.width, 'placeholder must not create horizontal scrollable content');
            }
            return null;
        });
    }

    function testHorizontalScrollExtentCoversTheWidestLaidOutLine() {
        // The first line is longest by bytes, but the second renders wider.
        final narrow = 'e' + ''.lpad('́', 200);
        final wide = ''.lpad('W', 300);
        final text = '$narrow\n$wide';
        final opened = decorationEditor(text, false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            assertHorizontalScrollReachesLineEnd(editor, Utf8.byteLength(text), window, app);

            // Editing the wider line invalidates the cached measurement.
            final wider = ''.lpad('W', 400);
            final edited = '$narrow\n$wider';
            editor.update(app, (state, cx) -> state.setValue(edited, window, cast cx));
            window.draw();
            assertHorizontalScrollReachesLineEnd(editor, Utf8.byteLength(edited), window, app);

            // A larger font must widen the extent instead of reusing the old
            // measurement.
            final before = editor.read(app).scrollSize.width;
            window.setRemSize(24.);
            window.draw();
            final after = editor.read(app).scrollSize.width;
            assertTrue(after > before, 'growing the font should widen the scroll extent: $after > $before');
            assertHorizontalScrollReachesLineEnd(editor, Utf8.byteLength(edited), window, app);
            return null;
        });
    }

    function testAlignedHorizontalScrollClampsDeferredTargets() {
        final opened = decorationEditor([for (_ in 0...80) 'wide text '].join(''), false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final layout = editor.read(app).lastLayout.clone();
            final inputBounds = editor.read(app).inputBounds;
            final element = new TextElement(base(editor));

            for (alignment in [TextAlign.Left, TextAlign.Right, TextAlign.Center]) {
                layout.textAlign = alignment;
                for (overflow in [0., 120.]) {
                    final scrollSize = new Size(inputBounds.size.width + overflow, inputBounds.size.height);
                    final minimum = alignment == Left ? -overflow : -overflow - TextElement.CURSOR_WIDTH;
                    editor.update(app, (state, _) -> {
                        state.textAlign = alignment;
                        state.lastSelectedRange = state.activeSelection().copy();
                        state.deferredScrollOffset = new Point(minimum, 0.);
                    });
                    final expected = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;

                    for (target in [minimum - 100., 100.]) {
                        editor.update(app, (state, _) -> {
                            state.deferredScrollOffset = new Point(target, 0.);
                        });
                        final result = element.layoutCursors(layout, inputBounds, scrollSize, window, app);
                        final carets = result.cursorInfos;
                        final offset = result.scrollOffset;
                        final expectedOffset = target < minimum ? minimum : 0.;
                        assertEquals(expectedOffset, offset.x);
                        assertEquals(inputBounds.left() + expectedOffset, result.bounds.left());
                        if (target < minimum) {
                            assertBounds(expected[0].bounds, carets[0].bounds);
                        }
                        if (alignment == Right) {
                            assertTrue(carets[0].bounds.right() <= inputBounds.right());
                        }
                        editor.update(app, (state, cx) -> {
                            state.scrollSize = scrollSize;
                            state.updateScrollOffset(offset, cast cx);
                            assertEquals(expectedOffset, state.scrollHandle.offset().x);
                        });
                    }
                }
            }
            return null;
        });
    }

    function testDeferredHorizontalScrollMovesEveryCaret() {
        final opened = decorationEditor([for (_ in 0...80) 'wide text '].join(''), false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final layout = editor.read(app).lastLayout.clone();
            final inputBounds = editor.read(app).inputBounds;
            final scrollSize = new Size(inputBounds.size.width + 120., inputBounds.size.height);
            final element = new TextElement(base(editor));

            for (offsets in [[0, 2, 4], [0, 4, 2], [4, 0, 2]]) {
                editor.update(app, (state, _) -> {
                    state.selections.replaceAll([for (id in 0...offsets.length) new CursorSelection(new CursorId(id), offsets[id], offsets[id])]);
                    state.lastSelectedRange = state.activeSelection().copy();
                    state.scrollHandle.setOffset(new Point(0., 0.));
                    state.deferredScrollOffset = null;
                });
                final baseline = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;
                editor.update(app, (state, _) -> {
                    state.deferredScrollOffset = new Point(-60., 0.);
                });
                final result = element.layoutCursors(layout, inputBounds, scrollSize, window, app);
                assertEquals(-60., result.scrollOffset.x);
                assertEquals(3, result.cursorInfos.length);
                for (i in 0...baseline.length) {
                    assertFloatEquals(baseline[i].bounds.left() - 60., result.cursorInfos[i].bounds.left());
                }
            }
            return null;
        });
    }

    function testEditorLineNumberGutterResizesWithDocumentLines() {
        final opened = decorationEditor([for (_ in 0...8) 'x\n'].join(''), false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final narrow = editor.read(app).lastLayout.lineNumberWidth;

            final longerText = [for (_ in 0...99) 'x\n'].join('');
            editor.update(app, (state, cx) -> state.setValue(longerText, window, cast cx));
            window.draw();
            final middle = editor.read(app).lastLayout.lineNumberWidth;
            assertEquals(narrow, middle, 'one to three digits must share a width');

            final longestText = [for (_ in 0...999) 'x\n'].join('');
            editor.update(app, (state, cx) -> state.setValue(longestText, window, cast cx));
            window.draw();
            final wide = editor.read(app).lastLayout.lineNumberWidth;

            assertTrue(wide > narrow, 'more line-number digits must widen the gutter');
            return null;
        });
    }

    static function cornersCount(corners:Null<Array<CornersOf<Point>>>):Int {
        return corners == null ? 0 : corners.length;
    }

    function testGeometricDecorationsClipScrolledViewportAndCullOffscreenRanges() {
        final text = [for (_ in 0...100) 'abcdefghij\n'].join('');
        final textLen = Utf8.byteLength(text);
        final opened = decorationEditor(text, false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            editor.update(app, (state, cx) -> {
                state.createRangeDecorationsCollection([
                    new RangeDecoration(new Range(0, textLen)).withStyle(Fill),
                    new RangeDecoration(new Range(0, textLen)),
                    new RangeDecoration(new Range(0, 3)),
                    new RangeDecoration(new Range(textLen - 3, textLen)),
                ], cast cx);
            });
            window.draw();
            editor.update(app, (state, cx) -> {
                final height = state.lastLayout.lineHeight;
                state.setScrollOffset(new Point(0., -height * 40.), cast cx);
            });
            // Deferred scroll is committed by prepaint and reflected next frame.
            window.draw();
            window.draw();
            final state = editor.read(app);
            final layout = state.lastLayout;
            assertTrue(layout.visibleRangeOffset.start > 0);
            assertTrue(layout.visibleRangeOffset.end < textLen);
            final all = TextElement.layoutRangeCorners(new Range(0, textLen), layout);
            final clipped = TextElement.layoutRangeCorners(layout.visibleRangeOffset, layout);
            assertNotNull(all);
            assertEquals(all.length, clipped.length);
            for (i in 0...all.length) {
                assertTrue(all[i].equals(clipped[i], (a, b) -> a.equals(b)));
            }
            assertTrue(all.length > 0);
            assertNull(TextElement.layoutRangeCorners(new Range(0, 3), layout));
            // Also execute the production path building seam, not just the corner helper.
            final paths = new TextElement(base(editor)).layoutRangeDecorations(layout, state.inputBounds, window, state.inputBounds, app);
            assertEquals(1, paths.fills.length);
            assertEquals(1, paths.frames.length);
            return null;
        });
    }

    function testGeometricDecorationsUseShapedWrapBoundariesAndNewlineCells() {
        final text = '    héllo world héllo world héllo world héllo world\n\nlast';
        final textLen = Utf8.byteLength(text);
        final opened = decorationEditor(text, true);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            window.draw();
            final state = editor.read(app);
            final layout = state.lastLayout;
            final first = layout.lines[0];
            assertTrue(first.wrappedLines.length > 1);
            assertTrue(first.wrapIndent > 0.);
            final boundary = first.wrappedLines[0].len;
            final firstRow = TextElement.layoutRangeCorners(new Range(0, boundary), layout);
            assertEquals(1, cornersCount(firstRow), 'a wrap end must not open the next visual row');
            assertFloatEquals(first.wrappedLines[0].width, firstRow[0].topRight.x);
            final rest = TextElement.layoutRangeCorners(new Range(boundary, first.len()), layout);
            assertEquals(first.wrappedLines.length - 1, cornersCount(rest));
            assertFloatEquals(layout.visibleTop + layout.lineHeight, rest[0].topLeft.y);
            for (index in 0...rest.length) {
                final corners = rest[index];
                assertFloatEquals(first.wrapIndent + first.wrappedLines[index + 1].width, corners.topRight.x);
                assertFloatEquals(layout.lineHeight, corners.bottomLeft.y - corners.topLeft.y);
            }
            final blankOffset = Utf8.byteLength(text.substr(0, text.indexOf('\n\n'))) + 1;
            final blank = TextElement.layoutRangeCorners(new Range(blankOffset, blankOffset + 1), layout);
            assertEquals(1, cornersCount(blank));
            assertFloatEquals(layout.spaceWidth, blank[0].topRight.x - blank[0].topLeft.x);
            // A later-line decoration cannot paint the first row via saturating_sub.
            final lastOffset = Utf8.byteLength(text.substr(0, text.lastIndexOf('last')));
            final last = TextElement.layoutRangeCorners(new Range(lastOffset, textLen), layout);
            assertEquals(1, cornersCount(last));
            assertTrue(last[0].topLeft.y > rest[rest.length - 1].topLeft.y);
            return null;
        });
    }

    function testGeometricDecorationsIncludeCrlfBoundaries() {
        final text = 'one\r\ntwo\r\nthree';
        final opened = decorationEditor(text, false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            editor.update(app, (state, cx) -> {
                state.createRangeDecorationsCollection([
                    new RangeDecoration(new Range(0, 8)),
                    new RangeDecoration(new Range(3, 5)),
                    new RangeDecoration(new Range(4, 5)),
                    new RangeDecoration(new Range(5, 8)),
                    new RangeDecoration(new Range(9, 10)),
                ], cast cx);
            });
            window.draw();
            final state = editor.read(app);
            final layout = state.lastLayout;
            // Shaping retains '\r'; only '\n' needs an additional newline cell.
            assertEquals('one\r'.length, layout.lines[0].len());
            assertEquals('0,5,10', layout.visibleLineByteOffsets.join(','));
            final spanning = TextElement.layoutRangeCorners(new Range(0, 8), layout);
            assertEquals(2, cornersCount(spanning));
            for (range in [new Range(3, 5), new Range(4, 5), new Range(9, 10)]) {
                final corners = TextElement.layoutRangeCorners(range, layout);
                assertEquals(1, cornersCount(corners));
                assertTrue(corners[0].topRight.x > corners[0].topLeft.x);
            }
            final paths = new TextElement(base(editor)).layoutRangeDecorations(layout, state.inputBounds, window, state.inputBounds, app);
            assertEquals(0, paths.fills.length);
            assertEquals(5, paths.frames.length);
            return null;
        });
    }

    function testGeometricDecorationsProjectFoldsWithoutChangingTrackedRanges() {
        final text = 'top\nhidden one\nhidden two\nend\nlast';
        final opened = decorationEditor(text, false);
        final editor = opened.editor;
        opened.cx.update((window, app) -> {
            final hidden = new Range(4, text.indexOf('end'));
            final collection = editor.update(app, (state, cx) -> {
                state.applyHighlighterFoldCandidates([new FoldRange(0, 3)], cast cx);
                state.displayMap.setFolded(0, true);
                return state.createRangeDecorationsCollection([new RangeDecoration(hidden)], cast cx);
            });
            window.draw();
            {
                final state = editor.read(app);
                final layout = state.lastLayout;
                assertEquals('0,3,4', layout.visibleBufferLines.join(','));
                assertNull(TextElement.layoutRangeCorners(hidden, layout));
                final paths = new TextElement(base(editor)).layoutRangeDecorations(layout, state.inputBounds, window, state.inputBounds, app);
                assertEquals(0, paths.frames.length);
                final spanning = TextElement.layoutRangeCorners(new Range(0, text.length), layout);
                assertEquals(3, cornersCount(spanning));
                assertFloatEquals(spanning[0].bottomLeft.y, spanning[1].topLeft.y);
            }
            assertEquals('${hidden.start}..${hidden.end}', [for (r in collection.getRanges(app)) '${r.start}..${r.end}'].join(','));
            editor.update(app, (state, cx) -> {
                state.displayMap.setFolded(0, false);
                cx.notify();
            });
            window.draw();
            final state = editor.read(app);
            final layout = state.lastLayout;
            final revealed = TextElement.layoutRangeCorners(hidden, layout);
            assertEquals(2, cornersCount(revealed));
            assertEquals('${hidden.start}..${hidden.end}', [for (r in collection.getRanges(app)) '${r.start}..${r.end}'].join(','));
            return null;
        });
    }

    function testGeometricDecorationsTrackEditsHistoryReplacementAndOwnerLifetime() {
        final opened = decorationEditor('abc def', false);
        final editor = opened.editor;
        function ranges(collection:gpui.base.input.RangeDecorationCollection):String {
            return [for (r in collection.getRanges(app)) '${r.start}..${r.end}'].join(',');
        }
        opened.cx.update((window, app) -> {
            final collections = editor.update(app, (state, cx) -> [
                state.createRangeDecorationsCollection([new RangeDecoration(new Range(4, 7))], cast cx),
                state.createRangeDecorationsCollection([new RangeDecoration(new Range(0, 3))], cast cx),
            ]);
            final first = collections[0];
            final second = collections[1];
            editor.update(app, (state, cx) -> {
                state.setSelectedRange(new Range(0, 0), cast cx);
                state.replaceTextInRange(null, '\n', window, cast cx);
            });
            assertEquals('5..8', ranges(first));
            editor.update(app, (state, cx) -> state.undo(new Undo(), window, cast cx));
            assertEquals('4..7', ranges(first));
            editor.update(app, (state, cx) -> state.redo(new Redo(), window, cast cx));
            assertEquals('5..8', ranges(first));
            first.clear(app);
            assertEquals('1..4', ranges(second));
            first.append([new RangeDecoration(new Range(5, 8))], app);
            editor.update(app, (state, cx) -> state.replaceAll('formatted', window, cast cx));
            assertEquals('0..9', ranges(first));
            editor.update(app, (state, cx) -> state.undo(new Undo(), window, cast cx));
            // Annotations are transformed, not snapshotted in undo history.
            assertEquals('0..8', ranges(first));
            editor.update(app, (state, cx) -> state.setValue('new', window, cast cx));
            assertEquals('0..3', ranges(first));
            // Rust clones the handle before disposing it: the clone shares the
            // collection id, which the port's single handle stands for.
            final clone = first;
            first.dispose(app);
            clone.append([new RangeDecoration(new Range(0, 1))], app);
            assertEquals('', ranges(clone));
            assertEquals('0..3', ranges(second));
            editor.update(app, (state, cx) -> state.setValue('', window, cast cx));
            assertEquals('', ranges(second));
            window.draw();
            return null;
        });
    }

}
