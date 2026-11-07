// Ported from gpui-kit 0.8.1: crates/component/src/table/column.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.table;

import gpui.Bounds;
import gpui.Context;
import gpui.Edges;
import gpui.IntoElement;
import gpui.Model;
import gpui.Pixels;
import gpui.Render;
import gpui.TextAlign;
import gpui.Window;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

/**
 * Represents a column in a table, used for initializing table columns.
 */
class Column {

    /**
     * The unique key of the column.
     *
     * This is used to identify the column in the table and your data source.
     * In most cases, it should match the field name in your data source.
     */
    public var key:String = '';

    /** The display name of the column. */
    public var name:String = '';

    /** The text alignment of the column. */
    public var align:TextAlign = Left;

    /**
     * The sorting behavior of the column, if any.
     *
     * If `null`, the column is not sortable.
     */
    public var sort:Null<ColumnSort> = null;

    /** The padding of the column. */
    public var paddings:Null<Edges> = null;

    /** The width of the column. */
    public var width:Pixels = 100.;

    /** Whether the column is fixed, the fixed column will pin at the left side when scrolling horizontally. */
    public var fixed:Null<ColumnFixed> = null;

    /** Whether the column is resizable. */
    public var resizable:Bool = true;

    /** Whether the column is movable. */
    public var movable:Bool = true;

    /**
     * Whether the column is selectable.
     *
     * When `true`:
     * - In column selection mode: The entire column can be selected
     * - In cell selection mode: Individual cells in this column can be selected
     *
     * When `false`:
     * - The column and its cells cannot be selected
     * - Useful for action columns (e.g., buttons, checkboxes) that shouldn't participate in selection
     */
    public var selectable:Bool = true;

    /** The minimum width of the column. */
    public var minWidth:Pixels = 20.;

    /** The maximum width of the column. */
    public var maxWidth:Pixels = 1200.;

    /** Create a new column with the given key and name (Rust `Column::new`, or `Default` with no arguments). */
    public function new(key:String = '', name:String = '') {
        this.key = key;
        this.name = name;
    }

    /** Rust `Clone`. */
    public function clone():Column {
        final column = new Column(key, name);
        column.align = align;
        column.sort = sort;
        column.paddings = paddings;
        column.width = width;
        column.fixed = fixed;
        column.resizable = resizable;
        column.movable = movable;
        column.selectable = selectable;
        column.minWidth = minWidth;
        column.maxWidth = maxWidth;
        return column;
    }

    /**
     * Set the column to be sortable with custom sort function, default is null (not sortable).
     *
     * See also `Column.sortable` to enable sorting with default.
     */
    public function withSort(sort:ColumnSort):Column {
        this.sort = sort;
        return this;
    }

    /**
     * Set whether the column is sortable, default is true.
     *
     * See also `Column.withSort`.
     */
    public function sortable():Column {
        sort = ColumnSort.Default;
        return this;
    }

    /** Set whether the column is sort with ascending order. */
    public function ascending():Column {
        sort = ColumnSort.Ascending;
        return this;
    }

    /** Set whether the column is sort with descending order. */
    public function descending():Column {
        sort = ColumnSort.Descending;
        return this;
    }

    /**
     * Center the column's text, in its header and in its cells.
     *
     * The table aligns text; a cell that renders its own layout, such as a
     * flex row, aligns that layout itself.
     */
    public function textCenter():Column {
        align = Center;
        return this;
    }

    /**
     * Right-align the column's text, in its header and in its cells. The
     * default is left.
     */
    public function textRight():Column {
        align = Right;
        return this;
    }

    /** Set the padding of the column, default is null. */
    public function withPaddings(paddings:Edges):Column {
        this.paddings = paddings;
        return this;
    }

    /** Set the padding of the column to 0px. */
    public function p0():Column {
        paddings = new Edges(0., 0., 0., 0.);
        return this;
    }

    /** Set the width of the column, default is 100px. */
    public function withWidth(width:Pixels):Column {
        this.width = width;
        return this;
    }

    /** Set whether the column is fixed, default is false. */
    public function withFixed(fixed:ColumnFixed):Column {
        this.fixed = fixed;
        return this;
    }

    /** Set whether the column is fixed on left side, default is false. */
    public function fixedLeft():Column {
        fixed = ColumnFixed.Left;
        return this;
    }

