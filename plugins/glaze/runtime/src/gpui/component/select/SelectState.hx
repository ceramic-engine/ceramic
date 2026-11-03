// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (`SelectEvent`, `SelectState`,
// the back-compat re-exports)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-010 (the menu is measured from the trigger). See DEVIATIONS.md.
package gpui.component.select;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.Context;
import gpui.DismissEvent;
import gpui.ElementId;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Length;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.base.Actions.Cancel;
import gpui.base.GlobalState;
import gpui.base.IndexPath;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.input.ClearButton;
import gpui.component.input.Input;
import gpui.component.list.List;
import gpui.component.list.ListState;
import gpui.component.popover.Popover;
import gpui.component.searchablelist.SearchableListAdapter;
import gpui.component.searchablelist.SearchableListChange;
import gpui.component.searchablelist.SearchableListDelegate;
import gpui.component.searchablelist.SearchableListItems;
import gpui.component.searchablelist.SearchableListState;
import gpui.component.searchablelist.SelectedItem;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.ElementExt;
using gpui.base.Observe;
using gpui.base.StyledExt;
using gpui.component.Size.SizeTools;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/** Re-exported for backward compatibility. New code should prefer `SearchableGroup`. */
typedef SelectGroup<I> = gpui.component.searchablelist.SearchableVec.SearchableGroup<I>;

/** Re-exported for backward compatibility. New code should prefer `SearchableListDelegate`. */
typedef SelectDelegate<I> = gpui.component.searchablelist.SearchableListDelegate<I>;

/** Re-exported for backward compatibility. New code should prefer `SearchableListItem`. */
typedef SelectItem = gpui.component.searchablelist.SearchableListItem;

/** Re-exported for backward compatibility. New code should prefer `SearchableListItemElement`. */
typedef SelectListItem = gpui.component.searchablelist.SearchableListItemElement;

/**
 * Events emitted by `SelectState`. The value is the item's value
 * (`SearchableListItems.value`), or null.
 */
enum SelectEvent {
    Confirm(value:Null<Any>);
}

/**
 * State of the `Select` component.
 *
 * Emits `DismissEvent` when an open menu closes, including after a selection is confirmed.
 *
 * `I` is the item type of the delegate (Rust `D::Item`).
 */
@:allow(gpui.component, tests)
class SelectState<I> extends Model implements Render {

    final state:SearchableListState<I>;

    // Select-specific fields
    var searchableValue:Bool = false;

    var icon:Null<Icon> = null;

    var titlePrefix:Null<String> = null;

    var focusRingEnabled:Bool = true;

