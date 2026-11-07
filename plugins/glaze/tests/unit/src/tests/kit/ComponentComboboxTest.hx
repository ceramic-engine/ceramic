// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/vec.rs (tests),
// crates/base/src/combobox.rs (tests), crates/component/src/combobox.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.Point;
import glaze.Render;
import glaze.Subscription;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.Component;
import glaze.kit.combobox.Combobox;
import glaze.kit.combobox.ComboboxState;
import glaze.kit.searchablelist.SearchableListChange;
import glaze.kit.searchablelist.SearchableListDelegate;
import glaze.kit.searchablelist.SearchableListDelegate.SearchableListDelegateBase;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.searchablelist.SearchableVec.SearchableGroup;
import glaze.kit.searchablelist.SelectedItem;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tests of gpui-component's `SearchableVec` (`searchable_list/vec.rs`),
 * gpui-base's unstyled `Combobox` and gpui-component's `Combobox` /
 * `ComboboxState`.
 *
 * `retained::drawing_a_combobox_again_leaves_the_page_around_it_retained` is
 * not ported: it only builds with gpui-kit's optional `gpui-fast` feature
 * (a retained GPUI fork), while the port and the reference harness follow
 * standard GPUI.
 */
class ComponentComboboxTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    var visual:Null<VisualTestContext> = null;

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
        if (visual != null) visual.destroy();
        visual = null;
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    /** `cx.add_empty_window()`. */
    function emptyWindow():Void {
        app.update(cx -> {
            window = Window.open(cx, {width: 640, height: 480, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                return cx.newEntity((c:Context<Blank>) -> new Blank());
            });
        });
        dispatcher.runUntilParked();
    }

    static inline function ip(row:Int, section:Int = 0):IndexPath {
        return new IndexPath(row).withSection(section);
    }

    static function samePath(a:Null<IndexPath>, b:Null<IndexPath>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    static function paths<I>(selection:Array<SelectedItem<I>>):String {
        return [for (entry in selection) entry.index.toString()].join(',');
    }

    static function newState<I>(cx:App, delegate:SearchableListDelegate<I>, selected:Array<IndexPath>, window:Window, multiple:Bool = false, searchable:Bool = false):Entity<ComboboxState<I>> {
        return cx.newEntity((c:Context<ComboboxState<I>>) -> new ComboboxState(delegate, selected, window, c).multiple(multiple).searchable(searchable));
    }

    static function vec(items:Array<String>):SearchableVec<String> {
        return new SearchableVec(items);
    }

    // MARK: searchable_list/vec.rs

    function testSearchableVecMapsMatchedRowsToItems() {
        emptyWindow();
        app.update(cx -> {
            final items = vec(["Rust", "Go", "Ruby"]);
            items.performSearch("ru", window, cx);
            assertEquals(2, items.itemsCount(0));
            assertEquals("Ruby", items.item(new IndexPath(1)));
            assertTrue(samePath(new IndexPath(1), items.position("Ruby")));
            assertEquals(null, items.position("Go"));

            items.push("Rune");
            assertEquals("Rune", items.item(new IndexPath(2)));

            items.performSearch("", window, cx);
            assertEquals(4, items.itemsCount(0));
        });
    }

    function testSearchableGroupKeepsMatchedRows() {
        emptyWindow();
        app.update(cx -> {
            final groups = SearchableVec.groups([
                new SearchableGroup<String>("Fruits").withItems(["Apple", "Banana"]),
                new SearchableGroup<String>("Berries").withItems(["Blueberry", "Cranberry"]),
                new SearchableGroup<String>("Nuts").withItems(["Almond"]),
            ]);

            groups.performSearch("cran", window, cx);
            assertEquals(1, groups.sectionsCount(cx));
            assertEquals(1, groups.itemsCount(0));
            assertEquals("Cranberry", groups.item(new IndexPath(0)));
            assertTrue(samePath(new IndexPath(0), groups.position("Cranberry")));
            assertEquals(null, groups.position("Blueberry"));

            // A title match keeps the section, with only its matching rows.
            groups.performSearch("nuts", window, cx);
            assertEquals(1, groups.sectionsCount(cx));
            assertEquals(0, groups.itemsCount(0));

            groups.performSearch("b", window, cx);
            assertEquals(2, groups.sectionsCount(cx));
            assertEquals(2, groups.itemsCount(1));
            assertTrue(samePath(new IndexPath(1).withSection(1), groups.position("Cranberry")));
        });
    }

    // MARK: base combobox.rs

    function harness():{cx:VisualTestContext, state:Entity<Harness>} {
        final result = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<Harness>) -> new Harness(cx));
        visual = result.cx;
        final cx = result.cx;
        final state = result.view;
        cx.update((window, cx) -> {
            final contentFocus = state.read(cx).contentFocus;
            contentFocus.focus(window, cx);
            window.draw();
        });
        return {cx: cx, state: state};
    }

    function testEscapeDismissesThenClosesAndRestoresTriggerFocus() {
        final h = harness();
        h.cx.simulateKeystrokes("escape");

        h.cx.update((window, cx) -> {
            assertFalse(h.state.read(cx).open);
            assertTrue(h.state.read(cx).triggerFocus.isFocused(window));
            // Dismissal runs before the close request so a caller can still
            // commit its pending value.
            assertEquals("dismiss,close", h.state.read(cx).events.join(','));
        });
    }

    function testEnterConfirmsWithoutDismissingWhileOpen() {
        final h = harness();
        h.cx.simulateKeystrokes("enter");

        h.cx.update((_, cx) -> {
            assertTrue(h.state.read(cx).open);
            assertEquals("confirm", h.state.read(cx).events.join(','));
        });
    }

    // MARK: component combobox.rs

    function testComboBoxBuilder() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["Rust", "Go", "C++"]), [], window, false, true);

            final cb = new Combobox(state)
                .placeholder("Select language")
                .searchPlaceholder("Search...")
                .menuWidth(px(300.))
                .menuMaxH(rems(15.))
                .cleanable(true)
                .disabled(false)
                .appearance(true);
            assertTrue(cb != null);
        });
    }

    function testComboBoxSearchFiltersItems() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["Rust", "Go", "C++"]), [], window, false, true);

            final list = state.read(cx).state.list;
            assertEquals(3, list.read(cx).delegate().delegate.itemsCount(0));

            list.update(cx, (list, cx) -> list.delegateMut().delegate.performSearch("Rust", window, cx.app));

            assertEquals(1, list.read(cx).delegate().delegate.itemsCount(0));
        });
    }

    function testComboBoxSetQueryUpdatesTextAndFiltersItems() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["Rust", "Go", "C++"]), [], window, false, true);

            state.update(cx, (state, cx) -> state.setQuery(" Rust ", window, cx.app));

            assertEquals(" Rust ", state.read(cx).query(cx));
            assertEquals(1, state.read(cx).state.list.read(cx).delegate().delegate.itemsCount(0));
        });
    }

    function testMultiComboBoxBuilder() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [new IndexPath(0)], window, true, true);

            new Combobox(state)
                .placeholder("Select frameworks")
                .searchPlaceholder("Search...")
                .menuWidth(px(300.))
                .cleanable(true)
                .disabled(false);

            assertEquals("React", state.read(cx).selectedValues().join(','));
        });
    }

    function testComboBoxSetSelectedValuesUsesCurrentDelegate() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);

            state.update(cx, (state, cx) -> {
                state.setSelectedValues(["Vue", "Missing"], window, cx);

                assertEquals("Vue", state.selectedValues().join(','));
                assertEquals(new IndexPath(1).toString(), paths(state.selection()));
                assertEquals(paths(state.selection()), paths(state.state.list.read(cx).delegate().selectionSnapshot));

                state.setItems(vec(["Vue", "Rust", "Go"]), window, cx);
                state.setSelectedValues(["Go", "Vue"], window, cx);

                assertEquals("Go,Vue", state.selectedValues().join(','));
                assertEquals([new IndexPath(2).toString(), new IndexPath(0).toString()].join(','), paths(state.selection()));
                assertEquals(paths(state.selection()), paths(state.state.list.read(cx).delegate().selectionSnapshot));

                state.setSelectedValues([], window, cx);

                assertEquals(0, state.selection().length);
                assertEquals(0, state.state.list.read(cx).delegate().selectionSnapshot.length);
            });
        });
    }

    /**
     * A value projected in from outside is not a position in the filtered view,
     * so an active search must not decide which values can be selected.
     */
    function testComboBoxSetSelectedValuesKeepsValuesHiddenByTheSearch() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);

            state.update(cx, (state, cx) -> {
                state.setSelectedValues(["React", "Vue"], window, cx);
                state.state.list.update(cx, (list, cx) -> list.setQuery("Angular", window, cx));

                state.setSelectedValues(["React", "Vue", "Angular"], window, cx);

                // a value the search had hidden must survive being reapplied
                assertEquals("React,Vue,Angular", state.selectedValues().join(','));
                // clearing the query puts every selected item back in view
                assertEquals([for (i in 0...3) new IndexPath(i).toString()].join(','), paths(state.selection()));
            });
        });
    }

    function testComboBoxSetSelectedValuesDoesNotEmitEvents() {
        emptyWindow();
        var count = 0;
        var state:Entity<ComboboxState<String>> = null;
        var subscription:Subscription = null;
        app.update(cx -> {
            state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);
            subscription = cx.subscribe(state, ComboboxEvent, (_, _, _) -> count++);
        });

        app.update(cx -> state.update(cx, (state, cx) -> state.setSelectedValues(["React", "Vue"], window, cx)));
        dispatcher.runUntilParked();

        assertEquals(0, count);
        subscription.dispose();
    }

    function testComboBoxInitialSelectionSeedsCursor() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [new IndexPath(1)], window, true);

            // initial selected_indices should seed ListState.selected_index, not just the snapshot
            assertTrue(samePath(new IndexPath(1), state.read(cx).state.list.read(cx).selectedIndex()));
            assertEquals("Vue", state.read(cx).selectedValues().join(','));
        });
    }

    function testMultiComboBoxToggle() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);

            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(0), cx));
            assertEquals("React", state.read(cx).selectedValues().join(','));

            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(1), cx));
            assertEquals("React,Vue", state.read(cx).selectedValues().join(','));

            state.update(cx, (s, cx) -> s.removeSelectedIndex(new IndexPath(0), cx));
            assertEquals("Vue", state.read(cx).selectedValues().join(','));
        });
    }

    function testMultiComboBoxSearchSelectionUsesValueIdentity() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);

            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(0), cx));
            assertEquals("React", state.read(cx).selectedValues().join(','));

            state.update(cx, (s, cx) -> {
                s.state.list.update(cx, (list, cx) -> list.delegateMut().delegate.performSearch("Vue", window, cx.app));
            });

            final s = state.read(cx);
            final selection = s.state.selection.copy();
            final delegate = s.state.list.read(cx).delegate().delegate;
            final ix = new IndexPath(0);
            final item = delegate.item(ix);
            assertEquals("Vue", item);
            // filtered row 0 should not inherit React's checked state
            assertFalse(delegate.isItemChecked(ix, item, selection, cx));

            state.update(cx, (s, cx) -> s.handleItemSelect(new IndexPath(0), window, cx));
            assertEquals("React,Vue", state.read(cx).selectedValues().join(','));
        });
    }

    function testMultiComboBoxSearchDeselectsByValue() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);

            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(0), cx));

            state.update(cx, (s, cx) -> {
                s.state.list.update(cx, (list, cx) -> list.delegateMut().delegate.performSearch("React", window, cx.app));
            });

            state.update(cx, (s, cx) -> s.handleItemSelect(new IndexPath(0), window, cx));
            assertEquals(0, state.read(cx).selectedValues().length);
        });
    }

    function testSearchableListDefaultChangeUsesValueIdentity() {
        emptyWindow();
        app.update(cx -> {
            final delegate = vec(["React", "Vue", "Angular"]);
            final selection = [new SelectedItem(new IndexPath(1), "Vue")];

            delegate.performSearch("Vue", window, cx);
            delegate.onWillChange(selection, [SearchableListChange.Deselect(new IndexPath(0))]);
            assertEquals(0, selection.length);

            delegate.onWillChange(selection, [SearchableListChange.Select(new IndexPath(0))]);
            assertEquals(1, selection.length);
            assertTrue(selection[0].equals(new SelectedItem(new IndexPath(0), "Vue")));
        });
    }

    function testMultiComboBoxClear() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["React", "Vue", "Angular"]), [new IndexPath(0), new IndexPath(1)], window, true);

            assertEquals(2, state.read(cx).selectedValues().length);
            state.update(cx, (s, cx) -> s.clearSelection(cx));
            assertEquals(0, state.read(cx).selectedValues().length);
        });
    }

    function testSingleComboBoxMode() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, vec(["Rust", "Go", "C++"]), [], window);

            // Default mode is Single.
            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(0), cx));
            assertEquals("Rust", state.read(cx).selectedValues().join(','));

            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(1), cx));
            assertEquals("Rust,Go", state.read(cx).selectedValues().join(','));
        });
    }

    function testOnWillChangeVeto() {
        emptyWindow();
        app.update(cx -> {
            final delegate = new VetoDelegate(vec(["Rust", "Go", "C++"]));
            final state = newState(cx, delegate, [], window);

            // Pre-select an item directly so we can verify veto prevents changes.
            state.update(cx, (s, cx) -> s.addSelectedIndex(new IndexPath(0), cx));
            assertEquals("Rust", state.read(cx).selectedValues().join(','));

            // Simulate a click on index 1 via handle_item_select; on_will_change vetoes it.
            state.update(cx, (s, cx) -> s.handleItemSelect(new IndexPath(1), window, cx));

            // Selection must remain unchanged because on_will_change left it unmodified.
            assertEquals("Rust", state.read(cx).selectedValues().join(','));
        });
    }

    static function leftPress(position:Point):MouseDownEvent {
        return new MouseDownEvent(Left, position, Modifiers.none(), 1, false);
    }

    function testComboBoxDismissIgnoresPressOnTrigger() {
        emptyWindow();
        var count = 0;
        var state:Entity<ComboboxState<String>> = null;
        var subscription:Subscription = null;
        app.update(cx -> {
            state = newState(cx, vec(["React", "Vue", "Angular"]), [], window, true);
            subscription = cx.subscribe(state, ComboboxEvent, (_, _, _) -> count++);
        });

        app.update(cx -> state.update(cx, (state, cx) -> {
            state.state.bounds = new Bounds(new Point(10., 10.), new glaze.Size(200., 32.));
            state.setOpen(true, cx);
            state.dismiss(leftPress(new Point(20., 20.)), window, cx);
        }));
        dispatcher.runUntilParked();

        // a press on the trigger must reach nested controls, so the menu stays
        // open and `toggle_menu` closes it on release instead
        app.update(cx -> assertTrue(state.read(cx).state.open));
        assertEquals(0, count);

        app.update(cx -> state.update(cx, (state, cx) -> state.dismiss(leftPress(new Point(20., 200.)), window, cx)));
        dispatcher.runUntilParked();

        app.update(cx -> assertFalse(state.read(cx).state.open));
        // dismissing from outside the trigger emits Confirm
        assertEquals(1, count);
        subscription.dispose();
    }

}

