// New code for Cityscape (not a port): the key context of the editor's root
// follows the context keys, and the host is asked to render only when it is
// stale.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.base.common.DebugCounters;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.Action;
import glaze.App;
import glaze.Component;
import glaze.KeyBinding;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

@:action(namespace = cityscape_key_context_test) class KeyContextShortcut implements Action {}

/**
 * The root element of `CityscapeEditor` carries the context keys of the
 * editor as a Glaze key context, for the bindings of the host
 * (`CityscapeEditor && editorReadonly`). A change of context keys asks the
 * host to render when a value really changed since the key context was
 * built (the versions of the contexts), and not otherwise.
 *
 * The app bindings below fire only when the key context drawn holds their
 * condition: they prove that a change that matters reaches key handling,
 * with nothing else asking the editor to render.
 */
@:access(cityscape.CityscapeEditor)
class KeyContextNotificationTest extends TestCase {

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

    function settle():Int {
        var frames = 0;
        ceramic.App.app.flushImmediate();
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
        return frames;
    }

    function key(source:String):Void {
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
        settle();
    }

    function open():CityscapeEditor {
        state = new KeyContextHostState(createTextModel('first line\nsecond line\nthird line'));
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, KeyContextHost.component(state));
        settle();
        app.update(cx -> cx.bindKeys([
            new KeyBinding('ctrl-alt-shift-f1', new KeyContextShortcut(), 'CityscapeEditor && testFlag'),
            new KeyBinding('ctrl-alt-shift-f2', new KeyContextShortcut(), 'CityscapeEditor && editorReadonly'),
            new KeyBinding('ctrl-alt-shift-f3', new KeyContextShortcut(), 'CityscapeEditor && testMode == insert'),
            new KeyBinding('ctrl-alt-shift-f4', new KeyContextShortcut(), 'CityscapeEditor && findWidgetVisible'),
            new KeyBinding('ctrl-alt-shift-f5', new KeyContextShortcut(), 'CityscapeEditor && editorHasSelection'),
            new KeyBinding('ctrl-alt-shift-f6', new KeyContextShortcut(), 'CityscapeEditor && editorTextFocus')
        ]));
        final editor = state.editor;
        assertNotNull(editor);
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        return editor;
    }

    /** Whether the app binding of `source` fires with the key context drawn. */
    function fires(source:String):Bool {
        final before = state.shortcuts;
        key(source);
        return state.shortcuts > before;
    }

    function testAContextKeyOfTheHostReachesKeyHandling() {
        final editor = open();
        final flag = editor.createContextKey('testFlag', false);
        settle();
        assertFalse(fires('ctrl-alt-shift-f1'));
        // only the context key changes: nothing else asks for a render
        var notifications = DebugCounters.keyContextNotifications;
        var hostRenders = DebugCounters.hostRenders;
        flag.set(true);
        assertTrue(DebugCounters.keyContextNotifications > notifications, 'the host is asked to render');
        assertEquals(1, settle());
        assertTrue(DebugCounters.hostRenders > hostRenders, 'the host rendered');
        assertTrue(fires('ctrl-alt-shift-f1'));
        // the same value again: nothing changed, nothing asked
        notifications = DebugCounters.keyContextNotifications;
        flag.set(true);
        assertEquals(notifications, DebugCounters.keyContextNotifications);
        assertEquals(0, settle());
        assertTrue(fires('ctrl-alt-shift-f1'));
        // back
        flag.set(false);
        settle();
        assertFalse(fires('ctrl-alt-shift-f1'));
        flag.set(true);
        settle();
        assertTrue(fires('ctrl-alt-shift-f1'));
        flag.reset();
        settle();
        assertFalse(fires('ctrl-alt-shift-f1'));
        // a string value
        final mode = editor.createContextKey('testMode', 'normal');
        settle();
        assertFalse(fires('ctrl-alt-shift-f3'));
        mode.set('insert');
        settle();
        assertTrue(fires('ctrl-alt-shift-f3'));
        mode.set('normal');
        settle();
        assertFalse(fires('ctrl-alt-shift-f3'));
        // two changes before a frame
        flag.set(true);
        mode.set('insert');
        settle();
        assertTrue(fires('ctrl-alt-shift-f1'));
        assertTrue(fires('ctrl-alt-shift-f3'));
        // a change undone before the frame
        flag.set(false);
        flag.set(true);
        settle();
        assertTrue(fires('ctrl-alt-shift-f1'));
    }

    function testEditorContextKeysReachKeyHandling() {
        final editor = open();
        // focus
        assertTrue(fires('ctrl-alt-shift-f6'));
        // read only
        assertFalse(fires('ctrl-alt-shift-f2'));
        editor.updateOptions({readOnly: true});
        settle();
        assertTrue(fires('ctrl-alt-shift-f2'));
        editor.updateOptions({readOnly: false});
        settle();
        assertFalse(fires('ctrl-alt-shift-f2'));
        // a selection
        assertFalse(fires('ctrl-alt-shift-f5'));
        editor.setSelection(new Selection(1, 1, 1, 6));
        settle();
        assertTrue(fires('ctrl-alt-shift-f5'));
        editor.setSelection(new Selection(1, 1, 1, 1));
        settle();
        assertFalse(fires('ctrl-alt-shift-f5'));
        // the find widget
        assertFalse(fires('ctrl-alt-shift-f4'));
        editor.trigger('test', 'actions.find', null);
        settle();
        assertTrue(fires('ctrl-alt-shift-f4'));
        editor.trigger('test', 'closeFindWidget', null);
        settle();
        assertFalse(fires('ctrl-alt-shift-f4'));
    }

    /**
     * Typing: the changes of context keys of one character, and how many of
     * them found the key context stale.
     */
    function testContextKeyNotificationsOfATypedCharacter() {
        final editor = open();
        final view:CityscapeView = editor.getView();
        editor.setSelection(new Selection(1, 11, 1, 11));
        settle();
        view.type('a');
        settle();
        var events = 0;
        final service = Std.downcast(editor.widget.contextKeyService, cityscape.platform.contextkey.view.ContextKeyService.AbstractContextKeyService);
        final listener = service.onDidChangeContext(_ -> events++);
        final notifications = DebugCounters.keyContextNotifications;
        final verify = Window.verifyCache;
        Window.verifyCache = false;
        final hostRenders = DebugCounters.hostRenders;
        view.type('b');
        final frames = settle();
        final renders = DebugCounters.hostRenders - hostRenders;
        Window.verifyCache = verify;
        listener.dispose();
        trace('context keys, one typed character: ' + events + ' change events, ' + (DebugCounters.keyContextNotifications - notifications)
            + ' found the key context stale (each event notified the host before), ' + frames + ' frame, ' + renders + ' host render');
        assertEquals(0, DebugCounters.keyContextNotifications - notifications, 'no context key changed its value');
        assertEquals(1, frames);
        assertEquals(1, renders);
    }

}

class KeyContextHostState {

    public final model:TextModel;
    public var editor:Null<CityscapeEditor> = null;
    public var shortcuts:Int = 0;

    public function new(model:TextModel) {
        this.model = model;
    }

}

class KeyContextHost extends Component {

    final state:KeyContextHostState;

    public function new(state:KeyContextHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {}

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        final toolbar = div().flex().flexRow().flexWrap().h(px(48)).flexShrink0();
        for (i in 0...60) {
            toolbar.child(div().id('tool-' + i).w(px(12)).h(px(12)).onClick(_ -> {}));
        }
        return div().keyContext('TestApp').flex().flexCol().sizeFull()
            .onAction(KeyContextShortcut, (_, _, _) -> state.shortcuts++)
            .child(toolbar)
            .child(CityscapeEditor.component().at('editor').model(state.model).onCreate(e -> state.editor = e).flex1());
    }

}
