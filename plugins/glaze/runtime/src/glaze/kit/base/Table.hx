// Ported from gpui-kit 0.8.1: crates/base/src/table.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;

/**
 * The shared body of the unstyled table parts (Rust: the fields and the
 * `Styled`, `ParentElement` and `InteractiveElement` impls each part
 * repeats, the latter forwarding to `base`).
 *
 * Interactive styles and listeners go to `base` (or to the forwarding
 * methods below).
 */
abstract class TablePart extends Component implements Styled implements ParentElement {

    /** The stateful element the part renders (Rust `base`). */
    public final base:Div;

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the part exports (filled by `render`). */
    public final a11y:A11y;

    function new(id:ElementIdArg, ?role:Role) {
        super();
        base = div().id(id).testSupport();
        a11y = new A11y(role);
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** A click listener (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):TablePart {
        base.onClick(listener);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):TablePart {
        base.onMouseDown(button, listener);
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):TablePart {
        base.hover(f);
        return this;
    }

    /** Rust `InteractiveElement::track_focus` (on `base`). */
    public function trackFocus(handle:FocusHandle):TablePart {
        base.trackFocus(handle);
        return this;
    }

    /** Rust `debug_selector` (on `base`, records nothing like GPUI outside debug test builds). */
    public function debugSelector(f:() -> String):TablePart {
        base.debugSelector(f);
        return this;
    }

    function renderBase():Div {
        base.extend(childElements);
        return base.refineStyle(partStyle);
    }

    public function render(window:Window, cx:App):IntoElement {
        return renderBase();
    }

}

/**
 * An unstyled semantic table root.
 *
 * Rust `gpui_base::Table`, in its own module so it does not clash with the
 * component `Table`.
 */
class Table extends TablePart {

    /**
     * Sets the total number of rows, including rows outside the rendered
     * range. Assistive technology needs this to announce "row 5 of 200" for a
     * virtualized table whose rendered rows are only a window onto the data.
     */
    @prop var rowCount:Null<Int> = null;

    /**
     * Sets the total number of columns, including columns outside the
     * rendered range.
     */
    @prop var columnCount:Null<Int> = null;

    /** Sets the table's accessible name. */
    @prop var accessibilityLabel:Null<String> = null;

    /** Create an unstyled semantic table root. */
    public function new(id:ElementIdArg) {
        super(id, Role.Table);
    }

    override public function render(window:Window, cx:App):IntoElement {
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        if (rowCount != null) a11y.rowCount = rowCount;
        if (columnCount != null) a11y.columnCount = columnCount;
        return renderBase();
    }

}

/** An unstyled table header group. */
class TableHeader extends TablePart {

    /** Create an unstyled table header group. */
    public function new(id:ElementIdArg) {
        super(id, Role.RowGroup);
    }

}

/** An unstyled table body group. */
class TableBody extends TablePart {

    /** Create an unstyled table body group. */
    public function new(id:ElementIdArg) {
        super(id, Role.RowGroup);
    }

}

/** An unstyled semantic table row. */
class TableRow extends TablePart {

    final rowIndex:Int;

    /** Create an unstyled semantic table row with a one-based accessibility index. */
    public function new(id:ElementIdArg, rowIndex:Int) {
        super(id, Role.Row);
        this.rowIndex = rowIndex;
    }

    override public function render(window:Window, cx:App):IntoElement {
        a11y.rowIndex = rowIndex;
        return renderBase();
    }

}

/** An unstyled table column header. */
class TableHead extends TablePart {

    final columnIndex:Int;

    /** Create an unstyled table column header with a one-based accessibility index. */
    public function new(id:ElementIdArg, columnIndex:Int) {
        super(id, Role.ColumnHeader);
        this.columnIndex = columnIndex;
    }

    override public function render(window:Window, cx:App):IntoElement {
        a11y.columnIndex = columnIndex;
        return renderBase();
    }

}

/** An unstyled table data cell. */
class TableCell extends TablePart {

    final columnIndex:Int;

    /** Create an unstyled table data cell with a one-based accessibility index. */
    public function new(id:ElementIdArg, columnIndex:Int) {
        super(id, Role.Cell);
        this.columnIndex = columnIndex;
    }

    override public function render(window:Window, cx:App):IntoElement {
        a11y.columnIndex = columnIndex;
        return renderBase();
    }

}

/** An unstyled table caption slot (no role). */
class TableCaption extends TablePart {

    /** Create an unstyled table caption slot. */
    public function new(id:ElementIdArg) {
        super(id, null);
    }

}
