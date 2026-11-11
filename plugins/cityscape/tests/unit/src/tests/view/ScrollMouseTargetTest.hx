// New code for Cityscape (not a port): the mouse target is computed again
// after a scroll without a mouse move. Monaco does nothing itself: Chromium
// marks the hover state dirty when a scroller moves and sends a synthetic
// `mousemove` to the page at the next frame, which `MouseHandler._onMouseMove`
// receives like a real move (the cursor of a view zone or of a link under
// Cmd follows the text that scrolled under the mouse, the `onMouseMove`
// listeners run once). Cityscape does the same from the view's scroll change
// event, once per frame, when the mouse is inside the editor.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeDiffEditor;
import cityscape.CityscapeEditor;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.contrib.links.view.Links.LinkDetector;
import cityscape.view.CityscapeView;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import glaze.App;
import glaze.CursorStyle;
import glaze.Modifiers;
import glaze.MouseMoveEvent;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.TestTextModel.instantiateTextModel;
import tests.view.DiffEditorTest.DiffHost;
import tests.view.EditorFontsTest.EditorFontsTestHost;

import glaze.Prelude.*;

class ScrollMouseTargetTest extends TestCase {

    var app:App;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
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

    function lines(count:Int):Array<String> {
        return [for (i in 1...count + 1) 'line ' + i];
    }

