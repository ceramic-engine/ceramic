// New code for Cityscape (not a port): the horizontal scrollbar of the
// editor, the drag of a selection outside the editor (mouseHandler.ts
// `_onMouseDownThenMove`, `TopBottomDragScrolling`), the horizontal scroll of
// the wheel and the horizontal reveal of the cursor (viewLines.ts
// `_computeScrollLeftToReveal`). The layout test is vscode's
// editorLayoutProvider.test.ts 'EditorLayoutProvider 1.1'.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.view.CityscapeView;
import cityscape.view.config.EditorConfiguration.ComputedEditorOptions;
import glaze.App;
import glaze.Hsla;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;

import glaze.Prelude.*;

class HorizontalScrollTest extends TestCase {

    var app:App;
    var dispatcher:TestDispatcher;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    /** The editor's place in the window (`HorizontalScrollTestHost`): 100 px on the left and the right, 50 above and below. */
    static inline final MARGIN_X:Float = 100;
    static inline final MARGIN_Y:Float = 50;

    override public function setup():Void {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        context = new Cityscape();
        glaze.kit.theme.Theme.setScrollbarMode(Always, app);
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        editor = null;
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    /** An editor of 600 by 300 pixels, in a window of 800 by 400 (scale 1). */
    function open(text:String, options:IEditorOptions):CityscapeEditor {
        final model:ITextModel = instantiateTextModel(context, text);
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 1, autoDraw: false, bindInput: false},
            HorizontalScrollTestHost.component(model, options, e -> editor = e));
        draw();
        draw();
        return editor;
    }

    static function longLine(words:Int):String {
        return [for (i in 0...words) 'word$i'].join(' ');
    }

    static function sameColor(q:glaze.scene.Quad, c:Hsla):Bool {
        return Math.abs(q.backgroundSolidH - c.h) < 0.0001 && Math.abs(q.backgroundSolidS - c.s) < 0.0001
            && Math.abs(q.backgroundSolidL - c.l) < 0.0001 && Math.abs(q.backgroundSolidA - c.a) < 0.0001;
    }

    /** The thumb quads of the horizontal scrollbar: the slider color, 8 px high (the kit's default thumb), in the 12 px band at the bottom. */
    function horizontalThumbs(e:CityscapeEditor):Array<glaze.scene.Quad> {
        final color = cityscape.view.EditorWidgets.color(e.getEditor(), 'scrollbarSlider.background', hsla(0, 0, 0, 0));
        final bottom = MARGIN_Y + 300;
        return [for (q in window.renderedScene().quads) if (sameColor(q, color) && q.boundsHeight == 8 && q.boundsY >= bottom - 12 && q.boundsY + q.boundsHeight <= bottom) q];
    }

    /**
     * vscode editorLayoutProvider.test.ts 'EditorLayoutProvider 1.1': the
     * layout keeps `horizontalScrollbarHeight` (`horizontalScrollbarSize`)
     * and the viewport its whole height (Monaco's horizontal scrollbar lies
     * over the bottom of the text area; viewLayout.ts adds its height to the
     * content height instead, without `scrollBeyondLastLine`).
     */
    function testLayoutInfoLikeMonaco() {
        final options = new ComputedEditorOptions();
        options._write(EditorOption.glyphMargin, false);
        options._write(EditorOption.lineNumbersMinChars, 0);
        options._write(EditorOption.lineDecorationsWidth, 10);
        options._write(EditorOption.folding, false);
        options._write(EditorOption.showFoldingControls, 'mouseover');
        options._write(EditorOption.padding, {top: 0, bottom: 0});
        options._write(EditorOption.scrollbar, new EditorScrollbar().validate({
            arrowSize: 13,
            verticalHasArrows: true,
            horizontalHasArrows: false,
            horizontalScrollbarSize: 12,
            verticalScrollbarSize: 11
        }));
        options._write(EditorOption.lineNumbers, {renderType: RenderLineNumbersType.Off, renderFn: null});
        options._write(EditorOption.wordWrap, 'off');
        options._write(EditorOption.wordWrapColumn, 80);
        options._write(EditorOption.wordWrapOverride1, 'inherit');
        options._write(EditorOption.wordWrapOverride2, 'inherit');
        final actual = EditorLayoutInfoComputer.computeLayout(options, {
            memory: null,
            outerWidth: 1000,
            outerHeight: 800,
            isDominatedByLongLines: false,
            lineHeight: 16,
            viewLineCount: 9,
            lineNumbersDigitCount: 1,
            typicalHalfwidthCharacterWidth: 10,
            maxDigitWidth: 10,
            pixelRatio: 1,
            glyphMarginDecorationLaneCount: 1
        });
        assertEquals(1000.0, actual.width);
        assertEquals(800.0, actual.height);
        assertEquals(10.0, actual.contentLeft);
        assertEquals(990.0, actual.contentWidth);
        assertEquals(97, actual.viewportColumn);
        assertEquals(false, actual.isViewportWrapping);
        assertEquals(11.0, actual.verticalScrollbarWidth);
        assertEquals(12.0, actual.horizontalScrollbarHeight);
        assertEquals(13.0, actual.overviewRuler.top);
        assertEquals(11.0, actual.overviewRuler.width);
        assertEquals(800.0 - 2 * 13, actual.overviewRuler.height);
    }

    /**
     * The scrollbar shows only when the content is wider than the viewport
     * (Monaco's `scroll width` is the widest line plus
     * `scrollBeyondLastColumn` characters and the vertical scrollbar), never
     * with word wrap, never with `scrollbar.horizontal: 'hidden'`; the
     * viewport keeps its height, the layout has Monaco's
     * `horizontalScrollbarHeight` (12 in the standalone editor) and the
     * content height grows by it without `scrollBeyondLastLine`
     * (viewLayout.ts `_getContentHeight`).
     */
    function testShownOnlyWhenContentIsWider() {
        final e = open('short\nlines', {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        assertFalse(v.isHorizontalScrollbarShown());
        assertEquals(0, horizontalThumbs(e).length);
        final layoutInfo = e.getLayoutInfo();
        assertEquals(12.0, layoutInfo.horizontalScrollbarHeight);
        assertEquals(300.0, layoutInfo.height);

        e.setValue('short\n' + longLine(60));
        draw();
        draw();
        assertTrue(v.isHorizontalScrollbarShown());
        final thumbs = horizontalThumbs(e);
        assertEquals(1, thumbs.length);
        assertEquals(300.0, e.getLayoutInfo().height, 'the viewport keeps its height');
        // the content height with the scrollbar's band (no scrollBeyondLastLine)
        e.updateOptions({scrollBeyondLastLine: false});
        draw();
        final lineHeight:Float = e.getOption(EditorOption.lineHeight);
        assertEquals(2 * lineHeight + 12, v.viewModel.viewLayout.getContentHeight());

        e.updateOptions({wordWrap: 'on'});
        draw();
        draw();
        assertFalse(v.isHorizontalScrollbarShown());
        assertEquals(0, horizontalThumbs(e).length);

        e.updateOptions({wordWrap: 'off', scrollbar: {horizontal: 'hidden'}});
        draw();
        draw();
        assertFalse(v.isHorizontalScrollbarShown());
        assertEquals(0, horizontalThumbs(e).length);
        assertEquals(2 * lineHeight, v.viewModel.viewLayout.getContentHeight());
    }

    /**
     * The thumb (the kit's shape in the editor's colors, the kit's default
     * 8 px thumb in the 12 px band, 2 px from the bottom) has Monaco's ratios: its track goes from
     * the content's left to the vertical scrollbar (scrollbarState.ts:126,
     * `visibleSize - oppositeScrollbarSize`), its length is the viewport over
     * the scroll width of that track, and it reaches the track's end at the
     * last scroll position.
     */
    function testThumbGeometry() {
        final e = open('short\n' + longLine(60), {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layoutInfo = e.getLayoutInfo();
        final layout = v.viewModel.viewLayout;
        final track = layoutInfo.contentWidth - 14;
        assertEquals(track, v.horizontalScrollHandle.trackLength());
        final thumb = horizontalThumbs(e)[0];
        final left = MARGIN_X + layoutInfo.contentLeft;
        final length = Math.max(layoutInfo.contentWidth / layout.getScrollWidth() * track, 48);
        assertTrue(Math.abs(thumb.boundsX - (left + 2)) < 0.5, 'starts at the content left: ' + thumb.boundsX);
        assertTrue(Math.abs(thumb.boundsWidth - (length - 4)) < 0.5, 'length ' + thumb.boundsWidth + ' for ' + (length - 4));
        assertEquals(MARGIN_Y + 300 - 2 - 8, thumb.boundsY);
        // at the end of the scroll range, the thumb ends at the track's end
        layout.setScrollPosition({scrollLeft: layout.getScrollWidth()}, cityscape.common.EditorCommon.ScrollType.Immediate);
        draw();
        final end = horizontalThumbs(e)[0];
        assertTrue(Math.abs(end.boundsX + end.boundsWidth - (left + track - 2)) < 0.5, 'ends at the vertical scrollbar: ' + (end.boundsX + end.boundsWidth));
    }

    /** Dragging the thumb scrolls by the content over the track; a click on the track centers the thumb there. */
    function testThumbDragAndTrackClick() {
        final e = open('short\n' + longLine(60), {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layout = v.viewModel.viewLayout;
        final layoutInfo = e.getLayoutInfo();
        final track = v.horizontalScrollHandle.trackLength();
        final thumb = horizontalThumbs(e)[0];
        final y = thumb.boundsY + 3;
        final x0 = thumb.boundsX + 10;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(x0, y)), app);
        window.dispatchEvent(new MouseMoveEvent(point(x0 + 50, y), MouseButton.Left), app);
        draw();
        final scrollRange = layout.getScrollWidth() - layoutInfo.contentWidth;
        final thumbTravel = track - (thumb.boundsWidth + 4);
        final expected = 50 / thumbTravel * scrollRange;
        assertTrue(Math.abs(layout.getCurrentScrollLeft() - expected) < 2, 'drag: ' + layout.getCurrentScrollLeft() + ' for ' + expected);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(x0 + 50, y)), app);
        draw();
        assertEquals('[1,1 -> 1,1]', e.getSelection().toString(), 'the selection does not move');
        // a click on the track at its right end: the last position
        final endX = MARGIN_X + layoutInfo.contentLeft + track - 2;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(endX, y)), app);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(endX, y)), app);
        draw();
        assertTrue(Math.abs(layout.getCurrentScrollLeft() - scrollRange) < 1, 'track click: ' + layout.getCurrentScrollLeft());
        // and at its left end: the start
        final startX = MARGIN_X + layoutInfo.contentLeft + 2;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(startX, y)), app);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(startX, y)), app);
        draw();
        assertEquals(0.0, layout.getCurrentScrollLeft());
        assertEquals('[1,1 -> 1,1]', e.getSelection().toString());
    }

    /**
     * mouseHandler.ts:516 `_getPositionOutsideEditor`: a drag past the
     * right edge of the editor selects to the end of the line beside the
     * mouse and reveals it (the minimal reveal scrolls to it); past the
     * left edge to its start.
     */
    function testDragPastTheRightEdgeScrolls() {
        final text = 'short\n' + longLine(60) + '\nend';
        final e = open(text, {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layout = v.viewModel.viewLayout;
        final layoutInfo = e.getLayoutInfo();
        final lineHeight:Float = e.getOption(EditorOption.lineHeight);
        final y = MARGIN_Y + lineHeight * 1.5;
        final x = MARGIN_X + layoutInfo.contentLeft + 5;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(x, y)), app);
        draw();
        // inside, near the right edge: the column under the mouse
        window.dispatchEvent(new MouseMoveEvent(point(MARGIN_X + 590, y), MouseButton.Left), app);
        draw();
        final inside = e.getSelection();
        assertEquals(2, inside.positionLineNumber);
        assertTrue(inside.positionColumn > 1 && inside.positionColumn < longLine(60).length + 1);
        // outside on the right: the end of the line, scrolled to it
        window.dispatchEvent(new MouseMoveEvent(point(MARGIN_X + 650, y), MouseButton.Left), app);
        draw();
        final maxColumn = longLine(60).length + 1;
        assertEquals('[2,2 -> 2,$maxColumn]', e.getSelection().toString());
        final atEnd = layout.getCurrentScrollLeft();
        assertTrue(atEnd > 0, 'scrolled right');
        final endX = v.renderViewLine(2).columnToX(maxColumn);
        assertTrue(endX >= atEnd && endX <= atEnd + layoutInfo.contentWidth - 14, 'the end of the line in the viewport');
        // outside on the left: the start of the line, scrolled back
        window.dispatchEvent(new MouseMoveEvent(point(MARGIN_X - 30, y), MouseButton.Left), app);
        draw();
        assertEquals('[2,2 -> 2,1]', e.getSelection().toString());
        assertEquals(0.0, layout.getCurrentScrollLeft());
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(MARGIN_X - 30, y)), app);
        draw();
        assertFalse(v.isMouseDown(), 'the mouse up outside ends the drag');
    }

    /**
     * mouseHandler.ts:631 `TopBottomDragScrolling`: held below the editor,
     * the drag scrolls down again at every frame by `_getScrollSpeed` lines
     * per second for the time elapsed, selecting to the last visible line;
     * above, up to the first visible line. It stops when the mouse comes
     * back in, and at the mouse up.
     */
    function testDragBelowAndAboveScrollsRepeatedly() {
        final text = [for (i in 1...201) 'line $i'].join('\n');
        final e = open(text, {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layout = v.viewModel.viewLayout;
        final layoutInfo = e.getLayoutInfo();
        final lineHeight:Float = e.getOption(EditorOption.lineHeight);
        final x = MARGIN_X + layoutInfo.contentLeft + 20;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(x, MARGIN_Y + lineHeight / 2)), app);
        draw();
        // 10 px below the editor (less than 1.5 lines): max(30, viewport lines * (1 + d))
        final outside = 10.;
        window.dispatchEvent(new MouseMoveEvent(point(x, MARGIN_Y + 300 + outside), MouseButton.Left), app);
        assertNotNull(v.topBottomDragScrolling);
        assertEquals('below', v.topBottomDragScrolling.position.outsidePosition);
        final speed = Math.max(30, (300 / lineHeight) * (1 + outside / lineHeight));
        draw();
        final start = layout.getCurrentScrollTop();
        dispatcher.advanceClock(0.1);
        window.simulateNextFrame(app);
        draw();
        final first = layout.getCurrentScrollTop();
        final expected = speed * 0.1 * lineHeight;
        assertTrue(Math.abs(first - start - expected) < 1.5, 'scrolled ' + (first - start) + ' for ' + expected);
        // held still: scrolls again at the next frames
        dispatcher.advanceClock(0.1);
        window.simulateNextFrame(app);
        draw();
        final second = layout.getCurrentScrollTop();
        assertTrue(second > first + expected - 1.5, 'scrolls again while held: ' + second);
        final viewportData = layout.getLinesViewportData();
        final selection = e.getSelection();
        assertEquals(1, selection.selectionStartLineNumber);
        assertTrue(selection.positionLineNumber >= viewportData.endLineNumber - 1 && selection.positionLineNumber <= viewportData.endLineNumber,
            'selected to the last visible line: ' + selection + ' ' + viewportData.endLineNumber);

        // above the editor: scrolls up, to the first visible line
        window.dispatchEvent(new MouseMoveEvent(point(x, MARGIN_Y - 10), MouseButton.Left), app);
        assertEquals('above', v.topBottomDragScrolling.position.outsidePosition);
        draw();
        final top0 = layout.getCurrentScrollTop();
        dispatcher.advanceClock(0.1);
        window.simulateNextFrame(app);
        draw();
        final top1 = layout.getCurrentScrollTop();
        assertTrue(top1 < top0, 'scrolls up: ' + top0 + ' -> ' + top1);
        final up = e.getSelection();
        assertEquals(layout.getLinesViewportData().startLineNumber, up.positionLineNumber);
        assertEquals(1, up.positionColumn);

        // back inside: the scrolling stops
        window.dispatchEvent(new MouseMoveEvent(point(x, MARGIN_Y + 100), MouseButton.Left), app);
        assertNull(v.topBottomDragScrolling);
        draw();
        final still = layout.getCurrentScrollTop();
        dispatcher.advanceClock(0.1);
        window.simulateNextFrame(app);
        draw();
        assertEquals(still, layout.getCurrentScrollTop());

        // below again, then the mouse up (outside the editor) stops it
        window.dispatchEvent(new MouseMoveEvent(point(x, MARGIN_Y + 320), MouseButton.Left), app);
        assertNotNull(v.topBottomDragScrolling);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(x, MARGIN_Y + 320)), app);
        assertNull(v.topBottomDragScrolling);
        draw();
        final after = layout.getCurrentScrollTop();
        dispatcher.advanceClock(0.1);
        window.simulateNextFrame(app);
        draw();
        assertEquals(after, layout.getCurrentScrollTop());
    }

    /** `_getScrollSpeed`, mouseHandler.ts:711, for the three distances. */
    function testScrollSpeed() {
        final target = new cityscape.view.CityscapeView.OutsideEditorTarget(1, new Position(1, 1), 'below', 0);
        final op = new cityscape.view.CityscapeView.TopBottomDragScrollingOperation(null, null, target, 0, 0);
        // a viewport of 20 lines of 15 px
        op.setPosition(new cityscape.view.CityscapeView.OutsideEditorTarget(1, new Position(1, 1), 'below', 15), 0);
        assertEquals(40.0, op.getScrollSpeed(15, 300));
        op.setPosition(new cityscape.view.CityscapeView.OutsideEditorTarget(1, new Position(1, 1), 'below', 0), 0);
        assertEquals(30.0, op.getScrollSpeed(15, 300));
        op.setPosition(new cityscape.view.CityscapeView.OutsideEditorTarget(1, new Position(1, 1), 'below', 45), 0);
        assertEquals(100.0, op.getScrollSpeed(15, 300));
        op.setPosition(new cityscape.view.CityscapeView.OutsideEditorTarget(1, new Position(1, 1), 'below', 150), 0);
        assertEquals(340.0, op.getScrollSpeed(15, 300));
        assertEquals(1000.0, op.tick(1));
    }

    /**
     * The wheel: a horizontal delta scrolls horizontally, Shift turns a
     * vertical one into a horizontal one, and a diagonal trackpad scroll
     * goes along its predominant axis only (scrollableElement.ts:408
     * `scrollPredominantAxis`).
     */
    function testWheelScrollsHorizontally() {
        final text = [for (i in 1...101) 'line $i ' + longLine(40)].join('\n');
        final e = open(text, {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layout = v.viewModel.viewLayout;
        final at = point(MARGIN_X + 300, MARGIN_Y + 150);
        window.dispatchEvent(new ScrollEvent(at, ScrollDelta.Pixels(point(-40, 0))), app);
        draw();
        assertEquals(40.0, layout.getCurrentScrollLeft());
        assertEquals(0.0, layout.getCurrentScrollTop());
        window.dispatchEvent(new ScrollEvent(at, ScrollDelta.Pixels(point(0, -30)), Modifiers.shiftKey()), app);
        draw();
        assertEquals(70.0, layout.getCurrentScrollLeft());
        assertEquals(0.0, layout.getCurrentScrollTop());
        // diagonal: the predominant axis only
        window.dispatchEvent(new ScrollEvent(at, ScrollDelta.Pixels(point(-5, -50))), app);
        draw();
        assertEquals(70.0, layout.getCurrentScrollLeft());
        assertEquals(50.0, layout.getCurrentScrollTop());
        window.dispatchEvent(new ScrollEvent(at, ScrollDelta.Pixels(point(-20, -3))), app);
        draw();
        assertEquals(90.0, layout.getCurrentScrollLeft());
        assertEquals(50.0, layout.getCurrentScrollTop());
    }

    /**
     * Typing at the end of a long line reveals the cursor horizontally
     * (viewLines.ts:766 `_computeScrollLeftToReveal`): the cursor stays
     * `revealHorizontalRightPadding` (15) pixels left of the vertical
     * scrollbar; going back to the start of the line scrolls back to 0.
     */
    function testTypingRevealsTheCursorHorizontally() {
        final e = open('short\n' + longLine(60), {wordWrap: 'off'});
        final v:CityscapeView = e.getView();
        final layout = v.viewModel.viewLayout;
        final layoutInfo = e.getLayoutInfo();
        final maxColumn = longLine(60).length + 1;
        e.setPosition(new Position(2, maxColumn));
        draw();
        v.type('!');
        draw();
        final column = maxColumn + 1;
        final x = Math.round(v.renderViewLine(2).columnToX(column));
        final viewportEnd = layoutInfo.contentWidth - layoutInfo.verticalScrollbarWidth;
        assertEquals(Math.max(0, x + 15 - viewportEnd), layout.getCurrentScrollLeft());
        assertTrue(layout.getCurrentScrollLeft() > 0);
        // the cursor's x is in the viewport, left of the vertical scrollbar
        assertTrue(x > layout.getCurrentScrollLeft() && x < layout.getCurrentScrollLeft() + viewportEnd);
        e.setPosition(new Position(2, 1));
        e.revealPosition(new Position(2, 1));
        draw();
        assertEquals(0.0, layout.getCurrentScrollLeft());
    }

}

/**
 * An editor of 600 by 300 pixels with 100 pixels left and right and 50
 * above and below in its window of 800 by 400, for the drags outside it.
 */
class HorizontalScrollTestHost extends glaze.Component {

    final model:ITextModel;
    final options:IEditorOptions;
    final onEditor:(editor:CityscapeEditor) -> Void;

    public function new(model:ITextModel, options:IEditorOptions, onEditor:(editor:CityscapeEditor) -> Void) {
        super();
        this.model = model;
        this.options = options;
        this.onEditor = onEditor;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull().pl(px(100)).pr(px(100)).pt(px(50)).pb(px(50))
            .child(CityscapeEditor.component().model(model).options(options).onCreate(onEditor).flex1());
    }

}
