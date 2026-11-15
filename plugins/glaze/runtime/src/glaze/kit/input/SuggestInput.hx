// New code for the Haxe port of gpui-kit: no gpui-kit component does this. It follows the pattern of the
// gallery's `InputCompletion` story (crates/story/src/stories/input_completion.rs, Copyright 2024-2026
// Longbridge, Apache-2.0): a menu owned by the application around a single-line `Input`, with the keys
// captured before the input sees them. Addition KIT-008 in docs/DEVIATIONS.md. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.ScrollHandle;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.input.InputActions.Escape;
import glaze.kit.base.input.InputActions.MoveDown;
import glaze.kit.base.input.InputActions.MoveUp;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.list.ListItem;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * The events of a `SuggestInputState` (subscribe with
 * `cx.subscribe(state, SuggestInputEvent, ...)`).
 */
enum SuggestInputEvent {

    /** The text changed: typed, or replaced by a picked suggestion. */
    Change(value:String);

    /** A suggestion was picked (Enter on the highlighted row, or a click). */
    Accept(value:String);

    /** Enter was pressed with no suggestion highlighted: the text as typed. */
    Submit(value:String);

}

/**
 * The state of a `SuggestInput`: a single-line input whose text is free,
 * with a list of suggestions filtered by what is typed, like an HTML
 * `<input list>` with its `<datalist>`.
 *
 * - Typing opens the list of the suggestions that match the text. The down
 *   arrow opens it too (every suggestion when the field is empty).
 * - Up and down move the highlighted row; no row is highlighted until the
 *   first down, so Enter keeps the text as typed (`Submit`).
 * - Enter on a highlighted row, or a click on a row, replaces the text with
 *   that suggestion (`Change`, then `Accept`).
 * - Escape closes the list and keeps the text; with the list closed it is
 *   left to whatever is around the field (a dialog for example).
 * - The list closes when the field loses the focus.
 */
@:allow(glaze.kit.input, tests)
class SuggestInputState extends Model {

    /** The state of the text field, for everything an `InputState` offers. */
    public final input:Entity<InputState>;

    var suggestionsValue:Array<String> = [];

    var filterValue:(String, Array<String>) -> Array<String> = defaultFilter;

    /** The suggestions shown, non null while the list is open. */
    var open:Null<Array<String>> = null;

    /** The highlighted row, `null` when none is. */
    var selected:Null<Int> = null;

    /** The text the open list was filtered for. */
    var openFor:String = '';

    final scrollHandle:ScrollHandle = new ScrollHandle();

    final subscription:Subscription;

