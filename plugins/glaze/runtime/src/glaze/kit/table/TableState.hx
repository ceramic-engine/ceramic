// Ported from gpui-kit 0.8.1: crates/component/src/table/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.table;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Div;
import glaze.DragMoveEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.ListSizingBehavior;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ScrollStrategy;
import glaze.Size;
import glaze.Task;
import glaze.TextAlign;
import glaze.UniformListScrollHandle;
import glaze.Unit;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectFirst;
import glaze.kit.base.Actions.SelectLast;
import glaze.kit.base.Actions.SelectNextColumn;
import glaze.kit.base.Actions.SelectPageDown;
import glaze.kit.base.Actions.SelectPageUp;
import glaze.kit.base.Actions.SelectPrevColumn;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.Measure;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.ScrollableMask;
import glaze.kit.base.VirtualList;
import glaze.kit.base.VirtualList.VirtualListScrollHandle;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.menu.PopupMenu;
import glaze.kit.scroll.Scrollbar;
import glaze.kit.table.Column;
import glaze.kit.table.DataTable.TableOptions;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.ClickEvent.ClickEventTools;
using glaze.kit.base.ElementExt;
using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;
using glaze.kit.Size.SizeTools;
using glaze.kit.StyleSized;
using glaze.kit.menu.ContextMenu.ContextMenuExt;

enum abstract SelectionMode(Int) {
    var Column = 0;
    var Row = 1;
    var Cell = 2;

    public inline function isRow():Bool {
        return (cast this : SelectionMode) == Row;
    }

    public inline function isColumn():Bool {
        return (cast this : SelectionMode) == Column;
    }

    public inline function isCell():Bool {
        return (cast this : SelectionMode) == Cell;
    }
}

/** A `(row_ix, col_ix)` pair of the table (Rust `(usize, usize)`). */
class CellPosition {

    public final row:Int;

    public final col:Int;

    public inline function new(row:Int, col:Int) {
        this.row = row;
        this.col = col;
    }

    public inline function equals(other:Null<CellPosition>):Bool {
        return other != null && other.row == row && other.col == col;
    }

    /** Rust `{:?}` of the tuple. */
    public function toString():String {
        return '($row, $col)';
    }

    public static inline function same(a:Null<CellPosition>, row:Int, col:Int):Bool {
        return a != null && a.row == row && a.col == col;
    }

}

/**
 * The current selection of a table, as one value.
 *
 * Mirrors `TableEvent.SelectRow`, `TableEvent.SelectColumn` and
 * `TableEvent.SelectCell`. Match on it instead of combining
 * `TableState.selectedRow`, `selectedCol` and `selectedCell`.
 */
@:using(glaze.kit.table.TableState.TableSelectionTools)
enum TableSelection {
    /** Nothing is selected. */
    None;
    /** A row is selected. */
    Row(rowIx:Int);
    /** A column is selected. */
    Column(colIx:Int);
    /** A cell is selected, as `(rowIx, colIx)`. */
    Cell(rowIx:Int, colIx:Int);
}

class TableSelectionTools {

    public static function equals(self:TableSelection, other:TableSelection):Bool {
        return Type.enumEq(self, other);
    }

    /** Rust `{:?}`. */
    public static function describe(self:TableSelection):String {
        return switch self {
            case None: 'None';
            case Row(r): 'Row($r)';
            case Column(c): 'Column($c)';
            case Cell(r, c): 'Cell($r, $c)';
        }
    }

}

/** The Table event. */
enum TableEvent {
    /** Single click or move to selected row. */
    SelectRow(rowIx:Int);
    /** Double click on the row. */
    DoubleClickedRow(rowIx:Int);
    /** Selected column. */
    SelectColumn(colIx:Int);
    /**
     * A cell has been selected (clicked or navigated to via keyboard).
     *
     * Emitted when a cell is selected in cell selection mode.
     */
    SelectCell(rowIx:Int, colIx:Int);
    /** A cell has been double-clicked, in cell selection mode. */
    DoubleClickedCell(rowIx:Int, colIx:Int);
    /** The column widths have changed: the new widths of all columns. */
    ColumnWidthsChanged(widths:Array<Pixels>);
    /** A column has been moved, from the original index to the new index. */
    MoveColumn(fromIx:Int, toIx:Int);
    /**
     * A row has been right-clicked.
     *
     * Contains the row index, or `null` if right-clicked on an empty area.
     */
    RightClickedRow(rowIx:Null<Int>);
    /** A cell has been right-clicked, in cell selection mode. */
    RightClickedCell(rowIx:Int, colIx:Int);
    /** The selection has been cleared. */
    ClearSelection;
}

/** The visible range of the rows and columns. */
class TableVisibleRange {

    @:allow(glaze.kit.table)
    var rowsValue:Range = new Range(0, 0);

    @:allow(glaze.kit.table)
    var colsValue:Range = new Range(0, 0);

    public function new() {}

    /** Returns the visible range of the rows. */
    public inline function rows():Range {
        return rowsValue;
    }

    /** Returns the visible range of the columns. */
    public inline function cols():Range {
        return colsValue;
    }

}

@:allow(glaze.kit.table)
class HeaderCell {

    public var label:String;

    public var width:Pixels;

    var colSpan:Int;

    var isLeaf:Bool;

    var leafColIx:Null<Int>;

    var startLeafColIx:Int;

    public function new(label:String, width:Pixels, colSpan:Int, isLeaf:Bool, leafColIx:Null<Int>, startLeafColIx:Int) {
        this.label = label;
        this.width = width;
        this.colSpan = colSpan;
        this.isLeaf = isLeaf;
        this.leafColIx = leafColIx;
        this.startLeafColIx = startLeafColIx;
    }

}

/**
 * The state for `DataTable`.
 *
 * # Selection Modes
 *
 * The table supports three selection modes:
 * - **Row Selection**: Select entire rows (default mode)
 * - **Column Selection**: Select entire columns
 * - **Cell Selection**: Select individual cells
 *
 * When `cellSelectable` is enabled, users can click on cells to select
 * them, right-click on cells to mark them for context menus, double-click on
 * cells to trigger actions, and navigate between cells using the keyboard
 * (arrow keys, Home, End, PageUp, PageDown, Tab). A row header column appears
 * on the left side, to select entire rows.
 */
@:allow(glaze.kit.table, tests)
class TableState<D:TableDelegate> extends Model implements Render {

    /** How far behind the pointer a resize drag trails the column edge. */
    static inline final HANDLE_SIZE:Pixels = 2.;

    /**
     * Grab room on each side of a resize handle's hairline, so the divider can be
     * caught without pixel-hunting. Both halves of the band are this wide, so
     * widening the grab area stays symmetric about the boundary. `resizable`'s
     * handle pads a hairline the same way, and by the same amount.
     */
    static inline final HANDLE_PADDING:Pixels = 4.;

    final focusHandleValue:FocusHandle;

    var delegateValue:D;

    var options:TableOptions = new TableOptions();

    /** The bounds of the table container. */
    var bounds:Bounds = new Bounds();

    /** The bounds of the fixed head cols. */
    var fixedHeadColsBounds:Bounds = new Bounds();

    var colGroups:Array<ColGroup> = [];

    var headerLayout:Array<Array<HeaderCell>> = [];

    /**
     * Whether the table can loop selection, default is true.
     *
     * When the prev/next selection is out of the table bounds, the selection will loop to the other side.
     */
    public var loopSelectionValue:Bool = true;

    /** Whether the table can select column. */
    public var colSelectableValue:Bool = true;

    /** Whether the table can select row. */
    public var rowSelectableValue:Bool = true;

    /**
     * Whether a row click with the secondary modifier (cmd on macOS, Ctrl
     * elsewhere) or Shift held selects the row, default is `true`.
     */
    var selectOnModifierClickValue:Bool = true;

    /** Whether the table can select cell, default is false. */
    public var cellSelectableValue:Bool = false;

    /**
     * Whether the row header column is visible when `cellSelectable` is enabled,
     * default is `true`.
     */
    public var rowHeaderValue:Bool = true;

    /** Whether the table can sort. */
    public var sortableValue:Bool = true;

    /** Whether the table can resize columns. */
    public var colResizableValue:Bool = true;

    /** Whether the table can move columns. */
    public var colMovableValue:Bool = true;

    /** Enable/disable fixed columns feature. */
    public var colFixed:Bool = true;

    public final verticalScrollHandle:UniformListScrollHandle = new UniformListScrollHandle();

    public final horizontalScrollHandle:VirtualListScrollHandle = new VirtualListScrollHandle();

    var selectedRowValue:Null<Int> = null;

    var selectionMode:SelectionMode = Row;

    var rightClickedRowValue:Null<Int> = null;

    var rightClickedCellValue:Null<CellPosition> = null;

    var selectedColValue:Null<Int> = null;

    var selectedCellValue:Null<CellPosition> = null;

    /** The column index that is being resized. */
    var resizingCol:Null<Int> = null;

    /**
     * The column a double-click on its resize handle just fitted.
     *
     * The double-click's second press also starts a drag on the handle, which
     * would move the fitted edge back under the pointer, so resize drags on
     * this column are ignored until the next single press.
     */
    var fittedCol:Null<Int> = null;

    /**
     * The insertion gap index (`0..=colsCount`) while dragging a column
     * header: the dragged column will be inserted between the columns
     * `gap - 1` and `gap` on drop.
     */
    var colDragGap:Null<Int> = null;

    /** The visible range of the rows and columns. */
    final visibleRangeValue:TableVisibleRange = new TableVisibleRange();

    final measures:Array<Float> = [];

    var loadMoreTask:Null<Task<Unit>> = null;

    /** Create a new TableState with the given delegate. */
    public function new(delegate:D, _:Window, cx:Context<Dynamic>) {
        super();
        focusHandleValue = cx.focusHandle().tabStop(true);
        delegateValue = delegate;
        prepareColGroups(cx);
    }

