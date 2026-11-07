// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/delegate.rs (SearchableListDelegate)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.searchablelist;

import gpui.AnyElement;
import gpui.App;
import gpui.Task;
import gpui.Unit;
import gpui.Window;
import gpui.base.IndexPath;

/**
 * Provides data and search behaviour to a searchable list component.
 *
 * `I` is the Rust associated type `Item` (see `SearchableListItem` for the
 * item calls). Extend `SearchableListDelegateBase` to get the trait defaults.
 */
interface SearchableListDelegate<I> {

    /** Number of sections (groups) in the list. Defaults to 1. */
    function sectionsCount(cx:App):Int;

    /**
     * Optional header element for the given section index.
     *
     * Deprecated in Rust: override `renderSectionHeader` instead.
     */
    function section(section:Int):Null<AnyElement>;

    /** Number of items in the given section. */
    function itemsCount(section:Int):Int;

    /** The item at the given index path. */
    function item(ix:IndexPath):Null<I>;

    /** Find the index path of the item whose value equals `value`. */
    function position(value:Any):Null<IndexPath>;

    /**
     * Called when the search query changes.
     *
     * Implementations should filter or fetch items and may return an async `Task`.
     */
    function performSearch(query:String, window:Window, cx:App):Task<Unit>;

    /**
     * Override the row content for the item at `ix`.
     *
     * When an element is returned, the adapter suppresses its default
     * `SearchableListItemElement` layout (including the automatic trailing
     * check icon). Return `null` to fall back to the standard rendering.
     * `checked` is `true` when the item is in the current selection.
     */
    function renderItem(ix:IndexPath, item:I, checked:Bool, window:Window, cx:App):Null<AnyElement>;

    /**
     * Render the header element for the given section (full render access).
     *
     * When an element is returned, it is rendered directly: the adapter's
     * default wrapper is bypassed. Return `null` to fall back to the
     * deprecated `section()` wrapped in the standard div.
     */
    function renderSectionHeader(section:Int, window:Window, cx:App):Null<AnyElement>;

    /**
     * Whether the item at `ix` should be rendered as interactive.
     *
     * Default: `!item.disabled()`.
     */
    function isItemEnabled(ix:IndexPath, item:I, cx:App):Bool;

    /**
     * Whether the item at `ix` should show a checkmark.
     *
     * Default: checks whether the item's value is present in `currentSelection`.
     */
    function isItemChecked(ix:IndexPath, item:I, currentSelection:Array<SelectedItem<I>>, cx:App):Bool;

    /**
     * Called before a user-triggered selection change is committed.
     *
     * `selection` is the live selection array: the delegate may freely mutate
     * it, or leave it unchanged to veto the operation. `changes` are the
     * atomic changes the mode-strategy computed; the default applies every
     * change in order.
     */
    function onWillChange(selection:Array<SelectedItem<I>>, changes:Array<SearchableListChange>):Void;

    /**
     * Called when the dropdown/popover is committed (Escape, `close_on_select`, or explicit
     * confirm). `finalSelection` is the selection after the last committed change.
     */
    function onConfirm(finalSelection:Array<SelectedItem<I>>):Void;

}

/**
 * The defaults of the Rust trait: implement `itemsCount`, `item` and `position`.
 */
abstract class SearchableListDelegateBase<I> implements SearchableListDelegate<I> {

    public function sectionsCount(cx:App):Int {
        return 1;
    }

    public function section(section:Int):Null<AnyElement> {
        return null;
    }

    public abstract function itemsCount(section:Int):Int;

    public abstract function item(ix:IndexPath):Null<I>;

    public abstract function position(value:Any):Null<IndexPath>;

    public function performSearch(query:String, window:Window, cx:App):Task<Unit> {
        return Task.ready(Unit.unit);
    }

    public function renderItem(ix:IndexPath, item:I, checked:Bool, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

    public function renderSectionHeader(section:Int, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

    public function isItemEnabled(ix:IndexPath, item:I, cx:App):Bool {
        return !SearchableListItems.disabled(item);
    }

    public function isItemChecked(ix:IndexPath, item:I, currentSelection:Array<SelectedItem<I>>, cx:App):Bool {
        final value = SearchableListItems.value(item);
        for (selected in currentSelection) {
            if (SearchableListItems.valueEquals(SearchableListItems.value(selected.item), value)) return true;
        }
        return false;
    }

    public function onWillChange(selection:Array<SelectedItem<I>>, changes:Array<SearchableListChange>):Void {
        defaultOnWillChange(this, selection, changes);
    }

    public function onConfirm(finalSelection:Array<SelectedItem<I>>):Void {}

    /**
     * The default `on_will_change`, for delegates that override it and still
     * want the default behaviour for some changes.
     */
    public static function defaultOnWillChange<I>(delegate:SearchableListDelegate<I>, selection:Array<SelectedItem<I>>, changes:Array<SearchableListChange>):Void {
        for (change in changes) {
            switch change {
                case Select(index):
                    final item = delegate.item(index);
                    if (item == null) continue;
                    final value = SearchableListItems.value(item);
                    var present = false;
                    for (selected in selection) {
                        if (SearchableListItems.valueEquals(SearchableListItems.value(selected.item), value)) {
                            present = true;
                            break;
                        }
                    }
                    if (!present) selection.push(new SelectedItem(index, item));
                case Deselect(index):
                    final item = delegate.item(index);
                    if (item != null) {
                        final value = SearchableListItems.value(item);
                        var hasValue = false;
                        for (selected in selection) {
                            if (SearchableListItems.valueEquals(SearchableListItems.value(selected.item), value)) {
                                hasValue = true;
                                break;
                            }
                        }
                        if (hasValue) {
                            retain(selection, selected -> !SearchableListItems.valueEquals(SearchableListItems.value(selected.item), value));
                            continue;
                        }
                    }
                    retain(selection, selected -> !selected.index.equals(index));
            }
        }
    }

    /** Rust `Vec::retain`, in place. */
    static function retain<I>(selection:Array<SelectedItem<I>>, keep:(SelectedItem<I>) -> Bool):Void {
        var j = 0;
        for (i in 0...selection.length) {
            final entry = selection[i];
            if (keep(entry)) selection[j++] = entry;
        }
        selection.resize(j);
    }

}
