// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Context;
import glaze.Entity;
import glaze.Keystroke;
import glaze.kit.input.SuggestInput;
import glaze.kit.input.SuggestInput.SuggestInputEvent;
import glaze.kit.input.SuggestInput.SuggestInputState;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * `SuggestInput` (KIT-008): a text field with a filtered list of
 * suggestions and free text allowed.
 */
class KitSuggestInputTest extends KitAdditionsTestCase {

    static final CODES = ['de', 'en', 'en-GB', 'es', 'fr', 'fr-CA', 'it', 'ja', 'pt-BR', 'zh-Hans'];

    var state:Entity<SuggestInputState>;

    final events:Array<String> = [];

    /** A 300 px field in a kit root, focused, with the language codes as suggestions. */
    function mount(?suggestions:Array<String>, ?configure:(SuggestInput) -> SuggestInput):VisualTestContext {
        events.resize(0);
        final escapes = this.escapes;
        escapes[0] = 0;
        final cx = open((window, cx) -> {
            if (state == null) {
                state = cx.newEntity((c:Context<SuggestInputState>) -> new SuggestInputState(window, c)
                    .withPlaceholder('Language code', c)
                    .withSuggestions(suggestions != null ? suggestions : CODES));
                cx.app.subscribe(state, SuggestInputEvent, (_, event:SuggestInputEvent, _) -> events.push(Std.string(event)));
            }
            final field = SuggestInput.component(state);
            return div()
                .sizeFull()
                .onAction(glaze.kit.base.input.InputActions.Escape, (_, _, _) -> escapes[0]++)
                .child(div().w(px(300.)).p4().child(probe('field', configure != null ? configure(field) : field)));
        }, 600, 500, true);
        cx.update((window, app) -> state.update(app, (state, cx) -> state.focus(window, cx)));
        draw(cx);
        return cx;
    }

    final escapes:Array<Int> = [0];

    override function teardown() {
        state = null;
        super.teardown();
    }

