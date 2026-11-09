// Ported from gpui-kit 0.8.1: crates/component/src/table/table.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.table;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.TextAlign;
import glaze.Window;
import glaze.kit.base.Table as BaseTable;
import glaze.kit.base.Table.TableBody as BaseTableBody;
import glaze.kit.base.Table.TableCaption as BaseTableCaption;
import glaze.kit.base.Table.TableCell as BaseTableCell;
import glaze.kit.base.Table.TableHead as BaseTableHead;
import glaze.kit.base.Table.TableHeader as BaseTableHeader;
import glaze.kit.base.Table.TableRow as BaseTableRow;
import glaze.kit.ChildElement;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.Size.SizeTools;

/**
 * A basic table component for directly rendering tabular data.
 *
 * Unlike `DataTable`, this is a simple, stateless, composable table
 * without virtual scrolling or column management.
 *
 * Size set via `Sizable` is automatically propagated to all children.
 */
class Table extends Component implements Styled implements ChildElement {

    static inline final MIN_CELL_WIDTH:Pixels = 100.;

    var ix:Int = 0;

    final tableStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyChildElement> = [];

    var size:Size = Medium;

    /**
     * Set the name a screen reader announces for the table.
     *
     * A `TableCaption` is visible descriptive content and is not used
     * automatically as the table's accessible name.
     */
    @:allow(tests)
    @prop var accessibilityLabel:Null<String> = null;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return tableStyle;
    }

    public function child(child:ChildElement):Table {
        if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function children(children:Array<ChildElement>):Table {
        for (child in children) if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function withSize(size:IntoSize):Table {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final base = new BaseTable(NamedInteger("table", ix));
        if (accessibilityLabel != null) base.accessibilityLabel(accessibilityLabel);
        final size = this.size;
        return base
            .wFull()
            .textSm()
            .overflowHidden()
            .bg(theme.tokens.table.background)
            .refineStyle(tableStyle)
            .children([for (ix => c in childElements) (c.intoAny(ix, size) : IntoElement)]);
    }

}

/** The header section of a `Table`, wrapping header rows. */
class TableHeader extends Component implements Styled implements ChildElement {

    var ix:Int = 0;

    final headerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyChildElement> = [];

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function child(child:ChildElement):TableHeader {
        if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function children(children:Array<ChildElement>):TableHeader {
        for (child in children) if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function withSize(size:IntoSize):TableHeader {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final size = this.size;
        return new BaseTableHeader(NamedInteger("table-header", ix))
            .wFull()
            .bg(theme.tokens.tableHead.background)
            .textColor(theme.tableHeadForeground)
            .refineStyle(headerStyle)
            .borderB1()
            .borderColor(theme.tableRowBorder)
            .children([for (ix => c in childElements) (c.intoAny(ix, size) : IntoElement)]);
    }

}

/** The body section of a `Table`, wrapping data rows. */
class TableBody extends Component implements Styled implements ChildElement {

    var ix:Int = 0;

    final bodyStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyChildElement> = [];

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return bodyStyle;
    }

    public function child(child:ChildElement):TableBody {
        if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function children(children:Array<ChildElement>):TableBody {
        for (child in children) if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function withSize(size:IntoSize):TableBody {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, _:App):IntoElement {
        final size = this.size;
        return new BaseTableBody(NamedInteger("table-body", ix))
            .wFull()
            .refineStyle(bodyStyle)
            .children([for (ix => c in childElements) (c.intoAny(ix, size) : IntoElement)]);
    }

}

/** The footer section of a `Table`, wrapping footer rows. */
class TableFooter extends Component implements Styled implements ChildElement {

    var ix:Int = 0;

    final footerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyChildElement> = [];

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return footerStyle;
    }

    public function child(child:ChildElement):TableFooter {
        if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function children(children:Array<ChildElement>):TableFooter {
        for (child in children) if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function withSize(size:IntoSize):TableFooter {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final size = this.size;
        return div()
            .id(NamedInteger("table-footer", ix))
            .wFull()
            .bg(theme.tokens.tableFoot.background)
            .textColor(theme.tableFootForeground)
            .borderT1()
            .borderColor(theme.tableRowBorder)
            .refineStyle(footerStyle)
            .children([for (ix => c in childElements) (c.intoAny(ix, size) : IntoElement)]);
    }

}

/** A row in a `Table`. */
class TableRow extends Component implements Styled implements ChildElement {

    var ix:Int = 0;

    final rowStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyChildElement> = [];

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return rowStyle;
    }

    public function child(child:ChildElement):TableRow {
        if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function children(children:Array<ChildElement>):TableRow {
        for (child in children) if (child != null) childElements.push(new AnyChildElement(child));
        return this;
    }

    public function withSize(size:IntoSize):TableRow {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final size = this.size;
        final row = new BaseTableRow(NamedInteger("table-row", ix), ix + 1)
            .wFull()
            .flex()
            .flexRow()
            .refineStyle(rowStyle)
            .borderColor(theme.tableRowBorder);
        if (ix > 0) row.borderT1();
        return row.children([for (ix => c in childElements) (c.intoAny(ix, size) : IntoElement)]);
    }

}

/** A header cell in a `TableRow`. */
class TableHead extends Component implements Styled implements ParentElement implements ChildElement {

    var ix:Int = 0;

    final headStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var colSpanValue:Int = 1;

    var align:TextAlign = Left;

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return headStyle;
    }

    /** Set the column span of this header cell. */
    public function colSpan(span:Int):TableHead {
        colSpanValue = span < 1 ? 1 : span;
        return this;
    }

    /** Set text alignment to center. */
    public function textCenter():TableHead {
        align = Center;
        return this;
    }

    /** Set text alignment to right. */
    public function textRight():TableHead {
        align = Right;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function withSize(size:IntoSize):TableHead {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, _:App):IntoElement {
        final paddings = size.tableCellPadding();
        final cell = new BaseTableHead(NamedInteger("table-head", ix), ix + 1)
            .flex()
            .itemsCenter();
        if (headStyle.sizeWidth == null) {
            cell.flexShrink1().flexBasis(glaze.Prelude.relative(colSpanValue));
        }
        cell.minW(glaze.Prelude.px(MIN_CELL_WIDTH * colSpanValue))
            .px(glaze.Prelude.px(paddings.left))
            .py(glaze.Prelude.px(paddings.top));
        if (align == Center) cell.justifyCenter();
        if (align == Right) cell.justifyEnd();
        cell.refineStyle(headStyle);
        cell.extend(childElements);
        return cell;
    }

    static inline final MIN_CELL_WIDTH:Pixels = 100.;

}

/** A data cell in a `TableRow`. */
class TableCell extends Component implements Styled implements ParentElement implements ChildElement {

    var ix:Int = 0;

    final cellStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var colSpanValue:Int = 1;

    var align:TextAlign = Left;

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return cellStyle;
    }

    /** Set the column span of this cell. */
    public function colSpan(span:Int):TableCell {
        colSpanValue = span < 1 ? 1 : span;
        return this;
    }

    /** Set text alignment to center. */
    public function textCenter():TableCell {
        align = Center;
        return this;
    }

    /** Set text alignment to right. */
    public function textRight():TableCell {
        align = Right;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function withSize(size:IntoSize):TableCell {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, _:App):IntoElement {
        final paddings = size.tableCellPadding();
        final cell = new BaseTableCell(NamedInteger("table-cell", ix), ix + 1)
            .flex()
            .itemsCenter();
        if (cellStyle.sizeWidth == null) {
            cell.flexShrink1().flexBasis(glaze.Prelude.relative(colSpanValue));
        }
        cell.minW(glaze.Prelude.px(MIN_CELL_WIDTH * colSpanValue))
            .px(glaze.Prelude.px(paddings.left))
            .py(glaze.Prelude.px(paddings.top));
        if (align == Center) cell.justifyCenter();
        if (align == Right) cell.justifyEnd();
        cell.refineStyle(cellStyle);
        cell.extend(childElements);
        return cell;
    }

    static inline final MIN_CELL_WIDTH:Pixels = 100.;

}

/** A caption displayed below the `Table`. */
class TableCaption extends Component implements Styled implements ParentElement implements ChildElement {

    var ix:Int = 0;

    final captionStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var size:Size = Medium;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return captionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function withSize(size:IntoSize):TableCaption {
        this.size = size;
        return this;
    }

    public function setIx(ix:Int):Void {
        this.ix = ix;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final paddings = size.tableCellPadding();
        final caption = new BaseTableCaption(NamedInteger("table-caption", ix))
            .wFull()
            .px(glaze.Prelude.px(paddings.left))
            .py(glaze.Prelude.px(paddings.top))
            .textSm()
            .textColor(theme.mutedForeground)
            .textCenter()
            .refineStyle(captionStyle);
        caption.extend(childElements);
        return caption;
    }

}
