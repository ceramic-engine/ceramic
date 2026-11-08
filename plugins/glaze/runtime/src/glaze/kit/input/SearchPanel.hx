// Ported from gpui-kit 0.8.1: crates/component/src/input/search.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.Action;
import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Range;
import glaze.Render;
import glaze.Subscription;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.SearchSession;
import glaze.kit.I18n;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.label.Label;
import glaze.kit.theme.Theme;
import ropey.Rope;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.input.InputSearchExt;

@:action(namespace = input) class Tab implements Action {}

/**
 * The search (and replace) panel of a multi-line input, shown above the text
 * while its search session is open.
 */
class SearchPanel extends Model implements Render {

    static inline final CONTEXT:String = "SearchPanel";

    final editor:WeakEntity<InputBaseState>;

    final searchInput:Entity<InputState>;

    final replaceInput:Entity<InputState>;

    var session:SearchSession = new SearchSession();

    var inputWidth:Pixels = 0.;

    final _subscriptions:Array<Subscription>;

    @:allow(glaze.kit.input, tests)
    function replaceMode():Bool {
        return session.replaceMode;
    }

    @:allow(glaze.kit.input, tests)
    function syncSession(session:SearchSession):Void {
        this.session = session.clone();
    }

    /** The query the panel's search input currently holds. */
    @:allow(glaze.kit.input, tests)
    function query(cx:App):String {
        return searchInput.read(cx).value();
    }

    /**
     * The panel's search input, so a test can assert what re-invoking search
     * does to its value and selection.
     */
    @:allow(tests)
    function getSearchInput():Entity<InputState> {
        return searchInput;
    }

    /** The panel's replace input (tests). */
    @:allow(tests)
    function getReplaceInput():Entity<InputState> {
        return replaceInput;
    }