    /** Returns the delegate. */
    public inline function delegate():D {
        return delegateValue;
    }

    /** Returns the delegate (Rust `delegate_mut`). */
    public inline function delegateMut():D {
        return delegateValue;
    }

    /** Set to loop selection, default to true. */
    public function loopSelection(loopSelection:Bool):TableState<D> {
        loopSelectionValue = loopSelection;
        return this;
    }

    /** Set to enable/disable column movable, default to true. */
    public function colMovable(colMovable:Bool):TableState<D> {
        colMovableValue = colMovable;
        return this;
    }

    /** Set to enable/disable column resizable, default to true. */
    public function colResizable(colResizable:Bool):TableState<D> {
        colResizableValue = colResizable;
        return this;
    }

    /** Set to enable/disable column sortable, default true */
    public function sortable(sortable:Bool):TableState<D> {
        sortableValue = sortable;
        return this;
    }

    /** Set to enable/disable row selectable, default true */
    public function rowSelectable(rowSelectable:Bool):TableState<D> {
        rowSelectableValue = rowSelectable;
        return this;
    }

    /**
     * Set whether a row click with the secondary modifier or Shift held
     * selects the row, default is `true`.
     */
    public function selectOnModifierClick(selectOnModifierClick:Bool):TableState<D> {
        selectOnModifierClickValue = selectOnModifierClick;
        return this;
    }

    /** Set to enable/disable column selectable, default true */
    public function colSelectable(colSelectable:Bool):TableState<D> {
        colSelectableValue = colSelectable;
        return this;
    }

    /**
     * Set to enable/disable cell selection, default is false.
     *
     * When enabled:
     * - Individual cells become selectable by clicking
     * - A row header column appears on the left side (can be hidden via `rowHeader`)
     * - Keyboard navigation operates at the cell level
     * - Cell-specific events (SelectCell, DoubleClickedCell, RightClickedCell) are emitted
     */
    public function cellSelectable(cellSelectable:Bool):TableState<D> {
        cellSelectableValue = cellSelectable;
        return this;
    }

    /**
     * Set whether the row header column is shown, default is `true`.
     *
     * Only effective when `cellSelectable` is `true`. When hidden, the first
     * click on a cell selects the cell; clicking the already-selected cell
     * again escalates to selecting the whole row (requires `rowSelectable`).
     */
    public function rowHeader(rowHeader:Bool):TableState<D> {
        rowHeaderValue = rowHeader;
        return this;
    }

    /** When we update columns or rows, we need to refresh the table. */
    public function refresh(cx:Context<Dynamic>):Void {
        prepareColGroups(cx);
    }

    /** Scroll to the row at the given index. */
    public function scrollToRow(rowIx:Int, cx:Context<Dynamic>):Void {
        verticalScrollHandle.scrollToItem(rowIx, ScrollStrategy.Top);
        cx.notify();
    }

    /** Scroll to the column at the given index. */
    public function scrollToCol(colIx:Int, cx:Context<Dynamic>):Void {
        final fixed = fixedLeftColsCount();
        final colIx = colIx > fixed ? colIx - fixed : 0;

        // Resolve the offset here instead of deferring it to the virtual list.
        //
        // The header and the rows share `horizontalScrollHandle`, but only
        // the rows are a `VirtualList`, and a deferred `scrollToItem` is
        // applied during that list's prepaint, which runs *after* the header
        // has already been rendered and prepainted with the old offset. The
        // header would therefore stay one frame behind the rows.
        final offsetX = horizontalOffsetForCol(colIx);
        if (offsetX != null) {
            final offset = horizontalScrollHandle.offset();
            horizontalScrollHandle.setOffset(new Point(offsetX, offset.y));
        } else {
            // Before the first layout the viewport size is unknown, let the
            // virtual list resolve the offset once it has been laid out.
            horizontalScrollHandle.scrollToItem(colIx, ScrollStrategy.Top);
        }

        cx.notify();
    }

    /**
     * The horizontal scroll offset that brings the scrollable (non-fixed)
     * column at `colIx` fully into view.
     *
     * This mirrors the nearest-edge behavior of `VirtualListScrollHandle.scrollToItem`
     * with `ScrollStrategy.Top`: an already visible column keeps the current
     * offset, otherwise the column is aligned to the edge it overflows.
     *
     * Returns `null` when the viewport size is not known yet, or when `colIx`
     * is out of range.
     */
    function horizontalOffsetForCol(colIx:Int):Null<Pixels> {
        final viewportWidth:Float = horizontalScrollHandle.bounds().size.width;
        if (viewportWidth <= 0.) {
            return null;
        }

        final fixed = fixedLeftColsCount();
        if (fixed > colGroups.length) return null;
        final cols = colGroups.slice(fixed);
        if (colIx > cols.length) return null;
        var colLeft:Float = 0.;
        for (i in 0...colIx) colLeft = f32(colLeft + cols[i].width);
        if (colIx >= cols.length) return null;
        final colRight:Float = f32(colLeft + cols[colIx].width);
        final offsetX:Float = horizontalScrollHandle.offset().x;

        return if (f32(colLeft + offsetX) < 0.) {
            -colLeft;
        } else if (f32(colRight + offsetX) > viewportWidth) {
            f32(viewportWidth - colRight);
        } else {
            offsetX;
        }
    }

    /**
     * Returns the current selection as one value.
     *
     * A selected cell reports as `TableSelection.Cell` only.
     */
    public function selection():TableSelection {
        final row = selectedRow();
        if (row != null) return TableSelection.Row(row);
        final col = selectedCol();
        if (col != null) return TableSelection.Column(col);
        final cell = selectedCell();
        if (cell != null) return TableSelection.Cell(cell.row, cell.col);
        return TableSelection.None;
    }

    /**
     * Returns the selected row index.
     *
     * Not null only when a row itself is selected; a selected cell does not
     * count, see `selection`.
     */
    public function selectedRow():Null<Int> {
        return selectionMode.isRow() ? selectedRowValue : null;
    }

    /** Sets the selected row to the given index. */
    public function setSelectedRow(rowIx:Int, cx:Context<Dynamic>):Void {
        final isDown = selectedRowValue != null ? rowIx > selectedRowValue : true;

        selectionMode = Row;
        rightClickedRowValue = null;
        selectedRowValue = rowIx;
        verticalScrollHandle.scrollToItem(rowIx, isDown ? ScrollStrategy.Bottom : ScrollStrategy.Top);
        cx.emit(TableEvent.SelectRow(rowIx));
        cx.emit(TableEvent.RightClickedRow(null));
        cx.notify();
    }

    /** Returns the row that has been right clicked. */
    public inline function rightClickedRow():Null<Int> {
        return rightClickedRowValue;
    }

    /** Returns the cell that has been right clicked, as `(rowIx, colIx)`. */
    public inline function rightClickedCell():Null<CellPosition> {
        return rightClickedCellValue;
    }

    /**
     * Set or clear the right-clicked row state.
     *
     * Pass `null` to clear, useful when opening a header context menu
     * to prevent the row context menu from appearing simultaneously.
     */
    public function setRightClickedRow(row:Null<Int>, cx:Context<Dynamic>):Void {
        rightClickedRowValue = row;
        cx.notify();
    }

    /**
     * Returns the selected column index.
     *
     * Not null only when a column itself is selected, see `selection`.
     */
    public function selectedCol():Null<Int> {
        return selectionMode.isColumn() ? selectedColValue : null;
    }

    /** Sets the selected col to the given index. */
    public function setSelectedCol(colIx:Int, cx:Context<Dynamic>):Void {
        selectionMode = Column;
        selectedColValue = colIx;
        scrollToCol(colIx, cx);
        cx.emit(TableEvent.SelectColumn(colIx));
        cx.notify();
    }

    /**
     * Returns the selected cell as `(rowIx, colIx)`.
     *
     * Not null only when a cell is selected; see `selection`.
     */
    public function selectedCell():Null<CellPosition> {
        return selectionMode.isCell() ? selectedCellValue : null;
    }

    /**
     * Sets the selected cell to the given row and column indices.
     *
     * Switches the table to cell selection mode, scrolls to make the cell
     * visible (centered vertically) and emits `TableEvent.SelectCell`.
     */
    public function setSelectedCell(rowIx:Int, colIx:Int, cx:Context<Dynamic>):Void {
        selectionMode = Cell;
        selectedCellValue = new CellPosition(rowIx, colIx);
        rightClickedCellValue = null;

        // Scroll to the cell
        verticalScrollHandle.scrollToItem(rowIx, ScrollStrategy.Center);
        scrollToCol(colIx, cx);

        cx.emit(TableEvent.SelectCell(rowIx, colIx));
        cx.notify();
    }

    /**
     * Sets the selection as one value; `TableSelection.None` clears it.
     *
     * Scrolls and emits exactly as the matching `setSelected*` or
     * `clearSelection` call would.
     */
    public function setSelection(selection:TableSelection, cx:Context<Dynamic>):Void {
        switch selection {
            case None: clearSelection(cx);
            case Row(rowIx): setSelectedRow(rowIx, cx);
            case Column(colIx): setSelectedCol(colIx, cx);
            case Cell(rowIx, colIx): setSelectedCell(rowIx, colIx, cx);
        }
    }

    /** Clear the selection of the table. */
    public function clearSelection(cx:Context<Dynamic>):Void {
        selectionMode = Row;
        selectedRowValue = null;
        selectedColValue = null;
        selectedCellValue = null;
        cx.emit(TableEvent.ClearSelection);
        cx.notify();
    }

    /** Returns the visible range of the rows and columns. */
    public inline function visibleRange():TableVisibleRange {
        return visibleRangeValue;
    }

    /**
     * Dump the header row of the table.
     *
     * Batched exporters can read the headers once with this, then stream the
     * rows with `dumpRange`.
     */
    public function headers(cx:App):Array<String> {
        final columnsCount = delegateValue.columnsCount(cx);
        final headers = [];
        for (colIx in 0...columnsCount) {
            final column = delegateValue.column(colIx, cx);
            headers.push(column.name);
        }

        return headers;
    }

