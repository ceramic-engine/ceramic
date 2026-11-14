// New code for Cityscape (not a port): the `options` prop of the editor
// component is applied when its content changes, and only then.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.base.common.DebugCounters;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.config.OptionValues;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Component;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

/**
 * `CityscapeEditor` compares the options its host gives with a copy of the
 * ones it applied last, by content:
 *
 * - every option changed is applied (table below): the editor's options
 *   hold the new value, the rendered lines are dropped (the lines are
 *   rendered again with it) and a configuration event is fired;
 * - the same options built again as a new object change nothing: the
 *   rendered lines are kept, no configuration event;
 * - a change of a nested field (`padding.top`) is seen;
 * - an object changed in place by the host is seen.
 */
class EditorOptionsPropTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var state:OptionsHostState;
    var editorEvents:Int = 0;
    var serviceEvents:Int = 0;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        editorEvents = 0;
        serviceEvents = 0;
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function settle():Void {
        ceramic.App.app.flushImmediate();
        var frames = 0;
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
    }

    function open(options:Dynamic):CityscapeEditor {
        final model = createTextModel('function first() {\n\tif (a) {\n\t\treturn [1, 2];\n\t}\n}\nsecond line\nthird line');
        state = new OptionsHostState(model, options);
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, OptionsHost.component(state));
        settle();
        final editor = state.editor;
        assertNotNull(editor);
        editor.onDidChangeConfiguration(_ -> editorEvents++);
        model.context.configurationService.onDidChangeConfiguration(_ -> serviceEvents++);
        // a first pass, so that nothing is pending
        renderHost();
        editorEvents = 0;
        serviceEvents = 0;
        return editor;
    }

    /**
     * The host renders (it gives `state.options` to the editor), then the
     * editor does. `options` is an unobserved prop: a new value is applied
     * at the next render of the editor, asked here.
     */
    function renderHost():Void {
        state.revision++;
        settle();
        state.editor.notify();
        settle();
    }

    static function base():Dynamic {
        return {
            fontSize: 14,
            lineHeight: 21,
            lineNumbers: 'on',
            padding: {top: 6},
            scrollBeyondLastLine: false,
            showFoldingControls: 'always',
            stickyScroll: {enabled: true},
            guides: {indentation: true},
            inlayHints: {enabled: 'on', padding: true},
            codeLens: true,
            semanticHighlighting: {enabled: true},
            renderLineHighlight: 'all'
        };
    }

    /** `options` built again with `name` set to `value`. */
    static function withField(options:Dynamic, name:String, value:Any):Dynamic {
        final result:Dynamic = OptionValues.copy(options);
        Reflect.setField(result, name, value);
        return result;
    }

    /**
     * Options that change what the editor draws: the name, a first value
     * and the value it changes to.
     */
    static function table():Array<{name:String, from:Any, to:Any}> {
        return [
            {name: 'fontSize', from: 14, to: 18},
            {name: 'lineHeight', from: 21, to: 28},
            {name: 'fontFamily', from: 'JetBrains Mono', to: 'Inter'},
            {name: 'fontWeight', from: 'normal', to: 'bold'},
            {name: 'fontLigatures', from: false, to: true},
            {name: 'letterSpacing', from: 0, to: 1},
            {name: 'lineNumbers', from: 'on', to: 'off'},
            {name: 'lineNumbersMinChars', from: 5, to: 3},
            {name: 'lineDecorationsWidth', from: 10, to: 20},
            {name: 'glyphMargin', from: false, to: true},
            {name: 'folding', from: true, to: false},
            {name: 'showFoldingControls', from: 'always', to: 'mouseover'},
            {name: 'padding', from: {top: 6}, to: {top: 12}},
            {name: 'padding', from: {top: 12}, to: {top: 12, bottom: 4}},
            {name: 'wordWrap', from: 'off', to: 'on'},
            {name: 'wordWrapColumn', from: 80, to: 40},
            {name: 'wrappingIndent', from: 'none', to: 'indent'},
            {name: 'renderWhitespace', from: 'selection', to: 'all'},
            {name: 'renderControlCharacters', from: true, to: false},
            {name: 'renderLineHighlight', from: 'all', to: 'gutter'},
            {name: 'renderLineHighlightOnlyWhenFocus', from: false, to: true},
            {name: 'renderFinalNewline', from: 'on', to: 'off'},
            {name: 'rulers', from: [], to: [40, 80]},
            {name: 'rulers', from: [40, 80], to: [40, 100]},
            {name: 'guides', from: {indentation: true}, to: {indentation: false}},
            {name: 'guides', from: {indentation: false}, to: {indentation: false, bracketPairs: true}},
            {name: 'stickyScroll', from: {enabled: true}, to: {enabled: false}},
            {name: 'stickyScroll', from: {enabled: true, maxLineCount: 5}, to: {enabled: true, maxLineCount: 2}},
            {name: 'inlayHints', from: {enabled: 'on', padding: true}, to: {enabled: 'off', padding: true}},
            {name: 'inlayHints', from: {enabled: 'on', padding: true}, to: {enabled: 'on', padding: false}},
            {name: 'inlayHints', from: {enabled: 'on', fontSize: 10}, to: {enabled: 'on', fontSize: 12}},
            {name: 'semanticHighlighting', from: {enabled: true}, to: {enabled: false}},
            {name: 'bracketPairColorization', from: {enabled: false}, to: {enabled: true}},
            {name: 'matchBrackets', from: 'never', to: 'always'},
            {name: 'scrollBeyondLastLine', from: false, to: true},
            {name: 'scrollbar', from: {verticalScrollbarSize: 14}, to: {verticalScrollbarSize: 20}},
            {name: 'scrollbar', from: {horizontal: 'auto'}, to: {horizontal: 'hidden'}},
            {name: 'cursorStyle', from: 'line', to: 'block'},
            {name: 'cursorWidth', from: 0, to: 3},
            {name: 'cursorBlinking', from: 'blink', to: 'solid'},
            {name: 'roundedSelection', from: true, to: false},
            {name: 'selectionHighlight', from: true, to: false},
            {name: 'occurrencesHighlight', from: 'singleFile', to: 'off'},
            {name: 'codeLens', from: true, to: false},
            {name: 'links', from: true, to: false},
            {name: 'colorDecorators', from: true, to: false},
            {name: 'readOnly', from: false, to: true},
            {name: 'tabSize', from: 4, to: 2},
            {name: 'stopRenderingLineAfter', from: 10000, to: 500},
            {name: 'disableMonospaceOptimizations', from: false, to: true},
            {name: 'overviewRulerBorder', from: true, to: false},
            {name: 'hideCursorInOverviewRuler', from: false, to: true},
            {name: 'smoothScrolling', from: false, to: true}
        ];
    }

    /**
     * Whether the editor holds `value` for the option `name`: in its raw
     * options (an object option is merged there with the fields given
     * before, so the fields of `value` are looked up), or in the
     * configuration of the context for the settings that are not editor
     * options (`tabSize`, `semanticHighlighting`).
     */
    function applied(editor:CityscapeEditor, name:String, value:Any):Bool {
        var actual:Any = name == 'tabSize' || name == 'semanticHighlighting'
            ? state.model.context.configurationService.getValue('editor.' + name)
            : Reflect.field(editor.getRawOptions(), name);
        if (Type.typeof(value) == TObject && actual != null) {
            for (field in Reflect.fields(value)) {
                if (!OptionValues.equals(Reflect.field(value, field), Reflect.field(actual, field))) {
                    return false;
                }
            }
            return true;
        }
        return OptionValues.equals(value, actual);
    }

    function testEveryOptionChangedIsApplied() {
        final editor = open(base());
        for (entry in table()) {
            final label = entry.name + ' ' + haxe.Json.stringify(entry.from) + ' to ' + haxe.Json.stringify(entry.to);
            state.options = withField(state.options, entry.name, entry.from);
            renderHost();
            assertTrue(applied(editor, entry.name, entry.from), label + ': the first value is applied');
            final resets = DebugCounters.renderCacheResets;
            final events = editorEvents + serviceEvents;
            // built again with one change
            state.options = withField(state.options, entry.name, entry.to);
            renderHost();
            assertTrue(applied(editor, entry.name, entry.to), label + ': the editor has the new value');
            assertTrue(DebugCounters.renderCacheResets > resets, label + ': the rendered lines are dropped');
            assertTrue(editorEvents + serviceEvents > events, label + ': a configuration event is fired');
            // built again without any change
            final resetsAfter = DebugCounters.renderCacheResets;
            final eventsAfter = editorEvents + serviceEvents;
            state.options = OptionValues.copy(state.options);
            renderHost();
            assertEquals(resetsAfter, DebugCounters.renderCacheResets, label + ': the same content keeps the rendered lines');
            assertEquals(eventsAfter, editorEvents + serviceEvents, label + ': the same content fires no configuration event');
        }
    }

    function testTheSameOptionsBuiltAgainChangeNothing() {
        final editor = open(base());
        final view:CityscapeView = editor.getView();
        final resets = DebugCounters.renderCacheResets;
        for (i in 0...3) {
            final previous = state.options;
            state.options = base();
            assertTrue(previous != state.options);
            renderHost();
        }
        assertEquals(resets, DebugCounters.renderCacheResets, 'the rendered lines are kept');
        assertEquals(0, editorEvents, 'no configuration event of the editor');
        assertEquals(0, serviceEvents, 'no event of the configuration service');
        // typing with a host that builds its options again at each render
        state.rebuild = base;
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        view.viewModel.setSelections('test', [new Selection(6, 1, 6, 1)]);
        settle();
        final resetsBefore = DebugCounters.renderCacheResets;
        for (i in 0...3) {
            view.type('x');
            state.revision++;
            settle();
        }
        assertEquals('xxxsecond line', state.model.getLineContent(6));
        assertEquals(resetsBefore, DebugCounters.renderCacheResets, 'typing keeps the rendered lines');
        assertEquals(0, editorEvents);
        assertEquals(0, serviceEvents);
    }

    function testANestedChangeIsSeen() {
        final editor = open(base());
        assertEquals(6.0, editor.getOption(EditorOption.padding).top);
        final resets = DebugCounters.renderCacheResets;
        final options = base();
        options.padding = {top: 20};
        state.options = options;
        renderHost();
        assertEquals(20.0, editor.getOption(EditorOption.padding).top);
        assertTrue(DebugCounters.renderCacheResets > resets, 'the rendered lines are dropped');
        assertTrue(editorEvents > 0, 'a configuration event is fired');
        // a nested field added, then removed
        final withBottom = base();
        withBottom.padding = {top: 20, bottom: 8};
        state.options = withBottom;
        renderHost();
        assertEquals(8.0, editor.getOption(EditorOption.padding).bottom);
        final events = editorEvents;
        final back = base();
        back.padding = {top: 20, bottom: 0};
        state.options = back;
        renderHost();
        assertEquals(0.0, editor.getOption(EditorOption.padding).bottom);
        assertTrue(editorEvents > events);
    }

    function testAnObjectChangedInPlaceIsSeen() {
        final editor = open(base());
        final options:Dynamic = state.options;
        // a nested field of the object the host gave
        var resets = DebugCounters.renderCacheResets;
        options.padding.top = 30;
        renderHost();
        assertEquals(30.0, editor.getOption(EditorOption.padding).top);
        assertTrue(DebugCounters.renderCacheResets > resets, 'the rendered lines are dropped');
        // a field of the object itself
        resets = DebugCounters.renderCacheResets;
        options.lineNumbers = 'off';
        renderHost();
        assertEquals('off', Reflect.field(editor.getRawOptions(), 'lineNumbers'));
        assertTrue(DebugCounters.renderCacheResets > resets);
        // an element of an array
        options.rulers = [40, 80];
        renderHost();
        resets = DebugCounters.renderCacheResets;
        options.rulers[1] = 100;
        renderHost();
        assertEquals(100, (Reflect.field(editor.getRawOptions(), 'rulers') : Array<Int>)[1]);
        assertTrue(DebugCounters.renderCacheResets > resets);
        // the configuration service too (its values are copies)
        final events = serviceEvents;
        options.semanticHighlighting.enabled = false;
        renderHost();
        assertTrue(serviceEvents > events, 'the configuration service saw the change');
        final value:Dynamic = state.model.context.configurationService.getValue('editor.semanticHighlighting');
        assertEquals(false, value.enabled);
        // nothing changed: nothing applied
        resets = DebugCounters.renderCacheResets;
        final eventsAfter = editorEvents + serviceEvents;
        renderHost();
        assertEquals(resets, DebugCounters.renderCacheResets);
        assertEquals(eventsAfter, editorEvents + serviceEvents);
    }

    /** Function valued options are compared by identity. */
    function testFunctionOptionsByIdentity() {
        final lineNumbers = (line:Int) -> 'L' + line;
        final options = base();
        options.lineNumbers = lineNumbers;
        final editor = open(options);
        var resets = DebugCounters.renderCacheResets;
        final again = base();
        again.lineNumbers = lineNumbers;
        state.options = again;
        renderHost();
        assertEquals(resets, DebugCounters.renderCacheResets, 'the same function: nothing applied');
        final other = base();
        other.lineNumbers = (line:Int) -> 'M' + line;
        state.options = other;
        renderHost();
        assertTrue(DebugCounters.renderCacheResets > resets, 'another function is applied');
    }

    /** The shortcut props keep their own check, over the options. */
    function testShortcutPropsStillApply() {
        final editor = open(base());
        final resets = DebugCounters.renderCacheResets;
        state.readOnly = true;
        state.revision++;
        settle();
        assertEquals(true, editor.getOption(EditorOption.readOnly));
        assertTrue(DebugCounters.renderCacheResets > resets);
        state.readOnly = false;
        state.revision++;
        settle();
        assertEquals(false, editor.getOption(EditorOption.readOnly));
    }

    function testOptionValues() {
        assertTrue(OptionValues.equals(null, null));
        assertFalse(OptionValues.equals(null, {}));
        assertTrue(OptionValues.equals({a: 1, b: {c: ([1, 2, {d: 'x'}] : Array<Dynamic>)}}, {b: {c: ([1, 2, {d: 'x'}] : Array<Dynamic>)}, a: 1}));
        assertFalse(OptionValues.equals({a: 1, b: {c: ([1, 2, {d: 'x'}] : Array<Dynamic>)}}, {a: 1, b: {c: ([1, 2, {d: 'y'}] : Array<Dynamic>)}}));
        assertFalse(OptionValues.equals({a: 1}, {a: 1, b: 2}));
        assertFalse(OptionValues.equals({a: 1, b: 2}, {a: 1}));
        assertFalse(OptionValues.equals([1, 2], [1, 2, 3]));
        assertFalse(OptionValues.equals([1, 2], {a: 1}));
        assertFalse(OptionValues.equals('1', 1));
        assertFalse(OptionValues.equals(true, 'true'));
        assertTrue(OptionValues.equals(1, 1.0));
        // a field set to null is a field left out
        final withNull:Dynamic = {a: 1, b: null};
        assertTrue(OptionValues.equals(withNull, {a: 1}));
        assertTrue(OptionValues.equals({a: 1}, withNull));
        // a copy does not follow the source
        final source:Dynamic = {a: {b: ([1, {c: 2}] : Array<Dynamic>)}};
        final copy:Dynamic = OptionValues.copy(source);
        assertTrue(OptionValues.equals(source, copy));
        source.a.b[1].c = 3;
        assertFalse(OptionValues.equals(source, copy));
        assertEquals(2, copy.a.b[1].c);
        // class instances are kept and compared by identity
        final instance = new Selection(1, 1, 1, 1);
        final holder:Dynamic = OptionValues.copy({s: instance});
        assertTrue(holder.s == instance);
        assertTrue(OptionValues.equals({s: instance}, holder));
        assertFalse(OptionValues.equals({s: new Selection(1, 1, 1, 1)}, holder));
    }

}

class OptionsHostState implements tracker.Observable {

    public final model:TextModel;

    /** The options given to the editor at the next render of the host. */
    public var options:Dynamic;

    /** When set, the options are built by this at each render of the host. */
    public var rebuild:Null<() -> Dynamic> = null;

    @observe public var revision:Int = 0;
    @observe public var readOnly:Null<Bool> = null;

    public var editor:Null<CityscapeEditor> = null;

    public function new(model:TextModel, options:Dynamic) {
        this.model = model;
        this.options = options;
    }

}

class OptionsHost extends Component {

    final state:OptionsHostState;

    public function new(state:OptionsHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {}

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        final revision = state.revision;
        final options:IEditorOptions = state.rebuild != null ? state.rebuild() : state.options;
        final toolbar = div().flex().flexRow().flexWrap().h(px(48)).flexShrink0();
        for (i in 0...60) {
            toolbar.child(div().id('tool-' + i).w(px(12)).h(px(12)).onClick(_ -> {}));
        }
        return div().flex().flexCol().sizeFull()
            .child(toolbar)
            .child(CityscapeEditor.component().at('editor').model(state.model).options(options).readOnly(state.readOnly)
                .onCreate(e -> state.editor = e).flex1());
    }

}
