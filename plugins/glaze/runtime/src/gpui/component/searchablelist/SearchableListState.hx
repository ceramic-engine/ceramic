// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.searchablelist;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.Length;
import gpui.Model;
import gpui.StyleRefinement;
import gpui.Subscription;
import gpui.Window;
import gpui.base.GlobalState.DeferredPopover;
import gpui.base.IndexPath;
import gpui.component.Size;
import gpui.component.list.ListState;

import gpui.Prelude.*;

/**
 * Shared infrastructure for all searchable-list-based components (`SelectState`, `ComboboxState`).
 *
 * This is a plain nested value inside a GPUI entity: it has no entity context of its
 * own and cannot call `cx.notify()` or `cx.emit()`. Callers are responsible for those after
 * calling mutable methods.
 *
 * The selection and the open state are observable (tracker), so that a view
 * reading them through its parent state re-renders when they change (Rust
 * tracks the parent entity the view read). Assign a new array to `selection`
 * rather than mutating it in place.
 */
class SearchableListState<I> extends ceramic.Entity implements tracker.Observable {

    public final focusHandle:FocusHandle;

    @:allow(gpui.component, tests)
    final list:Entity<ListState<SearchableListAdapter<I>>>;

    @:allow(gpui.component, tests)
    @observe var selection:Array<SelectedItem<I>> = [];

    @:allow(gpui.component, tests)
    @observe var open:Bool = false;

    /**
     * Held while the popup is open, so that a component dropped without
     * closing it first takes its registration with it (release it in place
     * of the Rust drop).
     */
    @:allow(gpui.component, tests)
    var deferredContext:Null<DeferredPopover> = null;

    @:allow(gpui.component, tests)
    var bounds:Bounds = new Bounds();

    // Shared options

    @:allow(gpui.component, tests)
    var size:Size = Medium;