private class Harness extends Model implements Render {

    public var open:Bool = true;

    public final triggerFocus:FocusHandle;

    public final contentFocus:FocusHandle;

    public final events:Array<String> = [];

    public function new(cx:Context<Harness>) {
        super();
        triggerFocus = cx.focusHandle();
        contentFocus = cx.focusHandle();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final state:Entity<Harness> = cast cx.entity();
        final events = this.events;

        return new glaze.kit.base.Combobox("combobox")
            .open(open)
            .focusHandle(triggerFocus)
            .contentFocusHandle(contentFocus)
            .onConfirm((_, _) -> events.push("confirm"))
            .onDismiss((_, _) -> events.push("dismiss"))
            .onOpenChange((open, _, cx) -> {
                events.push("close");
                state.update(cx, (state, cx) -> {
                    state.open = open;
                    cx.notify();
                });
            })
            .child(div().trackFocus(contentFocus).size(px(20.)));
    }

}

/** Delegate that vetoes all selections via `onWillChange` by ignoring the changes. */
private class VetoDelegate<I> extends SearchableListDelegateBase<I> {

    // Generic over the item type (used with String): on C#, Haxe cannot override the
    // base `item(ix):Null<I>` with a concrete `Null<String>` (the output does not compile).

    final inner:SearchableVec<I>;

    public function new(inner:SearchableVec<I>) {
        this.inner = inner;
    }

    public function itemsCount(section:Int):Int {
        return inner.itemsCount(section);
    }

    public function item(ix:IndexPath):Null<I> {
        return inner.item(ix);
    }

    public function position(value:Any):Null<IndexPath> {
        return inner.position(value);
    }

    override public function onWillChange(selection:Array<SelectedItem<I>>, changes:Array<SearchableListChange>):Void {
        // Leave selection unchanged: acts as a veto.
    }

}

private class Blank extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}