    public function new(window:Window, cx:Context<SuggestInputState>) {
        super();
        input = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx));
        subscription = cx.subscribeIn(input, InputEvent, window, (this_:SuggestInputState, _, event, window, cx) -> this_.onInputEvent(event, window, cx));
    }

    /** Sets the placeholder of the field (at creation). */
    public function withPlaceholder(placeholder:String, cx:Context<SuggestInputState>):SuggestInputState {
        input.update(cx, (input, _) -> input.withPlaceholder(placeholder));
        return this;
    }

    /** Sets the suggestions (at creation). */
    public function withSuggestions(suggestions:Array<String>):SuggestInputState {
        suggestionsValue = suggestions.copy();
        return this;
    }

    /**
     * Sets how the suggestions are filtered and ordered for a text (at
     * creation). The default keeps the suggestions that contain the text,
     * whatever the case, those that start with it first, each group in the
     * order given; an empty text keeps them all.
     */
    public function withFilter(filter:(query:String, suggestions:Array<String>) -> Array<String>):SuggestInputState {
        filterValue = filter;
        return this;
    }

    /** Replaces the suggestions; an open list is filtered again. */
    public function setSuggestions(suggestions:Array<String>, cx:Context<SuggestInputState>):Void {
        suggestionsValue = suggestions.copy();
        if (open != null) show(cx);
        cx.notify();
    }

    public function suggestions():Array<String> {
        return suggestionsValue.copy();
    }

    /** The text of the field. */
    public function value(cx:App):String {
        return input.read(cx).value();
    }

    /** Sets the text of the field, without event, and closes the list. */
    public function setValue(value:String, window:Window, cx:Context<SuggestInputState>):Void {
        input.update(cx, (input, cx) -> input.setValue(value, window, cast cx));
        close(cx);
    }

    /** Gives the field the keyboard focus. */
    public function focus(window:Window, cx:Context<SuggestInputState>):Void {
        input.update(cx, (input, cx) -> input.focus(window, cast cx));
    }

    /** Whether the list of suggestions is open. */
    public function isOpen():Bool {
        return open != null;
    }

    /** The suggestions of the open list, in display order (`null` when closed). */
    public function shownSuggestions():Null<Array<String>> {
        return open != null ? open.copy() : null;
    }

    /** The index of the highlighted row of the open list, `null` when none is. */
    public function selectedIndex():Null<Int> {
        return open != null ? selected : null;
    }

    /** Whether `value` is one of the suggestions, whatever the case. */
    public function isSuggestion(value:String):Bool {
        final lower = value.toLowerCase();
        for (suggestion in suggestionsValue) {
            if (suggestion.toLowerCase() == lower) return true;
        }
        return false;
    }

    /** Closes the list of suggestions. */
    public function close(cx:Context<SuggestInputState>):Void {
        if (open != null) {
            open = null;
            selected = null;
            cx.notify();
        }
    }

    static function defaultFilter(query:String, suggestions:Array<String>):Array<String> {
        if (query.length == 0) return suggestions.copy();
        final lower = query.toLowerCase();
        final prefixed:Array<String> = [];
        final contained:Array<String> = [];
        for (suggestion in suggestions) {
            final ix = suggestion.toLowerCase().indexOf(lower);
            if (ix == 0) prefixed.push(suggestion) else if (ix > 0) contained.push(suggestion);
        }
        return prefixed.concat(contained);
    }

    /** Opens the list for the current text, or closes it when nothing matches. */
    function show(cx:Context<SuggestInputState>):Void {
        final text = value(cx.app);
        final items = filterValue(text, suggestionsValue);
        if (items.length == 0) {
            open = null;
            selected = null;
        } else {
            // The highlighted suggestion stays highlighted while the list narrows.
            final previous = open != null && selected != null && selected < open.length ? open[selected] : null;
            final ix = previous != null ? items.indexOf(previous) : -1;
            open = items;
            selected = ix >= 0 ? ix : null;
            openFor = text;
        }
        cx.notify();
    }

    function onInputEvent(event:InputEvent, window:Window, cx:Context<SuggestInputState>):Void {
        switch event {
            case Change:
                show(cx);
                cx.emit(SuggestInputEvent.Change(value(cx.app)));
            case PressEnter(false, _):
                if (isCurrent(cx.app) && selected != null) {
                    accept(selected, window, cx);
                } else {
                    close(cx);
                    cx.emit(SuggestInputEvent.Submit(value(cx.app)));
                }
            case Blur:
                close(cx);
            case _:
        }
    }

    /** Whether the open list still belongs to the text of the field. */
    function isCurrent(cx:App):Bool {
        return open != null && openFor == value(cx);
    }

    /** Replaces the text with the suggestion of row `ix`. */
    function accept(ix:Int, window:Window, cx:Context<SuggestInputState>):Void {
        final items = open;
        if (items == null || ix < 0 || ix >= items.length) {
            return;
        }
        final picked = items[ix];
        final changed = picked != value(cx.app);
        input.update(cx, (input, cx) -> {
            input.setValue(picked, window, cast cx);
            input.focus(window, cast cx);
        });
        open = null;
        selected = null;
        cx.notify();
        if (changed) cx.emit(SuggestInputEvent.Change(picked));
        cx.emit(SuggestInputEvent.Accept(picked));
    }

    /** Up (`-1`) and down (`1`). Returns whether the key was taken. */
    function move(delta:Int, cx:Context<SuggestInputState>):Bool {
        if (open == null || !isCurrent(cx.app)) {
            // Down opens the list; up is left to the field.
            if (delta < 0) {
                if (open != null) close(cx);
                return false;
            }
            show(cx);
            if (open == null) return false;
            selected = 0;
            scrollHandle.scrollToItem(0);
            return true;
        }
        final last = open.length - 1;
        if (selected == null) {
            selected = delta > 0 ? 0 : null;
        } else {
            final next = selected + delta;
            // Up from the first row goes back to the text as typed.
            selected = next < 0 ? null : (next > last ? last : next);
        }
        if (selected != null) scrollHandle.scrollToItem(selected);
        cx.notify();
        return true;
    }

}