    /** Create a new Select state. */
    public function new(delegate:SearchableListDelegate<I>, selectedIndex:Null<IndexPath>, window:Window, cx:Context<SelectState<I>>) {
        super();
        final weak = cx.weakEntity();
        final weakConfirm = weak;
        final weakCancel = weak;
        final weakEmpty = weak;

        final selectedIndices = selectedIndex != null ? [selectedIndex] : [];

        state = new SearchableListState<I>(
            delegate,
            selectedIndices,
            // on_confirm: commit the selection
            (selectedIndex, _secondary, window, cx) -> {
                #if cs
                // Names I in this closure's own body: Haxe's C# output makes a closure generic
                // only then, and its nested closure below needs I (the output does not compile otherwise)
                final _csTypeParam:Null<I> = null;
                #end
                cx.deferIn(window, (listState, window, cx) -> {
                    final listState:ListState<SearchableListAdapter<I>> = cast listState;
                    final confirmEntity = weakConfirm.upgrade();
                    final selection:Array<SelectedItem<I>> = confirmEntity != null ? confirmEntity.read(cx).state.selection.copy() : [];

                    final changes:Array<SearchableListChange> = [for (entry in selection) Deselect(entry.index)];
                    if (selectedIndex != null) {
                        changes.push(Select(selectedIndex));
                    }

                    // on_will_change is called directly: entity-handle access would
                    // re-enter the ListState lock that defer_in holds for this callback.
                    listState.delegateMut().delegate.onWillChange(selection, changes);

                    final confirmed = weakConfirm.upgrade();
                    if (confirmed == null) return;
                    var newSelection:Array<SelectedItem<I>> = null;
                    var finalValue:Null<Any> = null;
                    confirmed.update(cx, (this_, cx) -> {
                        this_.state.selection = selection;

                        finalValue = this_.state.selection.length > 0 ? SearchableListItems.value(this_.state.selection[0].item) : null;

                        cx.emit(SelectEvent.Confirm(finalValue));
                        cx.notify();
                        this_.setOpen(false, cx);
                        this_.focus(window, cx.app);

                        newSelection = this_.state.selection.copy();
                    });

                    // Clear the query through list_state directly: an entity-handle
                    // update here would re-enter the ListState lock held above.
                    // The committed index pointed into the filtered view, so resolve
                    // the confirmed value in the restored full list; otherwise the
                    // cursor and the mark would disagree on the next open.
                    if (listState.queryInput.read(cx).value().length != 0) {
                        listState.setQuery("", window, cx);
                    }

                    final ix = finalValue != null ? listState.delegate().delegate.position(finalValue) : null;
                    if (ix != null) {
                        listState.setSelectedIndex(ix, window, cx);
                        if (newSelection.length > 0) {
                            newSelection[0] = new SelectedItem(ix, newSelection[0].item);
                        }
                        final entity = weakConfirm.upgrade();
                        if (entity != null) {
                            entity.update(cx, (this_, cx) -> {
                                if (this_.state.selection.length > 0) {
                                    final next = this_.state.selection.copy();
                                    next[0] = new SelectedItem(ix, next[0].item);
                                    this_.state.selection = next;
                                }
                                cx.notify();
                            });
                        }
                    }

                    listState.delegateMut().updateSelectionSnapshot(newSelection.copy());
                    listState.delegateMut().delegate.onConfirm(newSelection);
                });
            },
            // on_cancel: clear the query, restore cursor to committed index, close
            (_finalSelectedIndex, window, cx) -> {
                #if cs
                // Names I in this closure's own body: Haxe's C# output makes a closure generic
                // only then, and its nested closure below needs I (the output does not compile otherwise)
                final _csTypeParam:Null<I> = null;
                #end
                cx.deferIn(window, (listState, window, cx) -> {
                    final listState:ListState<SearchableListAdapter<I>> = cast listState;
                    final cancelEntity = weakCancel.upgrade();
                    final committedIx:Null<IndexPath> = cancelEntity != null && cancelEntity.read(cx).state.selection.length > 0
                        ? cancelEntity.read(cx).state.selection[0].index
                        : null;

                    if (listState.queryInput.read(cx).value().length != 0) {
                        listState.setQuery("", window, cx);
                    }
                    listState.setSelectedIndex(committedIx, window, cx);

                    final entity = weakCancel.upgrade();
                    if (entity != null) {
                        entity.update(cx, (this_, cx) -> {
                            this_.setOpen(false, cx);
                            this_.focus(window, cx.app);
                        });
                    }
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
                final state:SelectState<I> = this_;
                state.onBlur(window, cast cx);
            },
            window,
            cx
        );
    }

    /** Rust `Icon::new(IconName::Inbox).size(px(28.))` (`Styled::size`). */
    static function inboxIcon():Icon {
        final icon = new Icon(IconName.Inbox);
        new gpui.StyleBuilder(icon.style()).size(px(28.));
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

    /**
     * Sets whether the dropdown menu is searchable, default is `false`.
     *
     * When `true`, a search input appears at the top of the dropdown menu.
     */
    public function searchable(searchable:Bool):SelectState<I> {
        searchableValue = searchable;
        return this;
    }

    /** Set the selected index for the select. */
    public function setSelectedIndex(selectedIndex:Null<IndexPath>, window:Window, cx:Context<SelectState<I>>):Void {
        state.list.update(cx, (list, cx) -> {
            list._setSelectedIndex(selectedIndex, window, cx);
        });

        final item = selectedIndex != null ? state.list.read(cx).delegate().delegate.item(selectedIndex) : null;

        state.selection = selectedIndex != null && item != null ? [new SelectedItem(selectedIndex, item)] : [];
        state.syncSnapshot(cx.app);
    }

    /**
     * Set selected value for the select.
     *
     * Looks up the position from the delegate and sets the selected index accordingly.
     * Passes `None` when the value is not found.
     *
     * The delegate looks the value up in its matched items, so an active search query is
     * cleared first to get an index into the full item list.
     */
    public function setSelectedValue(selectedValue:Any, window:Window, cx:Context<SelectState<I>>):Void {
        state.clearQuery(window, cx.app);

        final selectedIndex = state.list.read(cx).delegate().delegate.position(selectedValue);

        setSelectedIndex(selectedIndex, window, cx);
    }

    /** Replace the delegate (item data) for the select state. */
    public function setItems(items:SearchableListDelegate<I>, window:Window, cx:Context<SelectState<I>>):Void {
        var selection = state.selection.copy();
        state.list.update(cx, (list, cx) -> {
            final cursorItem = list.selectedIndex() != null ? list.delegate().delegate.item(list.selectedIndex()) : null;
            final cursor = cursorItem != null ? items.position(SearchableListItems.value(cursorItem)) : null;
            // A value the new items no longer have is dropped, as
            // `set_selected_value` does, rather than kept at an index that
            // now points at another item.
            final kept:Array<SelectedItem<I>> = [];
            for (entry in selection) {
                final position = items.position(SearchableListItems.value(entry.item));
                if (position == null) continue;
                final replacement = items.item(position);
                if (replacement == null) continue;
                kept.push(new SelectedItem(position, replacement));
            }
            selection = kept;
            list.delegateMut().delegate = items;
            list.setSelectedIndex(cursor, window, cx);
            list.delegateMut().updateSelectionSnapshot(selection.copy());
            cx.notify();
        });
        state.selection = selection;
        cx.notify();
    }

    /** Get the current selected index. */
    public function selectedIndex(cx:App):Null<IndexPath> {
        return state.list.read(cx).selectedIndex();
    }

    /** Get the current selected value. */
    public function selectedValue():Null<Any> {
        return state.selection.length > 0 ? SearchableListItems.value(state.selection[0].item) : null;
    }

    /** Focus the select trigger input. */
    public function focus(window:Window, cx:App):Void {
        state.focusHandle.focus(window, cx);
    }

    function onBlur(window:Window, cx:Context<SelectState<I>>):Void {
        if (state.list.read(cx).isFocused(window, cx.app) || state.focusHandle.isFocused(window)) {
            return;
        }

        clearQueryAndRestoreCursor(window, cx);
        setOpen(false, cx);
        cx.notify();
    }

    function toggleMenu(_:ClickEvent, window:Window, cx:Context<SelectState<I>>):Void {
        cx.stopPropagation();

        setOpen(!state.open, cx);

        if (state.open) {
            state.list.read(cx).focusHandle(cx.app).focus(window, cx.app);
        } else {
            clearQueryAndRestoreCursor(window, cx);
        }

        cx.notify();
    }

    function escape(_:Null<Cancel>, window:Window, cx:Context<SelectState<I>>):Void {
        if (!state.open) {
            cx.propagate();
            return;
        }

        cx.stopPropagation();
        clearQueryAndRestoreCursor(window, cx);
        setOpen(false, cx);
        focus(window, cx.app);
        cx.notify();
    }

    /**
     * Drop the search query and move the cursor back to the committed
     * selection, so the next open shows every item. Call on every menu
     * close that does not go through the confirm/cancel callbacks.
     */
    function clearQueryAndRestoreCursor(window:Window, cx:Context<SelectState<I>>):Void {
        state.clearQuery(window, cx.app);

        final committedIx:Null<IndexPath> = state.selection.length > 0 ? state.selection[0].index : null;
        state.list.update(cx, (list, cx) -> {
            if (!sameIndex(list.selectedIndex(), committedIx)) {
                list.setSelectedIndex(committedIx, window, cx);
            }
        });
    }

    static function sameIndex(a:Null<IndexPath>, b:Null<IndexPath>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    function setOpen(open:Bool, cx:Context<SelectState<I>>):Void {
        final dismissed = state.open && !open;
        state.open = open;
        // Rust drops the previous token by replacing it.
        if (state.deferredContext != null) state.deferredContext.release();
        state.deferredContext = open ? GlobalState.registerDeferredPopover(cx) : null;

        if (dismissed) {
            cx.emit(DismissEvent.instance);
        }
        cx.notify();
    }

    function clean(_:ClickEvent, window:Window, cx:Context<SelectState<I>>):Void {
        cx.stopPropagation();
        setSelectedIndex(null, window, cx);
        cx.emit(SelectEvent.Confirm(null));
    }

    function displayTitle(_:Window, cx:Context<SelectState<I>>):IntoElement {
        final theme = Theme.global(cx);
        final defaultTitle = div().textColor(theme.mutedForeground).child(
            state.placeholder != null ? state.placeholder : I18n.t('Select.placeholder')
        );

        final selectedIndex = this.selectedIndex(cx.app);
        if (selectedIndex == null) {
            return defaultTitle;
        }

        final item = state.list.read(cx).delegate().delegate.item(selectedIndex);
        if (item == null) {
            return defaultTitle;
        }
        final display = SearchableListItems.displayTitle(item);
        final title:IntoElement = if (display != null) {
            display;
        } else if (titlePrefix != null) {
            titlePrefix + SearchableListItems.title(item);
        } else {
            SearchableListItems.title(item);
        }

        final element = div();
        if (state.disabled) {
            element.textColor(theme.mutedForeground);
        }
        return element.child(title);
    }

    function accessibilityValue():String {
        if (state.selection.length == 0) {
            return state.placeholder != null ? state.placeholder : I18n.t('Select.placeholder');
        }
        final item = state.selection[0].item;

        if (titlePrefix != null) {
            return titlePrefix + SearchableListItems.title(item);
        } else {
            return SearchableListItems.title(item);
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
        final cx:Context<SelectState<I>> = cast cx;
        final theme = Theme.global(cx);
        final searchable = searchableValue;
        final isFocused = state.focusHandle.isFocused(window);
        final showClean = state.cleanable && selectedIndex(cx.app) != null;
        final bounds = state.bounds;
        final allowOpen = !(state.open || state.disabled);
        final outlineVisible = state.open || (isFocused && !state.disabled);

        final colors = Input.inputStyleColors(state.disabled, cx.app);
        final bg = colors.background;
        final fg = colors.foreground;

        final size = state.size;
        state.list.update(cx, (list, cx) -> {
            list.setSearchable(searchable, cx);
            list.delegateMut().size = size;
        });

        final entity:gpui.Entity<SelectState<I>> = cx.entity();

        final input = div()
            .id("input")
            .testSupport()
            .relative()
            .flex()
            .itemsCenter()
            .justifyBetween()
            .border1()
            .borderColor(theme.transparent);
        if (state.appearance) {
            input.bg(bg).textColor(fg);
            if (state.disabled) input.opacity(0.5);
            input.borderColor(theme.input).rounded(theme.radius);
        }
        input.inputSize(state.size)
            .inputTextSize(state.size)
            .refineStyle(state.style);
        if (outlineVisible && state.appearance) {
            input.border1().borderColor(theme.ring);
        }
        if (outlineVisible && state.appearance && focusRingEnabled) {
            input.focusRingStyle(window, cx.app);
        }
        if (allowOpen) {
            input.onClick(cx.listener((this_:SelectState<I>, e:ClickEvent, window, cx) -> this_.toggleMenu(e, window, cx)));
        }

        final inner = hFlex()
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
                    .id("title")
                    .flex1()
                    .minW0()
                    .overflowHidden()
                    .whitespaceNowrap()
                    .truncate()
                    .child(displayTitle(window, cx))
            );
        if (showClean) {
            final button = ClearButton.clearButton(cx.app);
            if (state.disabled) {
                button.disabled(true);
            } else {
                button.onClick(cx.listener((this_:SelectState<I>, e:ClickEvent, window, cx) -> this_.clean(e, window, cx)));
            }
            inner.child(button);
        }
        if (!showClean) {
            final iconElement:IntoElement = switch icon {
                case null:
                    (new Caret(state.size).textColor(theme.mutedForeground) : IntoElement);
                case icon:
                    (icon.clone().xsmall().textColor(theme.mutedForeground) : IntoElement);
            }

            inner.child(iconElement);
        }
        input.child(inner);

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
            .child(input);
        if (state.open) {
            final surface = vFlex().occlude();
            switch state.menuWidth {
                case Auto: surface.w(px(bounds.size.width));
                case Definite(w): surface.w(w);
            }
            final list = new List(state.list);
            if (state.searchPlaceholder != null) list.searchPlaceholder(state.searchPlaceholder);
            list.withSize(state.size).maxH(state.menuMaxH);
            if (state.scrollBounce != null) list.scrollBounce(state.scrollBounce);
            list.paddingsEdges(gpui.Edges.all(SizeTools.DROPDOWN_LIST_PADDING));
            surface.popoverStyle(cx.app)
                .child(list)
                .onMouseDownOut(cx.listener((this_:SelectState<I>, _, window, cx) -> {
                    this_.escape(null, window, cx);
                }));
            anchor.child(
                deferred(Popover.dropdownPopup(
                    ElementId.NamedInteger("select-popup", cx.entityId()),
                    bounds,
                    surface,
                    cx.app
                ))
                    .withPriority(gpui.base.Popup.POPUP_PRIORITY)
            );
        }

        return div().sizeFull().relative().child(anchor);
    }

}
