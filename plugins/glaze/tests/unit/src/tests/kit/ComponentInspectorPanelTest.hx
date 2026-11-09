// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs (init, DivInspector,
// render_inspector, LspProvider)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

#if glaze_inspector

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.DivInspectorState;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseMoveEvent;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.TestDispatcher;
import glaze.Window;
import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationTokens;
import cityscape.common.Languages.CompletionList;
import cityscape.common.core.Position;
import glaze.kit.inspector.Inspector;
import glaze.kit.inspector.Inspector.DivInspector;
import glaze.kit.inspector.Inspector.InspectorCompletionProvider;
import glaze.kit.inspector.StyleJson;
import glaze.kit.theme.Theme;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.StyleRefinementOps;

/**
 * gpui-kit's inspector panel (`inspector.rs`, feature `inspector`): the
 * key binding and its action, the panel of the active element, the
 * `DivInspector` editors (Rust builder calls and JSON, Cityscape editors in
 * the port) and their edits, and the completion provider of the Rust editor.
 *
 * Two behaviours of the original are reproduced as they are (see the
 * report of the port): the first change of an editor after the element is
 * shown is only taken as the start of the editing (`set_value` emits no
 * change event, so the `editing` flags are still false at the first user
 * edit), and Reset puts the initial style back in the editors but not on
 * the element (it writes the panel's own copy of the state).
 */
