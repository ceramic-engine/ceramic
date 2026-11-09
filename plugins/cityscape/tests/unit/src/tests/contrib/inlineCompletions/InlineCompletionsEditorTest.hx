// New code for Cityscape (not a port): the inline completions in an editor
// placed in a Glaze window (headless): the ghost text injected after the
// cursor, the additional lines in a view zone, the keybindings of
// commands.ts (Tab accepts, Escape hides, Alt+] and Alt+[ cycle) and the
// automatic trigger while typing. Expected behaviour: Monaco's
// ghostTextView.ts (decorations and view zone) and commands.ts.
package tests.contrib.inlineCompletions;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.inlineCompletions.view.controller.InlineCompletionsController;
import cityscape.view.CityscapeView;
import cityscape.view.EditorBrowser.ICodeEditor;
import glaze.App;
import glaze.Entity;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.CeramicTimeTravel;
import tests.TestTextModel;
import tests.contrib.inlineCompletions.InlineCompletionsTestUtils;

import glaze.Prelude.*;

class InlineCompletionsEditorTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var ctx:Cityscape;
    var provider:MockInlineCompletionsProvider;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        ctx = new Cityscape();
        provider = new MockInlineCompletionsProvider();
        ctx.registerInlineCompletionsProvider('*', provider);
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

    function open(model:TextModel):{editor:CityscapeEditor, view:CityscapeView} {
        var editor:Null<CityscapeEditor> = null;
        window = Window.open(app, {width: 700, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false}, InlineCompletionsEditors.component(model, ctx, e -> editor = e));
        draw();
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        return {editor: editor, view: view};
    }

    function key(source:String):Void {
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
    }

    static function ghostDecorations(editor:ICodeEditor):Array<String> {
        final result:Array<String> = [];
        for (d in editor.getModel().getAllDecorations()) {
            final after = d.options.after;
            if (d.options.description == 'ghost-text' && after != null) {
                result.push(d.range.toString() + ' ' + after.inlineClassName + ' ' + after.content);
            }
        }
        return result;
    }

    function showGhostText(editor:ICodeEditor):Void {
        final controller = InlineCompletionsController.get(editor);
        controller.model.get().triggerExplicitly();
        CeramicTimeTravel.advance(1000);
        draw();
    }

    function testGhostTextAfterTheCursorAndLinesInAViewZone() {
        final o = open(TestTextModel.createTextModel('function fib(n) {\n'));
        final editor = o.editor.getEditor();
        editor.setSelections([new Selection(1, 18, 1, 18)]);
        provider.setReturnValue({insertText: 'function fib(n) { // first\n  return n;\n}', range: new Range(1, 1, 1, 18)});
        showGhostText(editor);

        // the first line of the ghost text is injected after the cursor
        assertDeepEquals(['[1,18 -> 1,18] ghost-text-decoration  // first'], ghostDecorations(editor));
        assertEquals('function fib(n) { // first', o.view.renderViewLine(1).runs.text);

        // the next lines are in a view zone below the line
        final views = InlineCompletionsController.get(editor).getGhostTextViews();
        assertEquals(1, views.length);
        final lines = views[0].getAdditionalLines();
        assertDeepEquals(['  return n;', '}'], [for (l in lines) l.content]);
        final whitespaces = editor.getWhitespaces();
        assertEquals(1, whitespaces.length);
        assertEquals(1, whitespaces[0].afterLineNumber);
        assertEquals(2.0 * editor.getOption(EditorOption.lineHeight), (whitespaces[0].height : Float));
        assertTrue(o.editor.getEditor().getModel().getAllDecorations().length > 0);
    }

    function testGhostTextInsideALineHidesTheRestOfTheLine() {
        final o = open(TestTextModel.createTextModel('foo()'));
        final editor = o.editor.getEditor();
        editor.setSelections([new Selection(1, 5, 1, 5)]);
        provider.setReturnValue({insertText: 'foo(x\ny)', range: new Range(1, 1, 1, 6)});
        showGhostText(editor);

        assertDeepEquals(['[1,5 -> 1,5] ghost-text-decoration x'], ghostDecorations(editor));
        // `)` moves to the view zone, after the ghost text of the next line
        final hidden = [for (d in editor.getModel().getAllDecorations()) if (d.options.description == 'ghost-text-hidden') d.range.toString()];
        assertDeepEquals(['[1,5 -> 1,6]'], hidden);
        assertEquals('foo(x', o.view.renderViewLine(1).runs.text);
        final lines = InlineCompletionsController.get(editor).getGhostTextViews()[0].getAdditionalLines();
        assertDeepEquals(['y)'], [for (l in lines) l.content]);
        assertDeepEquals([[1, 2]], [for (l in lines) for (d in l.decorations) [d.startColumn, d.endColumn]]);
        draw();

        key('tab');
        assertEquals('foo(x\ny)', editor.getValue());
    }

    function testTabAccepts() {
        final o = open(TestTextModel.createTextModel('foo'));
        final editor = o.editor.getEditor();
        editor.setSelections([new Selection(1, 4, 1, 4)]);
        provider.setReturnValue({insertText: 'foobar', range: new Range(1, 1, 1, 4)});
        showGhostText(editor);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration bar'], ghostDecorations(editor));

        key('tab');
        assertEquals('foobar', editor.getValue());
        assertEquals('[1,7 -> 1,7]', editor.getSelection().toString());
        assertDeepEquals([], ghostDecorations(editor));
        assertEquals(0, editor.getWhitespaces().length);
    }

    function testEscapeHides() {
        final o = open(TestTextModel.createTextModel('foo'));
        final editor = o.editor.getEditor();
        editor.setSelections([new Selection(1, 4, 1, 4)]);
        provider.setReturnValue({insertText: 'foobar\nbaz', range: new Range(1, 1, 1, 4)});
        showGhostText(editor);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration bar'], ghostDecorations(editor));
        assertEquals(1, editor.getWhitespaces().length);

        key('escape');
        assertEquals('foo', editor.getValue());
        assertDeepEquals([], ghostDecorations(editor));
        assertEquals(0, editor.getWhitespaces().length);
        // Tab indents again (to the next tab stop, with spaces)
        key('tab');
        assertEquals('foo ', editor.getValue());
    }

    function testNextAndPreviousCycle() {
        final o = open(TestTextModel.createTextModel('foo'));
        final editor = o.editor.getEditor();
        editor.setSelections([new Selection(1, 4, 1, 4)]);
        provider.setReturnValues([
            {insertText: 'foobar1', range: new Range(1, 1, 1, 4)},
            {insertText: 'foobizz2', range: new Range(1, 1, 1, 4)},
            {insertText: 'foobuzz3', range: new Range(1, 1, 1, 4)}
        ]);
        showGhostText(editor);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration bar1'], ghostDecorations(editor));

        key('alt-]');
        CeramicTimeTravel.advance(1000);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration bizz2'], ghostDecorations(editor));
        key('alt-]');
        CeramicTimeTravel.advance(1000);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration buzz3'], ghostDecorations(editor));
        key('alt-[');
        CeramicTimeTravel.advance(1000);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration bizz2'], ghostDecorations(editor));

        key('tab');
        assertEquals('foobizz2', editor.getValue());
    }

    function testTypingTriggersAutomatically() {
        final o = open(TestTextModel.createTextModel(''));
        final editor = o.editor.getEditor();
        provider.setReturnValue({insertText: 'console.log()', range: new Range(1, 1, 1, 4)});
        editor.trigger('keyboard', 'type', {text: 'con'});
        // debounced
        assertDeepEquals([], ghostDecorations(editor));
        CeramicTimeTravel.advance(1000);
        assertDeepEquals(['[1,4 -> 1,4] ghost-text-decoration sole.log()'], ghostDecorations(editor));
        // typing what is suggested keeps the ghost text
        editor.trigger('keyboard', 'type', {text: 's'});
        assertDeepEquals(['[1,5 -> 1,5] ghost-text-decoration ole.log()'], ghostDecorations(editor));
        // moving the cursor hides it
        key('left');
        assertDeepEquals([], ghostDecorations(editor));
    }

    function testDisabledByOption() {
        final o = open(TestTextModel.createTextModel(''));
        final editor = o.editor.getEditor();
        editor.updateOptions({inlineSuggest: {enabled: false}});
        provider.setReturnValue({insertText: 'console.log()', range: new Range(1, 1, 1, 4)});
        editor.trigger('keyboard', 'type', {text: 'con'});
        CeramicTimeTravel.advance(1000);
        assertDeepEquals([], provider.getAndClearCallHistory());
        assertDeepEquals([], ghostDecorations(editor));
    }

    function testOptionValidation() {
        final o = open(TestTextModel.createTextModel(''));
        final editor = o.editor.getEditor();
        var options = editor.getOption(EditorOption.inlineSuggest);
        assertDeepEquals({enabled: true, mode: 'subwordSmart', showToolbar: 'onHover', suppressSuggestions: false, keepOnBlur: false, fontFamily: 'default'}, options);
        editor.updateOptions({inlineSuggest: cast {enabled: 'yes', mode: 'prefix', showToolbar: 'sometimes', keepOnBlur: true, fontFamily: 12}});
        options = editor.getOption(EditorOption.inlineSuggest);
        assertDeepEquals({enabled: true, mode: 'prefix', showToolbar: 'onHover', suppressSuggestions: false, keepOnBlur: true, fontFamily: 'default'}, options);
    }

}

class InlineCompletionsEditors extends glaze.Component {

    final model:TextModel;
    final context:Cityscape;
    final onCreate:(editor:CityscapeEditor) -> Void;

    public function new(model:TextModel, context:Cityscape, onCreate:(editor:CityscapeEditor) -> Void) {
        super();
        this.model = model;
        this.context = context;
        this.onCreate = onCreate;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull()
            .child(CityscapeEditor.component().model(model).context(context).options({lineNumbers: 'on'}).onCreate(e -> onCreate(e)).flex1());
    }

}
