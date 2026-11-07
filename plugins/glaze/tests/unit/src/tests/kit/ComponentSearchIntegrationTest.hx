// Ported from gpui-kit 0.8.1: crates/kit/tests/integration/search.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Action;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.OperatingSystem;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.base.Root;
import glaze.kit.Component;
import glaze.kit.combobox.Combobox;
import glaze.kit.combobox.ComboboxState;
import glaze.kit.combobox.ComboboxState.ComboboxEvent;
import glaze.kit.command.Command;
import glaze.kit.command.CommandItem;
import glaze.kit.command.CommandItem.CommandGroup;
import glaze.kit.command.CommandState;
import glaze.kit.searchablelist.SearchableVec;
import testing.TestCase;

import glaze.Prelude.*;

@:action(namespace = search_test) class SearchSave implements Action {}

/**
 * gpui-kit's integration tests of the searchable controls (`search.rs`): the
 * command palette and the combobox driven through the window.
 *
 * gpui-kit finds elements through its accessibility test queries
 * (`window.find(id)`, `expanded()`, `selected()`, `focused()`); the port
 * has no accessibility tree, so the tests read the same facts from the
 * states (`ComboboxState` open and focus, `CommandState.selectedIndex`) and
 * click at the element's place in the laid out window (the palette rows are
 * 34.5 px apart, the first item row centered 87 px below the palette's top;
 * the combobox field is the 256 x 40 box at (16, 16)). Text goes through the
 * window's platform input handler like `window.input`. The `Save` action is
 * `SearchSave` here.
 */
class ComponentSearchIntegrationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    /** `common::open_window`: gpui-base's `Root` around the view, 640 x 480. */
    function openRoot<V:Model & Render>(build:(Window, Context<V>) -> V):Entity<V> {
        var view:Entity<V> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: 640, height: 480, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((viewCx:Context<V>) -> build(window, viewCx));
                return cx.newEntity((rootCx:Context<Root>) -> new Root(view, window, rootCx));
            });
        });
        app.update(_ -> window.setActive(true));
        runUntilParked();
        draw();
        return view;
    }

    function runUntilParked():Void {
        dispatcher.runUntilParked();
    }

    /** `window.render_frame(cx)`. */
    function draw():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        runUntilParked();
    }

    function click(x:Float, y:Float):Void {
        final position = new Point(x, y);
        app.update(cx -> window.dispatchEvent(new glaze.MouseMoveEvent(position, null, Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false), cx));
        app.update(cx -> window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1), cx));
        runUntilParked();
        draw();
    }

    /** `window.input(text)`: the platform's text input, to the focused handler. */
    function input(text:String):Void {
        draw();
        app.update(_ -> {
            final handler = window.peekInputHandler();
            if (handler != null) handler.replaceTextInRange(null, text);
        });
        runUntilParked();
        draw();
    }

    /** `window.press(key)` (key down then key up), then settle. */
    function press(key:String):Void {
        app.update(cx -> window.dispatchKeystroke(Keystroke.parse(key), cx));
        app.update(cx -> window.dispatchEvent(new glaze.KeyUpEvent(Keystroke.parse(key)), cx));
        runUntilParked();
        draw();
    }

    /** `window.press` with an already parsed keystroke. */
    function pressKeystroke(keystroke:Keystroke):Void {
        app.update(cx -> window.dispatchKeystroke(keystroke, cx));
        app.update(cx -> window.dispatchEvent(new glaze.KeyUpEvent(keystroke), cx));
        runUntilParked();
        draw();
    }

    /** `cx.wait_for(window, 1s, predicate)`: advances the clock until the predicate holds. */
    function waitFor(predicate:() -> Bool):Void {
        for (_ in 0...20) {
            if (predicate()) return;
            dispatcher.advanceClock(0.05);
            runUntilParked();
            draw();
        }
        assertTrue(predicate());
    }

    static function samePath(a:Null<IndexPath>, b:Null<IndexPath>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    static function paths(paths:Array<IndexPath>):String {
        return [for (p in paths) p.toString()].join(',');
    }

    static function lists(values:Array<Array<Any>>):String {
        return [for (v in values) '[' + v.join(',') + ']'].join(';');
    }

/// Command palette

    /** The center of item row `row` of the palette (one group, heading first). */
    static function rowY(row:Int):Float {
        return 87. + 34.5 * row;
    }

    function palette():Entity<Palette> {
        final view = openRoot((window, cx:Context<Palette>) -> new Palette(cx.newEntity(c -> new CommandState(window, c))));
        app.update(cx -> {
            final state = view.read(cx).state;
            state.update(cx, (state, cx) -> state.focus(window, cx.app));
        });
        draw();
        return view;
    }

    function selected(view:Entity<Palette>):Null<IndexPath> {
        return view.read(app).state.read(app).selectedIndex();
    }

    function testCommandSkipsDisabledRowsWrapsAndConfirmsOriginalIndex() {
        final view = palette();
        assertTrue(samePath(new IndexPath(0), selected(view)));
        click(100., rowY(1));
        press("down");
        assertTrue(samePath(new IndexPath(2), selected(view)));
        press("down");
        assertTrue(samePath(new IndexPath(0), selected(view)));
        press("up");
        assertTrue(samePath(new IndexPath(2), selected(view)));
        press("enter");
        runUntilParked();
        assertEquals(new IndexPath(2).toString(), paths(view.read(app).confirmed));
        assertEquals(1, view.read(app).saves);

        click(100., rowY(0));
        runUntilParked();
        assertEquals([new IndexPath(2), new IndexPath(0)].map(p -> p.toString()).join(','), paths(view.read(app).confirmed));
    }

    function testCommandSearchesUnicodeKeywordsAndEscapeClearsBeforeCancel() {
        final view = palette();
        input("保存");
        runUntilParked();
        draw();
        final state = view.read(app).state;
        assertEquals(1, state.read(app).matchedCount());
        assertTrue(samePath(new IndexPath(2), selected(view)));
        press("enter");
        runUntilParked();
        assertEquals(new IndexPath(2).toString(), paths(view.read(app).confirmed));
        assertEquals(1, view.read(app).saves);

        press("escape");
        runUntilParked();
        draw();
        assertEquals("", state.read(app).query(app));
        assertEquals(0, view.read(app).cancellations);
        assertEquals(3, state.read(app).matchedCount());
        press("escape");
        assertEquals(1, view.read(app).cancellations);
        assertTrue(view.read(app).queries.indexOf("保存") != -1);
    }

    function testCommandEmptyAndDisabledOnlyResultsCannotConfirm() {
        final view = palette();
        for (query in ["missing", "Delete"]) {
            input(query);
            runUntilParked();
            draw();
            assertEquals(null, selected(view));
            if (query == "missing") {
                assertEquals(0, view.read(app).state.read(app).matchedCount());
            } else {
                // the only row, Delete, is disabled
                click(100., rowY(0));
            }
            press("down");
            press("enter");
            runUntilParked();
            assertEquals(0, view.read(app).confirmed.length);
            press("escape");
            runUntilParked();
        }
    }

/// Combobox

    function languages(multiple:Bool, disabled:Bool):Entity<Languages> {
        return openRoot((window, cx:Context<Languages>) -> new Languages(window, cx, multiple, disabled));
    }

    function isOpen(view:Entity<Languages>):Bool {
        return view.read(app).state.read(app).state.open;
    }

    /** The trigger holds the focus (the `multi-combo-box` node's `focused()`). */
    function triggerFocused(view:Entity<Languages>):Bool {
        return view.read(app).state.read(app).state.focusHandle.isFocused(window);
    }

    function clickField():Void {
        click(144., 36.);
    }

    function testComboboxFiltersAndCommitsSingleSelection() {
        final view = languages(false, false);
        assertFalse(isOpen(view));
        clickField();
        assertTrue(isOpen(view));
        input("中文");
        runUntilParked();
        draw();
        assertEquals("中文", view.read(app).state.read(app).query(app));
        press("enter");
        waitFor(() -> !isOpen(view));
        assertTrue(triggerFocused(view));
        final v = view.read(app);
        assertEquals("中文", v.state.read(app).selectedValue());
        assertEquals("[中文]", lists(v.changes));
        assertEquals("[中文]", lists(v.confirmations));
    }

    function testComboboxMultipleSelectionTogglesAndConfirmsOnEscape() {
        final view = languages(true, false);
        clickField();
        press("down");
        press("enter");
        runUntilParked();
        draw();
        assertTrue(isOpen(view));
        assertEquals("Rust", view.read(app).state.read(app).selectedValues().join(','));
        press("down");
        press("enter");
        runUntilParked();
        assertEquals("Rust,Go", view.read(app).state.read(app).selectedValues().join(','));
        press("enter");
        runUntilParked();
        press("escape");
        waitFor(() -> !isOpen(view));
        assertTrue(triggerFocused(view));
        final v = view.read(app);
        assertEquals("[Rust];[Rust,Go];[Rust]", lists(v.changes));
        assertEquals("[Rust]", lists(v.confirmations));
        assertEquals("Rust", v.state.read(app).selectedValues().join(','));
    }

    function testDisabledComboboxRejectsOpeningAndEmitsNoSelection() {
        final view = languages(false, true);
        clickField();
        press("down");
        press("enter");
        assertFalse(isOpen(view));
        runUntilParked();
        final v = view.read(app);
        assertEquals(0, v.state.read(app).selectedValues().length);
        assertEquals(0, v.changes.length);
        assertEquals(0, v.confirmations.length);
    }

    function testComboboxEmptySearchCannotSelectAndCanRecover() {
        final view = languages(false, false);
        clickField();
        input("missing");
        waitFor(() -> view.read(app).state.read(app).state.list.read(app).delegate().delegate.itemsCount(0) == 0);
        press("down");
        press("enter");
        runUntilParked();
        assertEquals(0, view.read(app).state.read(app).selectedValues().length);
        assertEquals(0, view.read(app).changes.length);
        assertEquals(0, view.read(app).confirmations.length);
        assertTrue(isOpen(view));
        // Rust `secondary-a`, resolved for macOS, whose keymap the tests use.
        pressKeystroke(Keystroke.parseWithOs("secondary-a", OperatingSystem.Mac));
        input("Go");
        waitFor(() -> view.read(app).state.read(app).state.list.read(app).delegate().delegate.itemsCount(0) > 0);
        // An empty result clears the list cursor; navigate to the recovered row.
        press("down");
        press("enter");
        runUntilParked();
        final v = view.read(app);
        assertEquals("Go", v.state.read(app).selectedValue());
        assertEquals("[Go]", lists(v.changes));
        assertEquals("[Go]", lists(v.confirmations));
    }

    function testComboboxClearButtonUpdatesSelectionWithoutReopening() {
        final view = languages(false, false);
        clickField();
        press("down");
        press("enter");
        runUntilParked();
        draw();
        assertEquals("Rust", view.read(app).state.read(app).selectedValue());
        // The clear button sits where the caret was, at the trigger's right end.
        click(251., 36.);
        assertFalse(isOpen(view));
        runUntilParked();
        final v = view.read(app);
        assertEquals(0, v.state.read(app).selectedValues().length);
        assertEquals("[Rust];[]", lists(v.changes));
        assertEquals("[Rust]", lists(v.confirmations));
    }

}

