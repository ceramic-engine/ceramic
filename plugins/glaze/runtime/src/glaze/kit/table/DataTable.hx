// Ported from gpui-kit 0.8.1: crates/component/src/table/data_table.rs, crates/component/src/table/mod.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.table;

import glaze.App;
import glaze.AppContext;
import glaze.EdgesOf;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Pixels;
import glaze.RenderOnce;
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
import glaze.kit.base.ComponentTraits.FocusableExt;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.ThemeStyled;

/** The options a `DataTable` element hands to its state. */
@:allow(glaze.kit.table, tests)
class TableOptions {

    public var scrollBounce:Null<Bool> = null;

    public var scrollbarVisible:EdgesOf<Bool> = new EdgesOf<Bool>(true, true, true, true);

    /** Set stripe style of the table. */
    public var stripe:Bool = false;

    /** Set to use border style of the table. */
    public var bordered:Bool = true;

    /** Draw the border on the right edge of the fixed columns. */
    public var fixedColsBorder:Bool = true;

    /** The cell size of the table. */
    public var size:Size = Medium;

    /** Height of each header row. `null` uses `Size.tableRowHeight`. */
    public var headerRowHeight:Null<Pixels> = null;

    public function new() {}

}

/**
 * A table element with support for row, column, and cell selection.
 *
 * - **Multiple Selection Modes**: Support for row, column, and cell selection
 * - **Cell Selection**: Click to select individual cells, with keyboard navigation
 * - **Virtual Scrolling**: Efficient rendering of large datasets
 * - **Resizable Columns**: Drag column borders to resize
 * - **Movable Columns**: Drag column headers to reorder
 * - **Fixed Columns**: Pin columns to the left side
 * - **Sortable Columns**: Click column headers to sort
 * - **Context Menus**: Right-click support for rows and cells
 */
class DataTable<D:TableDelegate> implements RenderOnce implements Sizable implements FocusableExt {

    static inline final CONTEXT:String = "DataTable";

    /** Rust `table::init` (`data_table::init`): binds the table keys. */
    public static function bindKeys(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("escape", new Cancel(), CONTEXT),
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("left", new SelectPrevColumn(), CONTEXT),
            new KeyBinding("right", new SelectNextColumn(), CONTEXT),
            new KeyBinding("home", new SelectFirst(), CONTEXT),
            new KeyBinding("end", new SelectLast(), CONTEXT),
            new KeyBinding("pageup", new SelectPageUp(), CONTEXT),
            new KeyBinding("pagedown", new SelectPageDown(), CONTEXT),
            new KeyBinding("tab", new SelectNextColumn(), CONTEXT),
            new KeyBinding("shift-tab", new SelectPrevColumn(), CONTEXT),
        ]);
    }

    final state:Entity<TableState<D>>;

    @:allow(tests)
    final options:TableOptions = new TableOptions();

    var focusRingEnabled:Bool = true;

    /** Create a new DataTable element with the given `TableState`. */
    public function new(state:Entity<TableState<D>>) {
        this.state = state;
    }

    /** Set to use stripe style of the table, default to false. */
    public function stripe(stripe:Bool):DataTable<D> {
        options.stripe = stripe;
        return this;
    }

    /**
     * Bounce the rows at the vertical boundaries, keeping headers and
     * scrollbars fixed. On by default on iOS, Android and macOS, off
     * elsewhere.
     */
    public function scrollBounce(enabled:Bool):DataTable<D> {
        options.scrollBounce = enabled;
        return this;
    }

    /** Set to use border style of the table, default to true. */
    public function bordered(bordered:Bool):DataTable<D> {
        options.bordered = bordered;
        return this;
    }

    /**
     * Set the height of each header row.
     *
     * Column-group rows use the same height, so the whole header is this
     * height times the number of header rows. Body rows keep the height from
     * `Size.tableRowHeight`. When this is unset, header rows use that same
     * height.
     */
    public function headerRowHeight(height:Pixels):DataTable<D> {
        options.headerRowHeight = height;
        return this;
    }

    /**
     * Set whether to draw the border on the right edge of the fixed columns,
     * default to true.
     *
     * Turn it off when the fixed cells draw that edge themselves, so the
     * boundary is not drawn twice.
     */
    public function fixedColsBorder(fixedColsBorder:Bool):DataTable<D> {
        options.fixedColsBorder = fixedColsBorder;
        return this;
    }

    /** Set scrollbar visibility. */
    public function scrollbarVisible(vertical:Bool, horizontal:Bool):DataTable<D> {
        options.scrollbarVisible = new EdgesOf<Bool>(false, vertical, horizontal, false);
        return this;
    }

    public function withSize(size:IntoSize):DataTable<D> {
        options.size = size;
        return this;
    }

    /** Rust `FocusableExt::focus_ring`. */
    public function focusRing(enabled:Bool):DataTable<D> {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    public function render(window:Window, cx:App):IntoElement {
        final bordered = options.bordered;
        final focusRingEnabled = this.focusRingEnabled;
        final focusHandle = state.read(cx).focusHandle(cx);
        final options = this.options;
        state.update(cx, (state, _) -> {
            state.options = options;
        });
        final theme = Theme.global(cx);
        final state = this.state;

        final table = div()
            .id("table")
            .testSupport()
            .sizeFull()
            .keyContext(CONTEXT)
            .trackFocus(focusHandle)
            .onAction(Cancel, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionCancel(e, window, cx)))
            .onAction(SelectDown, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectNext(e, window, cx)))
            .onAction(SelectUp, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectPrev(e, window, cx)))
            .onAction(SelectNextColumn, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectNextCol(e, window, cx)))
            .onAction(SelectPrevColumn, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectPrevCol(e, window, cx)))
            .onAction(SelectFirst, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectFirstColumn(e, window, cx)))
            .onAction(SelectLast, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectLastColumn(e, window, cx)))
            .onAction(SelectPageUp, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectPageUp(e, window, cx)))
            .onAction(SelectPageDown, (e, window, cx) -> state.update(cx, (s, cx) -> s.actionSelectPageDown(e, window, cx)))
            .bg(theme.tokens.table.background);
        if (bordered) {
            table.rounded(px(theme.radius))
                .border1()
                .borderColor(theme.border);
        }
        table.child(state);
        // Clicking a row focuses the table too, so only keyboard focus
        // shows it, as CSS `:focus-visible` does.
        if (focusRingEnabled && focusHandle.isFocused(window) && window.lastInputWasKeyboard()) {
            table.focusRingStyle(window, cx);
        }
        return table;
    }

}
