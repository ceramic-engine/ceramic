// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/vec.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.searchablelist;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.Task;
import glaze.Unit;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.searchablelist.SearchableListDelegate.SearchableListDelegateBase;

/**
 * A vector of items that supports incremental filtering.
 *
 * On each `performSearch` call the matched view is rebuilt by filtering the
 * full `items` list. Use this as a delegate when all data is already in memory.
 *
 * Rust also implements the delegate for `SearchableVec<SearchableGroup<I>>`
 * (a sectioned list): that one is `SearchableGroupVec` here (Haxe cannot
 * specialize an implementation on the type parameter), built with
 * `SearchableVec.groups([...])` or `new SearchableGroupVec([...])`.
 */
class SearchableVec<T> extends SearchableListDelegateBase<T> {

    @:allow(glaze.kit.searchablelist)
    var items:Array<T>;

    @:allow(glaze.kit.searchablelist)
    var matched:Array<Matched>;

    /**
     * Create a new `SearchableVec` from an initial list of items.
     */
    public function new(items:Array<T>) {
        this.items = items.copy();
        this.matched = [for (ix in 0...this.items.length) Matched.all(ix)];
    }

    /**
     * A sectioned list (Rust `SearchableVec::new(vec![SearchableGroup...])`).
     */
    public static function groups<I>(groups:Array<SearchableGroup<I>>):SearchableGroupVec<I> {
        return new SearchableGroupVec(groups);
    }

    /**
     * Append an item to both the master list and the current filtered view.
     */
    public function push(item:T):Void {
        matched.push(Matched.all(items.length));
        items.push(item);
    }

    function matchedItem(ix:Int):Null<T> {
        if (ix < 0 || ix >= matched.length) return null;
        final m = matched[ix];
        if (m.ix >= items.length) return null;
        return items[m.ix];
    }

    public function itemsCount(section:Int):Int {
        return matched.length;
    }

    public function item(ix:IndexPath):Null<T> {
        return matchedItem(ix.row);
    }

    public function position(value:Any):Null<IndexPath> {
        // `matched_items().position(...)`: entries pointing past `items` are skipped
        var position = 0;
        for (m in matched) {
            if (m.ix >= items.length) continue;
            if (SearchableListItems.valueEquals(SearchableListItems.value(items[m.ix]), value)) {
                return IndexPath.defaultValue().withRow(position);
            }
            position++;
        }
        return null;
    }

    override public function performSearch(query:String, window:Window, cx:App):Task<Unit> {
        matched = [for (ix in 0...items.length) if (SearchableListItems.matches(items[ix], query)) Matched.all(ix)];
        return Task.ready(Unit.unit);
    }

}

/**
 * A named group of items used for sectioned lists.
 */
class SearchableGroup<I> {

    public var title:String;

    public var items:Array<I>;

    /**
     * Create an empty group with the given section title.
     */
    public function new(title:String) {
        this.title = title;
        this.items = [];
    }

    /**
     * Append a single item to this group.
     */
    public function item(item:I):SearchableGroup<I> {
        items.push(item);
        return this;
    }

    /**
     * Append multiple items to this group.
     */
    public function withItems(items:Array<I>):SearchableGroup<I> {
        for (item in items) this.items.push(item);
        return this;
    }

    /**
     * The rows matching `query`, or `null` when neither the title nor any
     * row matches and the whole group is hidden.
     */
    @:allow(glaze.kit.searchablelist)
    function matchedRows(query:String):Null<Array<Int>> {
        final rows = [for (ix in 0...items.length) if (SearchableListItems.matches(items[ix], query)) ix];
        return (rows.length > 0 || SearchableListItems.containsIgnoreCase(title, query)) ? rows : null;
    }

}

/**
 * The Rust `impl SearchableListDelegate for SearchableVec<SearchableGroup<I>>`:
 * one section per matched group.
 */
class SearchableGroupVec<I> extends SearchableListDelegateBase<I> {

