// New code for Cityscape (not a port): the find widget of the editor
// component in a Glaze window (headless): open, type, navigate, replace,
// toggles, close, and two editors with their own find state.
package tests.contrib.find;

import cityscape.CityscapeEditor;
import cityscape.base.common.Platform;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.find.view.FindModel;
import cityscape.contrib.find.view.FindWidget;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Entity;
import glaze.Keystroke;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

class FindWidgetTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var models:Array<TextModel> = [];

    function createModel(text:String):TextModel {
        final model = createTextModel(text);
        models.push(model);
        return model;
    }

    override public function setup():Void {
        app = new App(new TestDispatcher());
        app.update(cx -> glaze.kit.Kit.init(cx));
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
        for (model in models) {
            model.dispose();
        }
        models = [];
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function open(modelA:TextModel, ?modelB:TextModel):{a:CityscapeEditor, b:Null<CityscapeEditor>} {
        var a:Null<CityscapeEditor> = null;
        var b:Null<CityscapeEditor> = null;
        window = Window.open(app, {width: 900, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, FindEditors.component(modelA, modelB, v -> a = v, v -> b = v));
        draw();
        return {a: a, b: b};
    }

    function controllerOf(editor:CityscapeEditor):FindController {
        return editor.getContribution(CommonFindController.ID);
    }

    /**
     * The Glaze view of the find widget (created the first time the widget
     * is shown).
     */
    function widgetOf(editor:CityscapeEditor):FindWidget {
        final overlay:FindWidgetOverlay = cast controllerOf(editor).getWidget();
        return overlay != null ? overlay.getView() : null;
    }

    static function select(editor:CityscapeEditor, selection:Selection):Void {
        editor.setSelection(selection);
    }

    static function selection(editor:CityscapeEditor):String {
        return editor.getSelection().toString();
    }

    /**
     * The find decorations an editor shows (its own: the decorations are
     * owned by their editor).
     */
    function findDecorationsOf(editor:CityscapeEditor, model:TextModel):Int {
        var count = 0;
        for (d in controllerOf(editor).editor.getDecorationsInRange(model.getFullModelRange())) {
            if (d.options.className == 'findMatch' || d.options.className == 'currentFindMatch') count++;
        }
        return count;
    }

    function focusEditor(editor:CityscapeEditor):Void {
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        draw();
    }

    /**
     * Dispatches keystrokes (`cmd-f`, `enter`...): Cmd on macOS, Ctrl
     * elsewhere for `primary-`.
     */
    function key(source:String):Void {
        final mac = Platform.isMacintosh;
        source = StringTools.replace(source, 'primary-', mac ? 'cmd-' : 'ctrl-');
        draw();
        app.update(_ -> window.dispatchKeystroke(Keystroke.parse(source), app));
        draw();
    }

    function type(text:String):Void {
        for (i in 0...text.length) {
            key(text.charAt(i));
        }
    }

    static inline function mac():Bool {
        return Platform.isMacintosh;
    }

    static final TEXT = 'hello world\nsay hello\nHELLO again\nhello';

    function testOpenTypeAndNavigate() {
        final model = createModel(TEXT);
        final views = open(model);
        final a = views.a;
        final controller = controllerOf(a);
        focusEditor(a);
        select(a, new Selection(1, 1, 1, 1));

        // Cmd+F / Ctrl+F opens the widget with the word at the cursor and
        // focuses its find input
        key('primary-f');
        assertTrue(widgetOf(a).isVisible());
        assertTrue(FindModel.CONTEXT_FIND_WIDGET_VISIBLE.getValue(controller.contextKeyService) == true);
        assertTrue(widgetOf(a).findInput.read(app).focusHandle.isFocused(window));
        assertEquals('hello', controller.getState().searchString);
        assertEquals('hello', widgetOf(a).findInput.read(app).value());
        assertEquals(4, controller.getState().matchesCount);
        // the cursor touches the first match: it is the current position
        assertEquals('1 of 4', widgetOf(a).matchesCountLabel());

        // the input text is selected: Backspace clears it
        key('backspace');
        assertEquals('', controller.getState().searchString);
        assertEquals('No results', widgetOf(a).matchesCountLabel());

        // typing in the input searches again (case insensitive by default)
        // and moves to the first match while typing
        type('hello');
        assertEquals('hello', controller.getState().searchString);
        assertEquals(4, controller.getState().matchesCount);
        assertEquals('[1,1 -> 1,6]', selection(a));
        assertEquals('1 of 4', widgetOf(a).matchesCountLabel());

        // Enter goes to the next match, Shift+Enter to the previous one
        key('enter');
        assertEquals('[2,5 -> 2,10]', selection(a));
        assertEquals('2 of 4', widgetOf(a).matchesCountLabel());
        key('enter');
        assertEquals('[3,1 -> 3,6]', selection(a));
        key('shift-enter');
        assertEquals('[2,5 -> 2,10]', selection(a));
        // the text was not changed by Enter
        assertEquals(TEXT, model.getValue());

        // F3 / Cmd+G next match from the editor keys too
        key(mac() ? 'cmd-g' : 'f3');
        assertEquals('[3,1 -> 3,6]', selection(a));

        // the matches are decorated in this editor
        var findMatches = 0;
        for (d in model.getAllDecorations()) {
            if (d.options.className == 'findMatch' || d.options.className == 'currentFindMatch') {
                findMatches++;
            }
        }
        assertEquals(4, findMatches);
        draw();

        // Escape closes the widget, gives the focus back to the editor and
        // removes the decorations
        key('escape');
        assertFalse(widgetOf(a).isVisible());
        assertFalse(FindModel.CONTEXT_FIND_WIDGET_VISIBLE.getValue(controller.contextKeyService) == true);
        draw();
        assertTrue((a.getView() : CityscapeView).focusHandle.isFocused(window));
        for (d in model.getAllDecorations()) {
            assertFalse(d.options.className == 'findMatch' || d.options.className == 'currentFindMatch');
        }
        // the selection stays on the last match
        assertEquals('[3,1 -> 3,6]', selection(a));
    }

    function testNoResults() {
        final model = createModel(TEXT);
        final views = open(model);
        final a = views.a;
        focusEditor(a);
        key('primary-f');
        key('backspace');
        type('zzz');
        assertEquals('zzz', controllerOf(a).getState().searchString);
        assertEquals('No results', widgetOf(a).matchesCountLabel());
        draw();
    }

    function testReplaceOneAndAll() {
        final model = createModel(TEXT);
        final views = open(model);
        final a = views.a;
        final controller = controllerOf(a);
        focusEditor(a);
        select(a, new Selection(1, 1, 1, 1));

        // the replace widget (Cmd+Alt+F on macOS, Ctrl+H elsewhere): the find
        // input is empty here, so it gets the focus
        key('primary-f');
        assertEquals('hello', controller.getState().searchString);
        // from the find input, the replace keybinding focuses the replace input
        key(mac() ? 'cmd-alt-f' : 'ctrl-h');
        assertTrue(widgetOf(a).isReplaceVisible());
        assertTrue(widgetOf(a).replaceInput.read(app).focusHandle.isFocused(window));
        assertEquals('hello', controller.getState().searchString);
        type('bye');
        assertEquals('bye', controller.getState().replaceString);

        // Enter in the replace input: the first Enter selects the match, the
        // next one replaces it (Monaco's `replace`)
        assertEquals('[1,1 -> 1,1]', selection(a));
        key('enter');
        assertEquals('[1,1 -> 1,6]', selection(a));
        assertEquals(TEXT, model.getValue());
        key('enter');
        assertEquals('bye world', model.getLineContent(1));
        assertEquals('[2,5 -> 2,10]', selection(a));
        assertEquals(3, controller.getState().matchesCount);

        // Cmd+Enter / Ctrl+Enter replaces all
        key('primary-enter');
        assertEquals('bye world\nsay bye\nbye again\nbye', model.getValue());
        assertEquals(0, controller.getState().matchesCount);

        // one undo stop per replace
        key('escape');
        assertTrue((a.getView() : CityscapeView).focusHandle.isFocused(window));
        key('primary-z');
        assertEquals('bye world\nsay hello\nHELLO again\nhello', model.getValue());
    }

    function testRegexAndToggles() {
        final model = createModel(TEXT);
        final views = open(model);
        final a = views.a;
        final controller = controllerOf(a);
        focusEditor(a);
        key('primary-f');
        key('backspace');
        type('h.l');
        assertEquals(0, controller.getState().matchesCount);
        // Alt+R (Cmd+Alt+R on macOS) toggles the regular expression
        key(mac() ? 'cmd-alt-r' : 'alt-r');
        assertTrue(controller.getState().isRegex);
        assertEquals(4, controller.getState().matchesCount);
        // Alt+C (Cmd+Alt+C on macOS) toggles the case
        key(mac() ? 'cmd-alt-c' : 'alt-c');
        assertTrue(controller.getState().matchCase);
        assertEquals(3, controller.getState().matchesCount);
        // Alt+W (Cmd+Alt+W on macOS) toggles whole words
        key(mac() ? 'cmd-alt-w' : 'alt-w');
        assertTrue(controller.getState().wholeWord);
        assertEquals(0, controller.getState().matchesCount);
        key(mac() ? 'cmd-alt-w' : 'alt-w');
        assertFalse(controller.getState().wholeWord);
        // the options are kept in the storage of the context: the next find
        // widget starts with them (Monaco's query options persistence)
        assertEquals(true, controller.editor.context.storageService.getBoolean('editor.isRegex', cityscape.platform.storage.common.Storage.StorageScope.WORKSPACE));
        draw();
    }

    function testTwoEditorsHaveTheirOwnFindState() {
        final model = createModel(TEXT);
        final views = open(model, model);
        final a = views.a;
        final b = views.b;
        final controllerA = controllerOf(a);
        final controllerB = controllerOf(b);
        assertTrue(controllerA != controllerB);

        focusEditor(a);
        select(a, new Selection(1, 7, 1, 7));
        key('primary-f');
        assertEquals('world', controllerA.getState().searchString);
        assertEquals(1, controllerA.getState().matchesCount);
        assertFalse(controllerB.getState().isRevealed);
        assertEquals('', controllerB.getState().searchString);

        // the decorations of A's matches are A's own
        assertEquals(1, findDecorationsOf(a, model));
        assertEquals(0, findDecorationsOf(b, model));

        // B searches something else
        focusEditor(b);
        select(b, new Selection(2, 1, 2, 1));
        key('primary-f');
        assertEquals('say', controllerB.getState().searchString);
        assertEquals(1, controllerB.getState().matchesCount);
        // A is unchanged
        assertEquals('world', controllerA.getState().searchString);
        assertTrue(controllerA.getState().isRevealed);

        // Escape in B closes B only
        key('escape');
        assertFalse(controllerB.getState().isRevealed);
        assertTrue(controllerA.getState().isRevealed);
        draw();
    }

    function testCloseButtonAndCommands() {
        final model = createModel(TEXT);
        final views = open(model);
        final a = views.a;
        final controller = controllerOf(a);
        focusEditor(a);
        // the commands run by their Monaco ids
        a.trigger('test', FIND_IDS.StartFindReplaceAction, null);
        draw();
        assertTrue(controller.getState().isRevealed);
        assertTrue(controller.getState().isReplaceRevealed);
        assertTrue(widgetOf(a).isReplaceVisible());
        a.trigger('test', FIND_IDS.CloseFindWidgetCommand, null);
        draw();
        assertFalse(controller.getState().isRevealed);
        assertFalse(widgetOf(a).isVisible());
        draw();
    }

}

private class FindEditors extends glaze.Component {

    final modelA:TextModel;
    final modelB:Null<TextModel>;
    final onA:(editor:CityscapeEditor) -> Void;
    final onB:(editor:CityscapeEditor) -> Void;

    public function new(modelA:TextModel, modelB:Null<TextModel>, onA:(editor:CityscapeEditor) -> Void, onB:(editor:CityscapeEditor) -> Void) {
        super();
        this.modelA = modelA;
        this.modelB = modelB;
        this.onA = onA;
        this.onB = onB;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final root = div().flex().sizeFull()
            .child(CityscapeEditor.component().model(modelA).onCreate(onA).flex1());
        if (modelB != null) {
            root.child(CityscapeEditor.component().model(modelB).onCreate(onB).flex1());
        }
        return root;
    }

}
