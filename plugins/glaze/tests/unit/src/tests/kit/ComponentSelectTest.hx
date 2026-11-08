// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.I18n;
import glaze.kit.searchablelist.SearchableListItem;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.select.Select;
import glaze.kit.select.SelectState;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The tests of gpui-component's `Select` and `SelectState`.
 *
 * Rust builds the delegates as `SearchableVec::new(vec![...])`,
 * `SearchableVec<SelectGroup<_>>` (`SearchableVec.groups` here) and a bare
 * `Vec` (`VecDelegate`).
 *
 * `retained::drawing_a_select_again_leaves_the_page_around_it_retained` is
 * not ported: it only builds with gpui-kit's optional `gpui-fast` feature
 * (a retained GPUI fork), while the port and the reference harness follow
 * standard GPUI, where every draw renders the root view again.
 */
class ComponentSelectTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
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

    static function newState<I>(cx:App, delegate:glaze.kit.searchablelist.SearchableListDelegate<I>, selected:Null<IndexPath>, window:Window, searchable:Bool = false):Entity<SelectState<I>> {
        return cx.newEntity((c:Context<SelectState<I>>) -> new SelectState(delegate, selected, window, c).searchable(searchable));
    }

    static inline function ip(row:Int, section:Int = 0):IndexPath {
        return new IndexPath(row).withSection(section);
    }

    static function samePath(a:Null<IndexPath>, b:Null<IndexPath>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    function testAnExplicitAccessibilityLabelDoesNotReplaceThePlaceholder() {
        emptyWindow();
        app.update(cx -> {
            final items = new SearchableVec(["Rust", "Go", "C++"]);
            final state = newState(cx, items, null, window);

            final plain = new Select(state).placeholder("Choose a language");
            assertEquals(null, plain.builderOptions.accessibilityLabel);
            assertEquals("Choose a language", plain.builderOptions.placeholder);

            final named = new Select(state)
                .placeholder("Choose a language")
                .accessibilityLabel("Programming language");
            assertEquals("Programming language", named.builderOptions.accessibilityLabel);
            // an accessible name must not change what is drawn
            assertEquals("Choose a language", named.builderOptions.placeholder);
        });
    }

    function testSelectInitialSelectionSeedsCursor() {
        emptyWindow();
        app.update(cx -> {
            final items = new SearchableVec(["Rust", "Go", "C++"]);
            final state = newState(cx, items, ip(1), window);

            // initial cursor should be seeded on ListState so display_title can read it
            assertTrue(samePath(ip(1), state.read(cx).selectedIndex(cx)));
            assertEquals("Go", state.read(cx).selectedValue());
        });
    }

    function testSelectInitialGroupedSelectionSeedsCursor() {
        emptyWindow();
        app.update(cx -> {
            final groups = SearchableVec.groups([]);
            groups.push(new SelectGroup("A").withItems(["Apple", "Avocado"]));
            groups.push(new SelectGroup("B").withItems(["Banana", "Blueberry", "Blackberry"]));

            final initial = ip(1, 1);
            final state = newState(cx, groups, initial, window);

            assertTrue(samePath(initial, state.read(cx).selectedIndex(cx)));
            assertEquals("Blueberry", state.read(cx).selectedValue());
        });
    }

    function testSelectSetSelectedValueClearsSearchQuery() {
        emptyWindow();
        app.update(cx -> {
            final items = new SearchableVec(["Rust", "Go", "C++"]);
            final state = newState(cx, items, null, window, true);
            final list = state.read(cx).state.list;

            list.update(cx, (list, cx) -> list.setQuery("Rust", window, cx));
            assertEquals(1, list.read(cx).delegate().delegate.itemsCount(0));

            state.update(cx, (state, cx) -> {
                state.setSelectedValue("Go", window, cx);
            });

            assertEquals("Go", state.read(cx).selectedValue());
            assertTrue(samePath(ip(1), state.read(cx).selectedIndex(cx)));
            assertEquals("", list.read(cx).queryInput.read(cx).value());
        });
    }

    function testSelectSetSelectedValueClearsGroupedSearchQuery() {
        emptyWindow();
        app.update(cx -> {
            final groups = SearchableVec.groups([]);
            groups.push(new SelectGroup("A").withItems(["Apple", "Avocado"]));
            groups.push(new SelectGroup("B").withItems(["Banana", "Blueberry"]));

            final state = newState(cx, groups, null, window, true);
            final list = state.read(cx).state.list;

            list.update(cx, (list, cx) -> list.setQuery("Blue", window, cx));
            state.update(cx, (state, cx) -> {
                state.setSelectedValue("Banana", window, cx);
            });

            assertEquals("Banana", state.read(cx).selectedValue());
            assertTrue(samePath(ip(0, 1), state.read(cx).selectedIndex(cx)));
        });
    }

    function testSelectAccessibilityValueTracksPlaceholderAndSelection() {
        emptyWindow();
        app.update(cx -> {
            final items = new SearchableVec(["Rust", "Go"]);
            final state = newState(cx, items, null, window, true);

            new Select(state)
                .placeholder("Choose a language")
                .accessibilityLabel("Programming language")
                .render(window, cx);
            assertEquals("Choose a language", state.read(cx).accessibilityValue());

            state.update(cx, (state, cx) -> {
                state.setSelectedValue("Rust", window, cx);
            });
            assertEquals("Rust", state.read(cx).accessibilityValue());

            final list = state.read(cx).state.list;
            list.update(cx, (list, cx) -> list.setQuery("Go", window, cx));
            assertEquals(1, list.read(cx).delegate().delegate.itemsCount(0));
            // Filtering changes the available rows, not the committed value.
            assertEquals("Rust", state.read(cx).accessibilityValue());

            new Select(state)
                .placeholder("Choose a language")
                .titlePrefix("Language: ")
                .render(window, cx);
            assertEquals("Language: Rust", state.read(cx).accessibilityValue());

            state.update(cx, (state, cx) -> state.setSelectedIndex(null, window, cx));
            assertEquals("Choose a language", state.read(cx).accessibilityValue());

            new Select(state).render(window, cx);
            assertEquals(I18n.t("Select.placeholder"), state.read(cx).accessibilityValue());
        });
    }

    function testReplacingItemsReconcilesTheCursorAndSelection() {
        emptyWindow();
        app.update(cx -> {
            final state = newState(cx, new VecDelegate(["main", "topic", "release"]), ip(0), window);
            final list = state.read(cx).state.list;
            list.update(cx, (list, cx) -> list.setSelectedIndex(ip(1), window, cx));
            state.update(cx, (state, cx) -> state.setItems(new VecDelegate(["release", "main", "topic"]), window, cx));
            assertTrue(samePath(ip(2), state.read(cx).selectedIndex(cx)));
            assertEquals("main", state.read(cx).selectedValue());
            assertTrue(samePath(ip(1), state.read(cx).state.selection[0].index));
            assertTrue(samePath(ip(1), list.read(cx).delegate().selectionSnapshot[0].index));
            state.update(cx, (state, cx) -> state.setItems(new VecDelegate(["main", "replacement"]), window, cx));
            assertEquals(null, state.read(cx).selectedIndex(cx));
            assertEquals("main", state.read(cx).selectedValue());

            // A selected value the new items no longer have is dropped.
            state.update(cx, (state, cx) -> state.setItems(new VecDelegate(["replacement", "other"]), window, cx));
            assertEquals(null, state.read(cx).selectedValue());
            assertEquals(0, state.read(cx).state.selection.length);
            assertEquals(0, list.read(cx).delegate().selectionSnapshot.length);
        });
    }

    function testDisabledItemsCannotBeConfirmed() {
        emptyWindow();
        for (unavailable in [true, false]) {
            var state:Entity<SelectState<RemoteChoice>> = null;
            app.update(cx -> {
                state = newState(cx, new VecDelegate([new RemoteChoice("main", "Main", unavailable)]), ip(0), window);
                state.update(cx, (state, cx) -> state.setOpen(true, cx));
                final list = state.read(cx).state.list;
                list.update(cx, (list, cx) -> {
                    list.delegateMut().confirm(false, window, cast cx);
                });
            });
            dispatcher.runUntilParked();
            assertEquals(unavailable, state.read(app).state.open);
        }
    }

    /// crates/kit/tests/integration/controls.rs (the select cases)
    //
    // gpui-kit finds the controls through its accessibility test queries:
    // `find("language").value()` is the root's accessible value
    // (`accessibilityValue()`), `expanded()` its open state, and
    // `click("input")` lands on the trigger (the middle of its prepainted
    // bounds here). The `Form` keeps the controls these cases touch (the
    // `agree` checkbox and the select), in the same column.

    function openForm(build:(Window, Context<Form>) -> Form, width:Float = 640, height:Float = 600):Entity<Form> {
        var view:Entity<Form> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((viewCx:Context<Form>) -> build(window, viewCx));
                return cx.newEntity((rootCx:Context<glaze.kit.base.Root>) -> new glaze.kit.base.Root(view, window, rootCx));
            });
        });
        dispatcher.runUntilParked();
        renderFrame();
        return view;
    }

    function renderFrame():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function clickAt(position:glaze.Point):Void {
        app.update(cx -> window.dispatchEvent(new glaze.MouseMoveEvent(position, null, glaze.Modifiers.none()), cx));
        app.update(cx -> window.dispatchEvent(new glaze.MouseDownEvent(Left, position, glaze.Modifiers.none(), 1, false), cx));
        app.update(cx -> window.dispatchEvent(new glaze.MouseUpEvent(Left, position, glaze.Modifiers.none(), 1), cx));
        dispatcher.runUntilParked();
        renderFrame();
    }

    /**
     * `window.within(select).click("input")`: the middle of the trigger. The
     * prepainted bounds are those of the trigger's wrapper, which spans the
     * whole column; the `Form` sizes the trigger itself to 240.
     */
    function clickTrigger<I>(state:Entity<SelectState<I>>):Void {
        final bounds = state.read(app).state.bounds;
        clickAt(new glaze.Point(bounds.origin.x + Math.min(bounds.size.width, 240.) / 2, bounds.origin.y + bounds.size.height / 2));
    }

    /** `window.press(key)`. */
    function press(key:String):Void {
        app.update(cx -> window.dispatchKeystroke(glaze.Keystroke.parse(key), cx));
        app.update(cx -> window.dispatchEvent(new glaze.KeyUpEvent(glaze.Keystroke.parse(key)), cx));
        dispatcher.runUntilParked();
        renderFrame();
    }

    /** `window.input(text)`: the platform's text input, to the focused handler. */
    function input(text:String):Void {
        renderFrame();
        app.update(_ -> {
            final handler = window.peekInputHandler();
            if (handler != null) handler.replaceTextInRange(null, text);
        });
        dispatcher.runUntilParked();
        renderFrame();
    }

    /** `cx.wait_for(...)`: lets the deferred commit and the search timer run. */
    function waitFor():Void {
        dispatcher.advanceClock(0.5);
        dispatcher.runUntilParked();
        renderFrame();
    }

    static function languageState(window:Window, cx:Context<Form>, searchable:Bool = false):Entity<SelectState<String>> {
        return cx.newEntity((c:Context<SelectState<String>>) -> new SelectState(new SearchableVec(["Rust", "Go"]), ip(0), window, c).searchable(searchable));
    }

    function testSelectReportsValueAndKeyboardOpenState() {
        final form = openForm((window, cx) -> new Form(languageState(window, cx), "Language: "));
        final language = form.read(app).language;
        assertEquals("Language: Rust", language.read(app).accessibilityValue());
        assertFalse(language.read(app).state.open);
        clickTrigger(language);
        assertTrue(language.read(app).state.open);
        press("escape");
        assertFalse(language.read(app).state.open);
        clickTrigger(language);
        press("down");
        press("enter");
        // Select commits through defer_in after the dispatch callback returns.
        waitFor();
        assertFalse(language.read(app).state.open);
        assertEquals("Language: Go", language.read(app).accessibilityValue());
    }

    function testSelectEmitsOneDismissEventForEachOpenToClosedTransition() {
        for (searchable in [false, true]) {
            final form = openForm((window, cx) -> new Form(languageState(window, cx, searchable), "Language: "));
            final language = form.read(app).language;
            app.update(_ -> window.setActive(true));
            dispatcher.runUntilParked();
            final events:Array<String> = [];
            final subscriptions = [
                app.subscribe(language, glaze.DismissEvent, (_, _, _) -> events.push("dismiss")),
                app.subscribe(language, SelectEvent, (_, _, _) -> events.push("confirm")),
            ];

            for (close in ["escape", "outside", "blur", "confirm"]) {
                events.resize(0);
                renderFrame();
                clickTrigger(language);
                assertTrue(language.read(app).state.open);
                dispatcher.runUntilParked();
                assertEquals(0, events.length, "opening must not dismiss");

                switch close {
                    case "escape": press("escape");
                    case "outside": clickAt(form.read(app).agreeCenter());
                    case "blur": app.update(cx -> window.blur(cx));
                    case _: press("enter");
                }
                renderFrame();
                dispatcher.runUntilParked();
                renderFrame();
                assertFalse(language.read(app).state.open, '$close, searchable=$searchable');
                // Follow-up Escape and blur notifications must not dismiss twice.
                app.update(cx -> language.update(cx, (language, cx) -> language.focus(window, cx.app)));
                press("escape");
                app.update(cx -> window.blur(cx));
                renderFrame();
                dispatcher.runUntilParked();
                final expected = close == "confirm" ? "confirm,dismiss" : "dismiss";
                assertEquals(expected, events.join(","), '$close, searchable=$searchable');
            }
            for (subscription in subscriptions) subscription.dispose();
            window.destroy();
            window = null;
        }
    }

    function openSearchableLanguage():Entity<SelectState<String>> {
        final form = openForm((window, cx) -> new Form(cx.newEntity((c:Context<SelectState<String>>) -> {
            final items = new SearchableVec(["Dutch", "English", "French", "Hungarian"]);
            return new SelectState(items, ip(1), window, c).searchable(true);
        }), null), 640, 480);
        return form.read(app).language;
    }

    /** Opens the menu and types the query. The list filters in a task. */
    function searchLanguage(language:Entity<SelectState<String>>, query:String):Void {
        renderFrame();
        clickTrigger(language);
        if (query.length > 0) {
            input(query);
        }
        dispatcher.runUntilParked();
    }

    function testSearchableSelectNextOpenAfterCancelShowsAllItems() {
        final language = openSearchableLanguage();

        searchLanguage(language, "hun");
        press("escape");
        waitFor();
        assertFalse(language.read(app).state.open);

        // With an empty query, Down moves from English to French.
        searchLanguage(language, "");
        press("down");
        press("enter");
        waitFor();
        assertFalse(language.read(app).state.open);
        assertEquals("French", language.read(app).accessibilityValue());
    }

    function testSearchableSelectNextOpenAfterConfirmShowsAllItems() {
        final language = openSearchableLanguage();

        searchLanguage(language, "hun");
        press("enter");
        waitFor();
        assertFalse(language.read(app).state.open);
        assertEquals("Hungarian", language.read(app).accessibilityValue());

        // With an empty query, Up moves from Hungarian to French.
        searchLanguage(language, "");
        press("up");
        press("enter");
        waitFor();
        assertFalse(language.read(app).state.open);
        assertEquals("French", language.read(app).accessibilityValue());
    }

}

