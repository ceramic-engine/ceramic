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

    public function new(modelA:TextModel, modelB:TextModel, onA:(view:Entity<CityscapeView>) -> Void, onB:(view:Entity<CityscapeView>) -> Void) {
        super();
        this.modelA = modelA;
        this.modelB = modelB;
        this.onA = onA;
        this.onB = onB;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull()
            .child(CityscapeEditor.component().model(modelA).options({lineNumbers: 'on'}).onCreate(e -> onA(e.getView())).flex1())
            .child(CityscapeEditor.component().model(modelB).onCreate(e -> onB(e.getView())).flex1());
    }

}