/**
 * A single-line text field with a list of suggestions filtered by what is
 * typed, free text allowed (see `SuggestInputState`). Styles set on it go to
 * the field's wrapper; `input(...)` configures the `Input` itself.
 */
class SuggestInput extends Component implements Styled {

    final state:Entity<SuggestInputState>;

    final fieldStyle:StyleRefinement = new StyleRefinement();

    var configureInput:Null<(Input) -> Input> = null;

    /**
     * Sets the width of the list of suggestions, the width of the field
     * when `null` (the default).
     */
    @prop var menuWidth:Null<Pixels> = null;

    /** Sets the largest height of the list before it scrolls, default 256. */
    @prop var menuMaxHeight:Pixels = 256.;

    /** Sets how a suggestion is drawn in the list, its text by default. */
    @prop var renderSuggestion:Null<(String, Window, App) -> IntoElement> = null;

    public function new(state:Entity<SuggestInputState>) {
        super();
        this.state = state;
    }

    /** Configures the `Input` of the field (size, prefix, suffix, appearance). */
    public function input(configure:(Input) -> Input):SuggestInput {
        configureInput = configure;
        return this;
    }

    public inline function style():StyleRefinement {
        return fieldStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state;
        final model = state.read(cx);
        final theme = Theme.global(cx);
        final renderSuggestion = this.renderSuggestion;

        var input = Input.component(model.input);
        if (configureInput != null) input = configureInput(input);

        final field = div()
            .relative()
            .wFull()
            // Before the input sees them, while they mean something here.
            .captureAction(MoveUp, (_, _, cx) -> {
                if (state.update(cx, (state, cx) -> state.move(-1, cx))) cx.stopPropagation();
            })
            .captureAction(MoveDown, (_, _, cx) -> {
                if (state.update(cx, (state, cx) -> state.move(1, cx))) cx.stopPropagation();
            })
            .captureAction(Escape, (_, _, cx) -> {
                if (state.read(cx).isOpen()) {
                    state.update(cx, (state, cx) -> state.close(cx));
                    cx.stopPropagation();
                }
            })
            .refineStyle(fieldStyle)
            .child(input);

        final items = model.open;
        if (items != null) {
            final selected = model.selected;
            final menu = vFlex()
                .id('suggest-input-menu')
                .maxH(glaze.Prelude.px(menuMaxHeight))
                .overflowYScroll()
                .trackScroll(model.scrollHandle)
                .p1()
                .gapY0p5()
                .popoverStyle(cx)
                // A press in the list must not take the focus from the field.
                .onMouseDown(Left, (_, window, cx) -> {
                    window.preventDefault();
                    cx.stopPropagation();
                })
                .children([for (ix in 0...items.length) {
                    final suggestion = items[ix];
                    (new ListItem(ix)
                        .selected(ix == selected)
                        .rounded(theme.radius)
                        .onClick((_, window, cx) -> state.update(cx, (state, cx) -> state.accept(ix, window, cx)))
                        .child(renderSuggestion != null ? renderSuggestion(suggestion, window, cx) : div().textSm().child(suggestion)) : IntoElement);
                }]);
            final holder = div()
                .absolute()
                .left0()
                .top(relative(1.))
                .pt1();
            if (menuWidth != null) {
                menu.w(glaze.Prelude.px(menuWidth));
            } else {
                holder.right0();
                menu.wFull();
            }
            field.child(deferred(holder.child(menu)));
        }
        return field;
    }

}