    /** Set whether the column is resizable, default is true. */
    public function withResizable(resizable:Bool):Column {
        this.resizable = resizable;
        return this;
    }

    /** Set whether the column is movable, default is true. */
    public function withMovable(movable:Bool):Column {
        this.movable = movable;
        return this;
    }

    /**
     * Set whether the column is selectable, default is true.
     *
     * When `false`, this column and its cells will not participate in selection:
     * - In column selection mode: The column header cannot be clicked to select
     * - In cell selection mode: Cells in this column cannot be selected
     */
    public function withSelectable(selectable:Bool):Column {
        this.selectable = selectable;
        return this;
    }

    /** Set the minimum width of the column, default is 20px */
    public function withMinWidth(minWidth:Pixels):Column {
        this.minWidth = minWidth;

        // If the current width is smaller than the new minimum,
        // bump the width up to match the minimum.
        if (width < minWidth) {
            width = minWidth;
        }
        return this;
    }

    /**
     * Set the maximum width when resizing the column, default is 1200px.
     *
     * The default protects against oversized columns during resizing. Set a
     * larger maximum explicitly when wider columns are needed. It does not
     * limit an initial width set afterwards with `withWidth`.
     */
    public function withMaxWidth(maxWidth:Pixels):Column {
        this.maxWidth = maxWidth;

        // If the current width is larger than the new maximum,
        // pull the width down to match the maximum.
        if (width > maxWidth) {
            width = maxWidth;
        }
        return this;
    }

}

/**
 * A column group can be used to group multiple columns under a single header.
 */
class ColumnGroup {

    public var label:String;

    public var span:Int;

    public function new(label:String, span:Int) {
        this.label = label;
        this.span = span;
    }

}

enum abstract ColumnFixed(Int) {
    var Left = 0;
}

/**
 * The sorting behavior of a column.
 */
enum abstract ColumnSort(Int) {
    /** No sorting. */
    var Default = 0;
    /** Sort in ascending order. */
    var Ascending = 1;
    /** Sort in descending order. */
    var Descending = 2;

    public function toString():String {
        return switch (cast this : ColumnSort) {
            case Default: 'Default';
            case Ascending: 'Ascending';
            case Descending: 'Descending';
        }
    }
}

/**
 * Used to sort the column runtime info in Table internal.
 */
@:allow(gpui.component.table)
class ColGroup {

    public var column:Column;

    /**
     * This is the runtime width of the column, we may update it when the column is resized.
     *
     * Including the width with next columns by col_span.
     */
    public var width:Pixels;

    /** The bounds of the column in the table after it renders. */
    public var bounds:Bounds;

    public function new(column:Column, width:Pixels, bounds:Bounds) {
        this.column = column;
        this.width = width;
        this.bounds = bounds;
    }

    public inline function isResizable():Bool {
        return column.resizable;
    }

    /** Rust `Clone`. */
    public function clone():ColGroup {
        return new ColGroup(column.clone(), width, bounds);
    }

}

/**
 * The payload of a column header drag (Rust drags a `DragColumn` value and
 * renders a clone of it, see `DragColumnView`).
 */
class DragColumn {

    public final entityId:Int;

    public final name:String;

    public final width:Pixels;

    public final colIx:Int;

    public function new(entityId:Int, name:String, width:Pixels, colIx:Int) {
        this.entityId = entityId;
        this.name = name;
        this.width = width;
        this.colIx = colIx;
    }

}

/** The drag view of a `DragColumn` (Rust `impl Render for DragColumn`). */
class DragColumnView extends Model implements Render {

    final drag:DragColumn;

    public function new(drag:DragColumn) {
        super();
        this.drag = drag;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx);
        return div()
            .px4()
            .py1()
            .bg(theme.tokens.tableHead.background)
            .textColor(theme.mutedForeground)
            .opacity(0.9)
            .border1()
            .borderColor(theme.border)
            .shadowMd()
            .w(px(drag.width))
            .minW(px(100.))
            .maxW(px(450.))
            .child(drag.name);
    }

}

/** The payload of a column resize drag: the table's entity id and the column. */
class ResizeColumn {

    public final entityId:Int;

    public final ix:Int;

    public function new(entityId:Int, ix:Int) {
        this.entityId = entityId;
        this.ix = ix;
    }

}

/** The drag view of a `ResizeColumn` (renders nothing). */
class ResizeColumnView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}