    @:allow(glaze.kit.input, tests)
    static function create(editor:Entity<InputBaseState>, window:Window, cx:App):Entity<SearchPanel> {
        final searchInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        final replaceInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));

        return cx.newEntity((c:Context<SearchPanel>) -> new SearchPanel(editor, searchInput, replaceInput, c));
    }

    function new(editor:Entity<InputBaseState>, searchInput:Entity<InputState>, replaceInput:Entity<InputState>, cx:Context<SearchPanel>) {
        super();
        _subscriptions = [
            cx.subscribe(searchInput, InputEvent, (this_:SearchPanel, _, ev:InputEvent, cx:Context<SearchPanel>) -> {
                // Handle search input changes
                switch ev {
                    case Change:
                        this_.updateSearchQuery(null, cx);
                    case _:
                }
            }),
        ];

        this.editor = editor.downgrade();
        this.searchInput = searchInput;
        this.replaceInput = replaceInput;
    }

    @:allow(glaze.kit.input, tests)
    function showWithFocus(selectedText:Rope, replaceMode:Bool, visibleRangeOffset:Null<Range>, focus:Bool, window:Window, cx:Context<SearchPanel>):Void {
        session.open = true;
        session.replaceMode = replaceMode;
        if (focus) {
            searchInput.update(cx, (input, cx) -> input.focus(window, cast cx));
        }

        searchInput.update(cx, (this_, cx) -> {
            if (selectedText.len() > 0) {
                this_.setValue(selectedText.toString(), window, cast cx);
            }
            this_.selectAll(window, cast cx);
        });

        // The `set_value` does not emit `InputEvent::Change`, so update the query
        // here to match the value of the search input.
        updateSearchQuery(visibleRangeOffset, cx);
    }

    /**
     * Update the matcher by the value of the search input.
     *
     * The `visibleRangeOffset` is to select the nearest match of the visible range,
     * it is passed in, because the editor may be borrowed by the caller.
     */
    function updateSearchQuery(visibleRangeOffset:Null<Range>, cx:Context<SearchPanel>):Void {
        final query = searchInput.read(cx).value();
        final editor = this.editor;
        final caseInsensitive = session.caseInsensitive;
        editor.tryUpdate(cx, (state, cx) -> {
            state.setSearchQuery(query, caseInsensitive, cx);
        });
        final state = editor.upgrade();
        if (state != null) {
            session = state.read(cx).searchSession.clone();
        }
        if (visibleRangeOffset != null) {
            session.matcher.updateCursorByOffset(visibleRangeOffset.start);
        }
        cx.notify();
    }

    /** The click handler of the case sensitivity button. */
    @:allow(tests)
    function toggleCaseInsensitive(cx:Context<SearchPanel>):Void {
        session.caseInsensitive = !session.caseInsensitive;
        updateSearchQuery(null, cx);
        cx.notify();
    }

    function replaceable(cx:App):Bool {
        final state = editor.upgrade();
        return state != null ? state.read(cx).isReplaceable() : false;
    }

    @:allow(glaze.kit.input, tests)
    function hide(window:Window, cx:Context<SearchPanel>):Void {
        hideWithFocus(true, window, cx);
    }

    @:allow(glaze.kit.input, tests)
    function hideWithFocus(focusEditor:Bool, window:Window, cx:Context<SearchPanel>):Void {
        session.open = false;
        editor.tryUpdate(cx, (state, cx) -> {
            state.closeSearch(cx);
            if (focusEditor) {
                state.focus(window, cx);
            }
        });
        cx.notify();
    }

    function onActionEnter(action:Enter, window:Window, cx:Context<SearchPanel>):Void {
        if (action.shift) {
            prev(window, cx);
        }
        else {
            next(window, cx);
        }
    }

    function onActionEscape(_:Escape, window:Window, cx:Context<SearchPanel>):Void {
        hide(window, cx);
    }

    function onActionTab(_:IndentInline, window:Window, cx:Context<SearchPanel>):Void {
        cycleFocus(window, cx);
    }

    function onActionTabPrev(_:OutdentInline, window:Window, cx:Context<SearchPanel>):Void {
        cycleFocus(window, cx);
    }

    /**
     * Cycle focus between the search and the replace input, to keep the Tab key
     * staying in the panel.
     *
     * There are only 2 inputs, so the forward and the backward are the same.
     */
    function cycleFocus(window:Window, cx:Context<SearchPanel>):Void {
        if (!session.replaceMode || !replaceable(cx.app)) {
            return;
        }

        final searchFocusHandle = searchInput.read(cx).focusHandle;
        final focusHandle = if (searchFocusHandle.isFocused(window)) {
            replaceInput.read(cx).focusHandle;
        } else {
            searchFocusHandle;
        }
        focusHandle.focus(window, cx.app);
    }

    function onActionReplace(_:Replace, window:Window, cx:Context<SearchPanel>):Void {
        toggleReplaceMode(window, cx);
    }

    /** Toggle the replace field, and move focus to the field that is going to be used. */
    function toggleReplaceMode(window:Window, cx:Context<SearchPanel>):Void {
        if (!replaceable(cx.app)) {
            return;
        }

        session.replaceMode = !session.replaceMode;
        final replaceMode = session.replaceMode;
        editor.tryUpdate(cx, (state, cx) -> {
            state.setSearchReplaceMode(replaceMode, cx);
        });
        final focusHandle = if (session.replaceMode) {
            replaceInput.read(cx).focusHandle;
        } else {
            searchInput.read(cx).focusHandle;
        }
        focusHandle.focus(window, cx.app);
        cx.notify();
    }

    function prev(_:Window, cx:Context<SearchPanel>):Void {
        editor.tryUpdate(cx, (state, cx) -> {
            state.previousSearchMatch(cx);
        });
    }

    function next(_:Window, cx:Context<SearchPanel>):Void {
        editor.tryUpdate(cx, (state, cx) -> {
            state.nextSearchMatch(cx);
        });
    }

    function replaceNext(window:Window, cx:Context<SearchPanel>):Void {
        if (!replaceable(cx.app)) {
            session.replaceMode = false;
            cx.notify();
            return;
        }

        final replacement = replaceInput.read(cx).value();
        editor.tryUpdate(cx, (state, cx) -> {
            state.replaceCurrentSearchMatch(replacement, window, cx);
        });
    }

    function replaceAll(window:Window, cx:Context<SearchPanel>):Void {
        if (!replaceable(cx.app)) {
            session.replaceMode = false;
            cx.notify();
            return;
        }

        final replacement = replaceInput.read(cx).value();
        editor.tryUpdate(cx, (state, cx) -> {
            state.replaceAllSearchMatches(replacement, window, cx);
        });
    }

    /** Rust `Focusable::focus_handle`: the search input's. */
    public function focusHandle(cx:App):FocusHandle {
        return searchInput.read(cx).focusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<SearchPanel> = cast cx;
        if (!session.open) {
            return new Empty();
        }

        final theme = Theme.global(cx);
        final hasMatches = !session.matcher.isEmpty();
        final allowReplace = replaceable(cx.app);
        if (!allowReplace) {
            session.replaceMode = false;
        }

        final view:Entity<SearchPanel> = cx.entity();

        final caseButton = Button.component("case-insensitive")
            .selected(!session.caseInsensitive)
            .toggled(!session.caseInsensitive)
            .xsmall()
            .compact()
            .text()
            .icon(IconName.CaseSensitive)
            .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, _:Window, cx:Context<SearchPanel>) -> this_.toggleCaseInsensitive(cx)));

        final searchRow = hFlex()
            .wFull()
            .gap2()
            .child(div()
                .flex()
                .flex1()
                .gap1()
                .child(Input.component(searchInput)
                    .focusBordered(false)
                    .suffix(caseButton)
                    .small()
                    .wFull()
                    .shadowNone())
                .onPrepaint((bounds, _, cx) -> {
                    view.update(cx, (r, _) -> r.inputWidth = bounds.size.width);
                }));
        if (allowReplace) {
            searchRow.child(Button.component("replace-mode")
                .xsmall()
                .ghost()
                .icon(IconName.Replace)
                .selected(session.replaceMode)
                .toggled(session.replaceMode)
                .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                    this_.toggleReplaceMode(window, cx);
                })));
        }
        final matchLabel = Label.component(session.matcher.label());
        if (!hasMatches) matchLabel.textColor(theme.mutedForeground);
        searchRow
            .child(Button.component("prev")
                .xsmall()
                .ghost()
                .icon(IconName.ChevronLeft)
                .disabled(!hasMatches)
                .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                    this_.prev(window, cx);
                })))
            .child(Button.component("next")
                .xsmall()
                .ghost()
                .icon(IconName.ChevronRight)
                .disabled(!hasMatches)
                .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                    this_.next(window, cx);
                })))
            .child(matchLabel
                .textLeft()
                .minW16())
            .child(div().w7())
            .child(Button.component("close")
                .xsmall()
                .ghost()
                .icon(IconName.Close)
                .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                    this_.onActionEscape(new Escape(), window, cx);
                })));

        final panel = vFlex()
            .id("search-panel")
            .occlude()
            .trackFocus(focusHandle(cx.app))
            .keyContext(CONTEXT)
            .onAction(Enter, cx.listener((this_:SearchPanel, action:Action, window:Window, cx:Context<SearchPanel>) -> this_.onActionEnter(cast action, window, cx)))
            .onAction(Escape, cx.listener((this_:SearchPanel, action:Action, window:Window, cx:Context<SearchPanel>) -> this_.onActionEscape(cast action, window, cx)))
            .onAction(IndentInline, cx.listener((this_:SearchPanel, action:Action, window:Window, cx:Context<SearchPanel>) -> this_.onActionTab(cast action, window, cx)))
            .onAction(OutdentInline, cx.listener((this_:SearchPanel, action:Action, window:Window, cx:Context<SearchPanel>) -> this_.onActionTabPrev(cast action, window, cx)))
            .onAction(Replace, cx.listener((this_:SearchPanel, action:Action, window:Window, cx:Context<SearchPanel>) -> this_.onActionReplace(cast action, window, cx)))
            .fontFamily(theme.fontFamily)
            .itemsCenter()
            .py2()
            .px3()
            .wFull()
            .gap1()
            .bg(theme.tokens.popover.background)
            .borderB1()
            .rounded(theme.radius * 0.5)
            .borderColor(theme.border)
            .child(searchRow);
        if (session.replaceMode && allowReplace) {
            panel.child(hFlex()
                .wFull()
                .gap2()
                .child(Input.component(replaceInput)
                    .focusBordered(false)
                    .small()
                    .w(px(inputWidth))
                    .shadowNone())
                .child(Button.component("replace-one")
                    .small()
                    .label(I18n.t("Input.Replace"))
                    .disabled(!hasMatches)
                    .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                        this_.replaceNext(window, cx);
                    })))
                .child(Button.component("replace-all")
                    .small()
                    .label(I18n.t("Input.Replace All"))
                    .disabled(!hasMatches)
                    .onClick(cx.listener((this_:SearchPanel, _:ClickEvent, window:Window, cx:Context<SearchPanel>) -> {
                        this_.replaceAll(window, cx);
                    }))));
        }
        return panel;
    }

}

/**
 * The scroll direction helpers of `search.rs` (Rust `#[cfg(test)]`).
 */
@:allow(tests)
class SearchScroll {

    static function nextScrollDirection(previousMatchIx:Int, currentMatchIx:Int):Null<glaze.kit.base.input.MoveDirection> {
        if (currentMatchIx <= previousMatchIx) {
            return null;
        }
        return glaze.kit.base.input.MoveDirection.Down;
    }

    static function prevScrollDirection(previousMatchIx:Int, currentMatchIx:Int):Null<glaze.kit.base.input.MoveDirection> {
        if (currentMatchIx >= previousMatchIx) {
            return null;
        }
        return glaze.kit.base.input.MoveDirection.Up;
    }

}
