// New code for Cityscape (not a port): the public editor API in a Glaze
// window (headless): key routing between two editors and to the app,
// addCommand, addAction, keybinding rules, chords, view state per model,
// markers, NLS, events and props.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Platform;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.platform.keybinding.common.UsLayoutResolvedKeybinding;
import cityscape.platform.markers.common.Markers;
import cityscape.view.CityscapeView;
import cityscape.view.KeyboardEvents;
import glaze.Action;
import glaze.App;
import glaze.KeyBinding;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;

import glaze.Prelude.*;

@:action(namespace = cityscape_api_test) class TestAppShortcut implements Action {}

/**
 * What the host renders, changed by the tests between draws.
 */
class ApiHostState {
    public var modelA:TextModel;
    public var modelB:TextModel;
    public var readOnlyA:Null<Bool> = null;
    public var a:Null<CityscapeEditor> = null;
    public var b:Null<CityscapeEditor> = null;
    public var createdA:Int = 0;
    public var appShortcuts:Int = 0;
    /** Renders of the host component. */
    public var renders:Int = 0;
    /** A state the host gives to an action as a prop would (`testActionStateKeptWhenTheHostRendersAgain`). */
    public var onRender:Null<() -> Void> = null;

    public function new(modelA:TextModel, modelB:TextModel) {
        this.modelA = modelA;
        this.modelB = modelB;
    }
}

/**
 * Two editors in an app root with its own key context (`TestApp`) and
 * shortcut.
 */
class ApiHost extends glaze.Component {

    final state:ApiHostState;

    public function new(state:ApiHostState) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        state.renders++;
        if (state.onRender != null) {
            state.onRender();
        }
        return div().keyContext('TestApp').flex().sizeFull()
            .onAction(TestAppShortcut, (_, _, _) -> state.appShortcuts++)
            .child(CityscapeEditor.component().model(state.modelA).readOnly(state.readOnlyA).onCreate(e -> {
                state.a = e;
                state.createdA++;
            }).flex1())
            .child(CityscapeEditor.component().model(state.modelB).onCreate(e -> state.b = e).flex1());
    }

}

class CityscapeApiTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var context:Cityscape;
    var state:ApiHostState;

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

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function open(textA:String, textB:String):Void {
        state = new ApiHostState(instantiateTextModel(context, textA), instantiateTextModel(context, textB));
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, ApiHost.component(state));
        draw();
    }

    function focus(editor:CityscapeEditor):Void {
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        draw();
    }

    function key(source:String):Void {
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
    }

    /** `cmd` on macOS, `ctrl` elsewhere (Monaco's CtrlCmd) */
    static function mod():String {
        return Platform.isMacintosh ? 'cmd' : 'ctrl';
    }

    function testKeysGoToTheFocusedEditor() {
        open('alpha\nbeta', 'gamma\ndelta');
        final a = state.a;
        final b = state.b;
        assertNotNull(a);
        assertNotNull(b);
        var focusEvents = 0;
        a.onDidFocusEditorText(() -> focusEvents++);
        focus(a);
        assertTrue(a.hasTextFocus());
        assertFalse(b.hasTextFocus());
        assertEquals(1, focusEvents);
        a.setPosition({lineNumber: 1, column: 1});
        b.setPosition({lineNumber: 1, column: 1});
        key('end');
        assertEquals('[1,6 -> 1,6]', a.getSelection().toString());
        assertEquals('[1,1 -> 1,1]', b.getSelection().toString());
        key(mod() + '-a');
        assertEquals('[1,1 -> 2,5]', a.getSelection().toString());
        assertEquals('[1,1 -> 1,1]', b.getSelection().toString());

        var blurEvents = 0;
        a.onDidBlurEditorText(() -> blurEvents++);
        focus(b);
        assertFalse(a.hasTextFocus());
        assertTrue(b.hasTextFocus());
        assertEquals(1, blurEvents);
        key('down');
        assertEquals('[2,1 -> 2,1]', b.getSelection().toString());
        assertEquals('[1,1 -> 2,5]', a.getSelection().toString());
        // nothing reached the app
        assertEquals(0, state.appShortcuts);
    }

    function testAppShortcutsInAnAncestorContext() {
        open('alpha\nbeta', 'gamma');
        final a = state.a;
        app.update(cx -> cx.bindKeys([
            new KeyBinding('escape', new TestAppShortcut(), 'TestApp'),
            new KeyBinding(mod() + '-shift-f9', new TestAppShortcut(), 'TestApp'),
            new KeyBinding(mod() + '-a', new TestAppShortcut(), 'TestApp')
        ]));
        focus(a);
        // Escape with a selection: the editor's `cancelSelection` runs
        a.setSelection(new Selection(1, 1, 1, 4));
        key('escape');
        assertEquals('[1,4 -> 1,4]', a.getSelection().toString());
        assertEquals(0, state.appShortcuts);
        // Escape without a selection: no keybinding of the editor applies,
        // the key goes on to the app's binding
        key('escape');
        assertEquals(1, state.appShortcuts);
        // a key the editor does not bind at all
        key(mod() + '-shift-f9');
        assertEquals(2, state.appShortcuts);
        // the deepest context wins: select all in the editor
        key(mod() + '-a');
        assertEquals('[1,1 -> 2,5]', a.getSelection().toString());
        assertEquals(2, state.appShortcuts);
    }

    function testAddCommandIsScopedToItsEditor() {
        open('alpha', 'gamma');
        final a = state.a;
        final b = state.b;
        var runs = 0;
        final id = a.addCommand(KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyY, (_, _) -> runs++);
        assertNotNull(id);
        focus(a);
        key(mod() + '-shift-y');
        assertEquals(1, runs);
        focus(b);
        key(mod() + '-shift-y');
        assertEquals(1, runs);
        // the command runs from its id too
        context.commandService.executeCommand(id, []);
        assertEquals(2, runs);
    }

    function testAddCommandWithAContextKey() {
        open('alpha', 'gamma');
        final a = state.a;
        final enabled = a.createContextKey('testCommandEnabled', false);
        var runs = 0;
        a.addCommand(KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyY, (_, _) -> runs++, 'testCommandEnabled');
        focus(a);
        key(mod() + '-shift-y');
        assertEquals(0, runs);
        enabled.set(true);
        key(mod() + '-shift-y');
        assertEquals(1, runs);
    }

    /**
     * Regression (cs-perf-view): in a window caching its views, a change of
     * the editor (typing, an action, decorations) paints the editor again,
     * and the views around it render again (GPUI marks the ancestors of a
     * dirty view dirty). An action added after the first render, with a
     * keybinding, keeps working across those renders, and a host applying
     * its props on change (not at every render) keeps the state the action
     * changed: loreline-cityscape's Cmd+Shift+H toggle was reset by its
     * host's render, which now happens at every repaint of the editor.
     */
    function testActionStateKeptWhenTheHostRendersAgain() {
        open('alpha', 'gamma');
        final a = state.a;
        focus(a);
        // the action's state, and the prop the host gives it (applied on change)
        var hidden = false;
        var hiddenProp = false;
        var appliedProp = false;
        state.onRender = () -> {
            if (hiddenProp != appliedProp) {
                appliedProp = hiddenProp;
                hidden = hiddenProp;
            }
        };
        var runs = 0;
        a.addAction({
            id: 'test.toggle',
            label: 'Toggle',
            keybindings: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyH],
            run: (_, _) -> {
                runs++;
                hidden = !hidden;
                // a change of the editor, like a decoration update
                a.getModel().deltaDecorations([], [{range: new Range(1, 1, 1, 2), options: {description: 'mark', inlineClassName: 'mark'}}]);
            }
        });
        window.drawIfDirty();
        final rendersBefore = state.renders;
        key(mod() + '-shift-h');
        assertEquals(1, runs);
        assertTrue(hidden);
        // the editor repaints, its host renders again, the state stays
        assertTrue(window.drawIfDirty());
        assertTrue(state.renders > rendersBefore);
        assertTrue(hidden);
        // typing repaints the editor in the caching window
        final view:CityscapeView = a.getView();
        a.setPosition({lineNumber: 1, column: 6});
        view.type('!');
        assertTrue(window.drawIfDirty());
        assertEquals('alpha!', a.getModel().getLineContent(1));
        assertTrue(hidden);
        // the keybinding still runs the action after these renders
        key(mod() + '-shift-h');
        assertEquals(2, runs);
        assertFalse(hidden);
        // the host's prop still wins when it changes
        hiddenProp = true;
        window.refresh();
        assertTrue(window.drawIfDirty());
        assertTrue(hidden);
    }

    function testAddAction() {
        open('alpha', 'gamma');
        final a = state.a;
        final b = state.b;
        final runs:Array<String> = [];
        final disposable = a.addAction({
            id: 'test.action',
            label: 'Test Action',
            keybindings: [KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyJ],
            contextMenuGroupId: 'navigation',
            run: (editor, args) -> runs.push(editor.getModel().getValue())
        });
        focus(a);
        key(mod() + '-alt-j');
        assertEquals('alpha', runs.join(','));
        // trigger and getAction use the descriptor id
        a.trigger('test', 'test.action', null);
        assertEquals('alpha,alpha', runs.join(','));
        assertNotNull(a.getAction('test.action'));
        a.getAction('test.action').run();
        assertEquals(3, runs.length);
        // not on the other editor
        assertNull(b.getAction('test.action'));
        focus(b);
        key(mod() + '-alt-j');
        assertEquals(3, runs.length);
        // disposed: no keybinding, no action
        disposable.dispose();
        focus(a);
        key(mod() + '-alt-j');
        assertEquals(3, runs.length);
        assertNull(a.getAction('test.action'));
    }

    function testRemoveAndRebindDefaultKeybindings() {
        open('alpha beta', 'gamma');
        final a = state.a;
        focus(a);
        a.setPosition({lineNumber: 1, column: 1});
        key('end');
        assertEquals('[1,11 -> 1,11]', a.getSelection().toString());
        // Monaco: addKeybindingRule({keybinding: KeyCode.End, command: '-cursorEnd'})
        final removal = Cityscape.addKeybindingRule({keybinding: KeyCode.End, command: '-cursorEnd'}, context);
        a.setPosition({lineNumber: 1, column: 1});
        key('end');
        assertEquals('[1,1 -> 1,1]', a.getSelection().toString());
        // bind it to another key
        final rebind = Cityscape.addKeybindingRule({keybinding: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.KeyE, command: 'cursorEnd', when: 'editorTextFocus'}, context);
        key(mod() + '-alt-e');
        assertEquals('[1,11 -> 1,11]', a.getSelection().toString());
        // removing the rules gives the default back
        removal.dispose();
        rebind.dispose();
        a.setPosition({lineNumber: 1, column: 1});
        key(mod() + '-alt-e');
        assertEquals('[1,1 -> 1,1]', a.getSelection().toString());
        key('end');
        assertEquals('[1,11 -> 1,11]', a.getSelection().toString());
    }

    function testChords() {
        open('alpha', 'gamma');
        final a = state.a;
        var runs = 0;
        a.addCommand(KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyM), (_, _) -> runs++);
        focus(a);
        key(mod() + '-k');
        assertEquals(0, runs);
        key(mod() + '-m');
        assertEquals(1, runs);
        // a second chord that matches nothing ends the chord mode
        key(mod() + '-k');
        key('x');
        key(mod() + '-m');
        assertEquals(1, runs);
        assertEquals(0, state.appShortcuts);
    }

    function testPlatformResolution() {
        // KeyMod.CtrlCmd is the command key on macOS, Ctrl elsewhere (Monaco)
        final mac = Keybindings.decodeKeybinding(KeyMod.CtrlCmd | KeyCode.KeyZ, OperatingSystem.Macintosh);
        final macChord:KeyCodeChord = cast mac.chords[0];
        assertTrue(macChord.metaKey);
        assertFalse(macChord.ctrlKey);
        final win = Keybindings.decodeKeybinding(KeyMod.CtrlCmd | KeyCode.KeyZ, OperatingSystem.Windows);
        final winChord:KeyCodeChord = cast win.chords[0];
        assertFalse(winChord.metaKey);
        assertTrue(winChord.ctrlKey);
        // KeyMod.WinCtrl is Ctrl on macOS
        final macCtrl:KeyCodeChord = cast Keybindings.decodeKeybinding(KeyMod.WinCtrl | KeyCode.KeyA, OperatingSystem.Macintosh).chords[0];
        assertTrue(macCtrl.ctrlKey);
        // labels and dispatch strings (Monaco's)
        assertEquals('⌘Z', USLayoutResolvedKeybinding.resolveKeybinding(mac, OperatingSystem.Macintosh)[0].getLabel());
        assertEquals('Ctrl+Z', USLayoutResolvedKeybinding.resolveKeybinding(win, OperatingSystem.Windows)[0].getLabel());
        assertEquals('meta+Z', USLayoutResolvedKeybinding.getDispatchStr(macChord));
        assertEquals('ctrl+Z', USLayoutResolvedKeybinding.getDispatchStr(winChord));
        // their Glaze keystrokes
        assertEquals('cmd-z', KeyboardEvents.glazeKeystrokeOf(macChord));
        assertEquals('ctrl-z', KeyboardEvents.glazeKeystrokeOf(winChord));
        // and back from a Glaze keystroke
        assertEquals('meta+Z', KeyboardEvents.dispatchStringOf(glaze.Keystroke.parse('cmd-z')));
        assertEquals('ctrl+shift+K', KeyboardEvents.dispatchStringOf(glaze.Keystroke.parse('ctrl-shift-k')));
    }

    function testViewStateIsKeptPerModel() {
        open('one\ntwo\nthree', 'other');
        final a = state.a;
        final first = state.modelA;
        final second = instantiateTextModel(context, 'second model\nline 2');
        var modelChanges = 0;
        a.onDidChangeModel(_ -> modelChanges++);
        a.setSelection(new Selection(2, 2, 3, 3));
        a.setModel(second);
        assertEquals(1, modelChanges);
        assertEquals('[1,1 -> 1,1]', a.getSelection().toString());
        a.setSelection(new Selection(2, 4, 2, 4));
        a.setModel(first);
        assertEquals('[2,2 -> 3,3]', a.getSelection().toString());
        a.setModel(second);
        assertEquals('[2,4 -> 2,4]', a.getSelection().toString());
        // saveViewState and restoreViewState (Monaco's)
        final saved = a.saveViewState();
        a.setSelection(new Selection(1, 1, 1, 3));
        a.restoreViewState(saved);
        assertEquals('[2,4 -> 2,4]', a.getSelection().toString());
        draw();
        // the model prop is applied again only when it changes
        assertTrue(a.getModel() == second);
    }

    function testMarkersAreRenderedAsDecorations() {
        open('let x = 1;\nlet y = 2;', 'other');
        final model = state.modelA;
        Cityscape.setModelMarkers(model, 'test', [{
            severity: MarkerSeverity.Error,
            message: 'bad x',
            startLineNumber: 1,
            startColumn: 5,
            endLineNumber: 1,
            endColumn: 6
        }, {
            severity: MarkerSeverity.Warning,
            message: 'odd y',
            startLineNumber: 2,
            startColumn: 5,
            endLineNumber: 2,
            endColumn: 6
        }]);
        assertEquals(2, Cityscape.getModelMarkers({owner: 'test'}, context).length);
        final classNames:Array<String> = [];
        var withOverviewRuler = 0;
        for (d in model.getAllDecorations()) {
            if (d.options.className != null && StringTools.startsWith(d.options.className, 'squiggly-')) {
                classNames.push(d.options.className + '@' + d.range.toString());
                if (d.options.overviewRuler != null) {
                    withOverviewRuler++;
                }
            }
        }
        classNames.sort(Reflect.compare);
        assertEquals('squiggly-error@[1,5 -> 1,6],squiggly-warning@[2,5 -> 2,6]', classNames.join(','));
        assertEquals(2, withOverviewRuler);
        // the squiggle styles are known to the context (underlines)
        assertNotNull(context.decorationStyles.get('squiggly-error'));
        draw();
        // cleared
        Cityscape.setModelMarkers(model, 'test', []);
        var left = 0;
        for (d in model.getAllDecorations()) {
            if (d.options.className != null && StringTools.startsWith(d.options.className, 'squiggly-')) {
                left++;
            }
        }
        assertEquals(0, left);
    }

    function testMarkersSetBeforeTheEditorAndReadOnly() {
        final model = Cityscape.createModel('[x] bread\n[ ] milk', null, cityscape.base.common.Uri.parse('inmemory://test/todo.txt'), context);
        Cityscape.setModelMarkers(model, 'test', [{
            severity: MarkerSeverity.Warning,
            message: 'not bought',
            startLineNumber: 2,
            startColumn: 5,
            endLineNumber: 2,
            endColumn: 9
        }]);
        assertEquals(1, Cityscape.getModelMarkers({owner: 'test'}, context).length);
        assertEquals(1, [for (d in model.getAllDecorations()) if (d.options.className == 'squiggly-warning') d].length);
        state = new ApiHostState(cast model, instantiateTextModel(context, 'other'));
        state.readOnlyA = true;
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, ApiHost.component(state));
        draw();
        final view:CityscapeView = state.a.getView();
        final squiggles = () -> {
            final found:Array<String> = [];
            for (d in view.viewModel.getDecorationsInViewport(new Range(1, 1, 2, 9))) {
                if (d.options.className != null) {
                    found.push(d.options.className + '@' + d.range.toString());
                }
            }
            return found.join(',');
        };
        // Monaco: renderValidationDecorations 'editable' (the default) hides
        // the squiggles of a read-only editor
        assertEquals('', squiggles());
        state.readOnlyA = false;
        app.update(_ -> window.refresh());
        draw();
        assertEquals('squiggly-warning@[2,5 -> 2,9]', squiggles());
    }

    function testEditsAndEvents() {
        open('hello', 'other');
        final a = state.a;
        var contentChanges = 0;
        var positions:Array<String> = [];
        a.onDidChangeModelContent(_ -> contentChanges++);
        a.onDidChangeCursorPosition(e -> positions.push(e.position.toString()));
        a.setPosition({lineNumber: 1, column: 3});
        assertEquals('(1,3)', positions.join(','));
        a.executeEdits('test', [{range: new Range(1, 1, 1, 1), text: 'say '}]);
        assertEquals('say hello', a.getValue());
        assertEquals(1, contentChanges);
        a.pushUndoStop();
        a.setValue('replaced');
        assertEquals('replaced', a.getValue());
        assertEquals(2, contentChanges);
    }

    function testPropsUpdateOptionsWithoutRecreating() {
        open('alpha', 'gamma');
        final a = state.a;
        assertEquals(1, state.createdA);
        assertFalse(a.getOption(cityscape.common.config.EditorOptions.EditorOption.readOnly));
        state.readOnlyA = true;
        app.update(_ -> window.refresh());
        draw();
        assertTrue(state.a == a);
        assertEquals(1, state.createdA);
        assertTrue(a.getOption(cityscape.common.config.EditorOptions.EditorOption.readOnly));
        // updateOptions too
        a.updateOptions({readOnly: false});
        assertFalse(a.getOption(cityscape.common.config.EditorOptions.EditorOption.readOnly));
    }

    function testNlsTables() {
        final nls = context.nls;
        assertEquals('Find', nls.localize('startFindAction', 'Find'));
        assertEquals('Hello world', nls.localize('greeting', 'Hello {0}', ['world']));
        // a table keyed by English text (the shape of Monaco's translations)
        nls.loadJson('{"Find": "Rechercher", "Hello {0}": "Bonjour {0}"}');
        assertEquals('Rechercher', nls.localize('startFindAction', 'Find'));
        assertEquals('Bonjour monde', nls.localize('greeting', 'Hello {0}', ['monde']));
        // a key wins over the English text
        nls.loadTable(['startFindAction' => 'Chercher']);
        assertEquals('Chercher', nls.localize('startFindAction', 'Find'));
        nls.clear();
        assertEquals('Find', nls.localize('startFindAction', 'Find'));
    }

}
