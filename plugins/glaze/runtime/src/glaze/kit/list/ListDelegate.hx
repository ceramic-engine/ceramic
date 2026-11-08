// Ported from gpui-kit 0.8.1: crates/component/src/list/delegate.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.list;

import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Task;
import glaze.Unit;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.IndexPath;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.list.ListItem.Loading;
import glaze.kit.theme.Theme;

import glaze.kit.base.Prelude.*;

/**
 * An item a `ListDelegate` renders (Rust `ListDelegate::Item: Selectable +
 * IntoElement`). `setSecondarySelected` is the Rust `Selectable::
 * secondary_selected`, whose trait default does nothing.
 */
interface ListDelegateItem extends Selectable extends RenderOnce {

    function setSecondarySelected(selected:Bool):Void;

}

/**
 * A delegate for the List.
 *
 * The context of every method is the list's (Rust `Context<ListState<Self>>`).
 * The trait defaults are in `ListDelegateBase`: extend it, or implement every
 * method.
 */
interface ListDelegate {

    /**
     * When Query Input change, this method will be called.
     * You can perform search here.
     */
    function performSearch(query:String, window:Window, cx:Context<ListState<Dynamic>>):Task<Unit>;

    /**
     * Return the number of sections in the list, default is 1.
     *
     * Min value is 1.
     */
    function sectionsCount(cx:App):Int;

    /**
     * Return the number of items in the section at the given index.
     *
     * NOTE: Only the sections with items_count > 0 will be rendered. If the section has 0 items,
     * the section header and footer will also be skipped.
     */
    function itemsCount(section:Int, cx:App):Int;

    /**
     * Render the item at the given index.
     *
     * Return None will skip the item.
     *
     * NOTE: Every item should have same height.
     */
    function renderItem(ix:IndexPath, window:Window, cx:Context<ListState<Dynamic>>):Null<ListDelegateItem>;

    /**
     * Render the section header at the given index, default is None.
     *
     * NOTE: Every header should have same height.
     */
    function renderSectionHeader(section:Int, window:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement>;

    /**
     * Render the section footer at the given index, default is None.
     *
     * NOTE: Every footer should have same height.
     */
    function renderSectionFooter(section:Int, window:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement>;

    /** Return a Element to show when list is empty. */
    function renderEmpty(window:Window, cx:Context<ListState<Dynamic>>):IntoElement;

    /**
     * Returns Some(AnyElement) to render the initial state of the list.
     *
     * This can be used to show a view for the list before the user has
     * interacted with it.
     *
     * For example: The last search results, or the last selected item.
     *
     * Default is None, that means no initial state.
     */
    function renderInitial(window:Window, cx:Context<ListState<Dynamic>>):Null<AnyElement>;

    /** Returns the loading state to show the loading view. */
    function loading(cx:App):Bool;

    /**
     * Returns a Element to show when loading, default is built-in Skeleton
     * loading view.
     */
    function renderLoading(window:Window, cx:Context<ListState<Dynamic>>):IntoElement;

    /** Set the selected index, just store the ix, don't confirm. */
    function setSelectedIndex(ix:Null<IndexPath>, window:Window, cx:Context<ListState<Dynamic>>):Void;

    /** Set the index of the item that has been right clicked. */
    function setRightClickedIndex(ix:Null<IndexPath>, window:Window, cx:Context<ListState<Dynamic>>):Void;

    /**
     * Set the confirm and give the selected index,
     * this is means user have clicked the item or pressed Enter.
     *
     * This will always to `set_selected_index` before confirm.
     */
    function confirm(secondary:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void;

    /** Cancel the selection, e.g.: Pressed ESC. */
    function cancel(window:Window, cx:Context<ListState<Dynamic>>):Void;

    /**
     * Return true to enable load more data when scrolling to the bottom.
     *
     * Default: false
     */
    function hasMore(cx:App):Bool;

    /**
     * Returns a threshold value (n entities), of course,
     * when scrolling to the bottom, the remaining number of rows
     * triggers `load_more`.
     *
     * This should smaller than the total number of first load rows.
     *
     * Default: 20 entities (section header, footer and row)
     */
    function loadMoreThreshold():Int;

    /**
     * Load more data when the table is scrolled to the bottom.
     *
     * This will performed in a background task.
     *
     * This is always called when the table is near the bottom,
     * so you must check if there is more data to load or lock
     * the loading state.
     */
    function loadMore(window:Window, cx:Context<ListState<Dynamic>>):Void;

}

/**
 * The default methods of `ListDelegate` (Rust trait defaults). `itemsCount`,
 * `renderItem` and `setSelectedIndex` have no default.
 */
abstract class ListDelegateBase implements ListDelegate {

    public function performSearch(query:String, window:Window, cx:Context<ListState<Dynamic>>):Task<Unit> {
        return Task.ready(Unit.unit);
    }

    public function sectionsCount(cx:App):Int {
        return 1;
    }

    public abstract function itemsCount(section:Int, cx:App):Int;

    public abstract function renderItem(ix:IndexPath, window:Window, cx:Context<ListState<Dynamic>>):Null<ListDelegateItem>;

    public function renderSectionHeader(section:Int, window:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement> {
        return null;
    }

    public function renderSectionFooter(section:Int, window:Window, cx:Context<ListState<Dynamic>>):Null<IntoElement> {
        return null;
    }

    public function renderEmpty(window:Window, cx:Context<ListState<Dynamic>>):IntoElement {
        return ListDelegateDefaults.renderEmpty(window, cx.app);
    }

    public function renderInitial(window:Window, cx:Context<ListState<Dynamic>>):Null<AnyElement> {
        return null;
    }

    public function loading(cx:App):Bool {
        return false;
    }

    public function renderLoading(window:Window, cx:Context<ListState<Dynamic>>):IntoElement {
        return Loading.component();
    }

    public abstract function setSelectedIndex(ix:Null<IndexPath>, window:Window, cx:Context<ListState<Dynamic>>):Void;

    public function setRightClickedIndex(ix:Null<IndexPath>, window:Window, cx:Context<ListState<Dynamic>>):Void {}

    public function confirm(secondary:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void {}

    public function cancel(window:Window, cx:Context<ListState<Dynamic>>):Void {}

    public function hasMore(cx:App):Bool {
        return false;
    }

    public function loadMoreThreshold():Int {
        return 20;
    }

    public function loadMore(window:Window, cx:Context<ListState<Dynamic>>):Void {}

}

/**
 * The bodies of the trait defaults, for delegates that implement
 * `ListDelegate` without extending `ListDelegateBase`.
 */
class ListDelegateDefaults {

    /** Rust `ListDelegate::render_empty` default. */
    public static function renderEmpty(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return hFlex()
            .sizeFull()
            .justifyCenter()
            .textColor(theme.mutedForeground.opacity(0.6))
            .child(Icon.component(IconName.Inbox).size12());
    }

}
