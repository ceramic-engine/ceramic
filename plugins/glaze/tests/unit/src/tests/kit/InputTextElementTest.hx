// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.ListAlignment;
import glaze.ListOffset;
import glaze.ListState;
import glaze.MouseButton;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.TextAlign;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.Scrollbar;
import glaze.kit.base.input.CursorId;
import glaze.kit.base.input.CursorSelection;
import glaze.kit.base.input.EditorScrollbarContext;
import glaze.kit.base.input.InputActions.Redo;
import glaze.kit.base.input.InputActions.Undo;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.TextareaState;
import testing.InteractionScript.ScriptView;
import testing.VisualTestContext;
import glaze.Bounds;
import glaze.CornersOf;
import glaze.Edges;
import glaze.FontStyle;
import glaze.HighlightStyle;
import glaze.Point;
import glaze.Range;
import glaze.Size;
import glaze.TextRun;
import glaze.TextStyle;
import glaze.UnderlineStyle;
import glaze.kit.base.input.EditorScrollbarSnapshot.EditorScrollbarLayout;
import glaze.kit.base.input.StyledRange;
import glaze.kit.base.input.TextElement;
import glaze.util.Utf8;
import ropey.Rope;

import glaze.Prelude.*;

using StringTools;

/**
 * Tests of `glaze.kit.base.input.TextElement` (Rust `input/base/element.rs`).
 */
