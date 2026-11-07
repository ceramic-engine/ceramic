// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/adapter.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.searchablelist;

import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Task;
import glaze.Unit;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.list.ListDelegate;
import glaze.kit.list.ListDelegate.ListDelegateItem;
import glaze.kit.list.ListState;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.StyleSized;

/**
 * Bridges a `SearchableListDelegate` into the `ListDelegate` protocol.
 *
 * Parent states (`SelectState`, `ComboboxState`) create one of these, supplying closures that
 * encode parent-specific confirm / cancel / empty-render behaviour. All state mutation stays in
 * the parent; the adapter only handles item layout.
 */
class SearchableListAdapter<I> extends ListDelegateBase {

    public var delegate:SearchableListDelegate<I>;

    /** Keyboard cursor row, updated by `ListDelegate.setSelectedIndex`. */
    var selectedIndex:Null<IndexPath> = null;

    /**
     * Snapshot of the parent's committed selection, kept in sync by the parent state after every
     * selection change. `renderItem` reads this directly so it never touches the parent entity.
     */
    @:allow(glaze.kit, tests)
    var selectionSnapshot:Array<SelectedItem<I>> = [];

    /** Called when the user confirms an item (click or Enter). */
    final onConfirm:(Null<IndexPath>, Bool, Window, Context<ListState<Dynamic>>) -> Void;

    /** Called when the user cancels (Escape) or focus leaves the dropdown. */
    final onCancel:(Null<IndexPath>, Window, Context<ListState<Dynamic>>) -> Void;

    /** Renders the empty-state placeholder. */
    final onRenderEmpty:(Window, App) -> AnyElement;

    @:allow(glaze.kit, tests)
    var size:Size = Medium;

    /** Override the trailing check icon; defaults to `IconName.Check`. */
    @:allow(glaze.kit, tests)
    var checkIcon:Null<Icon> = null;

    @:allow(glaze.kit)
    function new(delegate:SearchableListDelegate<I>, onConfirm:(Null<IndexPath>, Bool, Window, Context<ListState<Dynamic>>) -> Void,
            onCancel:(Null<IndexPath>, Window, Context<ListState<Dynamic>>) -> Void, onRenderEmpty:(Window, App) -> AnyElement) {
        this.delegate = delegate;
        this.onConfirm = onConfirm;
        this.onCancel = onCancel;
        this.onRenderEmpty = onRenderEmpty;
    }

    /**
     * Replace the selection snapshot. Call this after every selection mutation so that
     * `renderItem` sees up-to-date check state without touching any external entity.
     */
    @:allow(glaze.kit)
    function updateSelectionSnapshot(snapshot:Array<SelectedItem<I>>):Void {
        selectionSnapshot = snapshot;
    }

    override public function sectionsCount(cx:App):Int {
        return delegate.sectionsCount(cx);
    }

    public function itemsCount(section:Int, cx:App):Int {
        return delegate.itemsCount(section);
    }

    override public function renderSectionHeader(section:Int, window:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement> {
        final el = delegate.renderSectionHeader(section, window, cx.app);
        if (el != null) return el;

        final item = delegate.section(section);
        if (item == null) return null;

        return div()
            .py0p5()
            .px2()
            .listSize(size)
            .textSm()
            .textColor(Theme.global(cx.app).mutedForeground)
            .child(item);
    }

    public function renderItem(ix:IndexPath, window:Window, cx:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        final item = delegate.item(ix);
        if (item == null) return null;
        // Read check state from the snapshot, never from an external entity.
        final isChecked = delegate.isItemChecked(ix, item, selectionSnapshot, cx.app);
        final disabled = !delegate.isItemEnabled(ix, item, cx.app);
        final size = this.size;

        final el = delegate.renderItem(ix, item, isChecked, window, cx.app);
        if (el != null) {
            return new SearchableListItemElement(ix.row)
                .disabled(disabled)
                .withSize(size)
                .child(el);
        }

        final checkIcon = this.checkIcon != null ? this.checkIcon.clone() : new Icon(IconName.Check);

        final content = div()
            .minW0()
            .truncate()
            .child(SearchableListItems.render(item, window, cx.app));

        return new SearchableListItemElement(ix.row)
            .checked(isChecked)
            .checkIcon(checkIcon)
            .disabled(disabled)
            .withSize(size)
            .child(content);
    }

    override public function cancel(window:Window, cx:Context<ListState<Dynamic>>):Void {
        final saved = selectedIndex;
        onCancel(saved, window, cx);
    }

    override public function confirm(secondary:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void {
        final ix = selectedIndex;
        if (ix == null) return;
        final item = delegate.item(ix);
        if (item == null) return;
        if (!delegate.isItemEnabled(ix, item, cx.app)) return;
        onConfirm(selectedIndex, secondary, window, cx);
    }

    override public function performSearch(query:String, window:Window, cx:Context<ListState<Dynamic>>):Task<Unit> {
        return delegate.performSearch(query, window, cx.app);
    }

    public function setSelectedIndex(ix:Null<IndexPath>, window:Window, cx:Context<ListState<Dynamic>>):Void {
        selectedIndex = ix;
    }

    override public function renderEmpty(window:Window, cx:Context<ListState<Dynamic>>):IntoElement {
        return onRenderEmpty(window, cx.app);
    }

}