    /**
     * Dump table data: `(headers, rows)` where each row is an array of cell
     * values.
     *
     * This materializes the complete table in memory. For large tables, prefer
     * `dumpRange` and process rows in batches.
     */
    public function dump(cx:App):{headers:Array<String>, rows:Array<Array<String>>} {
        return dumpRange(new Range(0, delegateValue.rowsCount(cx)), cx);
    }

    /**
     * Dump table data for the specified row range.
     *
     * The requested range is clamped to the table's current row count.
     */
    public function dumpRange(range:Range, cx:App):{headers:Array<String>, rows:Array<Array<String>>} {
        final columnsCount = delegateValue.columnsCount(cx);
        final rowsCount = delegateValue.rowsCount(cx);
        final start = range.start < rowsCount ? range.start : rowsCount;
        var end = range.end < rowsCount ? range.end : rowsCount;
        if (end < start) end = start;

        final rows = [];
        for (rowIx in start...end) {
            final row = [];
            for (colIx in 0...columnsCount) {
                row.push(delegateValue.cellText(rowIx, colIx, cx));
            }
            rows.push(row);
        }

        return {headers: headers(cx), rows: rows};
    }

    /**
     * Re-compute the header layout from the current delegate.
     *
     * Call this after changing delegate state that affects `groupHeaders`.
     */
    public function refreshHeaderLayout(cx:Context<Dynamic>):Void {
        updateHeaderLayout(cx.app);
        cx.notify();
    }

    function prepareColGroups(cx:Context<Dynamic>):Void {
        colGroups = [for (colIx in 0...delegateValue.columnsCount(cx.app)) {
            final column = delegateValue.column(colIx, cx.app);
            new ColGroup(column, column.width, new Bounds());
        }];

        updateHeaderLayout(cx.app);
    }

    function updateHeaderLayout(cx:App):Void {
        final groupRows = delegateValue.groupHeaders(cx);

        final layout:Array<Array<HeaderCell>> = [];

        if (groupRows != null) {
            for (row in groupRows) {
                final cellRow = [];
                var currentLeafIx = 0;
                for (group in row) {
                    var width:Float = 0.;
                    final startLeafColIx = currentLeafIx;
                    for (i in 0...group.span) {
                        if (currentLeafIx + i < colGroups.length) {
                            width = f32(width + colGroups[currentLeafIx + i].width);
                        }
                    }
                    currentLeafIx += group.span;
                    cellRow.push(new HeaderCell(group.label, width, group.span, false, null, startLeafColIx));
                }
                layout.push(cellRow);
            }
        }

        final leafRow = [];
        for (ix => group in colGroups) {
            leafRow.push(new HeaderCell(group.column.name, group.width, 1, true, ix, ix));
        }
        layout.push(leafRow);

        headerLayout = layout;
    }

    function fixedLeftColsCount():Int {
        if (!colFixed) {
            return 0;
        }

        var count = 0;
        for (col in colGroups) if (col.column.fixed == ColumnFixed.Left) count++;
        return count;
    }

    /** One header row. An unset header height matches the body rows. */
    function headerRowHeight():Pixels {
        return options.headerRowHeight != null ? options.headerRowHeight : options.size.tableRowHeight();
    }

    /**
     * Every header row, including column-group rows. An empty layout still
     * reserves one row, matching the vertical scrollbar's top inset.
     */
    function headerBandHeight():Pixels {
        final rows = headerLayout.length > 1 ? headerLayout.length : 1;
        return f32(headerRowHeight() * rows);
    }

    function pageItemCount():Int {
        final rowHeight:Float = options.size.tableRowHeight();
        var bodyHeight:Float = f32(bounds.size.height - (headerBandHeight() : Float));
        if (bodyHeight < 0.) bodyHeight = 0.;
        final count = Std.int(Math.ffloor(f32(bodyHeight / rowHeight)));
        return count > 1 ? count : 1;
    }

    // Never two parameters named `_` in this class: it is generic, and Haxe's C#
    // output declares its methods in an interface where duplicate names do not compile.
    function onRowRightClick(_1:MouseDownEvent, rowIx:Null<Int>, _2:Window, cx:Context<Dynamic>):Void {
        rightClickedRowValue = rowIx;
        rightClickedCellValue = null;
        cx.emit(TableEvent.RightClickedRow(rowIx));
    }

    function onCellRightClick(_1:MouseDownEvent, rowIx:Int, colIx:Int, _2:Window, cx:Context<Dynamic>):Void {
        if (!cellSelectableValue) {
            return;
        }

        cx.stopPropagation();
        rightClickedCellValue = new CellPosition(rowIx, colIx);
        rightClickedRowValue = null;
        cx.emit(TableEvent.RightClickedCell(rowIx, colIx));
    }

    function onRowLeftClick(e:ClickEvent, rowIx:Int, _:Window, cx:Context<Dynamic>):Void {
        if (!rowSelectableValue) {
            return;
        }

        cx.stopPropagation();
        if (selectsRowOnClick(e, cx.app)) {
            setSelectedRow(rowIx, cx);
        }

        if (e.clickCount() == 2) {
            cx.emit(TableEvent.DoubleClickedRow(rowIx));
        }
    }

    /** Whether a click on a row selects it, see `selectOnModifierClick`. */
    function selectsRowOnClick(e:ClickEvent, cx:App):Bool {
        final modifiers = e.modifiers();
        return selectOnModifierClickValue || !(modifiers.secondary() || modifiers.shift);
    }

    function onColHeadClick(colIx:Int, _:Window, cx:Context<Dynamic>):Void {
        if (!colSelectableValue) {
            return;
        }

        if (colIx < 0 || colIx >= colGroups.length) {
            return;
        }
        final colGroup = colGroups[colIx];

        if (!colGroup.column.selectable) {
            return;
        }

        setSelectedCol(colIx, cx);
    }

    function onCellClick(e:ClickEvent, rowIx:Int, colIx:Int, _:Window, cx:Context<Dynamic>):Void {
        if (!cellSelectableValue) {
            return;
        }

        cx.stopPropagation();

        final isDoubleClick = e.clickCount() == 2;

        // When the row header column is hidden, a single click on the
        // already-selected cell escalates the selection to the entire row,
        // giving users a way to pick rows without the dedicated header column.
        // Double-clicks are passed through to `DoubleClickedCell` and never
        // trigger the escalation.
        final isReselect = CellPosition.same(selectedCell(), rowIx, colIx);
        final shouldEscalateToRow = !rowHeaderValue
            && rowSelectableValue
            && isReselect
            && !isDoubleClick
            && selectsRowOnClick(e, cx.app);
        if (shouldEscalateToRow) {
            setSelectedRow(rowIx, cx);
            return;
        }

        setSelectedCell(rowIx, colIx, cx);

        if (isDoubleClick) {
            cx.emit(TableEvent.DoubleClickedCell(rowIx, colIx));
        }
    }

    function hasSelection():Bool {
        return selection() != TableSelection.None;
    }

    function actionCancel(_1:Cancel, _2:Window, cx:Context<Dynamic>):Void {
        if (hasSelection()) {
            clearSelection(cx);
            return;
        }
        cx.propagate();
    }

    function actionSelectPrev(_1:SelectUp, _2:Window, cx:Context<Dynamic>):Void {
        final rowsCount = delegateValue.rowsCount(cx.app);
        if (rowsCount < 1) {
            return;
        }

        // Cell selection mode: move up within the same column
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final newRow = if (cell.row > 0) {
                    cell.row - 1;
                } else if (loopSelectionValue) {
                    sat(rowsCount - 1);
                } else {
                    cell.row;
                }
                setSelectedCell(newRow, cell.col, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Row selection mode
        if (!rowSelectableValue) {
            return;
        }
        var selectedRow = selectedRowValue != null ? selectedRowValue : 0;
        if (selectedRow > 0) {
            selectedRow = selectedRow - 1;
        } else {
            if (loopSelectionValue) {
                selectedRow = sat(rowsCount - 1);
            }
        }

        setSelectedRow(selectedRow, cx);
    }

    function actionSelectNext(_1:SelectDown, _2:Window, cx:Context<Dynamic>):Void {
        final rowsCount = delegateValue.rowsCount(cx.app);
        if (rowsCount < 1) {
            return;
        }

        // Cell selection mode: move down within the same column
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final newRow = if (cell.row < sat(rowsCount - 1)) {
                    cell.row + 1;
                } else if (loopSelectionValue) {
                    0;
                } else {
                    cell.row;
                }
                setSelectedCell(newRow, cell.col, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Row selection mode
        if (!rowSelectableValue) {
            return;
        }
        final selected = selectedRowValue;
        final selectedRow = if (selected != null && selected < sat(rowsCount - 1)) {
            selected + 1;
        } else if (selected != null) {
            loopSelectionValue ? 0 : selected;
        } else {
            0;
        }

        setSelectedRow(selectedRow, cx);
    }

    function actionSelectFirstColumn(_1:SelectFirst, _2:Window, cx:Context<Dynamic>):Void {
        // Cell selection mode: move to first cell in current row
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                setSelectedCell(cell.row, 0, cx);
            } else {
                // No cell selected, select first cell of first row
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Row selection mode: Home goes to the first row, as in a list
        if (selectionMode.isRow() && rowSelectableValue) {
            if (delegateValue.rowsCount(cx.app) > 0) {
                setSelectedRow(0, cx);
            }
            return;
        }

        // Column selection mode
        setSelectedCol(0, cx);
    }

    function actionSelectLastColumn(_1:SelectLast, _2:Window, cx:Context<Dynamic>):Void {
        final columnsCount = delegateValue.columnsCount(cx.app);

        // Cell selection mode: move to last cell in current row
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                setSelectedCell(cell.row, sat(columnsCount - 1), cx);
            } else {
                // No cell selected, select last cell of first row
                setSelectedCell(0, sat(columnsCount - 1), cx);
            }
            return;
        }

        // Row selection mode: End goes to the last row, as in a list
        if (selectionMode.isRow() && rowSelectableValue) {
            final rowsCount = delegateValue.rowsCount(cx.app);
            if (rowsCount > 0) {
                setSelectedRow(rowsCount - 1, cx);
            }
            return;
        }

        // Column selection mode
        setSelectedCol(sat(columnsCount - 1), cx);
    }

