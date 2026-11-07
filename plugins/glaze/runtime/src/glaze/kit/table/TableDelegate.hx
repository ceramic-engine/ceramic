// Ported from gpui-kit 0.8.1: crates/component/src/table/delegate.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.table;

import gpui.App;
import gpui.Context;
import gpui.Div;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.Pixels;
import gpui.Range;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.menu.PopupMenu;
import gpui.component.table.Column;
import gpui.component.table.Loading;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

/**
 * A delegate trait for providing data and rendering for a table.
 *
 * The context of the rendering methods is the table's (Rust
 * `Context<TableState<Self>>`). The trait defaults are in
 * `TableDelegateBase`: extend it, or implement every method.
 */
interface TableDelegate {

    /** Return the number of columns in the table. */
    function columnsCount(cx:App):Int;

    /** Return the number of rows in the table. */
    function rowsCount(cx:App):Int;

    /**
     * Returns the table column at the given index.
     *
     * This only call on Table prepare or refresh.
     */
    function column(colIx:Int, cx:App):Column;

    /** Perform sort on the column at the given index. */
    function performSort(colIx:Int, sort:ColumnSort, window:Window, cx:Context<TableState<Dynamic>>):Void;

    /**
     * Return the width the content of column `colIx` needs to be read
     * whole, or `null` to leave the column as it is.
     *
     * Called when the column's resize handle is double-clicked. Measure the
     * widest of the column's cells and its header as drawn; the table adds
     * the cell padding, clamps the sum to the column's `minWidth` and
     * `maxWidth`, and emits `TableEvent.ColumnWidthsChanged`. A sortable
     * column's header also holds the table's sort icon (a 0.75rem icon with
     * 2 px of padding on each side), which a header measurement must count.
     *
     * This is called from inside the table's own update, so an
     * implementation must not update the table's entity again.
     *
     * Returns `null` by default, so a double-click changes nothing.
     */
    function fitColumn(colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Null<Pixels>;

    /** Render the table head row. */
    function renderHeader(window:Window, cx:Context<TableState<Dynamic>>):Div;

    /**
     * Return the group headers definitions (can be multi-level).
     *
     * By default, it returns null, meaning no group headers.
     */
    function groupHeaders(cx:App):Null<Array<Array<ColumnGroup>>>;

    /**
     * Custom render for a group header cell.
     * Receives the group label, the logical colSpan, and the pixel width.
     */
    function renderGroupTh(label:String, colSpan:Int, width:Pixels, window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /** Render the header cell at the given column index, default to the column name. */
    function renderTh(colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /**
     * Render the row at the given row and column.
     *
     * Not include the table head row.
     */
    function renderTr(rowIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Div;

    /** Render the context menu for the row at the given row index. */
    function contextMenu(rowIx:Int, menu:PopupMenu, window:Window, cx:Context<TableState<Dynamic>>):PopupMenu;

    /** Render cell at the given row and column. */
    function renderTd(rowIx:Int, colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /**
     * Return the text a screen reader should read for the cell at the given
     * row and column, usually the text `renderTd` draws.
     *
     * Returns `null` by default.
     */
    function cellLabel(rowIx:Int, colIx:Int, cx:App):Null<String>;

    /** Move the column at the given `colIx` so that it ends up at the index `toIx`. */
    function moveColumn(colIx:Int, toIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Void;

    /** Return a Element to show when table is empty. */
    function renderEmpty(window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /** Return true to show the loading view. */
    function loading(cx:App):Bool;

    /**
     * Return a Element to show when table is loading, default is built-in Skeleton loading view.
     *
     * The size is the size of the Table.
     */
    function renderLoading(size:Size, window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /**
     * Return true to enable load more data when scrolling to the bottom.
     *
     * Default: false
     */
    function hasMore(cx:App):Bool;

    /**
     * Returns a threshold value (n rows), of course, when scrolling to the bottom,
     * the remaining number of rows triggers `loadMore`.
     * This should smaller than the total number of first load rows.
     *
     * Default: 20 rows
     */
    function loadMoreThreshold():Int;

    /**
     * Load more data when the table is scrolled to the bottom.
     *
     * This will performed in a background task.
     *
     * This is always called when the table is near the bottom,
     * so you must check if there is more data to load or lock the loading state.
     */
    function loadMore(window:Window, cx:Context<TableState<Dynamic>>):Void;

    /** Render the last empty column, default to empty. */
    function renderLastEmptyCol(window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    /**
     * Called when the visible range of the rows changed.
     *
     * The range never ends past `rowsCount`; a table whose rows drop to none
     * reports `0..0`.
     *
     * NOTE: Make sure this method is fast, because it will be called frequently.
     */
    function visibleRowsChanged(visibleRange:Range, window:Window, cx:Context<TableState<Dynamic>>):Void;

    /**
     * Called when the visible range of the columns changed.
     *
     * NOTE: Make sure this method is fast, because it will be called frequently.
     */
    function visibleColumnsChanged(visibleRange:Range, window:Window, cx:Context<TableState<Dynamic>>):Void;

    /**
     * Get the text representation of a cell for export purposes (e.g., CSV export).
     *
     * Returns an empty string by default.
     */
    function cellText(rowIx:Int, colIx:Int, cx:App):String;

}

/**
 * The default methods of `TableDelegate` (Rust trait defaults).
 * `columnsCount`, `rowsCount`, `column` and `renderTd` have no default.
 */
abstract class TableDelegateBase implements TableDelegate {

    public abstract function columnsCount(cx:App):Int;

    public abstract function rowsCount(cx:App):Int;

    public abstract function column(colIx:Int, cx:App):Column;

    public function performSort(colIx:Int, sort:ColumnSort, window:Window, cx:Context<TableState<Dynamic>>):Void {}

    public function fitColumn(colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Null<Pixels> {
        return null;
    }

    public function renderHeader(window:Window, cx:Context<TableState<Dynamic>>):Div {
        return div().id("header");
    }

    public function groupHeaders(cx:App):Null<Array<Array<ColumnGroup>>> {
        return null;
    }

    public function renderGroupTh(label:String, colSpan:Int, width:Pixels, window:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        return TableDelegateDefaults.renderGroupTh(label, width, cx.app);
    }

    public function renderTh(colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        return div()
            .sizeFull()
            .child(column(colIx, cx.app).name);
    }

    public function renderTr(rowIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Div {
        return div().id(NamedInteger("row", rowIx));
    }

    public function contextMenu(rowIx:Int, menu:PopupMenu, window:Window, cx:Context<TableState<Dynamic>>):PopupMenu {
        return menu;
    }

    public abstract function renderTd(rowIx:Int, colIx:Int, window:Window, cx:Context<TableState<Dynamic>>):IntoElement;

    public function cellLabel(rowIx:Int, colIx:Int, cx:App):Null<String> {
        return null;
    }

    public function moveColumn(colIx:Int, toIx:Int, window:Window, cx:Context<TableState<Dynamic>>):Void {}

    public function renderEmpty(window:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        return TableDelegateDefaults.renderEmpty(cx.app);
    }

    public function loading(cx:App):Bool {
        return false;
    }

    public function renderLoading(size:Size, window:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        return new Loading().size(size);
    }

    public function hasMore(cx:App):Bool {
        return false;
    }

    public function loadMoreThreshold():Int {
        return 20;
    }

    public function loadMore(window:Window, cx:Context<TableState<Dynamic>>):Void {}

    public function renderLastEmptyCol(window:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        return TableDelegateDefaults.renderLastEmptyCol();
    }

    public function visibleRowsChanged(visibleRange:Range, window:Window, cx:Context<TableState<Dynamic>>):Void {}

    public function visibleColumnsChanged(visibleRange:Range, window:Window, cx:Context<TableState<Dynamic>>):Void {}

    public function cellText(rowIx:Int, colIx:Int, cx:App):String {
        return '';
    }

}

/**
 * The bodies of the trait defaults, for delegates that implement
 * `TableDelegate` without extending `TableDelegateBase`.
 */
class TableDelegateDefaults {

    /** Rust `TableDelegate::render_group_th` default. */
    public static function renderGroupTh(label:String, width:Pixels, cx:App):IntoElement {
        return div()
            .w(px(width))
            .hFull()
            .flexShrink0()
            .flex()
            .itemsCenter()
            .justifyCenter()
            .borderR1()
            .borderColor(Theme.global(cx).border)
            .child(label);
    }

    /** Rust `TableDelegate::render_empty` default. */
    public static function renderEmpty(cx:App):IntoElement {
        return hFlex()
            .sizeFull()
            .justifyCenter()
            .textColor(Theme.global(cx).mutedForeground.opacity(0.6))
            .child(new Icon(IconName.Inbox).size12());
    }

    /** Rust `TableDelegate::render_last_empty_col` default. */
    public static function renderLastEmptyCol():IntoElement {
        return hFlex().w3().hFull().flexShrink0();
    }

}
