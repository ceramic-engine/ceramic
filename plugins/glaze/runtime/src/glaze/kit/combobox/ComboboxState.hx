// Ported from gpui-kit 0.8.1: crates/component/src/combobox.rs (ComboboxTriggerContext, ComboboxEvent,
// ComboboxState, render_trigger_container, render_popup_shell)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-006 (default placeholder key). See docs/DEVIATIONS.md.
// Also modified during the initial port: deviation DEV-010 (the menu is measured from the trigger). See docs/DEVIATIONS.md.
package glaze.kit.combobox;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Length;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.base.GlobalState;
import glaze.kit.base.IndexPath;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.input.ClearButton;
import glaze.kit.input.Input;
import glaze.kit.list.List;
import glaze.kit.list.ListState;
import glaze.kit.popover.Popover;
import glaze.kit.searchablelist.SearchableListAdapter;
import glaze.kit.searchablelist.SearchableListChange;
import glaze.kit.searchablelist.SearchableListDelegate;
import glaze.kit.searchablelist.SearchableListItems;
import glaze.kit.searchablelist.SearchableListState;
import glaze.kit.searchablelist.SelectedItem;
import glaze.kit.select.Caret;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.StyledExt;
using glaze.kit.Size.SizeTools;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * Context passed to the `renderTrigger` closure on `Combobox`.
 *
 * The fields are private and reached through the methods below, so that a new
 * one can be added without breaking the trigger renderers.
 */
class ComboboxTriggerContext<I> {

    final selectionValue:Array<SelectedItem<I>>;

    final placeholderValue:Null<String>;

    final openValue:Bool;

    final disabledValue:Bool;

    final sizeValue:Size;

    @:allow(glaze.kit.combobox)
    function new(selection:Array<SelectedItem<I>>, placeholder:Null<String>, open:Bool, disabled:Bool, size:Size) {
        this.selectionValue = selection;
        this.placeholderValue = placeholder;
        this.openValue = open;
        this.disabledValue = disabled;
        this.sizeValue = size;
    }

    /** The items currently selected, empty when the combobox has no value. */
    public function selection():Array<SelectedItem<I>> {
        return selectionValue;
    }

    public function placeholder():Null<String> {
        return placeholderValue;
    }

    /** Whether the dropdown list is showing. */
    public function isOpen():Bool {
        return openValue;
    }

    public function isDisabled():Bool {
        return disabledValue;
    }

    public function size():Size {
        return sizeValue;
    }

}

/**
 * Events emitted by `ComboboxState`. The values are the item values
 * (`SearchableListItems.value`).
 */
enum ComboboxEvent {
    /** Emitted on every toggle (item added or removed). */
    Change(values:Array<Any>);
    /** Emitted when the popover closes. */
    Confirm(values:Array<Any>);
}

/**
 * State of the `Combobox` component.
 *
 * `I` is the item type of the delegate (Rust `D::Item`).
 */
@:allow(glaze.kit, tests)
class ComboboxState<I> extends Model implements Render {

    final state:SearchableListState<I>;

    // Combobox-specific fields

    var multipleValue:Bool = false;

    var searchableValue:Bool = false;

    var triggerIcon:Null<Icon> = null;

    var checkIcon:Null<Icon> = null;

    var renderTrigger:Null<(ComboboxTriggerContext<I>, Window, App) -> AnyElement> = null;

    var footer:Null<(Window, App) -> AnyElement> = null;

    var focusRingEnabled:Bool = true;