@:access(glaze.kit.base.input.TextElement)
@:access(glaze.kit.base.input.InputBaseState)
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

    /**
     * A 240x140 window with a textarea holding `text` (Rust `decoration_editor`,
     * with a textarea in place of gpui-kit's code editor).
     */
    function textareaView(text:String, wrap:Bool):{input:Entity<TextareaState>, cx:VisualTestContext} {
        app.update(cx -> Base.init(cx));
        var input:Entity<TextareaState> = null;
        final cx = openView(240., 140., (window, cx) -> {
            input = cx.newEntity(cx -> new TextareaState(window, cx).withSoftWrap(wrap).defaultValue(text));
            return (_, _) -> div().sizeFull().child(input);
        });
        return {input: input, cx: cx};
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

    static function runOfLen(len:Int, ?color:glaze.Hsla):TextRun {
        return new TextRun(len, glaze.Font.of('.SystemUIFont'), color != null ? color : black(), null, null, null);
    }

    static function lens(runs:Array<TextRun>):Array<Int> {
        return [for (run in runs) run.len];
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

    function testEditorScrollbarLayoutUsesCurrentScrollSize() {
        final inputBounds = new Bounds(new Point(10., 20.), new Size(300., 80.));
        final paddings = new Edges(2., 3., 5., 7.);

        // Rust's first case lays the track out right of a 40 px code editor
        // gutter, which inputs do not have.
        final layout = EditorScrollbarLayout.create(inputBounds, new Size(500., 120.), paddings);

        assertBounds(new Bounds(new Point(10., 18.), new Size(303., 87.)), layout.bounds);
        assertTrue(layout.scrollSize.equals(new Size(513., 120.)));
        assertTrue(layout.scrollViewportSize.equals(new Size(303., 80.)));
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
        final opened = textareaView(lines(0, 60), false);
        final input = opened.input;
        final cx = opened.cx;
        cx.update((window, app) -> {
            window.draw();
            final viewport = input.read(app).editorScrollbarSnapshot.layout.bounds;
            final textOrigin = input.read(app).lastBounds.origin;
            input.update(app, (state, cx) -> {
                state.setScrollBounce(true, cast cx);
                state.onScrollWheel(new ScrollEvent(new Point(), Pixels(new Point(0., 60.)), null, Started), window, cast cx);
            });
            window.draw();
            final state = input.read(app);
            final stretch = state.overscroll.offset();
            assertTrue(stretch > 0.);
            assertBounds(viewport, state.editorScrollbarSnapshot.layout.bounds);
            assertFloatEquals(textOrigin.y + stretch, state.lastBounds.origin.y);
            return null;
        });
    }

    /**
     * A scrollbar supplied through `setScrollbarRenderer` gets the input's own
     * scroll range through the standard ScrollbarHandle contract, so a
     * scrollbar can drag to the same end as wheel scrolling.
     */
    function testScrollbarRendererReceivesTheEditorsScrollRange() {
        final opened = textareaView(lines(0, 60), true);
        final input = opened.input;
        final cx = opened.cx;
        var presented:Null<EditorScrollbarContext> = null;
        cx.update((window, app) -> {
            input.update(app, (state, cx) -> {
                state.setScrollBounce(false, cast cx);
                state.setEditorPaddings(new Edges(10., 0., 10., 0.));
                state.setScrollbarRenderer((context, _, _) -> {
                    presented = context;
                    return Scrollbar.vertical(context).mode(Always).intoAnyElement();
                });
            });
            window.draw();
            input.update(app, (state, cx) -> {
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

        assertTrue(wheelEnd.equals(input.read(app).scrollOffset()), 'expected $wheelEnd, got ${input.read(app).scrollOffset()}');
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

    function testSelectionPathsFollowTheInputAndItsMenuFocus() {
        final opened = textareaView('alpha beta', false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            final menuFocus = app.focusHandle();
            final otherFocus = app.focusHandle();
            input.update(app, (state, cx) -> {
                state.setSelectedRange(new Range(0, 5), cast cx);
                state.focus(window, cast cx);
            });

            function selectionPaths():Int {
                window.draw();
                final state = input.read(app);
                final layout = state.lastLayout.clone();
                final bounds = state.inputBounds;
                return new TextElement(base(input)).layoutSelections(layout, bounds, window, app).length;
            }
            final focusedPaths = selectionPaths();
            assertTrue(focusedPaths > 0);

            input.update(app, (state, cx) -> state.setSelectionFocus(menuFocus, cast cx));
            menuFocus.focus(window, app);
            assertFalse(input.read(app).focusHandle.isFocused(window));
            assertEquals(focusedPaths, selectionPaths());
            // The opening frame can still use the input's old focus. Check
            // another frame with the menu already focused as well.
            assertEquals(focusedPaths, selectionPaths());

            otherFocus.focus(window, app);
            assertEquals(0, selectionPaths());
            assertTrue(new Range(0, 5).equals(input.read(app).selectedRange()));

            menuFocus.focus(window, app);
            input.update(app, (state, cx) -> state.setSelectionFocus(null, cast cx));
            assertEquals(0, selectionPaths());
            input.update(app, (state, cx) -> state.focus(window, cast cx));
            assertEquals(focusedPaths, selectionPaths());

            // Not ported: "retaining the input must not keep a removed menu
            // alive" drops the last strong focus handle and checks the weak
            // one no longer upgrades, which the garbage collected port cannot
            // trigger deterministically.
            return null;
        });
    }

    function testHorizontalScrollIsClampedBeforeTextAndCaretLayout() {
        final opened = textareaView('short text', false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            window.draw();
            final state = input.read(app);
            final layout = state.lastLayout.clone();
            final inputBounds = state.inputBounds;
            final scrollSize = inputBounds.size;
            final element = new TextElement(base(input));
            final baseline = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;

            // Both a stale offset after deletion and a deferred scroll target must
            // be limited before either text or carets are positioned this frame.
            for (deferred in ([null, new Point(-80., 0.)] : Array<Null<Point>>)) {
                input.update(app, (state, _) -> {
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
                input.update(app, (state, cx) -> {
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
    function assertHorizontalScrollReachesLineEnd(input:Entity<TextareaState>, end:Int, window:Window, app:App, ?pos:haxe.PosInfos) {
        final state = input.read(app);
        final layout = state.lastLayout.clone();
        final inputBounds = state.inputBounds;
        final scrollSize = state.scrollSize;

        input.update(app, (state, cx) -> {
            state.setSelectedRange(new Range(end, end), cast cx);
            state.deferredScrollOffset = new Point(-1000000., 0.);
        });

        final element = new TextElement(base(input));
        final result = element.layoutCursors(layout, inputBounds, scrollSize, window, app);
        assertTrue(result.cursorInfos.length > 0, 'a caret', pos);
        final caret = result.cursorInfos[0].bounds;
        assertTrue(caret.left() <= inputBounds.right() + 1.,
            'scrolling to the end (${result.scrollOffset}) leaves the caret at $caret past ${inputBounds.right()}', pos);
    }

    function testHorizontalScrollExtentExcludesPlaceholder() {
        final opened = textareaView('', false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            window.draw();
            final emptyWidth = input.read(app).scrollSize.width;

            for (placeholder in [''.lpad('W', 300), 'Short hint']) {
                input.update(app, (state, cx) -> state.setPlaceholder(placeholder, window, cast cx));
                window.draw();
                assertEquals(emptyWidth, input.read(app).scrollSize.width, 'placeholder must not create horizontal scrollable content');
            }
            return null;
        });
    }

    function testHorizontalScrollExtentCoversTheWidestLaidOutLine() {
        // The first line is longest by bytes, but the second renders wider.
        final narrow = 'e' + ''.lpad('́', 200);
        final wide = ''.lpad('W', 300);
        final text = '$narrow\n$wide';
        final opened = textareaView(text, false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            window.draw();
            assertHorizontalScrollReachesLineEnd(input, Utf8.byteLength(text), window, app);

            // Editing the wider line invalidates the cached measurement.
            final wider = ''.lpad('W', 400);
            final edited = '$narrow\n$wider';
            input.update(app, (state, cx) -> state.setValue(edited, window, cast cx));
            window.draw();
            assertHorizontalScrollReachesLineEnd(input, Utf8.byteLength(edited), window, app);

            // A larger font must widen the extent instead of reusing the old
            // measurement.
            final before = input.read(app).scrollSize.width;
            window.setRemSize(24.);
            window.draw();
            final after = input.read(app).scrollSize.width;
            assertTrue(after > before, 'growing the font should widen the scroll extent: $after > $before');
            assertHorizontalScrollReachesLineEnd(input, Utf8.byteLength(edited), window, app);
            return null;
        });
    }

    function testAlignedHorizontalScrollClampsDeferredTargets() {
        final opened = textareaView([for (_ in 0...80) 'wide text '].join(''), false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            window.draw();
            final layout = input.read(app).lastLayout.clone();
            final inputBounds = input.read(app).inputBounds;
            final element = new TextElement(base(input));

            for (alignment in [TextAlign.Left, TextAlign.Right, TextAlign.Center]) {
                layout.textAlign = alignment;
                for (overflow in [0., 120.]) {
                    final scrollSize = new Size(inputBounds.size.width + overflow, inputBounds.size.height);
                    final minimum = alignment == Left ? -overflow : -overflow - TextElement.CURSOR_WIDTH;
                    input.update(app, (state, _) -> {
                        state.textAlign = alignment;
                        state.lastSelectedRange = state.activeSelection().copy();
                        state.deferredScrollOffset = new Point(minimum, 0.);
                    });
                    final expected = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;

                    for (target in [minimum - 100., 100.]) {
                        input.update(app, (state, _) -> {
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
                        input.update(app, (state, cx) -> {
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
        final opened = textareaView([for (_ in 0...80) 'wide text '].join(''), false);
        final input = opened.input;
        opened.cx.update((window, app) -> {
            window.draw();
            final layout = input.read(app).lastLayout.clone();
            final inputBounds = input.read(app).inputBounds;
            final scrollSize = new Size(inputBounds.size.width + 120., inputBounds.size.height);
            final element = new TextElement(base(input));

            for (offsets in [[0, 2, 4], [0, 4, 2], [4, 0, 2]]) {
                input.update(app, (state, _) -> {
                    state.selections.replaceAll([for (id in 0...offsets.length) new CursorSelection(new CursorId(id), offsets[id], offsets[id])]);
                    state.lastSelectedRange = state.activeSelection().copy();
                    state.scrollHandle.setOffset(new Point(0., 0.));
                    state.deferredScrollOffset = null;
                });
                final baseline = element.layoutCursors(layout, inputBounds, scrollSize, window, app).cursorInfos;
                input.update(app, (state, _) -> {
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

}
