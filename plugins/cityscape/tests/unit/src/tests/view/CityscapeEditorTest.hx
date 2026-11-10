// New code for Cityscape (not a port): the editor component in a Glaze
// window (headless): layout by flex, two editors on one model, mouse, typing,
// decorations with typed styles, CJK and emoji.
package tests.view;

import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.CityscapeEditor;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Entity;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import cityscape.common.model.TextModel;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

class CityscapeEditorTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function openTwo(model:TextModel, ?modelB:TextModel):{a:Entity<CityscapeView>, b:Entity<CityscapeView>} {
        var a:Null<Entity<CityscapeView>> = null;
        var b:Null<Entity<CityscapeView>> = null;
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, TwoEditors.component(model, modelB != null ? modelB : model, v -> a = v, v -> b = v));
        draw();
        return {a: a, b: b};
    }

    function testTwoEditorsShareAModel() {
        final model = createTextModel('first line\nsecond line\nthird line');
        final views = openTwo(model);
        assertNotNull(views.a);
        assertNotNull(views.b);
        final a:CityscapeView = views.a;
        final b:CityscapeView = views.b;
        // laid out side by side by the flex layout
        assertTrue(a.elementBounds.size.width > 300);
        assertTrue(b.elementBounds.origin.x >= a.elementBounds.origin.x + a.elementBounds.size.width - 1);
        // separate selections
        a.viewModel.setSelections('test', [new Selection(2, 1, 2, 7)]);
        b.viewModel.setSelections('test', [new Selection(3, 3, 3, 3)]);
        assertEquals('[2,1 -> 2,7]', a.viewModel.getSelection().toString());
        assertEquals('[3,3 -> 3,3]', b.viewModel.getSelection().toString());
        // an edit made through one is seen by the other
        a.type('SECOND');
        assertEquals('SECOND line', model.getLineContent(2));
        assertEquals('SECOND line', b.viewModel.getLineContent(2));
        assertEquals('[2,7 -> 2,7]', a.viewModel.getSelection().toString());
        // the other's cursor stays where it was
        assertEquals('[3,3 -> 3,3]', b.viewModel.getSelection().toString());
        draw();
    }

    /**
     * Cityscape (step 3, cs3-cursor): the keys of the view run Monaco's
     * commands (vscode's results: core commands, word operations,
     * delete left, undo).
     */
    function testKeysRunMonacoCommands() {
        final model = createTextModel('    hello world\nsecond');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        draw();
        // focus the editor (the keys go to the focused element)
        app.update(_ -> a.focusHandle.focus(window, app));
        draw();
        a.viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);
        final key = (source:String) -> {
            window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
        };
        // Home goes to the first non whitespace character, then to column 1
        key('end');
        assertEquals('[1,16 -> 1,16]', a.viewModel.getSelection().toString());
        key('home');
        assertEquals('[1,5 -> 1,5]', a.viewModel.getSelection().toString());
        key('home');
        assertEquals('[1,1 -> 1,1]', a.viewModel.getSelection().toString());
        // shift+down selects to the same visible column of the next line
        key('shift-down');
        assertEquals('[1,1 -> 2,1]', a.viewModel.getSelection().toString());
        // backspace deletes the selection, then undo restores it
        key('backspace');
        assertEquals('second', model.getLineContent(1));
        a.type('x');
        assertEquals('xsecond', model.getLineContent(1));
        key(cityscape.base.common.Platform.isMacintosh ? 'cmd-z' : 'ctrl-z');
        assertEquals('second', model.getLineContent(1));
        key(cityscape.base.common.Platform.isMacintosh ? 'cmd-z' : 'ctrl-z');
        assertEquals('    hello world', model.getLineContent(1));
        draw();
    }

    /**
     * A window caching its views (Glaze's default) paints the editor again
     * after an edit: the editor view notifies the view that paints it (a
     * model read by an element of a cached view would not make it render).
     */
    function testEditRepaintsInAViewCachingWindow() {
        final model = createTextModel('first line\nsecond line');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        assertTrue(window.viewCaching);
        draw();
        final count = () -> @:privateAccess window.renderedFrame.scene.len();
        final before = count();
        a.viewModel.setSelections('test', [new Selection(1, 11, 1, 11)]);
        a.type(' with more text');
        // drawn from the caches: the edited line is painted
        assertTrue(window.drawIfDirty());
        final cached = count();
        assertTrue(cached > before, 'the typed glyphs are painted');
        // the same frame as a full redraw
        window.refresh();
        window.draw();
        assertEquals(count(), cached);
    }

    function testMouseClickPlacesTheCursor() {
        final model = createTextModel('hello world\nsecond');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        draw();
        final layoutInfo = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.layoutInfo);
        final lineHeight:Float = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.lineHeight);
        final line = a.renderViewLine(1);
        final x = a.elementBounds.origin.x + layoutInfo.contentLeft + line.columnToX(7) + 1;
        final y = a.elementBounds.origin.y + lineHeight / 2;
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(x, y)), app);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(x, y)), app);
        assertEquals('[1,7 -> 1,7]', a.viewModel.getSelection().toString());
        draw();
    }

    /**
     * viewLines.ts `onFlushed`: after `setValue` the widest line is measured
     * again, so the scroll width follows the new text and a horizontal
     * scroll past its end is clamped (a long line scrolled to its end, then
     * replaced by short lines, shows them from their start).
     */
    function testSetValueMeasuresTheWidestLineAgain() {
        final long = [for (_ in 0...40) 'word'].join(' ');
        final model = createTextModel(long);
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        draw();
        final layout = a.viewModel.viewLayout;
        final wide = layout.getScrollWidth();
        layout.setScrollPosition({scrollLeft: wide}, cityscape.common.EditorCommon.ScrollType.Immediate);
        draw();
        assertTrue(layout.getCurrentScrollLeft() > 0);
        model.setValue('{\n  "a": 1\n}');
        draw();
        draw();
        assertTrue(layout.getScrollWidth() < wide, 'the scroll width follows the new text');
        assertEquals(0., layout.getCurrentScrollLeft());
    }

    /**
     * The text cursor (I-beam) of an editor is set in paint, so it stays
     * when the editor's view is reused from the view cache while another
     * view renders again (GPUI replays the cursor styles of a reused paint).
     */
    function testTextCursorSurvivesViewCacheReuse() {
        final model = createTextModel('hello\nworld');
        openTwo(model);
        draw();
        inline function cursorStyles():String {
            final summary = window.debugFrameSummary();
            final start = summary.indexOf('cursor styles');
            return summary.substring(start, summary.indexOf('\n', start));
        }
        final expected = cursorStyles();
        final views = [for (id in @:privateAccess window.trackers.keys()) id];
        assertTrue(views.length >= 2);
        for (id in views) {
            app.update(cx -> cx.notify(id));
            window.drawIfDirty();
            assertEquals(expected, cursorStyles(), 'after a notify of view $id');
        }
    }

    /**
     * Cityscape additions: `scrollBeyondLastLineGap` (gpui-kit's space past
     * the last line, max(fraction of the viewport without padding, minimum
     * lines)) and `scrollbarThumbExcludesPadding` (the thumb measured
     * without the vertical padding). Monaco's default stays one viewport
     * less a line.
     */
    function testScrollBeyondLastLineGapAndThumbPadding() {
        final model = createTextModel('a\nb\nc\nd');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        draw();
        final layout = a.viewModel.viewLayout;
        final lineHeight:Float = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.lineHeight);
        final height:Float = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.layoutInfo).height;
        // Monaco: 4 lines, then the viewport less a line
        assertEquals(4 * lineHeight + Math.max(0, height - lineHeight), layout.getContentHeight());
        // validation: missing fields are 0, the fraction is clamped to 0..1
        a.updateOptions({padding: {top: 8, bottom: 8}, scrollBeyondLastLineGap: {viewportFraction: 2}});
        final gap = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.scrollBeyondLastLineGap);
        assertEquals(1., gap.viewportFraction);
        assertEquals(0., gap.minLines);
        // gpui-kit's rule: max(half the viewport without padding, 3 lines)
        a.updateOptions({padding: {top: 8, bottom: 8}, scrollBeyondLastLineGap: {viewportFraction: 0.5, minLines: 3}});
        final viewport = height - 16;
        assertEquals(16 + 4 * lineHeight + Math.max(viewport * 0.5, 3 * lineHeight), layout.getContentHeight());
        // the scrollbar sees the exact height (Monaco's scroll state rounds it)
        final exact = 16 + 4 * lineHeight + Math.max(viewport * 0.5, 3 * lineHeight);
        assertEquals(Math.max(exact, height), a.scrollHandle.contentSize().height);
        // a tiny viewport: the minimum lines
        a.updateOptions({padding: {top: 8, bottom: 8}, scrollBeyondLastLineGap: {viewportFraction: 0.01, minLines: 3}});
        assertEquals(16 + 4 * lineHeight + 3 * lineHeight, layout.getContentHeight());
        // without scrollBeyondLastLine, no gap
        a.updateOptions({padding: {top: 8, bottom: 8}, scrollBeyondLastLine: false, scrollBeyondLastLineGap: {viewportFraction: 0.5, minLines: 3}});
        assertTrue(layout.getContentHeight() <= 16 + 4 * lineHeight + 20);
        // the thumb padding of the scroll handle
        final handle:cityscape.view.CityscapeView.CityscapeScrollHandle = cast a.scrollHandle;
        assertEquals(0., handle.thumbVerticalPadding());
        a.updateOptions({padding: {top: 8, bottom: 8}, scrollbarThumbExcludesPadding: true});
        assertEquals(16., handle.thumbVerticalPadding());
    }

    /**
     * The key context of the editor root follows context keys set after its
     * render (the contributions, created one app turn after the editor, set
     * theirs then; here a key of the host): the root renders again, so the
     * dispatch tree of the next frame lists the key without a refresh of
     * the window.
     */
    function testLateContextKeysReachTheDispatchTree() {
        final model = createTextModel('hello');
        var editorA:Null<CityscapeEditor> = null;
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false},
            TwoEditors.component(model, model, _ -> {}, _ -> {}, e -> editorA = e));
        draw();
        app.update(_ -> window.drawIfDirty());
        app.update(_ -> window.drawIfDirty());
        assertTrue(window.debugFrameSummary().indexOf('cs6LateKey') < 0);
        assertFalse(window.dirty, 'nothing left to draw');
        final key = editorA.createContextKey('cs6LateKey', false);
        key.set(true);
        // a frame drawn because something is dirty, not a refresh
        app.update(_ -> window.drawIfDirty());
        assertTrue(window.debugFrameSummary().indexOf('cs6LateKey') >= 0, 'the key context lists the key set after the render');
    }

    function testCjkAndEmojiColumns() {
        final model = createTextModel('ab日本語😀cd');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        final line = a.renderViewLine(1);
        // columns grow with the shaped glyphs: CJK wider than ASCII, the
        // emoji (two UTF-16 units) one glyph
        final xA = line.columnToX(1);
        final xB = line.columnToX(2);
        final xCjk = line.columnToX(3);
        final xCjk2 = line.columnToX(4);
        final xEmoji = line.columnToX(6);
        final xAfterEmoji = line.columnToX(8);
        assertTrue(xB > xA);
        assertTrue(xCjk2 > xCjk);
        // With a font covering CJK (system fallback fonts on native desktop,
        // not on Node), the glyphs keep their own advance, wider than ASCII
        final info = a.fontInfo();
        if (info.typicalFullwidthCharacterWidth > info.typicalHalfwidthCharacterWidth * 1.2) {
            assertTrue(xCjk2 - xCjk > (xB - xA) * 1.2, 'CJK glyphs are wider');
        }
        assertTrue(xAfterEmoji > xEmoji, 'the emoji has a width');
        // hit testing returns the columns back
        assertEquals(4, line.xToColumn(xCjk2 + 0.5));
        assertEquals(8, line.xToColumn(xAfterEmoji + 0.5));
    }

    function testTypedDecorationsRender() {
        final model = createTextModel('choice A\nchoice B #tag');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        model.deltaDecorations([], [
            {range: new Range(1, 1, 1, 7), options: {description: 'pill', inlineStyle: {background: '#335', borderRadius: 4, paddingTop: 2, paddingBottom: 2, color: '#ff0000', fontStyle: 'italic'}}},
            {range: new Range(2, 10, 2, 14), options: {description: 'hide', hidden: true, revealOnCursorLine: true}},
        ]);
        draw();
        final line = a.renderViewLine(1);
        var found = false;
        for (style in line.partStyles) {
            if (style.box != null && style.box.background != null && style.italic) {
                found = true;
            }
        }
        assertTrue(found, 'the typed inline style reaches the rendered parts');
        // hidden on line 2 while the cursor is on line 1
        assertEquals('choice B ', a.viewModel.getLineContent(2));
        draw();
    }

    function testRegisteredClassStyle() {
        final model = createTextModel('strong text');
        // the editors use the context of their model
        model.context.registerDecorationStyle('test-strong', {fontWeight: 'bold', color: '#00ff00'});
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        model.deltaDecorations([], [{range: new Range(1, 1, 1, 7), options: {description: 'strong', inlineClassName: 'test-strong'}}]);
        draw();
        final line = a.renderViewLine(1);
        var bold = false;
        for (style in line.partStyles) {
            final weight:Null<Float> = style.fontWeight;
            if (weight != null && weight >= 700) {
                bold = true;
            }
        }
        assertTrue(bold);
    }

    /**
     * The resolved style of the part holding UTF-16 offset `offset` of a
     * rendered line: its color as `#rrggbb` and `i` when italic.
     */
    static function partLook(line:Dynamic, offset:Int):String {
        final starts:Array<Int> = line.runs.partStarts;
        final ends:Array<Int> = line.runs.partEnds;
        for (p in 0...starts.length) {
            if (starts[p] <= offset && offset < ends[p]) {
                final style:cityscape.view.DecorationStyleResolver.ResolvedPartStyle = line.partStyles[p];
                return style.color.toRgb().toHexString().substr(0, 7).toLowerCase() + (style.italic ? ' i' : '');
            }
        }
        return 'none';
    }

    function testDecorationStyleCascade() {
        // 'narration |pipe| tail': a long italic decoration with a short one
        // inside. Monaco orders the classes of a part by decoration end
        // offset (the pipe's first), so in span order the narration would
        // win; the CSS cascade of loreline-monaco gives the pipe its
        // `!important` color and upright style.
        final model = createTextModel('narration |pipe| tail');
        final context = model.context;
        context.registerDecorationStyle('test-pipe', {color: '#00ff00', fontStyle: 'normal', important: true});
        context.registerDecorationStyle('test-narration', {color: '#ff0000', fontStyle: 'italic'});
        // non-important rules: the one registered last wins, whatever the
        // order of the classes
        context.registerDecorationStyle('test-late', {color: '#0000ff'});
        context.registerDecorationStyle('test-early', {color: '#ffff00'});
        context.registerDecorationStyle('test-late', {color: '#0000ff'});
        // a higher priority wins over the registration order
        context.registerDecorationStyle('test-priority', {color: '#ff00ff', priority: 1});
        context.registerDecorationStyle('test-plain', {color: '#00ffff'});
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        model.deltaDecorations([], [
            {range: new Range(1, 1, 1, 22), options: {description: 'narration', inlineClassName: 'test-narration'}},
            {range: new Range(1, 11, 1, 12), options: {description: 'pipe', inlineClassName: 'test-pipe'}},
            {range: new Range(1, 13, 1, 14), options: {description: 'late', inlineClassName: 'test-late'}},
            {range: new Range(1, 13, 1, 15), options: {description: 'early', inlineClassName: 'test-early'}},
            {range: new Range(1, 18, 1, 19), options: {description: 'plain', inlineClassName: 'test-plain'}},
            {range: new Range(1, 18, 1, 20), options: {description: 'priority', inlineClassName: 'test-priority'}},
            // a typed style wins over registered non-important styles
            {range: new Range(1, 21, 1, 22), options: {description: 'typed', inlineStyle: {color: '#123456'}}},
        ]);
        draw();
        final line:Dynamic = a.renderViewLine(1);
        assertEquals('#ff0000 i', partLook(line, 0));
        assertEquals('#00ff00', partLook(line, 10));
        assertEquals('#0000ff i', partLook(line, 12));
        assertEquals('#ffff00 i', partLook(line, 13));
        assertEquals('#ff00ff i', partLook(line, 17));
        assertEquals('#123456 i', partLook(line, 20));
        // an important registered style wins over a typed one
        context.registerDecorationStyle('test-narration', {color: '#ff0000', fontStyle: 'italic', important: true});
        draw();
        final line2:Dynamic = a.renderViewLine(1);
        assertEquals('#ff0000 i', partLook(line2, 20));
        // and among important styles the order applies again: the pipe was
        // registered before the narration now
        assertEquals('#ff0000 i', partLook(line2, 10));
    }

    function testThemeChangeReachesTheView() {
        final model = createTextModel('themed');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        final context = model.context;
        // Monaco's default theme is 'vs' (editor.background #FFFFFE)
        assertEquals('#fffffe', a.theme.getColor('editor.background').toRgb().toHexString().substr(0, 7).toLowerCase());
        final version = a.theme.version;
        context.themeService.setTheme('vs-dark');
        assertTrue(a.theme.version > version);
        assertEquals('#1e1e1e', a.theme.getColor('editor.background').toRgb().toHexString().substr(0, 7).toLowerCase());
        // the token color map follows (default foreground of vs-dark)
        assertEquals('#d4d4d4', a.theme.getTokenColor(1).toRgb().toHexString().substr(0, 7).toLowerCase());
        draw();
    }

    /**
     * Monaco's scrollable element shadows (`scrollbar.useShadows`, on by
     * default, scrollbars.css): none at the top, an inset shadow 3 px high
     * from 3 px right of the text area's left when scrolled down (the
     * corner too), the left one when scrolled right; none with
     * `useShadows: false`.
     */
    function testScrollShadows() {
        final model = createTextModel([for (i in 0...200) 'line ' + i + ' ' + [for (j in 0...30) 'word'].join(' ')].join('\n'));
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        a.updateOptions({stickyScroll: {enabled: false}});
        draw();
        final contentLeft:Float = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.layoutInfo).contentLeft;
        // shadows of the left editor (x below 400 CSS px, device pixels at scale 2)
        function insetShadows():Array<glaze.scene.Shadow> {
            return [for (shadow in window.renderedScene().shadows) if (shadow.inset && shadow.elementBoundsX < 800) shadow];
        }
        assertEquals(0, insetShadows().length, 'no shadow at the top');
        a.viewModel.viewLayout.setScrollPosition({scrollTop: 100}, cityscape.common.EditorCommon.ScrollType.Immediate);
        draw();
        final top = insetShadows();
        assertEquals(2, top.length, 'top and corner shadows');
        assertFloatEquals((contentLeft + 3) * 2, top[0].elementBoundsX, 1);
        assertEquals(6., top[0].elementBoundsHeight);
        assertEquals(12., top[0].blurRadius);
        assertFloatEquals(contentLeft * 2, top[1].elementBoundsX, 1);
        a.viewModel.viewLayout.setScrollPosition({scrollLeft: 50}, cityscape.common.EditorCommon.ScrollType.Immediate);
        draw();
        assertEquals(3, insetShadows().length, 'top, left and corner shadows');
        a.updateOptions({stickyScroll: {enabled: false}, scrollbar: {useShadows: false}});
        draw();
        assertEquals(0, insetShadows().length, 'useShadows off');
    }

    /**
     * Monaco's drag and drop of the selection (dnd.ts, `dragAndDrop` on by
     * default): a press on the selection and a drag show the target (the
     * `dnd-target` decoration), the release moves the text there and selects
     * it; with Alt on macOS (Ctrl elsewhere) the text is copied; a press
     * outside the selection selects as usual; `dragAndDrop: false` selects
     * too; Escape cancels the drag.
     */
    function testDragAndDropOfTheSelection() {
        final model = createTextModel('hello world\nsecond line');
        final views = openTwo(model);
        final a:CityscapeView = views.a;
        draw();
        final layoutInfo = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.layoutInfo);
        final lineHeight:Float = a.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.lineHeight);
        function at(lineNumber:Int, column:Int):glaze.Point {
            final line = a.renderViewLine(lineNumber);
            return point(a.elementBounds.origin.x + layoutInfo.contentLeft + line.columnToX(column) + 1, a.elementBounds.origin.y + (lineNumber - 0.5) * lineHeight);
        }
        final copyModifiers = cityscape.base.common.Platform.isMacintosh ? glaze.Modifiers.of(false, true) : glaze.Modifiers.of(true);
        // the first move stays on the selection (Monaco takes the dragged
        // selection there), then the mouse goes to the target
        function drag(fromLine:Int, fromColumn:Int, toLine:Int, toColumn:Int, ?modifiers:glaze.Modifiers):Void {
            window.dispatchEvent(new MouseDownEvent(MouseButton.Left, at(fromLine, fromColumn)), app);
            window.dispatchEvent(new glaze.MouseMoveEvent(at(fromLine, fromColumn), MouseButton.Left, modifiers), app);
            window.dispatchEvent(new glaze.MouseMoveEvent(at(toLine, toColumn), MouseButton.Left, modifiers), app);
            draw();
            window.dispatchEvent(new MouseUpEvent(MouseButton.Left, at(toLine, toColumn), modifiers), app);
            draw();
        }
        final widget = a.widget;
        // move "hello" after "second"
        widget.setSelection(new Selection(1, 1, 1, 6));
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, at(1, 3)), app);
        window.dispatchEvent(new glaze.MouseMoveEvent(at(1, 4), MouseButton.Left), app);
        window.dispatchEvent(new glaze.MouseMoveEvent(at(2, 7), MouseButton.Left), app);
        draw();
        final targets = [for (d in model.getAllDecorations()) if (d.options.className == 'dnd-target') d];
        assertEquals(1, targets.length, 'the drop target is shown');
        assertEquals('[2,7 -> 2,7]', targets[0].range.toString());
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, at(2, 7)), app);
        draw();
        assertEquals(' world\nsecondhello line', model.getValue());
        assertEquals('[2,7 -> 2,12]', a.viewModel.getSelection().toString());
        assertEquals(0, [for (d in model.getAllDecorations()) if (d.options.className == 'dnd-target') d].length, 'the drop target is removed');
        // undo restores the text
        widget.trigger('keyboard', 'undo', null);
        assertEquals('hello world\nsecond line', model.getValue());
        // copy with the modifier
        widget.setSelection(new Selection(1, 7, 1, 12));
        drag(1, 8, 1, 1, copyModifiers);
        assertEquals('worldhello world\nsecond line', model.getValue());
        assertEquals('[1,1 -> 1,6]', a.viewModel.getSelection().toString());
        // a press outside the selection selects
        widget.setSelection(new Selection(1, 1, 1, 6));
        drag(2, 1, 2, 4);
        assertEquals('worldhello world\nsecond line', model.getValue());
        assertEquals('[2,1 -> 2,4]', a.viewModel.getSelection().toString());
        // Escape cancels
        widget.setSelection(new Selection(1, 1, 1, 6));
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, at(1, 3)), app);
        window.dispatchEvent(new glaze.MouseMoveEvent(at(1, 4), MouseButton.Left), app);
        window.dispatchEvent(new glaze.MouseMoveEvent(at(2, 3), MouseButton.Left), app);
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse('escape'), false, false), app);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, at(2, 3)), app);
        draw();
        assertEquals('worldhello world\nsecond line', model.getValue());
        assertEquals(0, [for (d in model.getAllDecorations()) if (d.options.className == 'dnd-target') d].length);
        // dragAndDrop off: the press selects
        a.updateOptions({dragAndDrop: false});
        widget.setSelection(new Selection(1, 1, 1, 6));
        drag(1, 3, 2, 3);
        assertEquals('worldhello world\nsecond line', model.getValue());
        assertEquals('[1,3 -> 2,3]', a.viewModel.getSelection().toString());
    }

    function testCreateAndDestroyManyEditors() {
        final model = createTextModel('a\nb\nc');
        for (i in 0...20) {
            openTwo(model);
            draw();
            window.destroy();
            window = null;
            ceramic.App.app.flushImmediate();
        }
        assertEquals(0, model.getAttachedEditorCount());
    }

}

/**
 * Two editors side by side in a flex row.
 */
class TwoEditors extends glaze.Component {

    final modelA:TextModel;
    final modelB:TextModel;
    final onA:(view:Entity<CityscapeView>) -> Void;
    final onB:(view:Entity<CityscapeView>) -> Void;
    final onEditorA:Null<(editor:CityscapeEditor) -> Void>;

    public function new(modelA:TextModel, modelB:TextModel, onA:(view:Entity<CityscapeView>) -> Void, onB:(view:Entity<CityscapeView>) -> Void,
            ?onEditorA:(editor:CityscapeEditor) -> Void) {
        super();
        this.modelA = modelA;
        this.modelB = modelB;
        this.onA = onA;
        this.onB = onB;
        this.onEditorA = onEditorA;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull()
            .child(CityscapeEditor.component().model(modelA).options({lineNumbers: 'on'}).onCreate(e -> {
                onA(e.getView());
                if (onEditorA != null) onEditorA(e);
            }).flex1())
            .child(CityscapeEditor.component().model(modelB).onCreate(e -> onB(e.getView())).flex1());
    }

}