    /**
     * Create a new `Combobox` state.
     */
    public function new(delegate:SearchableListDelegate<I>, selectedIndices:Array<IndexPath>, window:Window, cx:Context<ComboboxState<I>>) {
        super();
        final weak = cx.weakEntity();
        final weakConfirm = weak;
        final weakCancel = weak;
        final weakEmpty = weak;

        state = new SearchableListState<I>(
            delegate,
            selectedIndices,
            (selectedIndex, _secondary, window, cx) -> {
                #if cs
                // Names I in this closure's own body: Haxe's C# output makes a closure generic
                // only then, and its nested closure below needs I (the output does not compile otherwise)
                final _csTypeParam:Null<I> = null;
                #end
                cx.deferIn(window, (listState, window, cx) -> {
                    final listState:ListState<SearchableListAdapter<I>> = cast listState;
                    final index = selectedIndex;
                    if (index == null) return;

                    final item = listState.delegate().delegate.item(index);
                    if (item == null) return;

                    final ix = index;

                    final entity = weakConfirm.upgrade();
                    if (entity == null) return;

                    final s = entity.read(cx);
                    final multiple = s.multipleValue;
                    final selection = s.state.selection.copy();

                    final changes = selectionChanges(multiple, selection, ix, item);

                    final beforeIndices = [for (entry in selection) entry.index];

                    // on_will_change is called directly: entity-handle access would
                    // re-enter the ListState lock that defer_in holds for this callback.
                    listState.delegateMut().delegate.onWillChange(selection, changes);

                    final afterIndices = [for (entry in selection) entry.index];
                    final changed = !sameIndices(beforeIndices, afterIndices);
                    final shouldClose = changed && !multiple;

                    var newSelection:Null<Array<SelectedItem<I>>> = null;
                    if (weakConfirm.upgrade() != null) {
                        newSelection = weakConfirm.update(cx, (this_, cx) -> {
                            this_.state.selection = selection;

                            if (changed) {
                                cx.emit(ComboboxEvent.Change(this_.selectedValues()));
                                cx.notify();
                            }

                            if (shouldClose) {
                                cx.emit(ComboboxEvent.Confirm(this_.selectedValues()));
                                this_.setOpen(false, cx);
                                this_.focus(window, cx.app);
                            }

                            return this_.state.selection.copy();
                        });
                    }

                    // Sync snapshot and fire on_confirm directly: same re-entrancy guard.
                    if (newSelection != null) {
                        listState.delegateMut().updateSelectionSnapshot(newSelection.copy());

                        if (shouldClose) {
                            listState.delegateMut().delegate.onConfirm(newSelection);
                        }
                    }
                });
            },
            // on_cancel: close and emit Confirm with current values
            (_finalSelectedIndex, window, cx) -> {
                #if cs
                // Names I in this closure's own body: Haxe's C# output makes a closure generic
                // only then, and its nested closure below needs I (the output does not compile otherwise)
                final _csTypeParam:Null<I> = null;
                #end
                cx.deferIn(window, (_listState, window, cx) -> {
                    #if cs final _csTypeParam:Null<I> = null; #end
                    weakCancel.tryUpdate(cx, (this_, cx) -> {
                        // Cancel propagates to the BaseCombobox, which may already
                        // have confirmed and closed before this deferred callback.
                        if (!this_.state.open) return;
                        cx.emit(ComboboxEvent.Confirm(this_.selectedValues()));
                        this_.setOpen(false, cx);
                        this_.focus(window, cx.app);
                    });
                });
            },
            // on_render_empty
            (window, cx) -> {
                final entity = weakEmpty.upgrade();
                final empty = entity != null ? entity.read(cx).state.empty : null;
                if (empty != null) {
                    return empty(window, cx);
                } else {
                    return hFlex()
                        .justifyCenter()
                        .py6()
                        .textColor(Theme.global(cx).mutedForeground.opacity(0.6))
                        .child(inboxIcon())
                        .intoAnyElement();
                }
            },
            (this_:Dynamic, window, cx) -> {
                // A local typed with I (not an inline cast) so that Haxe's C# output makes this closure generic
                final state:ComboboxState<I> = this_;
                state.onBlur(window, cast cx);
            },
            window,
            cx
        );
    }

    /** Rust `Icon::new(IconName::Inbox).size(px(28.))` (`Styled::size`). */
    static function inboxIcon():Icon {
        final icon = Icon.component(IconName.Inbox);
        new glaze.StyleBuilder(icon.style()).size(px(28.));
        return icon;
    }