    function actionSelectPageUp(_1:SelectPageUp, _2:Window, cx:Context<Dynamic>):Void {
        final step = pageItemCount();

        // Cell selection mode: move up by page within the same column
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final target = sat(cell.row - step);
                setSelectedCell(target, cell.col, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Row selection mode
        if (!rowSelectableValue) {
            return;
        }
        final current = selectedRowValue != null ? selectedRowValue : 0;
        final target = sat(current - step);
        setSelectedRow(target, cx);
    }

    function actionSelectPageDown(_1:SelectPageDown, _2:Window, cx:Context<Dynamic>):Void {
        final rowsCount = delegateValue.rowsCount(cx.app);
        if (rowsCount == 0) {
            return;
        }

        final step = pageItemCount();

        // Cell selection mode: move down by page within the same column
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final maxRow = sat(rowsCount - 1);
                final target = cell.row + step < maxRow ? cell.row + step : maxRow;
                setSelectedCell(target, cell.col, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Row selection mode
        if (!rowSelectableValue) {
            return;
        }
        final current = selectedRowValue != null ? selectedRowValue : 0;
        final maxRow = sat(rowsCount - 1);
        final target = current + step < maxRow ? current + step : maxRow;
        setSelectedRow(target, cx);
    }

    function actionSelectPrevCol(_1:SelectPrevColumn, _2:Window, cx:Context<Dynamic>):Void {
        final columnsCount = delegateValue.columnsCount(cx.app);

        // Cell selection mode: move left within the same row
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final newCol = if (cell.col > 0) {
                    cell.col - 1;
                } else if (loopSelectionValue) {
                    sat(columnsCount - 1);
                } else {
                    cell.col;
                }
                setSelectedCell(cell.row, newCol, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Column selection mode
        var selectedCol = selectedColValue != null ? selectedColValue : 0;
        if (selectedCol > 0) {
            selectedCol = selectedCol - 1;
        } else {
            if (loopSelectionValue) {
                selectedCol = sat(columnsCount - 1);
            }
        }
        setSelectedCol(selectedCol, cx);
    }

    function actionSelectNextCol(_1:SelectNextColumn, _2:Window, cx:Context<Dynamic>):Void {
        final columnsCount = delegateValue.columnsCount(cx.app);

        // Cell selection mode: move right within the same row
        if (selectionMode.isCell()) {
            final cell = selectedCellValue;
            if (cell != null) {
                final newCol = if (cell.col < sat(columnsCount - 1)) {
                    cell.col + 1;
                } else if (loopSelectionValue) {
                    0;
                } else {
                    cell.col;
                }
                setSelectedCell(cell.row, newCol, cx);
            } else {
                // No cell selected, select first cell
                setSelectedCell(0, 0, cx);
            }
            return;
        }

        // Column selection mode
        var selectedCol = selectedColValue != null ? selectedColValue : 0;
        if (selectedCol < sat(columnsCount - 1)) {
            selectedCol += 1;
        } else {
            if (loopSelectionValue) {
                selectedCol = 0;
            }
        }

        setSelectedCol(selectedCol, cx);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    /** Rust `usize::saturating_sub` against zero. */
    static inline function sat(value:Int):Int {
        return value < 0 ? 0 : value;
    }

    /** Scroll table when mouse position is near the edge of the table bounds. */
    function scrollTableByColResizing(mousePosition:Point, colGroup:ColGroup):Void {
        // Do nothing if pos out of the table bounds right for avoid scroll to the right.
        if (mousePosition.x > bounds.right()) {
            return;
        }

        final offset = horizontalScrollHandle.offset();
        var offsetX:Float = offset.x;
        final colBounds = colGroup.bounds;

        if (mousePosition.x < bounds.left() && colBounds.right() < f32(bounds.left() + 20.)) {
            offsetX = f32(offsetX + 1.);
        } else if (mousePosition.x > bounds.right() && colBounds.right() > f32(bounds.right() - 20.)) {
            offsetX = f32(offsetX - 1.);
        }

        horizontalScrollHandle.setOffset(new Point(offsetX, offset.y));
    }

    /**
     * The width column `colIx` is drawn at now, or `null` past the last
     * column.
     *
     * This is the table's own width, which follows a drag or a fit as it
     * happens; the delegate's `Column.width` is read again only on `refresh`.
     */
    public function colWidth(colIx:Int):Null<Pixels> {
        return colIx >= 0 && colIx < colGroups.length ? colGroups[colIx].width : null;
    }

    /**
     * Fits column `colIx` to its content, as a double-click on its resize
     * handle does.
     *
     * The width is `TableDelegate.fitColumn` plus the cell padding,
     * clamped to the column's `minWidth` and `maxWidth`, and
     * `TableEvent.ColumnWidthsChanged` is emitted when it changed. Returns
     * whether the delegate gave a width: `false` when the column cannot be
     * resized or the delegate answered `null`.
     */
    public function fitCol(colIx:Int, window:Window, cx:Context<Dynamic>):Bool {
        if (!isColResizable(colIx)) {
            return false;
        }
        final content:Null<Pixels> = delegateValue.fitColumn(colIx, window, cast cx);
        if (content == null) {
            return false;
        }
        final paddings = colIx < colGroups.length ? colGroups[colIx].column.paddings : null;
        final padding = paddings != null ? paddings : options.size.tableCellPadding();
        // Layout rounds a width to the nearest device pixel, and text even a
        // fraction of a pixel wider than its cell is truncated, so round every
        // part up to a whole device pixel.
        final scaleFactor:Float = f32(window.scaleFactor());
        inline function devicePixels(length:Float):Float {
            return Math.fceil(f32(f32(length) * scaleFactor));
        }
        var contentPixels = devicePixels(content);
        // Dividing back can land one ulp below the content at a fractional
        // scale, and the text is cut for that ulp too.
        if (f32(contentPixels / scaleFactor) < f32(content)) {
            contentPixels += 1.;
        }
        final width:Float = f32(f32(contentPixels + devicePixels(padding.left)) + devicePixels(padding.right));
        if (resizeCols(colIx, f32(width / scaleFactor), window, cx)) {
            final newWidths = [for (g in colGroups) g.width];
            cx.emit(TableEvent.ColumnWidthsChanged(newWidths));
        }
        return true;
    }

    /**
     * The `ix` is the index of the col to resize, and the `size` is the new
     * size for the col.
     *
     * Returns whether the width changed.
     */
    function resizeCols(ix:Int, size:Pixels, _:Window, cx:Context<Dynamic>):Bool {
        if (!colResizableValue) {
            return false;
        }

        var changed = false;
        if (ix >= 0 && ix < colGroups.length) {
            final colGroup = colGroups[ix];
            if (colGroup.isResizable()) {
                // Rust `size.max(min_width).min(max_width)`
                var newWidth:Float = size;
                if (newWidth < colGroup.column.minWidth) newWidth = colGroup.column.minWidth;
                if (newWidth > colGroup.column.maxWidth) newWidth = colGroup.column.maxWidth;
                if (colGroup.width != newWidth) {
                    colGroup.width = newWidth;
                    changed = true;
                }
            }
        }

        if (changed) {
            updateHeaderLayout(cx.app);
            cx.notify();
        }
        return changed;
    }

    function performSort(colIx:Int, window:Window, cx:Context<Dynamic>):Void {
        if (!sortableValue) {
            return;
        }

        final sort:Null<ColumnSort> = colIx >= 0 && colIx < colGroups.length ? colGroups[colIx].column.sort : null;
        if (sort == null) {
            return;
        }

        final sort:ColumnSort = switch (sort : ColumnSort) {
            case Ascending: Default;
            case Descending: Ascending;
            case Default: Descending;
        }

        for (ix => colGroup in colGroups) {
            if (ix == colIx) {
                colGroup.column.sort = sort;
            } else {
                if (colGroup.column.sort != null) {
                    colGroup.column.sort = Default;
                }
            }
        }

        delegateValue.performSort(colIx, sort, window, cast cx);

        cx.notify();
    }

    function moveColumn(colIx:Int, toIx:Int, window:Window, cx:Context<Dynamic>):Void {
        if (colIx == toIx) {
            return;
        }

        delegateValue.moveColumn(colIx, toIx, window, cast cx);
        final colGroup = colGroups.splice(colIx, 1)[0];
        colGroups.insert(toIx, colGroup);

        cx.emit(TableEvent.MoveColumn(colIx, toIx));
        cx.notify();
    }

    /**
     * Resolve the insertion gap for a column-header drag at the window
     * coordinate `x`, or `null` when dropping there would not move the
     * dragged column at `dragColIx`.
     */
    function dragGapAt(x:Pixels, dragColIx:Int):Null<Int> {
        final fixedCount = fixedLeftColsCount();

        // A column can only be reordered within its own region: rendering
        // pins the first `fixedCount` columns, so a cross-region move would
        // change which columns are pinned without updating their `fixed`
        // flags.
        final dragInFixed = dragColIx < fixedCount;
        final pointerInFixed = fixedCount > 0 && x < fixedHeadColsBounds.right();
        if (dragInFixed != pointerInFixed) {
            return null;
        }

        // Columns scrolled beneath the fixed region keep stale bounds, so
        // resolve `x` against the fixed columns alone when it falls in that
        // region, and against the visible scrollable columns otherwise.
        final candidates = pointerInFixed ? new Range(0, fixedCount) : calculateVisibleLeafColRange(fixedCount).range;

        // The gap sits after the last candidate column whose center is left of `x`.
        var gap = candidates.start;
        for (ix in candidates.start...candidates.end) {
            if (x < colGroups[ix].bounds.center().x) {
                break;
            }
            gap = ix + 1;
        }

        // No gap if dropping there would put the dragged column back to
        // where it already is.
        return gap == dragColIx || gap == dragColIx + 1 ? null : gap;
    }

    /** Dispatch delegate's `loadMore` method when the visible range is near the end. */
    function loadMoreIfNeed(rowsCount:Int, visibleEnd:Int, window:Window, cx:Context<Dynamic>):Void {
        final threshold = delegateValue.loadMoreThreshold();
        // Securely handle subtract logic to prevent attempt to subtract with overflow
        if (visibleEnd >= sat(rowsCount - threshold)) {
            if (!delegateValue.hasMore(cx.app)) {
                return;
            }

            final ctx:Context<TableState<D>> = cast cx;
            loadMoreTask = ctx.spawn((view, acx) -> {
                #if cs
                // Names D in this closure's own body: Haxe's C# output makes a closure generic
                // only then, and its nested closure below needs D (the output does not compile otherwise)
                final _csTypeParam:Null<D> = null;
                #end
                if (!window.isDestroyed()) {
                    view.tryUpdate(acx, (view, cx) -> {
                        view.delegateValue.loadMore(window, cast cx);
                    });
                }
                return Task.ready(Unit.unit);
            });
        }
    }

    function updateVisibleRangeIfNeed(visibleRange:Range, itemsCount:Int, axis:Axis, window:Window, cx:Context<Dynamic>):Void {
        // Skip when visible range is only 1 item, unless there is at most 1 item.
        // The visual_list will use first item to measure.
        if (sat(visibleRange.end - visibleRange.start) <= 1 && itemsCount > 1) {
            return;
        }

        // Stripe filler rows are rendered past the last row; never report them.
        final end = visibleRange.end < itemsCount ? visibleRange.end : itemsCount;
        final visibleRange = new Range(visibleRange.start < end ? visibleRange.start : end, end);
        // A range wholly past the last item is stale; the list scrolls back next frame.
        if (visibleRange.isEmpty() && itemsCount > 0) {
            return;
        }

        if (axis == Vertical) {
            if (visibleRangeValue.rowsValue.equals(visibleRange)) {
                return;
            }
            delegateValue.visibleRowsChanged(visibleRange, window, cast cx);
            visibleRangeValue.rowsValue = visibleRange;
        } else {
            if (visibleRangeValue.colsValue.equals(visibleRange)) {
                return;
            }
            delegateValue.visibleColumnsChanged(visibleRange, window, cast cx);
            visibleRangeValue.colsValue = visibleRange;
        }
    }

    function renderCell(_rowIx:Null<Int>, colIx:Int, _1:Window, _2:Context<Dynamic>):Div {
        if (colIx < 0 || colIx >= colGroups.length) {
            return div();
        }
        final colGroup = colGroups[colIx];

        final colWidth = colGroup.width;
        final colPadding = colGroup.column.paddings;

        final cell = div()
            .w(px(colWidth))
            .hFull()
            .flexShrink0()
            .overflowHidden()
            .whitespaceNowrap()
            .tableCellSize(options.size);
        // Text alignment is inherited, so this aligns the header name and
        // the delegate's cell text without changing how cells lay out.
        switch colGroup.column.align {
            case Center: cell.textCenter();
            case Right: cell.textRight();
            case _:
        }
        if (colPadding != null) {
            cell.pl(px(colPadding.left))
                .pr(px(colPadding.right))
                .pt(px(colPadding.top))
                .pb(px(colPadding.bottom));
        }
        return cell;
    }

    /**
     * Expose a body cell to assistive technology: its role, its column and
     * the delegate's `cellLabel`.
     *
     * In cell selection mode the cell is a `GridCell` that reports whether it
     * is selected; otherwise it is a plain `Cell`. The port has no
     * accessibility tree (Rust `role`, `aria_selected`, `aria_column_index`,
     * `aria_label`), and the labels are only built when assistive technology
     * is connected, so this returns the cell unchanged.
     */
    function a11yCell(cell:Div, rowIx:Int, colIx:Int, window:Window, cx:App):Div {
        return cell;
    }

    /**
     * Show Column selection style, when the column is selected and the selection state is Column.
     * Note: When a cell is selected, column selection style is not shown.
     */
    function renderColWrap(_rowIx:Null<Int>, colIx:Int, _:Window, cx:Context<Dynamic>):Div {
        final el = hFlex().hFull();
        final selectable = colSelectableValue && (colIx >= 0 && colIx < colGroups.length ? colGroups[colIx].column.selectable : false);

        // `selectedCol()` is null outside column mode, so a selected cell
        // never leaves its column highlighted.
        if (selectable && selectedCol() == colIx) {
            return el.bg(Theme.global(cx).tokens.tableActive.background);
        } else {
            return el;
        }
    }

    /**
     * The other half of that band, for the boundary on the *left* of column
     * `ix`, the one owned by column `ix - 1`.
     *
     * It is positioned absolutely so that reaching back over the boundary
     * costs the header row no width, and it paints after this column's own
     * cell so that it, and not a column reorder, receives the drag.
     */
    function renderLeadingResizeHandle(ix:Int, _:Window, cx:Context<Dynamic>):IntoElement {
        final prev = ix - 1;
        if (ix < 1 || !isColResizable(prev)) {
            return div();
        }

        return resizeHandleBand(prev, NamedInteger("resizable-handle-leading", ix), cx)
            .absolute()
            .top0()
            .left0()
            .hFull()
            .w(px(HANDLE_PADDING));
    }

    /**
     * The half of column `ix`'s resize handle that lies inside column `ix`,
     * along with the hairline that marks the boundary.
     *
     * It is `HANDLE_PADDING` wide, like the half on the far side, so the
     * grab area is symmetric about the boundary. The negative margin keeps
     * the band's net contribution to the header row zero, and `justifyEnd`
     * pins the hairline to the column edge.
     */
    function renderResizeHandle(ix:Int, _:Window, cx:Context<Dynamic>):IntoElement {
        if (!isColResizable(ix)) {
            return div();
        }

        final groupId = 'resizable-handle:' + ix;
        final theme = Theme.global(cx);

        return resizeHandleBand(ix, NamedInteger("resizable-handle", ix), cx)
            .group(groupId)
            .hFull()
            .w(px(HANDLE_PADDING))
            .ml(px(-HANDLE_PADDING))
            .justifyEnd()
            .itemsCenter()
            .child(div()
                .hFull()
                .justifyCenter()
                .bg(theme.tableRowBorder)
                .groupHover(groupId, s -> s.bg(theme.border).hFull())
                .w(px(1.)));
    }

    function isColResizable(ix:Int):Bool {
        return colResizableValue && (ix >= 0 && ix < colGroups.length ? colGroups[ix].isResizable() : false);
    }

    /**
     * The interactive band that drags the boundary on the right of column
     * `ix`, carrying no styling that places or paints it.
     *
     * Paint order decides which element is offered a drag first: later
     * siblings win, and a header cell starts a column reorder. So a single
     * band straddling the boundary would lose its outer half to the next
     * column's cell. Each boundary is covered by two bands instead, one in
     * the `th` on either side, each rendered after that `th`'s own cell and
     * so above everything it overlaps.
     */
    function resizeHandleBand(ix:Int, id:ElementIdArg, cx:Context<Dynamic>):Div {
        final cx:Context<TableState<D>> = cast cx;
        final entityId = cx.entityId();
        return hFlex()
            .id(id)
            .occlude()
            .cursorColResize()
            .onDragMove(ResizeColumn, cx.listener((view:TableState<D>, e:DragMoveEvent<ResizeColumn>, window:Window, cx:Context<TableState<D>>) -> {
                final drag = e.drag(cx.app);
                if (cx.entityId() != drag.entityId) {
                    return;
                }

                // sync col widths into real widths
                // TODO: Consider to remove this, this may not need now.

                final ix = drag.ix;
                if (view.fittedCol == ix) {
                    return;
                }
                view.resizingCol = ix;

                if (ix < 0 || ix >= view.colGroups.length) throw 'BUG: invalid col index';
                final colGroup = view.colGroups[ix].clone();

                view.resizeCols(ix, f32(f32(e.event.position.x - (HANDLE_SIZE : Float)) - colGroup.bounds.left()), window, cx);

                // scroll the table if the drag is near the edge
                view.scrollTableByColResizing(e.event.position, colGroup);
            }))
            .onDrag(new ResizeColumn(entityId, ix), (drag, _, _, cx) -> {
                cx.stopPropagation();
                return cx.newEntity((_:Context<ResizeColumnView>) -> new ResizeColumnView());
            })
            .onMouseDown(MouseButton.Left, cx.listener((view:TableState<D>, e:MouseDownEvent, window:Window, cx:Context<TableState<D>>) -> {
                switch e.clickCount {
                    case 1: view.fittedCol = null;
                    case 2: if (view.fitCol(ix, window, cx)) view.fittedCol = ix;
                    case _:
                }
            }))
            .onMouseUpOut(MouseButton.Left, cx.listener((view:TableState<D>, _, _, cx:Context<TableState<D>>) -> {
                if (view.resizingCol == null) {
                    return;
                }

                view.resizingCol = null;

                final newWidths = [for (g in view.colGroups) g.width];
                cx.emit(TableEvent.ColumnWidthsChanged(newWidths));
                cx.notify();
            }));
    }

    /**
     * The border on the right edge of the fixed columns, unless turned off
     * with `DataTable.fixedColsBorder`.
     */
    function renderFixedColsBorder(cx:App):Null<Div> {
        if (!options.fixedColsBorder) return null;
        return div()
            .absolute()
            .top0()
            .right0()
            .bottom0()
            .w0()
            .flexShrink0()
            .borderR1()
            .borderColor(Theme.global(cx).border);
    }

    /** Render the row header cell (when cellSelectable is enabled) */
    function renderRowHeaderCell(rowIx:Int, isHead:Bool, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TableState<D>> = cast cx;
        final theme = Theme.global(cx);
        final cell = div()
            .id(NamedInteger("row-header", rowIx))
            .w3()
            .hFull()
            .borderR1()
            .borderColor(theme.tableRowBorder)
            .bg(theme.tokens.tableHead.background)
            .flexShrink0()
            .tableCellSize(options.size);
        if (!isHead) {
            if (rowSelectableValue) {
                cell.onClick(cx.listener((table:TableState<D>, e:ClickEvent, _, cx:Context<TableState<D>>) -> {
                    cx.stopPropagation();
                    if (table.selectsRowOnClick(e, cx.app)) {
                        table.setSelectedRow(rowIx, cx);
                    }
                }));
            }
        }
        return cell;
    }

    function renderSortIcon(colIx:Int, colGroup:ColGroup, _:Window, cx:Context<Dynamic>):Null<IntoElement> {
        final cx:Context<TableState<D>> = cast cx;
        if (!sortableValue) {
            return null;
        }

        final sort = colGroup.column.sort;
        if (sort == null) {
            return null;
        }

        final theme = Theme.global(cx);
        final icon:IconName = switch (sort : ColumnSort) {
            case Ascending: IconName.SortAscending;
            case Descending: IconName.SortDescending;
            case Default: IconName.ChevronsUpDown;
        }
        final isOn = sort != Default;

        // Rust `.role(Role::Button)`, `.aria_label(t!("Table.SortBy", column = name))`:
        // no accessibility tree in the port.
        final button = div()
            .id(NamedInteger("icon-sort", colIx))
            .testSupport()
            .p(px(2.))
            .rounded(px(theme.radius / 2.));
        if (!isOn) button.opacity(0.5);
        return button
            .hover(s -> s.bg(theme.tokens.secondary.background).opacity(7.))
            .active(s -> s.bg(theme.tokens.secondaryActive.background).opacity(1.))
            .onClick(cx.listener((table:TableState<D>, _, window, cx) -> table.performSort(colIx, window, cx)))
            .child(new Icon(icon)
                .size3()
                .textColor(theme.secondaryForeground));
    }

    /** Rust `t!("Table.SortBy", column = name)`, the accessible name of the sort button. */
    public static function sortByLabel(name:String):String {
        return I18n.t('Table.SortBy', {column: name});
    }

    /**
     * Render the column header.
     * The children must be one by one items.
     * Because the horizontal scroll handle will use the child_item_bounds to
     * calculate the item position for itself's `scrollToItem` method.
     */
    function renderTh(colIx:Int, window:Window, cx:Context<Dynamic>):Div {
        final cx:Context<TableState<D>> = cast cx;
        final entityId = cx.entityId();
        if (colIx < 0 || colIx >= colGroups.length) throw 'BUG: invalid col index';
        final colGroup = colGroups[colIx];

        final movable = colMovableValue && colGroup.column.movable;
        final paddings = colGroup.column.paddings;
        final name = colGroup.column.name;
        final theme = Theme.global(cx);

        final inner = hFlex()
            .sizeFull()
            .justifyBetween()
            .itemsCenter()
            .child(delegateValue.renderTh(colIx, window, cast cx));
        if (paddings != null) {
            // Leave right space for the sort icon, if this column have custom padding
            final offsetPr:Float = f32(options.size.tableCellPadding().right - paddings.right);
            inner.pr(px(offsetPr > 0. ? offsetPr : 0.));
        }
        final sortIcon = renderSortIcon(colIx, colGroup, window, cx);
        if (sortIcon != null) inner.child(sortIcon);

        // Rust `.role(Role::ColumnHeader)`, `.aria_label(name)`,
        // `.aria_column_index(col_ix)`: no accessibility tree in the port.
        final cell = renderCell(null, colIx, window, cx)
            .id(NamedInteger("col-header", colIx))
            .testSupport()
            .onClick(cx.listener((this_:TableState<D>, _, window, cx) -> {
                this_.onColHeadClick(colIx, window, cx);
            }))
            .child(inner);
        if (movable) {
            cell.onDrag(new DragColumn(entityId, name, colGroup.width, colIx), (drag, _, _, cx) -> {
                cx.stopPropagation();
                return cx.newEntity((_:Context<DragColumnView>) -> new DragColumnView(drag));
            });
        }
        // Draw the insertion indicator on the left edge of the gap
        // column, or on the right edge of the last column for the
        // trailing gap. Use an absolutely positioned overlay instead
        // of a border, to avoid shifting the cell content.
        final lastGap = colIx + 1 == colGroups.length;
        final gap = colDragGap;
        if (gap != null && cx.app.hasActiveDrag() && (gap == colIx || (lastGap && gap == colIx + 1))) {
            final rightSide = gap == colIx + 1;
            final indicator = div()
                .absolute()
                .top0()
                .bottom0()
                .w(px(2.));
            if (rightSide) indicator.right0() else indicator.left0();
            cell.relative().child(indicator.bg(theme.dragBorder));
        }

        final view = cx.entity();
        return hFlex()
            .hFull()
            .child(cell)
            // resize handle cell right side
            .child(renderResizeHandle(colIx, window, cx))
            // resize handle cell left side
            .child(renderLeadingResizeHandle(colIx, window, cx))
            // to save the bounds of this col.
            .onPrepaint((bounds, _, cx) -> view.update(cx, (r, _) -> r.colGroups[colIx].bounds = bounds));
    }

    /**
     * Compute the visible non-fixed leaf-column range for header rendering.
     *
     * Returns `(range, leftSpacer)` where `range` is the column-index range
     * that should be rendered and `leftSpacer` the total width of the
     * off-screen left columns, used as a spacer div to keep visible columns
     * at the correct position.
     *
     * On the first frame `bounds` is zero, so a fallback that covers all
     * columns is returned to avoid a blank header on initial paint.
     */
    function calculateVisibleLeafColRange(leftColumnsCount:Int):{range:Range, leftSpacer:Pixels} {
        final totalCols = colGroups.length;

        if (bounds.size.width == 0.) {
            return {range: new Range(leftColumnsCount, totalCols), leftSpacer: 0.};
        }

        final fixedWidth:Float = fixedHeadColsBounds.size.width;
        var availableWidth:Float = f32(bounds.size.width - fixedWidth);
        if (availableWidth < 0.) availableWidth = 0.;
        // The scroll handle offset is negative when scrolled right; negate it
        // to obtain a positive distance from the left edge of the scroll area.
        var scrollX:Float = -horizontalScrollHandle.offset().x;
        if (scrollX < 0.) scrollX = 0.;

        // Walk left-to-right through non-fixed columns to find the first one
        // whose right edge enters the viewport. The accumulated width of the
        // skipped columns becomes the left spacer width.
        var rangeStart = leftColumnsCount;
        var leftSpacer:Float = 0.;
        var cumulative:Float = 0.;
        for (i in leftColumnsCount...totalCols) {
            final rightEdge:Float = f32(cumulative + colGroups[i].width);
            if (rightEdge > scrollX) {
                rangeStart = i;
                leftSpacer = cumulative;
                break;
            }
            cumulative = rightEdge;
        }

        // Continue from `rangeStart` (skipping already-scanned columns) to
        // find the last column still within the viewport. The 200 px overdraw
        // buffer prevents a visible flash when the user scrolls quickly.
        final rightBound:Float = f32(f32(scrollX + availableWidth) + 200.);
        var rangeEnd = totalCols;
        var cumulative:Float = leftSpacer; // already summed widths before `rangeStart`
        for (i in rangeStart...totalCols) {
            cumulative = f32(cumulative + colGroups[i].width);
            if (cumulative > rightBound) {
                rangeEnd = i + 1 < totalCols ? i + 1 : totalCols;
                break;
            }
        }

        return {range: new Range(rangeStart, rangeEnd), leftSpacer: leftSpacer};
    }

    function renderHeaderCells(rowCells:Array<HeaderCell>, fixedRegion:Bool, leftColumnsCount:Int, window:Window, cx:Context<Dynamic>):Array<IntoElement> {
        final cells:Array<IntoElement> = [];
        for (cell in rowCells) {
            final inRegion = fixedRegion ? cell.startLeafColIx < leftColumnsCount : cell.startLeafColIx >= leftColumnsCount;
            if (!inRegion) continue;
            if (cell.isLeaf) {
                if (cell.leafColIx != null) {
                    cells.push(renderTh(cell.leafColIx, window, cx));
                }
            } else {
                cells.push(delegateValue.renderGroupTh(cell.label, cell.colSpan, cell.width, window, cast cx));
            }
        }
        return cells;
    }

    function renderTableHeader(leftColumnsCount:Int, window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TableState<D>> = cast cx;
        final view:Entity<TableState<D>> = cast cx.entity();
        final horizontalScrollHandle = this.horizontalScrollHandle;
        final theme = Theme.global(cx);

        // Header leaf-column virtualization.
        //
        // `renderTh` creates interactive elements with resize-handle listeners.
        // Calling it for every column every frame is O(n) in column count; with
        // 1000+ columns this alone drops FPS below 60 even in release mode.
        //
        // We restrict rendering to the columns currently visible inside the
        // overflow-scroll viewport, surrounding them with inert spacer divs:
        //
        //   [left_spacer] [visible columns...] [right_spacer] [last_empty_col]
        //
        // The spacers preserve the flex container's total content width so that
        // the scrollbar range stays correct.
        final totalCols = colGroups.length;
        final visible = calculateVisibleLeafColRange(leftColumnsCount);
        final visibleColRange = visible.range;
        final leftSpacer:Float = visible.leftSpacer;

        final layoutLen = headerLayout.length;
        final headerRowHeight = this.headerRowHeight();

        // Reset fixed head columns bounds, if no fixed columns are present
        if (leftColumnsCount == 0) {
            fixedHeadColsBounds = new Bounds();
        }

        final header = delegateValue.renderHeader(window, cast cx);
        final style = header.style().clone();
        final layout = headerLayout.copy();

        // Rust `.role(Role::Row)`, `.aria_row_index(0)`: one header row holds
        // every column header, including the pinned ones, which are laid out
        // in a separate container. No accessibility tree in the port.
        header
            .hFlex()
            .wFull()
            .flexShrink0()
            .bg(theme.tokens.tableHead.background)
            .textColor(theme.tableHeadForeground)
            .refineStyle(style)
            .onDragMove(DragColumn, cx.listener((table:TableState<D>, e:DragMoveEvent<DragColumn>, _, cx:Context<TableState<D>>) -> {
                final drag = e.drag(cx.app);
                final dragEntityId = drag.entityId;
                final dragColIx = drag.colIx;

                final gap = dragEntityId == cx.entityId() && e.bounds.contains(e.event.position)
                    ? table.dragGapAt(e.event.position.x, dragColIx)
                    : null;

                if (table.colDragGap != gap) {
                    table.colDragGap = gap;
                    cx.notify();
                }
            }))
            .onDrop(DragColumn, cx.listener((table:TableState<D>, drag:DragColumn, window, cx:Context<TableState<D>>) -> {
                if (drag.entityId != cx.entityId()) {
                    return;
                }

                // Insert the dragged column into the indicated gap.
                final gap = table.colDragGap;
                table.colDragGap = null;
                if (gap == null) {
                    return;
                }
                final toIx = drag.colIx < gap ? gap - 1 : gap;
                table.moveColumn(drag.colIx, toIx, window, cx);
            }));
        if (cellSelectableValue && rowHeaderValue) {
            header.child(renderRowHeaderCell(0, true, cx));
        }
        if (leftColumnsCount > 0) {
            // Render left fixed columns
            final fixed = hFlex()
                .relative()
                .hFull()
                .bg(theme.tokens.tableHead.background)
                .child(vFlex().minWFull().flexShrink0().children([for (rowCells in layout) (hFlex()
                    .minWFull()
                    .h(px(headerRowHeight))
                    .borderB1()
                    .borderColor(theme.border)
                    .children(renderHeaderCells(rowCells, true, leftColumnsCount, window, cx)) : IntoElement)]));
            final border = renderFixedColsBorder(cx.app);
            if (border != null) fixed.child(border);
            header.child(fixed.onPrepaint((bounds, _, cx) -> view.update(cx, (r, _) -> r.fixedHeadColsBounds = bounds)));
        }

        final rows:Array<IntoElement> = [];
        for (rowIx => rowCells in layout) {
            final isLeafRow = rowIx + 1 == layoutLen;
            final row = hFlex()
                .minWFull()
                .h(px(headerRowHeight))
                .borderB1()
                .borderColor(theme.border);
            if (isLeafRow) {
                // Leaf row: apply the spacer virtualization pattern.
                // Only columns in `visibleColRange` are rendered; the two
                // spacer divs preserve the container's total content width
                // so the scrollbar range stays correct.
                if (leftSpacer > 0.) {
                    row.child(div().w(px(leftSpacer)).hFull().flexShrink0());
                }
                for (cell in rowCells) {
                    if (cell.isLeaf) {
                        final ix = cell.leafColIx;
                        if (ix == null) continue;
                        if (!visibleColRange.contains(ix)) continue;
                        row.child(renderTh(ix, window, cx));
                    }
                }
                if (visibleColRange.end < totalCols) {
                    var rightSpacer:Float = 0.;
                    for (i in visibleColRange.end...totalCols) rightSpacer = f32(rightSpacer + colGroups[i].width);
                    row.child(div().w(px(rightSpacer)).hFull().flexShrink0());
                }
                row.child(delegateValue.renderLastEmptyCol(window, cast cx));
            } else {
                // Group header rows have far fewer cells (one per group),
                // so the cost of rendering all of them is negligible.
                row.children(renderHeaderCells(rowCells, false, leftColumnsCount, window, cx))
                    .child(delegateValue.renderLastEmptyCol(window, cast cx));
            }
            rows.push(row);
        }

        return header.child(
            // Columns
            hFlex()
                .id("table-head")
                .sizeFull()
                .overflowScroll()
                .relative()
                .trackScroll(horizontalScrollHandle.baseHandle())
                .bg(theme.tokens.tableHead.background)
                .child(vFlex().minWFull().flexShrink0().children(rows)));
    }

    function renderBodyCell(table:TableState<D>, rowIx:Int, colIx:Int, cellId:String, window:Window, cx:Context<Dynamic>):Div {
        final theme = Theme.global(cx);
        final isCellSelected = CellPosition.same(table.selectedCell(), rowIx, colIx);
        final isCellRightClicked = CellPosition.same(table.rightClickedCellValue, rowIx, colIx);

        final cell = table.a11yCell(table.renderCell(rowIx, colIx, window, cx)
            .id(cellId)
            .testSupport(), rowIx, colIx, window, cx.app)
            .relative()
            .child(table.measureRenderTd(rowIx, colIx, window, cx));
        if (isCellSelected) {
            cell.child(div()
                .absolute()
                .inset0()
                .bg(theme.tokens.tableActive.background));
        }
        if (isCellRightClicked && !isCellSelected) {
            cell.child(div()
                .absolute()
                .inset0()
                .border1()
                .borderColor(theme.tableActiveBorder.opacity(0.5)));
        }
        return cell;
    }

    function renderTableRow(rowIx:Int, rowsCount:Int, leftColumnsCount:Int, colSizes:Array<Size>, columnsCount:Int, isFilled:Bool, window:Window, cx:Context<Dynamic>):AnyElement {
        final cx:Context<TableState<D>> = cast cx;
        final theme = Theme.global(cx);
        final isStripeRow = options.stripe && rowIx % 2 != 0;
        // `selectedRow()` is null outside row mode, so a selected cell or
        // column never highlights its row.
        final isSelected = selectedRow() == rowIx;
        final view:Entity<TableState<D>> = cast cx.entity();
        final rowHeight:Float = options.size.tableRowHeight();

        if (rowIx < rowsCount) {
            final isLastRow = rowIx + 1 == rowsCount;
            final needRenderBorder = isSelected || !isLastRow || !isFilled;

            final tr = delegateValue.renderTr(rowIx, window, cast cx);
            final style = tr.style().clone();

            // Rust `.role(Role::Row)`, `.aria_row_index(row_ix + 1)` (row 0
            // is the header row), `.aria_selected(is_selected)`: no
            // accessibility tree in the port.
            tr.testSupport()
                .hFlex()
                .wFull()
                .h(px(rowHeight));
            if (needRenderBorder) {
                tr.borderB1().borderColor(theme.tableRowBorder);
            }
            if (isStripeRow) tr.bg(theme.tokens.tableEven.background);
            tr.refineStyle(style);
            final rightClicked = isSelected || rightClickedRowValue == rowIx;
            tr.hover(s -> rightClicked ? s : s.bg(theme.tokens.tableHover.background));
            if (cellSelectableValue && rowHeaderValue) {
                tr.child(renderRowHeaderCell(rowIx, false, cx));
            }
            if (leftColumnsCount > 0) {
                // Left fixed columns
                final items:Array<IntoElement> = [];
                for (colIx in 0...leftColumnsCount) {
                    final cell = renderBodyCell(this, rowIx, colIx, 'table-cell:' + rowIx + ':' + colIx, window, cx);
                    if (cellSelectableValue) {
                        cell.onClick(cx.listener((table:TableState<D>, e:ClickEvent, window, cx) -> {
                            table.onCellClick(e, rowIx, colIx, window, cx);
                        }))
                            .onMouseDown(MouseButton.Right, cx.listener((table:TableState<D>, e:MouseDownEvent, window, cx) -> {
                                table.onCellRightClick(e, rowIx, colIx, window, cx);
                            }));
                    }
                    items.push(renderColWrap(rowIx, colIx, window, cx).child(cell));
                }

                final fixed = hFlex()
                    .relative()
                    .hFull()
                    .children(items);
                final border = renderFixedColsBorder(cx.app);
                if (border != null) fixed.child(border);
                tr.child(fixed);
            }
            tr.child(hFlex()
                .flex1()
                .hFull()
                .overflowHidden()
                .relative()
                .child(VirtualList.virtualList(view, rowIx, Horizontal, colSizes, (table:TableState<D>, start:Int, end:Int, window:Window, cx:Context<TableState<D>>) -> {
                    table.updateVisibleRangeIfNeed(new Range(start, end), sat(columnsCount - leftColumnsCount), Horizontal, window, cx);

                    final items:Array<IntoElement> = [];

                    for (visibleIx in start...end) {
                        final colIx = visibleIx + leftColumnsCount;
                        final cell = table.renderBodyCell(table, rowIx, colIx, 'table-cell-' + rowIx + ':' + colIx, window, cx);
                        if (table.cellSelectableValue) {
                            cell.onClick(cx.listener((table:TableState<D>, e:ClickEvent, window, cx) -> {
                                cx.stopPropagation();
                                table.onCellClick(e, rowIx, colIx, window, cx);
                            }))
                                .onMouseDown(MouseButton.Right, cx.listener((table:TableState<D>, e:MouseDownEvent, window, cx) -> {
                                    table.onCellRightClick(e, rowIx, colIx, window, cx);
                                }));
                        }
                        items.push(table.renderColWrap(rowIx, colIx, window, cx).child(cell));
                    }

                    return items;
                })
                    .withScrollHandle(horizontalScrollHandle))
                .child(delegateValue.renderLastEmptyCol(window, cast cx)));
            // Row selected style
            if (isSelected) {
                final bg = theme.listSettings.activeHighlight ? theme.tokens.tableActive.background : theme.tokens.accent.background;
                tr.bg(bg);
            }
            // Row right click row style
            if (rightClickedRowValue == rowIx) {
                tr.borderColor(transparentWhite()).child(div()
                    .top(px(rowIx == 0 ? 0. : -1.))
                    .left(px(0.))
                    .right(px(0.))
                    .bottom(px(-1.))
                    .absolute()
                    .border1()
                    .borderColor(theme.selection));
            }
            return tr
                .onMouseDown(MouseButton.Right, cx.listener((this_:TableState<D>, e:MouseDownEvent, window, cx) -> {
                    this_.onRowRightClick(e, rowIx, window, cx);
                }))
                .onClick(cx.listener((this_:TableState<D>, e:ClickEvent, window, cx) -> {
                    this_.onRowLeftClick(e, rowIx, window, cx);
                }))
                .intoAnyElement();
        } else {
            var colsWidth:Float = 0.;
            for (i in 0...(columnsCount < colGroups.length ? columnsCount : colGroups.length)) colsWidth = f32(colsWidth + colGroups[i].width);

            // Render fake rows to fill the rest table space
            final tr = delegateValue.renderTr(rowIx, window, cast cx)
                .hFlex()
                .wFull()
                .h(px(rowHeight))
                .borderB1()
                .borderColor(theme.tableRowBorder);
            if (isStripeRow) tr.bg(theme.tokens.tableEven.background);
            if (cellSelectableValue && rowHeaderValue) {
                // Render empty row header cell for fake rows
                tr.child(div()
                    .w(px(40.))
                    .hFull()
                    .flexShrink0()
                    .tableCellSize(options.size));
            }
            // The fake cells paint nothing, so a single spacer as wide as all
            // the columns keeps the last empty column in place without laying
            // out one element per column.
            return tr
                .child(div().flexShrink0().hFull().w(px(colsWidth)))
                .child(delegateValue.renderLastEmptyCol(window, cast cx))
                .intoAnyElement();
        }
    }

    /** Calculate the extra rows needed to fill the table empty space when `stripe` is true. */
    function calculateExtraRowsNeeded(totalHeight:Float, actualHeight:Float, rowHeight:Float):Int {
        var extraRowsNeeded = 0;

        final remainingHeight:Float = f32(totalHeight - actualHeight);
        if (remainingHeight > 0.) {
            extraRowsNeeded = Std.int(Math.ffloor(f32(remainingHeight / rowHeight)));
        }

        return extraRowsNeeded;
    }

    function measureRenderTd(rowIx:Int, colIx:Int, window:Window, cx:Context<Dynamic>):IntoElement {
        if (!Measure.measurementEnabled()) {
            return delegateValue.renderTd(rowIx, colIx, window, cast cx);
        }

        final start = haxe.Timer.stamp();
        final el = delegateValue.renderTd(rowIx, colIx, window, cast cx);
        measures.push(haxe.Timer.stamp() - start);
        return el;
    }

    function measure(_1:Window, _2:Context<Dynamic>):Void {
        if (!Measure.measurementEnabled()) {
            return;
        }

        // Print avg measure time of each td
        if (measures.length > 0) {
            var total = 0.;
            for (d in measures) total += d;
            final avg = total / measures.length;
            ceramic.Shortcuts.log.debug('last render ${measures.length} cells total: ${total * 1000}ms, avg: ${avg * 1000}ms');
        }
        measures.resize(0);
    }

    function renderVerticalScrollbar(_1:Window, _2:Context<Dynamic>):Null<IntoElement> {
        return div()
            .absolute()
            .top(px(headerBandHeight()))
            .right0()
            .bottom0()
            .w(px(Scrollbar.width()))
            .child(Scrollbar.vertical(verticalScrollHandle)
                .viewportFromLayout()
                .maxFps(60));
    }

    function renderHorizontalScrollbar(_1:Window, _2:Context<Dynamic>):IntoElement {
        return div()
            .absolute()
            .left(px(fixedHeadColsBounds.size.width))
            .right0()
            .bottom0()
            .h(px(Scrollbar.width()))
            .child(Scrollbar.horizontal(horizontalScrollHandle).viewportFromLayout());
    }

    /** Rust `Focusable::focus_handle`. */
    public inline function focusHandle(?_:App):FocusHandle {
        return focusHandleValue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TableState<D>> = cast cx;
        measure(window, cx);
        final theme = Theme.global(cx);

        final columnsCount = delegateValue.columnsCount(cx.app);
        var leftColumnsCount = 0;
        for (col in colGroups) if (colFixed && col.column.fixed == ColumnFixed.Left) leftColumnsCount++;
        final rowsCount = delegateValue.rowsCount(cx.app);
        final loading = delegateValue.loading(cx.app);

        final rowHeight:Float = options.size.tableRowHeight();
        final totalHeight:Float = verticalScrollHandle.state.baseHandle.bounds().size.height;
        final actualHeight:Float = f32(rowHeight * rowsCount);
        final extraRowsCount = calculateExtraRowsNeeded(totalHeight, actualHeight, rowHeight);
        final renderRowsCount = options.stripe ? rowsCount + extraRowsCount : rowsCount;
        final hasRightClick = rightClickedRowValue != null || rightClickedCellValue != null;
        final isFilled = totalHeight > 0. && totalHeight <= actualHeight;

        final loadingView:Null<IntoElement> = loading ? delegateValue.renderLoading(options.size, window, cast cx) : null;

        var emptyView:Null<IntoElement> = null;
        if (rowsCount == 0) {
            // The rows list is not rendered, so report the empty range here.
            updateVisibleRangeIfNeed(new Range(0, 0), 0, Vertical, window, cx);
            emptyView = div()
                .sizeFull()
                .child(delegateValue.renderEmpty(window, cast cx));
        }

        final view:Entity<TableState<D>> = cast cx.entity();
        // Rust `.role(Grid or Table)` (a table that selects rows or cells is
        // a grid), `.aria_row_count(rows_count + 1)`, `.aria_column_count(columns_count)`:
        // no accessibility tree in the port.
        final inner = vFlex()
            .id("table-inner")
            .testSupport()
            .sizeFull()
            .overflowHidden()
            .child(renderTableHeader(leftColumnsCount, window, cx));
        final innerTable = inner.contextMenu((this_, window:Window, cx:Context<PopupMenu>) -> {
            final rowIx = view.read(cx).rightClickedRowValue;
            if (rowIx != null) {
                return view.update(cx, (menu, cx) -> menu.delegateValue.contextMenu(rowIx, this_, window, cast cx));
            } else {
                return this_;
            }
        });
        if (rowsCount == 0) {
            innerTable.child(emptyView);
        } else {
            final process = cx.processor((table:TableState<D>, range:Range, window:Window, cx:Context<TableState<D>>) -> {
                // Use `col.width` (always up-to-date) rather than
                // `col.bounds.size.width`, which is only set after
                // prepaint and is therefore zero on the first frame.
                final colSizes:Array<Size> = [for (i in leftColumnsCount...table.colGroups.length) new Size(table.colGroups[i].width, 0.)];

                table.loadMoreIfNeed(rowsCount, range.end, window, cx);
                table.updateVisibleRangeIfNeed(range, rowsCount, Vertical, window, cx);

                if (range.end > rowsCount) {
                    final last = sat(rowsCount - 1);
                    table.scrollToRow(range.start < last ? range.start : last, cx);
                }

                final items:Array<IntoElement> = [];

                // Render fake rows to fill the table
                for (rowIx in range.start...range.end) {
                    // Render real rows for available data
                    items.push(table.renderTableRow(rowIx, rowsCount, leftColumnsCount, colSizes, columnsCount, isFilled, window, cx));
                }

                return items;
            });
            final rows = uniformList("table-uniform-list", renderRowsCount, (start, end, window, app) -> process(new Range(start, end), window, app))
                .flexGrow1()
                .sizeFull()
                .withSizingBehavior(ListSizingBehavior.Auto)
                .trackScroll(verticalScrollHandle);
            final bounce = new ScrollBounce("table-scroll-bounce", verticalScrollHandle, rows);
            if (options.scrollBounce != null) bounce.enabled(options.scrollBounce);
            innerTable.child(hFlex().id("table-body").flexGrow1().sizeFull().child(bounce));
        }

        final root = div().sizeFull();
        if (loadingView != null) root.child(loadingView);
        if (!loading) {
            root.child(innerTable)
                .child(new ScrollableMask(Horizontal, horizontalScrollHandle));
            // Keep vertical wheel scrolling from leaking into an
            // ancestor scroller. Skipped when the table is empty:
            // the `uniformList` is not rendered then, so the
            // handle's offset and `maxOffset` are stale.
            if (rowsCount > 0) {
                root.child(new ScrollableMask(Vertical, verticalScrollHandle.state.baseHandle));
            }
            if (hasRightClick) {
                root.onMouseDownOut(cx.listener((this_:TableState<D>, e:MouseDownEvent, window, cx) -> {
                    this_.onRowRightClick(e, null, window, cx);
                    cx.notify();
                }));
            }
        }
        final state = view;
        root.onPrepaint((bounds, _, cx) -> state.update(cx, (state, _) -> state.bounds = bounds));
        // Rust `.when(!window.is_inspector_picking(cx), ...)`: no inspector in the port.
        #if glaze_inspector
        if (window.isInspectorPicking(cx.app)) {
            return root;
        }
        #end
        final overlay = div()
            .absolute()
            .top0()
            .sizeFull();
        if (options.scrollbarVisible.bottom) {
            overlay.child(renderHorizontalScrollbar(window, cx));
        }
        if (options.scrollbarVisible.right && rowsCount > 0) {
            final scrollbar = renderVerticalScrollbar(window, cx);
            if (scrollbar != null) overlay.child(scrollbar);
        }
        return root.child(overlay);
    }

}
