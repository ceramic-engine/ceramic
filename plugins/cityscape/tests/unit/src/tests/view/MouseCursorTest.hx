// New code for Cityscape (not a port): the mouse cursors of an editor
// rendered by Glaze, as Monaco's style sheets give them: the text cursor over
// the view lines (viewLines.css), the default cursor over the margin and the
// line numbers (lineNumbers.css), the pointer over the folding controls
// and the `⋯` of a folded line (folding.css), the sticky lines
// (stickyScroll.css, stickyScrollWidget.ts, the text cursor over the digits
// of their numbers) and the buttons of the find widget (findWidget.css,
// toggle.css). Positions measured on the real Monaco 0.52.2 (glaze-golden
// scratchpad/cs-polish-probe, s1-cursors.js).
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.contrib.folding.view.Folding.FoldingController;
import cityscape.contrib.stickyScroll.view.StickyScrollController;
import cityscape.contrib.stickyScroll.view.StickyScrollProvider.StickyLineCandidateProvider;
import glaze.App;
import glaze.CursorStyle;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;
import tests.view.EditorFontsTest.EditorFontsTestHost;

import glaze.Prelude.*;

class MouseCursorTest extends TestCase {

    static final INDENTED = [
        'class A {',
        '    function b() {',
        '        if (c) {',
        '            d();',
        '            e();',
        '            f();',
        '        }',
        '        g();',
        '    }',
        '    function h() {',
        '        i();',
        '    }',
        '}'
    ].join('\n');

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
        ceramic.App.app.flushImmediate();
    }

    function open(text:String, options:IEditorOptions):CityscapeEditor {
        final model:ITextModel = instantiateTextModel(context, text);
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 1, autoDraw: false, bindInput: false},
            EditorFontsTestHost.component(model, options, e -> editor = e));
        app.update(_ -> window.draw());
        final folding = FoldingController.get(editor.getEditor());
        if (folding != null) {
            folding._flushPendingUpdate();
        }
        app.update(_ -> window.draw());
        return editor;
    }

    function close():Void {
        window.destroy();
        window = null;
        editor = null;
    }

    function cursorAt(x:Float, y:Float):CursorStyle {
        window.dispatchEvent(new glaze.MouseMoveEvent(point(x, y)), app);
        app.update(_ -> window.draw());
        app.update(_ -> window.draw());
        return window.cursorStyle();
    }

    function lineHeight(e:CityscapeEditor):Float {
        return e.getOption(EditorOption.lineHeight);
    }

    /**
     * The margin: the default cursor over the glyph margin, the line
     * numbers and the line decorations, the pointer over the folding control
     * of a line that starts a folding range (the box of the line
     * decorations moved right by the codicon's `margin-left: 2px`, the
     * chevron shown or not), the text cursor from `contentLeft`.
     */
    function testGutterCursors() {
        final e = open(INDENTED, {glyphMargin: true, lineNumbers: 'on'});
        final layout = e.getLayoutInfo();
        final lh = lineHeight(e);
        assertTrue(layout.glyphMarginWidth > 0);
        assertTrue(layout.decorationsWidth > 2);
        final line1 = lh / 2;
        final line4 = 3.5 * lh;
        final folding = layout.decorationsLeft + layout.decorationsWidth / 2;

        assertEquals(CursorStyle.IBeam, cursorAt(layout.contentLeft + 40, line1), 'text');
        assertEquals(CursorStyle.Arrow, cursorAt(layout.glyphMarginLeft + layout.glyphMarginWidth / 2, line1), 'glyph margin');
        assertEquals(CursorStyle.Arrow, cursorAt(layout.lineNumbersLeft + layout.lineNumbersWidth / 2, line1), 'line number');
        assertEquals(CursorStyle.PointingHand, cursorAt(folding, line1), 'folding control of line 1');
        assertEquals(CursorStyle.PointingHand, cursorAt(layout.contentLeft - 0.5, line1), 'right edge of the folding control');
        assertEquals(CursorStyle.Arrow, cursorAt(layout.decorationsLeft + 1, line1), 'left of the folding control (margin-left: 2px)');
        assertEquals(CursorStyle.Arrow, cursorAt(folding, line4), 'line decorations of a line without folding control');
        assertEquals(CursorStyle.PointingHand, cursorAt(folding, 2.5 * lh), 'folding control of line 3');
        assertEquals(CursorStyle.IBeam, cursorAt(layout.contentLeft + 1, line4), 'text after the margin');
        assertEquals(CursorStyle.Arrow, cursorAt(folding, 13.5 * lh), 'margin below the last line');

        // a collapsed range keeps its control
        e.getEditor().setPosition(new cityscape.common.core.Position(2, 5));
        e.getEditor().trigger('test', 'editor.fold', null);
        app.update(_ -> window.draw());
        assertEquals(CursorStyle.PointingHand, cursorAt(folding, 1.5 * lh), 'collapsed folding control');
        // lines 3 to 8 hidden: line 9 is the third view line, line 10 the fourth
        assertEquals(7, e.getEditor()._getViewModel().getLineCount());
        assertEquals(CursorStyle.Arrow, cursorAt(folding, 2.5 * lh), 'line 9, after the folded lines');
        assertEquals(CursorStyle.PointingHand, cursorAt(folding, 3.5 * lh), 'folding control of line 10');
        close();
    }

    /**
     * The `⋯` after a folded line (`.inline-folded:after { cursor: pointer }`,
     * `margin: 0.1em 0.2em 0 0.2em`): the pointer over the glyph, between
     * the ascent and descent of the font; the text cursor in its left margin
     * and above and below its box in the line (real Monaco: hand from the
     * top of the content area to its bottom, text 1 px from the line edges).
     */
    function testFoldedEllipsisCursor() {
        final e = open(INDENTED, {});
        final lh = lineHeight(e);
        final fontSize:Float = e.getOption(EditorOption.fontInfo).fontSize;
        e.getEditor().setPosition(new cityscape.common.core.Position(2, 5));
        e.getEditor().trigger('test', 'editor.fold', null);
        app.update(_ -> window.draw());
        final view:cityscape.view.CityscapeView = e.getView();
        final ellipsisLayout = view.foldedEllipsisLayout();
        final ellipsis = {width: (ellipsisLayout.width : Float), ascent: (ellipsisLayout.ascent : Float), descent: (ellipsisLayout.descent : Float)};
        final layout = e.getLayoutInfo();
        final end = e.getEditor().getScrolledVisiblePosition(new cityscape.common.core.Position(2, 19));
        final left = end.left + fontSize * 0.2;
        final middle = 1.5 * lh;
        final textHeight:Float = (ellipsis.ascent : Float) + (ellipsis.descent : Float);
        assertTrue(lh - textHeight >= 2, 'the line is taller than the text');
        assertEquals(CursorStyle.PointingHand, cursorAt(left + ellipsis.width / 2, middle), 'center of the ellipsis');
        assertEquals(CursorStyle.PointingHand, cursorAt(left + 0.5, middle), 'left edge of the glyph');
        assertEquals(CursorStyle.PointingHand, cursorAt(left + ellipsis.width - 0.5, middle), 'right edge of the glyph');
        assertEquals(CursorStyle.IBeam, cursorAt(left - 1, middle), 'its left margin');
        assertEquals(CursorStyle.IBeam, cursorAt(left + ellipsis.width + 2, middle), 'after it');
        assertEquals(CursorStyle.IBeam, cursorAt(left + ellipsis.width / 2, lh + 0.4), 'above its box');
        assertEquals(CursorStyle.IBeam, cursorAt(left + ellipsis.width / 2, 2 * lh - 0.4), 'below its box');
        assertEquals(CursorStyle.PointingHand, cursorAt(left + ellipsis.width / 2, lh + (lh - textHeight) / 2 + 0.5), 'top of its box');
        // unfolded: the text cursor again
        e.getEditor().trigger('test', 'editor.unfold', null);
        app.update(_ -> window.draw());
        assertEquals(CursorStyle.IBeam, cursorAt(left + ellipsis.width / 2, middle), 'no ellipsis');
        // scrolled horizontally out of the text area: the margin keeps its cursor
        assertTrue(layout.contentLeft > 0);
        close();
    }

    /** Without folding, the line decorations have the default cursor. */
    function testNoFoldingControls() {
        final e = open(INDENTED, {folding: false, lineDecorationsWidth: 20});
        final layout = e.getLayoutInfo();
        final lh = lineHeight(e);
        assertEquals(CursorStyle.Arrow, cursorAt(layout.decorationsLeft + layout.decorationsWidth / 2, lh / 2), 'line decorations');
        assertEquals(CursorStyle.Arrow, cursorAt(layout.lineNumbersLeft + layout.lineNumbersWidth / 2, lh / 2), 'line number');
        assertEquals(CursorStyle.IBeam, cursorAt(layout.contentLeft + 10, lh / 2), 'text');
        close();
    }

    /**
     * Sticky scroll: the pointer over the content of a sticky line and over
     * a folding icon shown, the default cursor over the line numbers.
     */
    function testStickyScrollCursors() {
        final e = open(INDENTED, {stickyScroll: {enabled: true}, showFoldingControls: 'always'});
        final controller = StickyScrollController.get(e.getEditor());
        final provider:StickyLineCandidateProvider = cast controller.stickyScrollCandidateProvider;
        provider.update();
        controller._flushPendingUpdate();
        final lh = lineHeight(e);
        e.getEditor().setScrollTop(3 * lh);
        controller._flushPendingUpdate();
        app.update(_ -> window.draw());
        assertEquals('[1,2,3]', haxe.Json.stringify(controller.stickyScrollWidget.lineNumbers));
        final layout = e.getLayoutInfo();

        assertEquals(CursorStyle.PointingHand, cursorAt(layout.contentLeft + 40, lh * 1.5), 'sticky line content');
        assertEquals(CursorStyle.Arrow, cursorAt(layout.lineNumbersLeft + 2, lh * 1.5), 'sticky line number');
        // the digits of a sticky line number: the text cursor over their box
        // (the width of the number by the ascent and descent of the font)
        final digitsRight = layout.lineNumbersLeft + layout.lineNumbersWidth;
        assertEquals(CursorStyle.IBeam, cursorAt(digitsRight - 1, lh * 1.5), 'digit of line 2');
        assertEquals(CursorStyle.IBeam, cursorAt(digitsRight - 1, lh * 0.5), 'digit of line 1');
        assertEquals(CursorStyle.Arrow, cursorAt(digitsRight - 1, lh + 0.4), 'above the digits');
        assertEquals(CursorStyle.Arrow, cursorAt(digitsRight - 12, lh * 1.5), 'left of the one digit of line 2');
        assertEquals(CursorStyle.PointingHand, cursorAt(layout.contentLeft - lh / 2, lh * 0.5), 'folding icon shown');
        // below the widget, the editor's own cursors
        assertEquals(CursorStyle.IBeam, cursorAt(layout.contentLeft + 40, lh * 5.5), 'text under the widget');
        close();
    }

    /**
     * The box of the digits of a sticky line number is Monaco's: the DOM
     * range of the digits, measured on the real Monaco 0.52.2 with font
     * size 14 and line height 18 (glaze-golden scratchpad cs-cursor probe
     * s7-sticky.json): 16.5 px from 2 px below the top of the line, so the
     * text cursor on rows 2..18 of the first sticky line and 20..35 of the
     * second (the widget ends at 36), the arrow on the other rows of the
     * number column.
     */
    function testStickyScrollDigitsBox() {
        final e = open(INDENTED, {stickyScroll: {enabled: true}, fontSize: 14, lineHeight: 18});
        final controller = StickyScrollController.get(e.getEditor());
        final provider:StickyLineCandidateProvider = cast controller.stickyScrollCandidateProvider;
        provider.update();
        controller._flushPendingUpdate();
        e.getEditor().setScrollTop(3 * 18);
        controller._flushPendingUpdate();
        app.update(_ -> window.draw());
        assertEquals('[1,2,3]', haxe.Json.stringify(controller.stickyScrollWidget.lineNumbers));
        final layout = e.getLayoutInfo();
        final x = layout.lineNumbersLeft + layout.lineNumbersWidth - 1;
        // sampled at integer rows like the probe (y = row)
        for (row in 0...36) {
            final expected = (row >= 2 && row <= 18) || (row >= 20 && row <= 35) ? CursorStyle.IBeam : CursorStyle.Arrow;
            assertEquals(expected, cursorAt(x, row), 'row ' + row);
        }
        // the bottom of the box of the first number: 18.5
        assertEquals(CursorStyle.IBeam, cursorAt(x, 18.25), 'inside the box at 18.25');
        assertEquals(CursorStyle.Arrow, cursorAt(x, 18.5), 'below the box at 18.5');
        assertEquals(CursorStyle.IBeam, cursorAt(x, 2.0), 'the top of the box at 2');
        assertEquals(CursorStyle.Arrow, cursorAt(x, 1.75), 'above the box');
        close();
    }

    /**
     * The find widget (at the top right of the editor): the pointer over
     * its enabled buttons and toggles (the replace toggle, Match Case,
     * Match Whole Word, Use Regular Expression, Find in Selection, Close),
     * the default cursor over its background and its disabled buttons
     * (previous and next match without a search), the text cursor in its
     * input. Read along the middle of its first row.
     */
    function testFindWidgetCursors() {
        final e = open(INDENTED, {});
        final view:cityscape.view.CityscapeView = e.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        app.update(_ -> window.draw());
        final mac = cityscape.base.common.Platform.isMacintosh;
        app.update(_ -> window.dispatchKeystroke(glaze.Keystroke.parse(mac ? 'cmd-f' : 'ctrl-f'), app));
        app.update(_ -> window.draw());
        app.update(_ -> window.draw());
        final runs:Array<String> = [];
        var x = 0.0;
        while (x < 800) {
            final name = Std.string(cursorAt(x, 18));
            if (runs.length == 0 || runs[runs.length - 1] != name) {
                runs.push(name);
            }
            x += 2;
        }
        // the margin and its folding control, the text, then the widget:
        // the replace toggle, the input (with its three toggles), the
        // disabled buttons, Find in Selection and Close
        var pointers = 0;
        for (r in runs) {
            if (r == Std.string(CursorStyle.PointingHand)) {
                pointers++;
            }
        }
        assertTrue(pointers >= 4, 'pointer runs: ' + runs.join(' '));
        assertTrue(runs.indexOf(Std.string(CursorStyle.IBeam)) != -1);
        assertTrue(runs.indexOf(Std.string(CursorStyle.Arrow)) != -1);
        close();
    }

}