    @:allow(gpui.component, tests)
    var style:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component, tests)
    var cleanable:Bool = false;

    @:allow(gpui.component, tests)
    var placeholder:Null<String> = null;

    @:allow(gpui.component, tests)
    var searchPlaceholder:Null<String> = null;

    @:allow(gpui.component, tests)
    var menuWidth:Length = Length.Auto;

    @:allow(gpui.component, tests)
    var menuMaxH:Length = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(20.)));

    @:allow(gpui.component, tests)
    var scrollBounce:Null<Bool> = null;

    @:allow(gpui.component, tests)
    var disabled:Bool = false;

    @:allow(gpui.component, tests)
    var appearance:Bool = true;

    @:allow(gpui.component, tests)
    var empty:Null<(Window, App) -> AnyElement> = null;

    @:allow(gpui.component, tests)
    final _subscriptions:Array<Subscription>;

    /**
     * Create a new `SearchableListState`, creating the list entity in the given parent context.
     *
     * `onConfirm`, `onCancel`, and `onRenderEmpty` are forwarded to the underlying adapter.
     * `onBlur` is invoked on the parent entity when focus leaves any of the
     * list's focus handles (Rust `fn(&mut P, ...)` on the parent `Context<P>`;
     * Haxe constructors take no type parameters, so the parent is untyped).
     */
    public function new(delegate:SearchableListDelegate<I>, selectedIndices:Array<IndexPath>,
            onConfirm:(Null<IndexPath>, Bool, Window, Context<ListState<Dynamic>>) -> Void,
            onCancel:(Null<IndexPath>, Window, Context<ListState<Dynamic>>) -> Void, onRenderEmpty:(Window, App) -> AnyElement,
            onBlur:(Dynamic, Window, Context<Dynamic>) -> Void, window:Window, cx:Context<Dynamic>) {
        super();
        final focusHandle = cx.focusHandle();

        final adapter = new SearchableListAdapter<I>(delegate, onConfirm, onCancel, onRenderEmpty);
        final list = cx.newEntity((c:Context<ListState<SearchableListAdapter<I>>>) -> new ListState(adapter, window, c).resetOnCancel(false));

        final listFocusHandle = list.read(cx).focusHandleValue;
        final listSearchFocusHandle = list.read(cx).queryInput.read(cx).focusHandle;

        final selection:Array<SelectedItem<I>> = [];
        {
            final delegate = list.read(cx).delegate().delegate;
            for (ix in selectedIndices) {
                final item = delegate.item(ix);
                if (item != null) selection.push(new SelectedItem(ix, item));
            }
        }

        if (selectedIndices.length > 0) {
            final cursor = selectedIndices[0];
            list.update(cx, (l, cx) -> l.setSelectedIndex(cursor, window, cx));
        }

        // Prime the adapter's snapshot so the very first render pass sees correct check state.
        final initialSnapshot = selection.copy();
        list.update(cx, (l, _) -> l.delegateMut().updateSelectionSnapshot(initialSnapshot));

        _subscriptions = [
            cx.onBlur(listFocusHandle, window, onBlur),
            cx.onBlur(listSearchFocusHandle, window, onBlur),
            cx.onBlur(focusHandle, window, onBlur),
        ];

        this.focusHandle = focusHandle;
        this.list = list;
        this.selection = selection;
    }

    // MARK: Read-only accessors

    public function selectionItems():Array<SelectedItem<I>> {
        return selection;
    }

    public function selectedValues():Array<Any> {
        return [for (entry in selection) SearchableListItems.value(entry.item)];
    }

    public function isOpen():Bool {
        return open;
    }

    public function focusHandleRef():FocusHandle {
        return focusHandle;
    }

    /**
     * Drop the search query, if there is one, so that a value lookup resolves
     * against every item rather than the filtered view.
     *
     * A delegate's `position` answers for the list as it is currently
     * displayed. Projecting an authoritative value in from outside is not a
     * position in that view: the value's item may be filtered out.
     */
    @:allow(gpui.component)
    function clearQuery(window:Window, cx:App):Void {
        list.update(cx, (list, cx) -> {
            if (list.queryInput.read(cx).value().length != 0) {
                list.setQuery("", window, cx);
            }
        });
    }

    // MARK: Mutation (no cx: callers emit events and notify)

    /** Add an index+item pair to the selection; no-op if already present. */
    @:allow(gpui.component)
    function addByItem(index:IndexPath, item:I):Void {
        for (entry in selection) if (entry.index.equals(index)) return;
        selection = selection.concat([new SelectedItem(index, item)]);
    }

    /** Remove an index from the selection by index path. */
    @:allow(gpui.component)
    function removeByIndex(index:IndexPath):Bool {
        for (pos in 0...selection.length) {
            if (selection[pos].index.equals(index)) {
                final next = selection.copy();
                next.splice(pos, 1);
                selection = next;
                return true;
            }
        }
        return false;
    }

    /**
     * Add a single index to the selection by looking up the item in the list.
     *
     * Requires `cx` only to read the list entity; does not notify.
     */
    public function addSelectedIndex(index:IndexPath, cx:App):Bool {
        for (entry in selection) if (entry.index.equals(index)) return false;

        final item = list.read(cx).delegate().delegate.item(index);
        if (item == null) return false;

        addByItem(index, item);

        return true;
    }

    /** Remove a single index from the selection. */
    public function removeSelectedIndex(index:IndexPath):Bool {
        return removeByIndex(index);
    }

    /** Replace the entire selection, looking up items from the list. */
    public function setSelectedIndices(indices:Array<IndexPath>, cx:App):Void {
        final delegate = list.read(cx).delegate().delegate;
        final next:Array<SelectedItem<I>> = [];
        for (ix in indices) {
            final item = delegate.item(ix);
            if (item != null) next.push(new SelectedItem(ix, item));
        }
        selection = next;
    }

    /**
     * Push the current selection into the adapter's snapshot so the next render pass sees
     * up-to-date check state. Call after every mutation that changes `selection`.
     */
    @:allow(gpui.component)
    function syncSnapshot(cx:App):Void {
        final snapshot = selection.copy();
        list.update(cx, (l, _) -> l.delegateMut().updateSelectionSnapshot(snapshot));
    }

}
