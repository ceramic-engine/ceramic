// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.DefiniteLength;
import glaze.HighlightStyle;
import glaze.Pixels;
import glaze.Range;
import glaze.TextStyle;
import glaze.TextStyleRefinement;

using glaze.DefiniteLengthTools;

/** A row of a table. */
class TableRow {

    public var children:Array<TableCell> = [];

    public function new(?children:Array<TableCell>) {
        if (children != null)
            this.children = children;
    }

    public function clone():TableRow {
        return new TableRow([for (cell in children) cell.clone()]);
    }

    public function equals(other:Null<TableRow>):Bool {
        if (other == null || children.length != other.children.length)
            return false;
        for (i in 0...children.length) {
            if (!children[i].equals(other.children[i]))
                return false;
        }
        return true;
    }

}

/** A cell of a table. */
class TableCell {

    public var children:Paragraph;

    public var width:Null<DefiniteLength> = null;

    public function new(?children:Paragraph, ?width:DefiniteLength) {
        this.children = children != null ? children : new Paragraph();
        this.width = width;
    }

    public function clone():TableCell {
        return new TableCell(children.clone(), width);
    }

    public function equals(other:Null<TableCell>):Bool {
        return other != null && children.equals(other.children)
            && (width == null ? other.width == null : other.width != null && width.equals(other.width));
    }

}

/**
 * Column widths measured for a table, kept between frames.
 */
class TableColumnWidths {

    public var textSystem:Null<glaze.WindowTextSystem>;

    /** The styles the header row and the body rows render with. */
    public var textStyles:TableTextStyles;

    public var remSize:Pixels;
    public var monoFamily:String;
    public var inlineCode:HighlightStyle;

    /** Maxima from ordinary text only. Custom cells may shrink after an update. */
    public var widths:Array<Float>;

    /** `(row, column)` of the cells holding custom inline nodes. */
    public var customCells:Array<Array<Int>>;

    public function new(textSystem:Null<glaze.WindowTextSystem>, textStyles:TableTextStyles, remSize:Pixels, monoFamily:String,
            inlineCode:HighlightStyle, widths:Array<Float>, customCells:Array<Array<Int>>) {
        this.textSystem = textSystem;
        this.textStyles = textStyles;
        this.remSize = remSize;
        this.monoFamily = monoFamily;
        this.inlineCode = inlineCode;
        this.widths = widths;
        this.customCells = customCells;
    }

}

/**
 * The text styles table rows render with: the window's, refined by
 * `style.table` on the frame, `style.tableHead` on the header row and
 * `style.tableCell` on every cell, in the order the elements apply them.
 */
class TableTextStyles {

    public final head:TextStyle;
    public final body:TextStyle;
    public final headRefinement:TextStyleRefinement;
    public final bodyRefinement:TextStyleRefinement;

    function new(head:TextStyle, body:TextStyle, headRefinement:TextStyleRefinement, bodyRefinement:TextStyleRefinement) {
        this.head = head;
        this.body = body;
        this.headRefinement = headRefinement;
        this.bodyRefinement = bodyRefinement;
    }

    public static function of(style:TextViewStyle, window:glaze.Window):TableTextStyles {
        inline function textOf(refinement:glaze.StyleRefinement):TextStyleRefinement {
            return refinement.text != null ? refinement.text : new TextStyleRefinement();
        }
        final bodyRefinement = textOf(style.table()).clone();
        final headRefinement = bodyRefinement.clone();
        headRefinement.refine(textOf(style.tableHead()));
        headRefinement.refine(textOf(style.tableCell()));
        bodyRefinement.refine(textOf(style.tableCell()));
        final head = window.textStyle();
        final body = head.clone();
        head.refine(headRefinement);
        body.refine(bodyRefinement);
        return new TableTextStyles(head, body, headRefinement, bodyRefinement);
    }

    public inline function row(rowIx:Int):TextStyle {
        return rowIx == 0 ? head : body;
    }

    public inline function rowRefinement(rowIx:Int):TextStyleRefinement {
        return rowIx == 0 ? headRefinement : bodyRefinement;
    }

    public function equals(other:Null<TableTextStyles>):Bool {
        return other != null && head.equals(other.head) && body.equals(other.body) && headRefinement.equals(other.headRefinement)
            && bodyRefinement.equals(other.bodyRefinement);
    }

}

/**
 * A table: rows of cell paragraphs and per-column alignment.
 */
class Table {

    @:allow(glaze.kit.base.text)
    var children:Array<TableRow> = [];

    @:allow(glaze.kit.base.text)
    var columnAligns_:Array<ColumnumnAlign> = [];

    @:allow(glaze.kit.base.text)
    var span:Null<Span> = null;

    /**
     * The `TableData` handed to the `tableActions` hook, kept between
     * frames; see `cachedTableData`. Derived state, invisible to equality;
     * a clone carries what was cached so far.
     */
    @:allow(glaze.kit.base.text)
    var tableDataCache:Null<TableData> = null;

    @:allow(glaze.kit.base.text)
    var columnWidthsCache:Null<TableColumnWidths> = null;

    /** `Table::default()`. */
    public function new() {}