private class Palette extends Model implements Render {

    public final state:Entity<CommandState>;

    public final confirmed:Array<IndexPath> = [];

    public var cancellations:Int = 0;

    public var saves:Int = 0;

    public final queries:Array<String> = [];

    public function new(state:Entity<CommandState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final view = this;
        return div()
            .sizeFull()
            .onAction(SearchSave, (_, _, _) -> view.saves++)
            .child(new Command(state)
                .group(new CommandGroup()
                    .label("Files")
                    .item(new CommandItem().label("Open"))
                    .item(new CommandItem().label("Delete").disabled(true))
                    .item(new CommandItem().label("Save").keywords(["persist", "保存"]).action(new SearchSave())))
                .empty((_, _, _) -> div().child("No commands"))
                .onConfirm((index, _, _) -> view.confirmed.push(index))
                .onCancel((_, _) -> view.cancellations++)
                .onQuery((value, _, _) -> view.queries.push(value)));
    }

}

private class Languages extends Model implements Render {

    public final state:Entity<ComboboxState<String>>;

    public final disabled:Bool;

    public final changes:Array<Array<Any>> = [];

    public final confirmations:Array<Array<Any>> = [];

    final subscription:Subscription;

    public function new(window:Window, cx:Context<Languages>, multiple:Bool, disabled:Bool) {
        super();
        this.disabled = disabled;
        state = cx.newEntity((c:Context<ComboboxState<String>>) -> new ComboboxState(new SearchableVec(["Rust", "Go", "中文"]), [], window, c)
            .multiple(multiple)
            .searchable(true));
        subscription = cx.subscribe(state, ComboboxEvent, (this_:Languages, _, event, _) -> {
            switch event {
                case Change(values): this_.changes.push(values);
                case Confirm(values): this_.confirmations.push(values);
            }
        });
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().p4().child(
            div()
                .id("language-field")
                .w64()
                .h10()
                .child(new Combobox(state)
                    .disabled(disabled)
                    .cleanable(true)
                    .empty((_, _) -> div().child("No languages")))
        );
    }

}
