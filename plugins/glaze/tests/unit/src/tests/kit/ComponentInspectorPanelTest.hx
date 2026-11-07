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
import glaze.kit.base.input.CompletionContext;
import glaze.kit.base.input.CompletionItem;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.Component;
import glaze.kit.inspector.Inspector;
import glaze.kit.inspector.Inspector.DivInspector;
import glaze.kit.inspector.Inspector.InspectorCompletionProvider;
import glaze.kit.inspector.StyleJson;
import glaze.kit.theme.Theme;
import ropey.Rope;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.StyleRefinementOps;

/**
 * gpui-kit's inspector panel (`inspector.rs`, feature `inspector`): the
 * key binding and its action, the panel of the active element, the
 * `DivInspector` editors (Rust builder calls and JSON) and their edits, and
 * the completion provider of the Rust editor.
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
            Component.init(cx);
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

    static function editorValue(state:Entity<EditorState>):String {
        return (state : InputBaseState).value();
    }

    function testEditorsShowTheStyleAsRustAndJson() {
        final d = divInspector();
        final inspector:DivInspector = d.view;
        final rust = Inspector.styleToRust(d.state.baseStyle);
        assertEquals(rust.code, editorValue(inspector.rustState.state));
        assertEquals('fn build() -> Div {\n    div()\n        .rounded_md()\n        .absolute()\n}', rust.code);
        assertEquals(StyleJson.toJson(d.state.baseStyle), editorValue(inspector.jsonState.state));
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
        assertEquals(Inspector.styleToRust(d.state.baseStyle).code, editorValue(inspector.rustState.state));
        // Second change: applied, the Rust editor follows
        app.update(cx -> d.view.update(cx, (this_, dcx) -> this_.editJson(json, window, dcx)));
        assertEquals(null, inspector.jsonState.error);
        assertEquals('fn build() -> Div {\n    div()\n}', editorValue(inspector.rustState.state));
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
        final diagnostics = (inspector.rustState.state : InputBaseState).diagnosticsMut();
        assertTrue(diagnostics != null);
        // The JSON editor shows the unconvertible part plus the parsed methods
        final json = editorValue(inspector.jsonState.state);
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
        assertEquals(StyleJson.toJson(d.state.baseStyle), editorValue(inspector.jsonState.state));
        assertFalse(inspector.jsonState.editing);
        // The element (the window's state) keeps the edited style
        window.withInspectorState(d.id, DivInspectorState, app, (state, _) -> {
            assertEquals('{\n  "opacity": 0.5\n}', StyleJson.toJson(state.value.baseStyle));
            return null;
        });
    }

    function testCompletionsAfterADot() {
        final provider = new InspectorCompletionProvider();
        // Like Rust's `char_at`, no char is found at the very end of the
        // text: the cursor is followed by the rest of the code
        final rope = Rope.fromStr('div()\n    .p_\n}');
        var items:Array<CompletionItem> = null;
        app.update(cx -> {
            final task = provider.completions(rope, rope.len() - 2, new CompletionContext(1), null, cx);
            task.then(result -> items = result);
        });
        dispatcher.runUntilParked();
        assertTrue(items != null);
        final labels = [for (item in items) item.label];
        assertEquals('p_0', labels[0]);
        assertTrue(labels.indexOf('p_1') >= 0);
        assertTrue(labels.indexOf('mx_1') < 0);
        final first = items[0];
        assertEquals('p_', first.filterText);
        assertEquals(2, first.kind);
        assertEquals('()', first.detail);
        switch first.textEdit {
            case Edit(edit):
                assertEquals('.p_0()', edit.newText);
                assertEquals('1:4', edit.range.start.line + ':' + edit.range.start.character);
                assertEquals('1:7', edit.range.end.line + ':' + edit.range.end.character);
            case _:
                fail('expected a text edit');
        }
        // No dot before the cursor: no completion
        var none:Array<CompletionItem> = null;
        final plain = Rope.fromStr('div\n');
        app.update(cx -> provider.completions(plain, 3, new CompletionContext(1), null, cx).then(result -> none = result));
        dispatcher.runUntilParked();
        assertEquals(0, none.length);
        assertTrue(provider.isCompletionTrigger(0, 'x', app));
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
