// New code for Cityscape (not a port): the order in which the editor and the
// application bind their keys is defined.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.common.core.Selection;
import cityscape.view.CityscapeView;
import cityscape.view.KeyboardEvents;
import glaze.App;
import glaze.KeyBinding;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;
import tests.view.KeyContextNotificationTest.KeyContextHost;
import tests.view.KeyContextNotificationTest.KeyContextHostState;
import tests.view.KeyContextNotificationTest.KeyContextShortcut;

/**
 * An application and the editor may bind the same chord in the
 * `CityscapeEditor` key context. Glaze takes the binding added last, so:
 *
 * - by default the editor binds its keys when it is first drawn, after the
 *   bindings the application made at startup: the editor wins;
 * - with `Cityscape.bindKeys(cx)` called before the application's
 *   `cx.bindKeys`, the application wins.
 *
 * The chord used is `cmd-a` or `ctrl-a`, which the editor binds on every
 * system (select all, or the start of the line): the test only looks at
 * whether the editor moved its selection.
 */
class KeyBindingOrderTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var state:KeyContextHostState;

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

    function settle():Void {
        var frames = 0;
        ceramic.App.app.flushImmediate();
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
    }

    /** A chord the editor binds by default: `cmd-a` or `ctrl-a`. */
    function editorKeystroke():String {
        // the default keybindings come with the extensions of the context
        state.model.context.editorExtensions;
        for (chord in state.model.context.keybindingService.getAllChords()) {
            final keystroke = KeyboardEvents.glazeKeystrokeOf(chord);
            if (keystroke == 'cmd-a' || keystroke == 'ctrl-a') {
                return keystroke;
            }
        }
        throw 'neither cmd-a nor ctrl-a is bound';
    }

    function bindApplicationKey():Void {
        app.update(cx -> cx.bindKeys([new KeyBinding(editorKeystroke(), new KeyContextShortcut(), 'CityscapeEditor')]));
    }

    function openEditor():CityscapeView {
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, KeyContextHost.component(state));
        settle();
        final editor = state.editor;
        assertNotNull(editor);
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        view.viewModel.setSelections('test', [new Selection(1, 5, 1, 5)]);
        settle();
        return view;
    }

    function press(view:CityscapeView):{shortcuts:Int, editorRan:Bool} {
        final before = state.shortcuts;
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(editorKeystroke()), false, false), app);
        settle();
        final selection = view.viewModel.getSelection();
        return {shortcuts: state.shortcuts - before, editorRan: !selection.equalsSelection(new Selection(1, 5, 1, 5))};
    }

    function testByDefaultTheEditorBindsAtItsFirstRenderAndWins() {
        state = new KeyContextHostState(createTextModel('first line\nsecond line'));
        // the application binds at startup, before any editor is drawn
        bindApplicationKey();
        final result = press(openEditor());
        assertEquals(0, result.shortcuts);
        assertTrue(result.editorRan, 'the editor ran its keybinding');
    }

    function testBoundFirstTheEditorLeavesTheChordToTheApplication() {
        state = new KeyContextHostState(createTextModel('first line\nsecond line'));
        app.update(cx -> state.model.context.bindKeys(cx));
        bindApplicationKey();
        final result = press(openEditor());
        assertEquals(1, result.shortcuts, 'the binding of the application ran');
        assertFalse(result.editorRan);
    }

    function testBoundAfterTheApplicationTheEditorWins() {
        state = new KeyContextHostState(createTextModel('first line\nsecond line'));
        bindApplicationKey();
        app.update(cx -> state.model.context.bindKeys(cx));
        // a second call binds nothing more
        app.update(cx -> state.model.context.bindKeys(cx));
        final result = press(openEditor());
        assertEquals(0, result.shortcuts);
        assertTrue(result.editorRan);
    }

}