    function openEditor(text:String, options:IEditorOptions):CityscapeEditor {
        final model:ITextModel = instantiateTextModel(context, text);
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 1, autoDraw: false, bindInput: false},
            EditorFontsTestHost.component(model, options, e -> editor = e));
        draw();
        draw();
        return editor;
    }

    /**
     * A side by side diff whose modified editor has a diagonal fill zone of
     * ten lines after its line 20 (lines 21 to 30 of the original deleted).
     */
    function openDiff():CityscapeDiffEditor {
        final original = createTextModel(lines(60).join('\n'));
        final modifiedLines = lines(60);
        modifiedLines.splice(20, 10);
        final modified = createTextModel(modifiedLines.join('\n'));
        var diffEditor:Null<CityscapeDiffEditor> = null;
        window = Window.open(app, {width: 1200, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false},
            DiffHost.component([{original: original, modified: modified}], {hideUnchangedRegions: {enabled: false}}, e -> diffEditor = e));
        draw();
        draw();
        diffEditor.getWidget()._flush();
        draw();
        final m:CodeEditorWidget = cast diffEditor.getModifiedEditor().getEditor();
        final lineHeight:Float = m.getOption(EditorOption.lineHeight);
        final whitespaces = m.getWhitespaces();
        assertEquals(1, whitespaces.length);
        assertEquals(20, whitespaces[0].afterLineNumber);
        assertEquals(10 * lineHeight, whitespaces[0].height);
        return diffEditor;
    }

    function moveTo(x:Float, y:Float, ?modifiers:Modifiers):Void {
        window.dispatchEvent(new MouseMoveEvent(point(x, y), null, modifiers), app);
        draw();
    }

    /**
     * A wheel scroll of `lines` lines at the mouse (down when positive), then
     * one frame, no mouse move.
     */
    function wheel(x:Float, y:Float, lines:Float, lineHeight:Float, ?modifiers:Modifiers):Void {
        window.dispatchEvent(new ScrollEvent(point(x, y), ScrollDelta.Pixels(point(0, -lines * lineHeight)), modifiers), app);
        draw();
    }

    /**
     * The mouse over the text of the modified editor, a wheel scroll brings
     * the diagonal fill zone under it: the arrow in the next frame without a
     * mouse move; scrolled back, the text and the I-beam again.
     */
    function testWheelScrollBringsAZoneUnderTheMouse() {
        final diffEditor = openDiff();
        final m:CodeEditorWidget = cast diffEditor.getModifiedEditor().getEditor();
        final view:CityscapeView = diffEditor.getModifiedEditor().getView();
        final b = view.elementBounds;
        final lineHeight:Float = m.getOption(EditorOption.lineHeight);
        final x = b.origin.x + m.getLayoutInfo().contentLeft + 30;
        final y = b.origin.y + 2.5 * lineHeight;
        moveTo(x, y);
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'line 3');
        // scrollTop 19 lines: vertical offset 21.5 lines at the mouse, in the
        // zone (20 to 30 lines)
        wheel(x, y, 19, lineHeight);
        assertEquals(19 * lineHeight, m.getScrollTop());
        assertEquals(CursorStyle.Arrow, window.cursorStyle(), 'the zone under the still mouse');
        assertEquals(CursorStyle.Arrow, view.zoneMouseCursor);
        wheel(x, y, -19, lineHeight);
        assertEquals(0., m.getScrollTop());
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'the text again');
        assertEquals(null, view.zoneMouseCursor);
    }

    /**
     * Programmatic scrolls: `setScrollTop` brings the zone under the mouse,
     * `revealLineInCenter` the text.
     */
    function testProgrammaticScrollBringsAZoneUnderTheMouse() {
        final diffEditor = openDiff();
        final m:CodeEditorWidget = cast diffEditor.getModifiedEditor().getEditor();
        final view:CityscapeView = diffEditor.getModifiedEditor().getView();
        final b = view.elementBounds;
        final lineHeight:Float = m.getOption(EditorOption.lineHeight);
        final x = b.origin.x + m.getLayoutInfo().contentLeft + 30;
        final y = b.origin.y + 2.5 * lineHeight;
        moveTo(x, y);
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'line 3');
        m.setScrollTop(19 * lineHeight);
        draw();
        assertEquals(CursorStyle.Arrow, window.cursorStyle(), 'the zone after setScrollTop');
        m.revealLineInCenter(3);
        draw();
        assertEquals(0., m.getScrollTop());
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'the text after the reveal');
        // a scroll while the mouse is outside the editor changes nothing
        // and fires no mouse move
        var moves = 0;
        final subscription = m.onMouseMove(_ -> moves++);
        moveTo(-10, -10);
        assertFalse(view.mouseInside);
        m.setScrollTop(19 * lineHeight);
        draw();
        assertEquals(0, moves);
        assertEquals(null, view.zoneMouseCursor);
        subscription.dispose();
    }

    /**
     * A link detected on line 30, Cmd held: the hand when the scroll brings
     * it under the mouse (Monaco's link gesture resets on scroll, the
     * synthetic move activates the link again), the I-beam when the scroll
     * takes it away.
     */
    function testLinkUnderCmdAfterScroll() {
        final text = lines(60);
        text[29] = 'see http://foo.bar here';
        final e = openEditor(text.join('\n'), {links: true});
        final widget:CodeEditorWidget = cast e.getEditor();
        final detector = LinkDetector.get(widget);
        assertNotNull(detector);
        detector._flushComputeLinks();
        assertEquals(1, detector.getLinkDecorations().length);
        final view:CityscapeView = e.getView();
        final b = view.elementBounds;
        final lineHeight:Float = widget.getOption(EditorOption.lineHeight);
        // Cmd and Ctrl together: the trigger modifier of every platform
        final cmd = Modifiers.of(true, false, false, true);
        final x = b.origin.x + widget.getLayoutInfo().contentLeft + view.renderViewLine(30).columnToX(8) + 1;
        final y = b.origin.y + 2.5 * lineHeight;
        moveTo(x, y, cmd);
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'line 3 under Cmd: no link');
        assertEquals(null, view.mouseCursor);
        // scrollTop 27 lines: line 30 at the mouse
        wheel(x, y, 27, lineHeight, cmd);
        assertEquals(27 * lineHeight, widget.getScrollTop());
        window.drawIfDirty();
        assertEquals(CursorStyle.PointingHand, window.cursorStyle(), 'the link under the still mouse');
        assertTrue(detector.getLinkDecorations()[0].active);
        wheel(x, y, -27, lineHeight, cmd);
        window.drawIfDirty();
        assertEquals(CursorStyle.IBeam, window.cursorStyle(), 'the link scrolled away');
        assertFalse(detector.getLinkDecorations()[0].active);
        assertEquals(null, view.mouseCursor);
    }

    /**
     * Several wheel events before a frame give one synthetic move; when
     * nothing under the mouse changed, the frame after the scroll is the
     * last one (no extra render).
     */
    function testOneMovePerFrameAndNoExtraRender() {
        final e = openEditor(lines(60).join('\n'), {});
        final widget:CodeEditorWidget = cast e.getEditor();
        final view:CityscapeView = e.getView();
        final b = view.elementBounds;
        final lineHeight:Float = widget.getOption(EditorOption.lineHeight);
        final x = b.origin.x + widget.getLayoutInfo().contentLeft + 30;
        final y = b.origin.y + 2.5 * lineHeight;
        moveTo(x, y);
        draw();
        assertFalse(window.drawIfDirty(), 'idle before the scroll');
        var moves = 0;
        final subscription = widget.onMouseMove(_ -> moves++);
        window.dispatchEvent(new ScrollEvent(point(x, y), ScrollDelta.Pixels(point(0, -2 * lineHeight))), app);
        window.dispatchEvent(new ScrollEvent(point(x, y), ScrollDelta.Pixels(point(0, -3 * lineHeight))), app);
        assertEquals(0, moves, 'no move before the frame');
        assertTrue(window.drawIfDirty(), 'the scroll renders');
        assertEquals(5 * lineHeight, widget.getScrollTop());
        assertEquals(1, moves, 'one synthetic move per frame');
        assertEquals(CursorStyle.IBeam, window.cursorStyle());
        assertFalse(window.drawIfDirty(), 'nothing under the mouse changed: no extra render');
        assertEquals(1, moves);
        subscription.dispose();
    }

}