    override function destroy() {
        // Rust drops the deferred popover token with the state.
        if (state != null && state.deferredContext != null) {
            state.deferredContext.release();
            state.deferredContext = null;
        }
        super.destroy();
    }

    static function sameIndices(a:Array<IndexPath>, b:Array<IndexPath>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) if (!a[i].equals(b[i])) return false;
        return true;
    }

    /**
     * Enable multi-select mode.
     *
     * When `true`, clicking an item toggles it in the selection and the popover stays open.
     * When `false` (default), clicking an item replaces the selection and closes the popover.
     */
    public function multiple(multiple:Bool):ComboboxState<I> {
        multipleValue = multiple;
        return this;
    }

    /**
     * Enable or disable the search input at the top of the dropdown.
     */
    public function searchable(searchable:Bool):ComboboxState<I> {
        searchableValue = searchable;
        return this;
    }

    /**
     * Return the currently selected values.
     */
    public function selectedValues():Array<Any> {
        return state.selectedValues();
    }

    /**
     * Return the first selected value, or `null` when nothing is selected.
     *
     * Convenience for single-select mode (`multiple(false)`).
     */
    public function selectedValue():Null<Any> {
        final values = state.selectedValues();
        return values.length > 0 ? values[0] : null;
    }

    /**
     * Return the currently selected `(IndexPath, Item)` pairs.
     */
    public function selection():Array<SelectedItem<I>> {
        return state.selectionItems();
    }

    /**
     * Replace the entire selection set by item values.
     *
     * Values are resolved through the current delegate. Values that cannot be resolved are
     * ignored. This updates the committed selection and snapshot without emitting a
     * `ComboboxEvent`.
     */
    public function setSelectedValues(values:Array<Any>, window:Window, cx:Context<ComboboxState<I>>):Void {
        state.clearQuery(window, cx.app);

        final delegate = state.list.read(cx).delegate().delegate;
        final selectedIndices:Array<IndexPath> = [];
        for (value in values) {
            final position = delegate.position(value);
            if (position != null) selectedIndices.push(position);
        }

        setSelectedIndices(selectedIndices, window, cx);
    }

    /**
     * Replace the entire selection set.
     */
    public function setSelectedIndices(indices:Array<IndexPath>, _window:Window, cx:Context<ComboboxState<I>>):Void {
        state.setSelectedIndices(indices, cx.app);
        state.syncSnapshot(cx.app);
        cx.notify();
    }

    /**
     * Add a single index to the selection, if not already present, returning whether it was added.
     */
    public function addSelectedIndex(index:IndexPath, cx:Context<ComboboxState<I>>):Bool {
        final added = state.addSelectedIndex(index, cx.app);

        if (added) {
            state.syncSnapshot(cx.app);
            cx.notify();
        }

        return added;
    }

    /**
     * Remove a single index from the selection, returning whether it was removed.
     */
    public function removeSelectedIndex(index:IndexPath, cx:Context<ComboboxState<I>>):Bool {
        final removed = state.removeSelectedIndex(index);

        if (removed) {
            state.syncSnapshot(cx.app);
        }

        return removed;
    }

    /**
     * Clear all selected values.
     */
    public function clearSelection(cx:Context<ComboboxState<I>>):Void {
        state.selection = [];
        state.syncSnapshot(cx.app);
        cx.emit(ComboboxEvent.Change(selectedValues()));
        cx.notify();
    }

    /**
     * Replace the underlying delegate (item data source).
     */
    public function setItems(items:SearchableListDelegate<I>, _:Window, cx:Context<ComboboxState<I>>):Void {
        state.list.update(cx, (list, _) -> {
            list.delegateMut().delegate = items;
        });
    }

    /**
     * Focus the trigger.
     */
    public function focus(window:Window, cx:App):Void {
        state.focusHandle.focus(window, cx);
    }

    /**
     * Returns the search query.
     */
    public function query(cx:App):String {
        return state.list.read(cx).queryInput.read(cx).value();
    }

    /**
     * Sets the search query and updates the filtered items.
     */
    public function setQuery(query:String, window:Window, cx:App):Void {
        state.list.update(cx, (list, cx) -> {
            list.setQuery(query, window, cx);
        });
    }

    static function selectionChanges<I>(multiple:Bool, selection:Array<SelectedItem<I>>, ix:IndexPath, item:I):Array<SearchableListChange> {
        final value = SearchableListItems.value(item);
        var isSelected = false;
        for (entry in selection) {
            if (SearchableListItems.valueEquals(SearchableListItems.value(entry.item), value)) {
                isSelected = true;
                break;
            }
        }

        if (multiple) {
            return isSelected ? [Deselect(ix)] : [Select(ix)];
        } else {
            final changes:Array<SearchableListChange> = [for (entry in selection) Deselect(entry.index)];
            changes.push(Select(ix));
            return changes;
        }
    }

    /**
     * Process an item click: single-select replaces the selection and closes; multi-select toggles.
     *
     * Calls `delegate.onWillChange` before committing and `delegate.onConfirm` when closing.
     */
    function handleItemSelect(ix:IndexPath, window:Window, cx:Context<ComboboxState<I>>):Void {
        final item = state.list.read(cx).delegate().delegate.item(ix);
        if (item == null) return;

        final changes = selectionChanges(multipleValue, state.selection, ix, item);

        final selection = state.selection.copy();
        final beforeIndices = [for (entry in selection) entry.index];

        state.list.update(cx, (list, _cx) -> {
            list.delegateMut().delegate.onWillChange(selection, changes);
        });

        final afterIndices = [for (entry in selection) entry.index];
        final changed = !sameIndices(beforeIndices, afterIndices);
        final shouldClose = changed && !multipleValue;

        state.selection = selection;
        state.syncSnapshot(cx.app);

        if (changed) {
            cx.emit(ComboboxEvent.Change(selectedValues()));
            cx.notify();
        }

        if (shouldClose) {
            final finalSelection = state.selection.copy();
            state.list.update(cx, (list, _cx) -> {
                list.delegateMut().delegate.onConfirm(finalSelection);
            });

            cx.emit(ComboboxEvent.Confirm(selectedValues()));
            setOpen(false, cx);
            focus(window, cx.app);
        }
    }

    function onBlur(window:Window, cx:Context<ComboboxState<I>>):Void {
        if (state.list.read(cx).isFocused(window, cx.app) || state.focusHandle.isFocused(window)) {
            return;
        }

        setOpen(false, cx);
        cx.notify();
    }

    function toggleMenu(_:ClickEvent, window:Window, cx:Context<ComboboxState<I>>):Void {
        cx.stopPropagation();

        setOpen(!state.open, cx);

        if (state.open) {
            state.list.read(cx).focusHandle(cx.app).focus(window, cx.app);
        } else {
            cx.emit(ComboboxEvent.Confirm(selectedValues()));
            focus(window, cx.app);
        }

        cx.notify();
    }

    /**
     * Close the menu when a press lands outside the popup.
     *
     * A press on the trigger is left to propagate: swallowing it here would keep nested
     * controls (a tag remove button, the clear button) from ever seeing the press, and
     * `toggleMenu` closes the menu on release anyway.
     */
    function dismiss(event:MouseDownEvent, window:Window, cx:Context<ComboboxState<I>>):Void {
        if (!state.open || state.bounds.contains(event.position)) {
            return;
        }

        cx.stopPropagation();
        cx.emit(ComboboxEvent.Confirm(selectedValues()));

        setOpen(false, cx);
        focus(window, cx.app);
        cx.notify();
    }

    function setOpen(open:Bool, cx:Context<ComboboxState<I>>):Void {
        state.open = open;
        // Rust drops the previous token by replacing it.
        if (state.deferredContext != null) state.deferredContext.release();
        state.deferredContext = open ? GlobalState.registerDeferredPopover(cx) : null;

        cx.notify();
    }

    function clean(_:ClickEvent, _:Window, cx:Context<ComboboxState<I>>):Void {
        cx.stopPropagation();
        clearSelection(cx);
    }

    function defaultTriggerBody(_window:Window, cx:Context<ComboboxState<I>>):AnyElement {
        // Initial port deviation DEV-006: the original reads `Combobox.placeholder`,
        // a key the locales do not have (they spell it `ComboBox`), so it showed
        // the key itself.
        final placeholderText = state.placeholder != null ? state.placeholder : I18n.t("ComboBox.placeholder");

        if (state.selection.length == 0) {
            return div()
                .textColor(Theme.global(cx).mutedForeground)
                .child(placeholderText)
                .intoAnyElement();
        }

        if (multipleValue) {
            final items = [for (entry in state.selection) SearchableListItems.title(entry.item)];

            return div()
                .wFull()
                .overflowHidden()
                .whitespaceNowrap()
                .truncate()
                .child(items.join(", "))
                .intoAnyElement();
        } else {
            final title = state.selection.length > 0 ? SearchableListItems.title(state.selection[0].item) : "";

            return div()
                .wFull()
                .overflowHidden()
                .whitespaceNowrap()
                .truncate()
                .child(title)
                .intoAnyElement();
        }
    }

    /** Rust `Focusable::focus_handle`. */
    public function focusHandle(cx:App):FocusHandle {
        if (state.open) {
            return state.list.read(cx).focusHandle(cx);
        } else {
            return state.focusHandle;
        }
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<ComboboxState<I>> = cast cx;
        final theme = Theme.global(cx);
        final searchable = searchableValue;
        final isFocused = state.focusHandle.isFocused(window);
        final showClean = state.cleanable && state.selection.length != 0;
        final bounds = state.bounds;
        final allowOpen = !state.disabled;
        final outlineVisible = state.open || (isFocused && !state.disabled);
        final disabled = state.disabled;

        final colors = Input.inputStyleColors(disabled, cx.app);
        final bg = colors.background;
        final fg = colors.foreground;

        final size = state.size;
        final checkIcon = this.checkIcon;
        state.list.update(cx, (list, cx) -> {
            list.setSearchable(searchable, cx);
            list.delegateMut().size = size;
            list.delegateMut().checkIcon = checkIcon != null ? checkIcon.clone() : null;
        });

        final selection = state.selection;
        final placeholder = state.placeholder;
        final open = state.open;
        final hasCustomTrigger = renderTrigger != null;

        final triggerBody = if (renderTrigger != null) {
            final trigger = new ComboboxTriggerContext(selection, placeholder, open, disabled, size);

            renderTrigger(trigger, window, cx.app);
        } else {
            defaultTriggerBody(window, cx);
        };

        final trailing:AnyElement = if (hasCustomTrigger) {
            div().intoAnyElement();
        } else if (showClean) {
            final button = ClearButton.clearButton(cx.app);
            if (disabled) {
                button.disabled(true);
            } else {
                button.onClick(cx.listener((this_:ComboboxState<I>, e:ClickEvent, window, cx) -> this_.clean(e, window, cx)));
            }
            (button:IntoElement);
        } else if (triggerIcon != null) {
            (triggerIcon.clone().xsmall().textColor(theme.mutedForeground):IntoElement);
        } else {
            (Caret.component(size).textColor(theme.mutedForeground):IntoElement);
        };

        final toggleHandler:Null<(ClickEvent, Window, App) -> Void> = allowOpen
            ? cx.listener((this_:ComboboxState<I>, e:ClickEvent, window, cx) -> this_.toggleMenu(e, window, cx))
            : null;

        final footerEl = footer != null ? footer(window, cx.app) : null;

        final dismissHandler:(MouseDownEvent, Window, App) -> Void = cx.listener((this_:ComboboxState<I>, e:MouseDownEvent, window, cx) -> this_.dismiss(e, window, cx));

        final entity:Entity<ComboboxState<I>> = cx.entity();

        final anchor = div()
            .relative()
            // Deviation DEV-010: the menu is sized and placed from the trigger
            // (the first child, border box), not from this wrapper, which spans
            // the parent when the trigger has a width of its own.
            .onChildrenPrepainted((children, _, cx) -> {
                if (children.length > 0) {
                    final bounds = children[0];
                    entity.update(cx, (r, _) -> r.state.bounds = bounds);
                }
            })
            .child(renderTriggerContainer(
                disabled,
                state.appearance,
                focusRingEnabled,
                state.size,
                state.style,
                bg,
                fg,
                outlineVisible,
                allowOpen,
                triggerBody,
                trailing,
                toggleHandler,
                window,
                cx.app
            ));
        if (state.open) {
            anchor.child(
                deferred(renderPopupShell(
                    ElementId.NamedInteger("combobox-popup", cx.entityId()),
                    state.list,
                    state.menuWidth,
                    state.searchPlaceholder,
                    state.size,
                    state.menuMaxH,
                    bounds,
                    footerEl,
                    dismissHandler,
                    cx.app
                ))
                    .withPriority(glaze.kit.base.Popup.POPUP_PRIORITY)
            );
        }

        return div().sizeFull().relative().child(anchor);
    }

    // MARK: Rendering helpers

    /**
     * Renders the styled trigger container.
     */
    static function renderTriggerContainer(disabled:Bool, appearance:Bool, focusRingEnabled:Bool, size:Size, style:StyleRefinement, bg:Hsla,
            fg:Hsla, outlineVisible:Bool, allowOpen:Bool, triggerBody:AnyElement, trailing:AnyElement,
            toggleHandler:Null<(ClickEvent, Window, App) -> Void>, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = div()
            .id("input")
            .relative()
            .flex()
            .itemsCenter()
            .justifyBetween()
            .border1()
            .borderColor(theme.transparent);
        if (appearance) {
            element.bg(bg).textColor(fg);
            if (disabled) element.opacity(0.5);
            element.borderColor(theme.input).rounded(theme.radius);
        }
        element.inputSize(size)
            .inputTextSize(size)
            .refineStyle(style);
        if (outlineVisible && appearance) {
            element.border1().borderColor(theme.ring);
        }
        if (outlineVisible && appearance && focusRingEnabled) {
            element.focusRingStyle(window, cx);
        }
        if (allowOpen && toggleHandler != null) {
            element.onClick(toggleHandler);
        }
        return element.child(
            hFlex()
                .id("inner")
                .wFull()
                .minW0()
                .overflowHidden()
                .whitespaceNowrap()
                .itemsCenter()
                .justifyBetween()
                .gap1()
                .child(
                    div()
                        .flex1()
                        .minW0()
                        .overflowHidden()
                        .whitespaceNowrap()
                        .child(triggerBody)
                )
                .child(trailing)
        );
    }

    /**
     * Renders the deferred anchored popup shell containing the searchable list and optional footer.
     */
    static function renderPopupShell<I>(id:ElementId, list:Entity<ListState<SearchableListAdapter<I>>>, menuWidth:Length,
            searchPlaceholder:Null<String>, size:Size, menuMaxH:Length, bounds:Bounds, footerEl:Null<AnyElement>,
            dismissHandler:(MouseDownEvent, Window, App) -> Void, cx:App):AnyElement {
        final theme = Theme.global(cx);
        final hasFooter = footerEl != null;

        final surface = vFlex().occlude();
        switch menuWidth {
            case Auto: surface.w(px(bounds.size.width));
            case Definite(w): surface.w(w);
        }
        final listElement = List.component(list);
        if (searchPlaceholder != null) listElement.searchPlaceholder(searchPlaceholder);
        listElement.withSize(size).maxH(menuMaxH);
        listElement.paddingsEdges(glaze.Edges.all(SizeTools.DROPDOWN_LIST_PADDING));
        surface.popoverStyle(cx).child(listElement);
        if (hasFooter) {
            surface.child(
                div()
                    .borderT1()
                    .borderColor(theme.border)
                    .p1()
                    .child(footerEl)
            );
        }
        surface.onMouseDownOut(dismissHandler);

        return Popover.dropdownPopup(id, bounds, surface, cx).intoAnyElement();
    }

}
