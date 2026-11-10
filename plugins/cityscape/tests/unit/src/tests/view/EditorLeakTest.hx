// New code for Cityscape (not a port): editors created and destroyed again
// and again release everything they took (plan, "Plusieurs instances": no
// leak after 100 creations and destructions).
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeDiffEditor;
import cityscape.CityscapeEditor;
import cityscape.base.common.DebugCounters;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService.DiffComputationMode;
import glaze.App;
import glaze.TestDispatcher;
import glaze.WeakEntity;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.instantiateTextModel;

import glaze.Prelude.*;

/**
 * What the host shows, changed by the test between draws.
 */
class LeakHostState {
    /** The models of the editors shown (an entry per editor, a model may repeat). */
    public var models:Array<TextModel> = [];
    /** The models of the diff editors shown. */
    public var diffs:Array<cityscape.view.widget.diffEditor.DiffEditorViewModel.IDiffEditorModel> = [];
    public final editors:Array<CityscapeEditor> = [];
    public final diffEditors:Array<CityscapeDiffEditor> = [];
    public var round:Int = 0;

    public function new() {}
}

class LeakHost extends glaze.Component {

    final state:LeakHostState;

    public function new(state:LeakHostState) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        final root = div().flex().flexRow().flexWrap().sizeFull();
        for (i in 0...state.models.length) {
            // a new identity each round: new editors, not the previous ones
            root.child(CityscapeEditor.component().at('r' + state.round + 'e' + i).model(state.models[i])
                .options({wordWrap: i % 2 == 0 ? 'on' : 'off', lineNumbers: 'on'})
                .onCreate(e -> state.editors.push(e)).w(px(300)).h(px(150)));
        }
        for (i in 0...state.diffs.length) {
            root.child(CityscapeDiffEditor.component().at('r' + state.round + 'd' + i).model(state.diffs[i])
                .computationMode(DiffComputationMode.Synchronous)
                .onCreate(e -> state.diffEditors.push(e)).w(px(600)).h(px(150)));
        }
        return root;
    }

}

/**
 * 100 `CityscapeEditor`s (10 rounds of 10: half of them on a model shared
 * by all the rounds, half on models of their own created and disposed with
 * them) and 20 `CityscapeDiffEditor`s (4 rounds of 5) are created, used
 * (focus, typing, selections, decorations, the find widget, the suggest
 * widget), and destroyed in a headless window. After that the counts are
 * back to the ones of the first round: emitter listeners, disposables
 * (Monaco's `Disposable`, contributions and widgets included), pending
 * timers and cursor blinks, editor views and the Glaze entities of the
 * editors and their widgets (released, not only dropped), scoped
 * context key services, editors of the code editor service, background
 * tokenization tasks, and the decorations of the shared model.
 */
class EditorLeakTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var context:Cityscape;
    var state:LeakHostState;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
        state = new LeakHostState();
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
        ceramic.App.app.flushImmediate();
    }

    function counts(shared:TextModel):Map<String, Int> {
        return [
            'listeners' => DebugCounters.listeners,
            'disposables' => DebugCounters.disposables,
            'timers' => DebugCounters.timers,
            'views' => DebugCounters.views,
            'entities' => DebugCounters.entities,
            'contextKeyContexts' => context.contextKeyService.contextCount(),
            'codeEditors' => context.codeEditorService.listCodeEditors().length,
            'backgroundTasks' => context.backgroundScheduler.taskCount(),
            'sharedModelDecorations' => shared.getAllDecorations().length,
            'models' => context.modelService.getModels().length
        ];
    }

    function key(source:String):Void {
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
        draw();
    }

    function text(editor:CityscapeEditor, value:String):Void {
        editor.getEditor().trigger('keyboard', 'type', {text: value});
        draw();
    }

    /**
     * One round: `editors` editors (every other one on `shared`) and
     * `diffs` diff editors created, used, then destroyed. Returns the weak
     * entities of the editor views.
     */
    function round(shared:TextModel, editors:Int, diffs:Int):Array<WeakEntity<CityscapeView>> {
        final entitiesBefore = DebugCounters.entities;
        state.round++;
        state.editors.resize(0);
        state.diffEditors.resize(0);
        final own:Array<TextModel> = [];
        state.models = [for (i in 0...editors) {
            if (i % 2 == 0) {
                shared;
            }
            else {
                final model = instantiateTextModel(context, 'own model ${state.round} $i\nfunction f(a, b) {\n\treturn a + b;\n}\n');
                own.push(model);
                model;
            }
        }];
        state.diffs = [for (i in 0...diffs) {
            final original = instantiateTextModel(context, 'a\nb\nc\nd ${state.round}\n');
            final modified = instantiateTextModel(context, 'a\nX\nc\nd ${state.round}\ne\n');
            own.push(original);
            own.push(modified);
            ({original: original, modified: modified} : cityscape.view.widget.diffEditor.DiffEditorViewModel.IDiffEditorModel);
        }];
        app.update(cx -> cx.refreshWindows());
        draw();
        draw();
        assertEquals(editors, state.editors.length, 'editors created in round ${state.round}');
        assertEquals(diffs, state.diffEditors.length, 'diff editors created in round ${state.round}');

        final weakViews:Array<WeakEntity<CityscapeView>> = [];
        for (editor in state.editors) {
            weakViews.push(editor.getView().downgrade());
        }

        // Use the editors: focus, typing (quick suggestions), selections,
        // decorations owned by the editor, the find widget, word highlights
        for (index in 0...state.editors.length) {
            final editor = state.editors[index];
            final view:CityscapeView = editor.getView();
            app.update(_ -> view.focusHandle.focus(window, app));
            draw();
            editor.setSelections([new Selection(1, 1, 1, 1)]);
            text(editor, 'x');
            text(editor, 'y');
            key('backspace');
            key('backspace');
            final collection = editor.getEditor().createDecorationsCollection([
                {range: new Range(1, 1, 1, 3), options: {description: 'leak-test', inlineClassName: 'leak'}}
            ]);
            if (index % 3 == 0) {
                key(cityscape.base.common.Platform.isMacintosh ? 'cmd-f' : 'ctrl-f');
                key('escape');
            }
            if (index % 4 == 1) {
                // a decoration left for the editor to remove when it goes away
                assertEquals(1, collection.length);
            }
            else {
                collection.clear();
            }
        }
        for (diffEditor in state.diffEditors) {
            diffEditor.getWidget()._flush();
        }
        draw();
        // the views of the editors (and of the diff editors' two editors),
        // their paint views, and the find widgets with their two inputs
        final findWidgets = Math.ceil(editors / 3);
        assertTrue(DebugCounters.entities >= entitiesBefore + 2 * (editors + 2 * diffs) + 3 * findWidgets, 'entities while the editors are shown: ${DebugCounters.entities - entitiesBefore}');

        // Destroy them all
        state.models = [];
        state.diffs = [];
        app.update(cx -> cx.refreshWindows());
        draw();
        draw();
        state.editors.resize(0);
        state.diffEditors.resize(0);
        for (model in own) {
            model.dispose();
        }
        draw();
        return weakViews;
    }

    function testEditorsAndDiffEditorsAreReleased() {
        assertTrue(DebugCounters.enabled(), 'the unit tests define cityscape_debug_counters');
        final shared = instantiateTextModel(context, 'shared model\nlet value = 1;\nvalue = value + 1;\n');
        window = Window.open(app, {width: 1600, height: 1000, scaleFactor: 2, autoDraw: false, bindInput: false}, LeakHost.component(state));
        draw();

        // First round: what is created once per context or app (registries,
        // providers, the editor contributions' shared state) is kept
        round(shared, 10, 5);
        final baseline = counts(shared);

        final allWeak:Array<WeakEntity<CityscapeView>> = [];
        for (i in 0...10) {
            for (weak in round(shared, 10, i < 4 ? 5 : 0)) {
                allWeak.push(weak);
            }
        }
        final after = counts(shared);
        for (name => value in baseline) {
            assertEquals(value, after.get(name), 'count of $name after 100 editors and 20 diff editors');
        }
        assertEquals(100, allWeak.length);
        var alive = 0;
        for (weak in allWeak) {
            if (weak.upgrade() != null) {
                alive++;
            }
        }
        assertEquals(0, alive, 'editor view entities released');
    }

}