    @:allow(glaze.kit.searchablelist)
    var items:Array<SearchableGroup<I>>;

    @:allow(glaze.kit.searchablelist)
    var matched:Array<Matched>;

    public function new(groups:Array<SearchableGroup<I>>) {
        this.items = groups.copy();
        this.matched = [for (ix in 0...this.items.length) Matched.all(ix)];
    }

    /**
     * Append a group to both the master list and the current filtered view.
     */
    public function push(group:SearchableGroup<I>):Void {
        matched.push(Matched.all(items.length));
        items.push(group);
    }

    function matchedGroup(ix:Int):Null<SearchableGroup<I>> {
        if (ix < 0 || ix >= matched.length) return null;
        final m = matched[ix];
        if (m.ix >= items.length) return null;
        return items[m.ix];
    }

    override public function sectionsCount(cx:App):Int {
        return matched.length;
    }

    public function itemsCount(section:Int):Int {
        final group = matchedGroup(section);
        return group == null ? 0 : matched[section].len(group.items.length);
    }

    override public function section(section:Int):Null<AnyElement> {
        final group = matchedGroup(section);
        if (group == null) return null;
        return (group.title:IntoElement);
    }

    public function item(ix:IndexPath):Null<I> {
        final group = matchedGroup(ix.section);
        if (group == null) return null;
        final row = matched[ix.section].row(ix.row);
        if (row == null || row < 0 || row >= group.items.length) return null;
        return group.items[row];
    }

    public function position(value:Any):Null<IndexPath> {
        var ix = 0;
        for (m in matched) {
            if (m.ix >= items.length) continue;
            final group = items[m.ix];
            for (rowIx in 0...m.len(group.items.length)) {
                final row = m.row(rowIx);
                if (row == null || row >= group.items.length) continue;
                if (SearchableListItems.valueEquals(SearchableListItems.value(group.items[row]), value)) {
                    return IndexPath.defaultValue().withSection(ix).withRow(rowIx);
                }
            }
            ix++;
        }
        return null;
    }

    override public function performSearch(query:String, window:Window, cx:App):Task<Unit> {
        final next:Array<Matched> = [];
        for (ix in 0...items.length) {
            final rows = items[ix].matchedRows(query);
            if (rows == null) continue;
            next.push(new Matched(ix, rows));
        }
        matched = next;
        return Task.ready(Unit.unit);
    }

}

/**
 * The Rust `impl SearchableListDelegate for Vec<T>`: every item, no search.
 */
class VecDelegate<T> extends SearchableListDelegateBase<T> {

    public var items:Array<T>;

    public function new(items:Array<T>) {
        this.items = items;
    }

    public function itemsCount(section:Int):Int {
        return items.length;
    }

    public function item(ix:IndexPath):Null<T> {
        return ix.row >= 0 && ix.row < items.length ? items[ix.row] : null;
    }

    public function position(value:Any):Null<IndexPath> {
        for (ix in 0...items.length) {
            if (SearchableListItems.valueEquals(SearchableListItems.value(items[ix]), value)) {
                return IndexPath.defaultValue().withRow(ix);
            }
        }
        return null;
    }

}

/**
 * An entry of the filtered view, pointing into `SearchableVec.items`.
 */
@:allow(glaze.kit.searchablelist)
class Matched {

    public final ix:Int;

    /** The matched rows of a group, or `null` to keep every row. */
    public final rows:Null<Array<Int>>;

    public function new(ix:Int, rows:Null<Array<Int>>) {
        this.ix = ix;
        this.rows = rows;
    }

    public static function all(ix:Int):Matched {
        return new Matched(ix, null);
    }

    /** The number of rows shown, out of `all` rows of the item. */
    public function len(all:Int):Int {
        return rows == null ? all : rows.length;
    }

    public function row(row:Int):Null<Int> {
        if (rows == null) return row;
        return row >= 0 && row < rows.length ? rows[row] : null;
    }

}