    /** A table of `rows` (one paragraph per cell) with the column alignments. */
    public static function of(rows:Array<Array<Paragraph>>, columnAligns:Array<ColumnumnAlign>):Table {
        final table = new Table();
        table.children = [for (row in rows) new TableRow([for (children in row) new TableCell(children)])];
        table.columnAligns_ = columnAligns;
        return table;
    }

    public function clone():Table {
        final table = new Table();
        table.children = [for (row in children) row.clone()];
        table.columnAligns_ = columnAligns_.copy();
        table.span = span != null ? span.copy() : null;
        table.tableDataCache = tableDataCache;
        table.columnWidthsCache = columnWidthsCache;
        return table;
    }

    public function equals(other:Null<Table>):Bool {
        if (other == null || children.length != other.children.length || columnAligns_.length != other.columnAligns_.length
            || !Span.eq(span, other.span))
            return false;
        for (i in 0...children.length) {
            if (!children[i].equals(other.children[i]))
                return false;
        }
        for (i in 0...columnAligns_.length) {
            if (columnAligns_[i] != other.columnAligns_[i])
                return false;
        }
        return true;
    }

    /** The rows, each an array of its cells' paragraphs. */
    public function rows():Array<Array<Paragraph>> {
        return [for (row in children) [for (cell in row.children) cell.children]];
    }

    /** The alignment of each column. */
    public inline function columnAligns():Array<ColumnumnAlign> {
        return columnAligns_;
    }

    @:allow(glaze.kit.base.text)
    function columnAlign(index:Int):ColumnumnAlign {
        return index < columnAligns_.length ? columnAligns_[index] : None;
    }

    static function alignDelimiter(align:ColumnumnAlign):String {
        return switch align {
            case None | Left: ':--';
            case Center: ':-:';
            case Right: '--:';
        }
    }

    /**
     * Serialize the table back to GFM pipe-table Markdown (`| a | b |`),
     * preserving column alignments. Cell newlines collapse to spaces and `|`
     * is escaped so rows stay intact.
     */
    @:allow(glaze.kit.base.text)
    function toMarkdown():String {
        final lines:Array<String> = [];

        for (rowIx in 0...children.length) {
            final row = children[rowIx];
            final cells = [
                for (cell in row.children)
                    StringTools.replace(StringTools.replace(TextUtils.trim(cell.children.toMarkdown()), '\n', ' '), '|', '\\|')
            ];
            lines.push('| ' + cells.join(' | ') + ' |');

            // The Markdown delimiter row carries the column alignments and must
            // follow the header row.
            if (rowIx == 0) {
                final aligns = [for (ix in 0...row.children.length) alignDelimiter(columnAlign(ix))];
                lines.push('| ' + aligns.join(' | ') + ' |');
            }
        }

        return lines.join('\n');
    }

    /** Snapshot of this table for the `TextView.tableActions` hook. */
    @:allow(glaze.kit.base.text)
    function tableData():TableData {
        function rowText(row:TableRow):Array<String> {
            return [for (cell in row.children) TextUtils.trim(cell.children.text())];
        }

        final data = new TableData();
        data.headers = children.length > 0 ? rowText(children[0]) : [];
        data.rows = [for (i in 1...children.length) rowText(children[i])];
        data.markdown = toMarkdown();
        data.span = span != null ? new Range(span.start, span.end) : null;
        return data;
    }

    /**
     * `tableData`, built on the first render and reused by later ones: a
     * parsed table does not change after parsing (a reparse builds a new
     * one).
     */
    @:allow(glaze.kit.base.text)
    function cachedTableData():TableData {
        if (tableDataCache != null) {
            return tableDataCache;
        }

        final data = tableData();
        tableDataCache = data;
        return data;
    }

    /**
     * Reconstruct the Markdown source of the selected cells of `table`.
     *
     * Cells emit their own selected source; rows are piped (`| a | b |`)
     * and the delimiter/alignment row is inserted after the first row, so a
     * selected table round-trips as a Markdown table. A selection in one cell
     * (a drag that started in a cell stays in it) is that cell's source
     * alone. Returns an empty string when no cell is selected. Rust free
     * `table_selected_source`.
     */
    @:allow(glaze.kit.base.text)
    static function tableSelectedSource(table:Table):String {
        function cellSource(cell:TableCell):String {
            return StringTools.replace(cell.children.selectedSource(), '\n', ' ');
        }

        var first:Null<String> = null;
        var count = 0;
        for (row in table.children) {
            for (cell in row.children) {
                final source = cellSource(cell);
                if (TextUtils.trim(source) != '') {
                    if (first == null)
                        first = source;
                    count++;
                    if (count > 1)
                        break;
                }
            }
            if (count > 1)
                break;
        }
        if (count == 0)
            return '';
        if (count == 1)
            return TextUtils.trim(first);

        final lines:Array<String> = [];
        for (rowIx in 0...table.children.length) {
            final row = table.children[rowIx];
            final cells = [for (cell in row.children) TextUtils.trim(cellSource(cell))];
            lines.push('| ' + cells.join(' | ') + ' |');

            // The Markdown delimiter row carries the column alignments and must
            // follow the header row.
            if (rowIx == 0) {
                final aligns = [for (ix in 0...row.children.length) alignDelimiter(table.columnAlign(ix))];
                lines.push('| ' + aligns.join(' | ') + ' |');
            }
        }

        return lines.join('\n');
    }

}