/**
 * The `Form` of gpui-kit's `controls.rs` (and its `SearchableLanguageForm`
 * when `titlePrefix` is null): the `agree` checkbox and the select.
 */
private class Form extends Model implements Render {

    public var agreed:Bool = false;

    public final language:Entity<SelectState<String>>;

    final titlePrefix:Null<String>;

    var agreeBounds:Null<glaze.Bounds> = null;

    public function new(language:Entity<SelectState<String>>, titlePrefix:Null<String>) {
        super();
        this.language = language;
        this.titlePrefix = titlePrefix;
    }

    public function agreeCenter():glaze.Point {
        final b = agreeBounds;
        return new glaze.Point(b.origin.x + b.size.width / 2, b.origin.y + b.size.height / 2);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<Form> = cast cx;
        final self = this;
        final select = new Select(language).id("language");
        if (titlePrefix != null) select.titlePrefix(titlePrefix);
        select.w(px(240.));
        if (titlePrefix == null) {
            return div().sizeFull().child(select);
        }
        final agree = div().child(
            new glaze.kit.checkbox.Checkbox("agree")
                .label("Agree")
                .checked(agreed)
                .onChange(cx.listener((this_:Form, checked:Bool, _, cx) -> {
                    this_.agreed = checked;
                    cx.notify();
                }))
        );
        glaze.kit.base.ElementExt.onPrepaint(agree, (bounds, _, _) -> self.agreeBounds = bounds);
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .gap4()
            .child(agree)
            .child(select);
    }

}

typedef VecDelegate<T> = glaze.kit.searchablelist.SearchableVec.VecDelegate<T>;

private class RemoteChoice extends glaze.kit.searchablelist.SearchableListItem.SearchableListItemBase {

    final valueValue:String;

    final titleValue:String;

    final unavailable:Bool;

    public function new(value:String, title:String, unavailable:Bool) {
        this.valueValue = value;
        this.titleValue = title;
        this.unavailable = unavailable;
    }

    public function value():Any {
        return valueValue;
    }

    public function title():String {
        return titleValue;
    }

    override public function disabled():Bool {
        return unavailable;
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