    function type(cx:VisualTestContext, text:String):Void {
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final keystroke = Keystroke.parse(String.fromCharCode(c));
            cx.update((window, app) -> window.dispatchKeystroke(keystroke, app));
        }
        cx.runUntilParked();
        draw(cx);
    }

    function keys(cx:VisualTestContext, keystrokes:String):Void {
        cx.simulateKeystrokes(keystrokes);
        draw(cx);
    }

    function shown():Null<String> {
        final items = state.read(app).shownSuggestions();
        return items != null ? items.join(',') : null;
    }

    function value():String {
        return state.read(app).value(app);
    }

    function testTypingFiltersTheSuggestions() {
        final cx = mount();
        assertEquals(null, shown());
        type(cx, 'e');
        // Those that start with the text first, then those that contain it.
        assertEquals('en,en-GB,es,de', shown());
        assertEquals(null, state.read(app).selectedIndex());
        type(cx, 'n');
        assertEquals('en,en-GB', shown());
        type(cx, '-');
        assertEquals('en-GB', shown());
        // Nothing matches: the list closes, the text stays.
        type(cx, 'x');
        assertEquals(null, shown());
        assertEquals('en-x', value());
        assertEquals('Change(e),Change(en),Change(en-),Change(en-x)', events.join(','));
    }

    function testTheFilterIgnoresCase() {
        final cx = mount();
        type(cx, 'ZH');
        assertEquals('zh-Hans', shown());
        assertTrue(state.read(app).isSuggestion('FR-ca'));
        assertFalse(state.read(app).isSuggestion('xx'));
    }

    function testEnterKeepsFreeTextWhenNoRowIsHighlighted() {
        final cx = mount();
        type(cx, 'fr');
        assertEquals('fr,fr-CA', shown());
        keys(cx, 'enter');
        assertEquals('fr', value());
        assertEquals(null, shown());
        assertEquals('Change(f),Change(fr),Submit(fr)', events.join(','));

        // A text that is no suggestion at all is submitted as it is.
        events.resize(0);
        type(cx, '-x-klingon');
        keys(cx, 'enter');
        assertEquals('fr-x-klingon', value());
        assertEquals('Submit(fr-x-klingon)', events[events.length - 1]);
    }

    function testArrowsHighlightAndEnterPicks() {
        final cx = mount();
        type(cx, 'e');
        keys(cx, 'down');
        assertEquals(0, state.read(app).selectedIndex());
        keys(cx, 'down down');
        assertEquals(2, state.read(app).selectedIndex());
        keys(cx, 'up');
        assertEquals(1, state.read(app).selectedIndex());
        keys(cx, 'enter');
        assertEquals('en-GB', value());
        assertEquals(null, shown());
        assertEquals('Change(e),Change(en-GB),Accept(en-GB)', events.join(','));
        // The field keeps the focus and goes on taking text.
        type(cx, 'x');
        assertEquals('en-GBx', value());
    }

    function testTheHighlightStopsAtTheEndsAndUpLeavesTheList() {
        final cx = mount();
        type(cx, 'fr');
        keys(cx, 'down down down down');
        assertEquals(1, state.read(app).selectedIndex());
        keys(cx, 'up up');
        // Back on the text as typed: Enter submits it.
        assertEquals(null, state.read(app).selectedIndex());
        assertEquals('fr,fr-CA', shown());
        keys(cx, 'enter');
        assertEquals('Submit(fr)', events[events.length - 1]);
    }

    function testDownOpensTheWholeListOnAnEmptyField() {
        final cx = mount();
        keys(cx, 'down');
        assertEquals(CODES.join(','), shown());
        assertEquals(0, state.read(app).selectedIndex());
        keys(cx, 'enter');
        assertEquals('de', value());
        assertEquals('Change(de),Accept(de)', events.join(','));
    }

    function testEscapeClosesTheListThenIsLeftToTheSurroundings() {
        final cx = mount();
        type(cx, 'e');
        keys(cx, 'down');
        keys(cx, 'escape');
        assertEquals(null, shown());
        assertEquals('e', value());
        assertEquals(0, escapes[0]);
        // The list closed, Escape reaches what is around the field.
        keys(cx, 'escape');
        assertEquals(1, escapes[0]);
    }

    function testAClickPicksASuggestion() {
        final cx = mount();
        type(cx, 'p');
        assertEquals('pt-BR', shown());
        final field = boundsOf(cx, 'field');
        // The list hangs under the field, as wide as it.
        cx.simulateClick(point(field.left() + 30., field.bottom() + 20.));
        draw(cx);
        assertEquals('pt-BR', value());
        assertEquals(null, shown());
        assertEquals('Change(p),Change(pt-BR),Accept(pt-BR)', events.join(','));
        type(cx, '!');
        assertEquals('pt-BR!', value());
    }

    function testTheListIsDrawnUnderTheFieldAndScrollsToTheHighlight() {
        final many = [for (i in 0...60) 'lang-$i'];
        final cx = mount(many, field -> field.menuMaxHeight(120.).renderSuggestion((suggestion, _, _) -> probe('row-$suggestion', div().child(suggestion))));
        keys(cx, 'down');
        final field = boundsOf(cx, 'field');
        final first = boundsOf(cx, 'row-lang-0');
        assertTrue(first.top() >= field.bottom(), 'first row at ${first.top()}, field ends at ${field.bottom()}');
        assertTrue(first.left() >= field.left() && first.right() <= field.right());
        for (_ in 0...30) cx.simulateKeystrokes('down');
        draw(cx);
        draw(cx);
        assertEquals(30, state.read(app).selectedIndex());
        final row = boundsOf(cx, 'row-lang-30');
        assertTrue(row.top() >= field.bottom() && row.bottom() <= field.bottom() + 4. + 120. + 1., 'row 30 at ${row.top()}..${row.bottom()}');
    }

    function testSetValueAndSetSuggestions() {
        final cx = mount();
        cx.update((window, app) -> state.update(app, (state, cx) -> state.setValue('ja', window, cx)));
        draw(cx);
        assertEquals('ja', value());
        assertEquals(null, shown());
        assertEquals('', events.join(','));
        type(cx, '-');
        assertEquals(null, shown());
        cx.update((_, app) -> state.update(app, (state, cx) -> state.setSuggestions(['ja-JP', 'ja-Latn'], cx)));
        type(cx, 'J');
        assertEquals('ja-JP', shown());
    }

    function testLosingTheFocusClosesTheList() {
        final cx = mount();
        type(cx, 'e');
        assertEquals('en,en-GB,es,de', shown());
        // The test window is not active, so GPUI reports no focus change
        // to it: the input's blur event is delivered by hand.
        cx.update((window, app) -> state.update(app, (state, cx) -> @:privateAccess state.onInputEvent(glaze.kit.base.input.InputEvent.Blur, window, cx)));
        draw(cx);
        assertEquals(null, shown());
    }

}