@:access(glaze.kit.inspector.DivInspector)
class ComponentInspectorPanelTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Null<Window> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
        app.update(cx -> {
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    function openWindow():Void {
        app.update(cx -> {
            window = Window.open(cx, {width: 1024, height: 640, scaleFactor: 1, autoDraw: false, active: true, bindInput: false}, (_, cx) -> {
                return cx.newEntity((_:Context<PanelTestView>) -> new PanelTestView());
            });
        });
        draw();
    }

    function draw():Void {
        dispatcher.runUntilParked();
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function testInitBindsTheToggleKeyAndTheAction() {
        openWindow();
        assertFalse(window.isInspectorPicking(app));
        app.update(cx -> window.dispatchKeystroke(Keystroke.parseWithOs('cmd-alt-i', glaze.OperatingSystem.Mac), cx));
        dispatcher.runUntilParked();
        draw();
        assertTrue(window.inspectorEntity() != null);
        assertTrue(window.isInspectorPicking(app));
        // The close button dispatches ToggleInspector
        app.update(cx -> window.dispatchAction(new glaze.kit.inspector.Inspector.ToggleInspector(), cx));
        dispatcher.runUntilParked();
        draw();
        assertTrue(window.inspectorEntity() == null);
    }

    function testHoverShowsTheDivInspector() {
        openWindow();
        app.update(cx -> window.toggleInspector(cx));
        draw();
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(new Point(360, 80)), cx));
        draw();
        draw();
        final active = window.inspectorEntity().activeElementId();
        assertTrue(active != null);
        window.withInspectorState(active, DivInspectorState, app, (state, _) -> {
            assertTrue(state.value != null);
            assertEquals('(320, 40)', state.value.bounds.origin.toString());
            assertEquals('80 × 80', state.value.bounds.size.toString());
            return null;
        });
    }

    function divInspector():{view:Entity<DivInspector>, state:DivInspectorState, id:glaze.InspectorElementId} {
        openWindow();
        app.update(cx -> window.toggleInspector(cx));
        draw();
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(new Point(360, 80)), cx));
        draw();
        final id = window.inspectorEntity().activeElementId();
        final style = StyleBuilder.build(s -> s.absolute().left(px(320)).top(px(40)).size(px(80)).roundedMd());
        final state = new DivInspectorState(style, new Bounds(new Point(320, 40), new Size(80, 80)), new Size(80, 80));
        var view:Entity<DivInspector> = null;
        app.update(cx -> {
            view = cx.newEntity((dcx:Context<DivInspector>) -> new DivInspector(window, dcx));
            view.update(cx, (this_, dcx) -> this_.updateInspectedElement(id, state.clone(), window, dcx));
        });
        return {view: view, state: state, id: id};
    }

    static function editorValue(state:Dynamic):String {
        return (state.value() : String);
    }

    function testEditorsShowTheStyleAsRustAndJson() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final rust = Inspector.styleToRust(d.state.baseStyle);
        assertEquals(rust.code, editorValue(inspector.rustState));
        assertEquals('fn build() -> Div {\n    div()\n        .rounded_md()\n        .absolute()\n}', rust.code);
        assertEquals(StyleJson.toJson(d.state.baseStyle), editorValue(inspector.jsonState));
        // The part the Rust code cannot express
        assertEquals('{\n  "inset": {\n    "top": "40px",\n    "left": "320px"\n  },\n  "size": {\n    "width": "80px",\n    "height": "80px"\n  }\n}', StyleJson.toJson(inspector.unconvertibleStyle));
    }

    function testTheFirstJsonEditIsOnlyTheStartOfTheEditing() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final json = '{"opacity": 0.5}';
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson(json, window, dcx)));
        assertTrue(inspector.jsonState.editing);
        // Nothing applied: the Rust editor still shows the initial code
        assertEquals(Inspector.styleToRust(d.state.baseStyle).code, editorValue(inspector.rustState));
        // Second change: applied, the Rust editor follows
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson(json, window, dcx)));
        assertEquals(null, inspector.jsonState.error);
        assertEquals('fn build() -> Div {\n    div()\n}', editorValue(inspector.rustState));
        assertEquals('{\n  "opacity": 0.5\n}', StyleJson.toJson(inspector.unconvertibleStyle));
        // An invalid JSON keeps the style and shows serde_json's error
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson('{"opacity": "x"}', window, dcx)));
        assertEquals('invalid type: string "x", expected f32 at line 1 column 15', inspector.jsonState.error);
    }

    function testRustEditsAreParsedWithDiagnostics() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final code = 'fn build() -> Div {\n    div()\n        .p_1()\n        .bad_method()\n}';
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editRust(code, window, dcx)));
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editRust(code, window, dcx)));
        // The parse errors are markers of the Rust editor
        final markers = Cityscape.getModelMarkers({resource: inspector.rustState.model.uri}, @:privateAccess inspector.context);
        assertEquals(1, markers.length);
        assertEquals('unknown method `bad_method`', markers[0].message);
        assertEquals(4, markers[0].startLineNumber);
        // The JSON editor shows the unconvertible part plus the parsed methods
        final json = editorValue(inspector.jsonState);
        assertTrue(json.indexOf('"padding"') >= 0);
        assertTrue(json.indexOf('"inset"') >= 0);
        assertFalse(inspector.jsonState.editing);
    }

    function testResetRestoresTheEditorsButNotTheElement() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final json = '{"opacity": 0.5}';
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson(json, window, dcx)));
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson(json, window, dcx)));
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.resetStyle(window, dcx)));
        assertEquals(StyleJson.toJson(d.state.baseStyle), editorValue(inspector.jsonState));
        assertFalse(inspector.jsonState.editing);
        // The element (the window's state) keeps the edited style
        window.withInspectorState(d.id, DivInspectorState, app, (state, _) -> {
            assertEquals('{\n  "opacity": 0.5\n}', StyleJson.toJson(state.value.baseStyle));
            return null;
        });
    }

    /**
     * The JSON editor after the edits of the golden script (`kit-inspector-script`):
     * the whole text replaced twice by the user, then Reset puts the
     * initial style back; every line shows its text.
     */
    function testJsonEditorShowsItsTextAfterUserEditsAndReset() {
        openWindow();
        final style = StyleBuilder.build(s -> s.absolute().left(px(320)).top(px(40)).size(px(80)).roundedMd());
        final state = new DivInspectorState(style, new Bounds(new Point(320, 40), new Size(80, 80)), new Size(80, 80));
        var view:Entity<DivInspector> = null;
        app.update(cx -> {
            window.toggleInspector(cx);
        });
        draw();
        app.update(cx -> window.dispatchEvent(new MouseMoveEvent(new Point(360, 80)), cx));
        draw();
        final id = window.inspectorEntity().activeElementId();
        var host:Null<Window> = null;
        app.update(cx -> {
            host = Window.open(cx, {width: 480, height: 640, scaleFactor: 1, autoDraw: false, active: true, bindInput: false}, (w, cx) -> {
                view = cx.newEntity((dcx:Context<DivInspector>) -> new DivInspector(w, dcx));
                view.update(cx, (this_, dcx) -> this_.updateInspectedElement(id, state.clone(), w, dcx));
                return view;
            });
            host.draw();
        });
        dispatcher.runUntilParked();
        final inspector:DivInspector = view;
        final model = inspector.jsonState.model;
        function userReplace(text:String) {
            app.update(cx -> {
                model.pushEditOperations([], [{range: model.getFullModelRange(), text: text}], _ -> null);
            });
            dispatcher.runUntilParked();
            app.update(_ -> {
                host.refresh();
                host.draw();
            });
        }
        userReplace('{"position": "Absolute", "inset": {"top": "40px", "left": "320px"}, "size": {"width": "120px", "height": "40px"}, "opacity": 0.5}');
        userReplace('{"position": "Absolute", "inset": {"top": "40px", "left": "320px"}, "size": {"width": "120px", "height": "40px"}, "opacity": 0.5} ');
        userReplace('{"opacity": "x"}');
        app.update(cx -> view.update(cx, (this_, dcx) -> this_.resetStyle(host, dcx)));
        dispatcher.runUntilParked();
        app.update(_ -> {
            host.refresh();
            host.draw();
        });
        dispatcher.runUntilParked();
        final editor = inspector.editors.get('json-editor');
        assertTrue(editor != null);
        final cityscapeView:cityscape.view.CityscapeView = editor.getView();
        for (line in 1...model.getLineCount() + 1) {
            final rendered = cityscapeView.renderViewLine(line);
            assertEquals(model.getLineContent(line), rendered.runs.text, 'line $line');
            for (run in rendered.decorationRuns) {
                assertTrue(run.color.a > 0, 'line $line: a visible color');
            }
        }
        host.destroy();
    }

    /**
     * The JSON pane indents by 2 spaces like gpui-kit's editor: after
     * `setValue` (no indentation detection), the indent guides of the view
     * are at every 2 columns (visible columns 1, 3, 5...), the Rust pane's
     * at every 4.
     */
    function testIndentGuidesFollowTheKitTabSizes() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final host = window;
        app.update(cx -> {
            final json = '{\n  "text": {\n    "font_size": "1.125rem"\n  }\n}';
            @:privateAccess inspector.jsonState.setValue(json);
        });
        assertEquals(2, inspector.jsonState.model.getOptions().indentSize);
        assertEquals(2, inspector.jsonState.model.getOptions().tabSize);
        assertTrue(inspector.jsonState.model.getOptions().insertSpaces);
        assertEquals(4, inspector.rustState.model.getOptions().indentSize);
        // In an editor (a window showing the panel's editors)
        var panel:Null<Window> = null;
        app.update(cx -> {
            panel = Window.open(cx, {width: 480, height: 640, scaleFactor: 1, autoDraw: false, active: true, bindInput: false}, (_, _) -> d.view);
            panel.draw();
        });
        dispatcher.runUntilParked();
        app.update(_ -> {
            panel.refresh();
            panel.draw();
        });
        final editor = inspector.editors.get('json-editor');
        assertTrue(editor != null);
        final view:cityscape.view.CityscapeView = editor.getView();
        final viewModel = view.viewModel;
        // line 3 ("    \"font_size\"...") has guides at levels 1 and 2
        final guides = cityscape.view.viewParts.indentGuides.IndentGuides.getGuidesByLine(viewModel,
            view.configuration.options.get(cityscape.common.config.EditorOptions.EditorOption.guides), 1, 5, null);
        assertEquals('', [for (g in guides[0]) g.visibleColumn].join(','));
        assertEquals('1', [for (g in guides[1]) g.visibleColumn].join(','));
        assertEquals('1,3', [for (g in guides[2]) g.visibleColumn].join(','));
        assertEquals('1', [for (g in guides[3]) g.visibleColumn].join(','));
        panel.destroy();
    }

    function testCompletionsAfterADot() {
        // Like Rust's `char_at`, no char is found at the very end of the
        // text: the cursor is followed by the rest of the code
        final text = 'div()\n    .p_\n}';
        final completions = Inspector.styleMethodCompletions(text, text.length - 2);
        assertTrue(completions != null);
        final labels = [for (method in completions.methods) method.name];
        assertEquals('p_0', labels[0]);
        assertTrue(labels.indexOf('p_1') >= 0);
        assertTrue(labels.indexOf('mx_1') < 0);
        assertEquals('p_', completions.prefix);
        assertEquals(10, completions.start);
        // No dot before the cursor: no completion
        assertEquals(null, Inspector.styleMethodCompletions('div\n', 3));

        // The provider of the Rust editor (Monaco's API): `.name()` replaces the dot and the prefix
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final model = inspector.rustState.model;
        @:privateAccess inspector.rustState.setValue(text);
        var list:Null<CompletionList> = null;
        new InspectorCompletionProvider().provideCompletionItems(model, new Position(2, 8), {triggerKind: cast 1, triggerCharacter: '.'}, CancellationTokens.None,
            result -> list = result);
        assertTrue(list != null);
        final first = list.suggestions[0];
        assertEquals('p_0', first.label);
        assertEquals('.p_0()', first.insertText);
        assertEquals('.p_0', first.filterText);
        assertEquals('()', first.detail);
        final range:cityscape.common.core.Range = cast first.range;
        assertEquals('2:5-2:8', range.startLineNumber + ':' + range.startColumn + '-' + range.endLineNumber + ':' + range.endColumn);
    }

}

private class PanelTestView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .relative()
            .child(div().absolute().left(px(320)).top(px(40)).size(px(80)).roundedMd());
    }

}

#end
