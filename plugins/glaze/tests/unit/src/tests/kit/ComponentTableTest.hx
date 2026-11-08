// Ported from gpui-kit 0.8.1: crates/component/src/table/table.rs, data_table.rs and state.rs (tests),
// crates/component/tests/integration/table_dump_range.rs and table_fit_column.rs,
// and crates/kit/tests/integration/collections.rs (the table tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Edges;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.Size;
import glaze.kit.table.Column;
import glaze.kit.table.DataTable;
import glaze.kit.table.Table;
import glaze.kit.table.TableDelegate;
import glaze.kit.table.TableState;
import glaze.kit.theme.Theme;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.table.TableState.TableSelectionTools;

/**
 * The tests of gpui-component's `table` module (`table.rs`,
 * `data_table.rs`, `state.rs`), its integration tests (`table_dump_range`,
 * `table_fit_column`) and the table tests of gpui-kit's `collections`
 * integration test.
 *
 * The kit tests find elements by id (`window.find(("row", 1))`); the port
 * has no UI query layer, so they click the same places computed from the
 * table's layout (a 1 px border, 32 px header and rows, the 12 px row header
 * of cell selection) and read the state the queries reflect: a row is
 * "selected" when `selectedRow()` is it, "visible" or "found" when it is in
 * the rendered range `visibleRange().rows()`. The two accessibility tests
 * (`table_exposes_its_header_and_cells_to_assistive_technology`,
 * `selectable_cells_report_their_selection`) are not ported: the port has no
 * accessibility tree, and the table's roles and labels are only written to
 * it. The focus ring tests look for the ring in the rendered scene (a quad
 * bordered with the theme's ring color) instead of `debug_bounds("focus-ring")`.
 */
class ComponentTableTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    /** Rust `common::open_window`: the content inside gpui-base's `Root`. */
    function openWindow<V:Model & Render>(width:Float, height:Float, build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        var content:Null<Entity<V>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            content = rootCx.newEntity((c:Context<V>) -> build(window, c));
            return new Root(content, window, rootCx);
        }, width, height);
        contexts.push(opened.cx);
        renderFrame(opened.cx);
        return {view: content, cx: opened.cx};
    }

    /** Rust `window.render_frame(cx)`. */
    static function renderFrame(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.runUntilParked();
    }

    /** The top of body row `row` of a bordered table at (0, 0), unscrolled. */
    static inline function rowTop(row:Int):Float {
        return 1. + 32. + 32. * row;
    }

    /** Rust `window.click_at(id, offset)`: a click at a point, then a frame. */
    static function clickAt(cx:VisualTestContext, x:Float, y:Float, ?modifiers:Modifiers):Void {
        final m = modifiers != null ? modifiers : Modifiers.none();
        cx.simulateEvent(new MouseMoveEvent(new Point(x, y), null, m));
        cx.simulateEvent(new MouseDownEvent(Left, new Point(x, y), m, 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(x, y), m, 1));
        renderFrame(cx);
    }

    /** Rust `window.click(("row", row))`: the center of the row of a 640 px wide table. */
    static function clickRow(cx:VisualTestContext, row:Int, ?modifiers:Modifiers):Void {
        clickAt(cx, 320., rowTop(row) + 16., modifiers);
    }

    /** Rust `window.press(key)`. */
    static function press(cx:VisualTestContext, key:String):Void {
        cx.simulateKeystrokes(key);
        renderFrame(cx);
    }

    static function widths(table:TableState<Dynamic>):String {
        return [for (g in table.colGroups) Std.string((g.width : Float))].join(',');
    }

/// table.rs

    function testStoresAnExplicitAccessibilityLabel() {
        final plain = new Table();
        assertEquals(null, plain.accessibilityLabelValue);

        final named = new Table().accessibilityLabel('Recent invoices');
        assertEquals('Recent invoices', named.accessibilityLabelValue);
    }

/// data_table.rs

    function keyboardFocusedTable(focusRing:Bool):VisualTestContext {
        final opened = openWindow(1920, 1080, (window, cx:Context<FocusRingHarness>) -> new FocusRingHarness(cx.newEntity((c:Context<TableState<RowsDelegate>>) -> new TableState(new RowsDelegate(), window, c)), focusRing));
        final cx = opened.cx;
        final state = opened.view.read(app).state;
        cx.update((window, app) -> window.focus(state.read(app).focusHandle(app), app));
        cx.simulateKeystrokes('down');
        cx.update((window, _) -> window.draw());
        return cx;
    }

    /** Whether the scene has a quad bordered with the ring color (the tinted table edge). */
    function hasFocusRing(cx:VisualTestContext):Bool {
        final ring = Theme.global(app).ring;
        for (quad in cx.window.renderedScene().quads) {
            if (quad.borderWidthTop > 0 && Math.abs(quad.borderColorH - ring.h) < 1e-4 && Math.abs(quad.borderColorS - ring.s) < 1e-4
                && Math.abs(quad.borderColorL - ring.l) < 1e-4)
                return true;
        }
        return false;
    }

    function testDataTableBuilder() {
        final opened = openWindow(1920, 1080, (window, cx:Context<FocusRingHarness>) -> new FocusRingHarness(cx.newEntity((c:Context<TableState<RowsDelegate>>) -> new TableState(new RowsDelegate(), window, c)), true));
        final state = opened.view.read(app).state;
        assertTrue(new DataTable(state).isFocusRingEnabled());

        final table = new DataTable(state)
            .stripe(true)
            .bordered(false)
            .scrollBounce(false)
            .headerRowHeight(32.)
            .fixedColsBorder(false)
            .scrollbarVisible(false, true)
            .withSize(Small)
            .focusRing(false);
        assertTrue(table.options.stripe);
        assertFalse(table.options.bordered);
        assertEquals(false, table.options.scrollBounce);
        assertEquals(32., table.options.headerRowHeight);
        assertFalse(table.options.fixedColsBorder);
        assertFalse(table.options.scrollbarVisible.right);
        assertTrue(table.options.scrollbarVisible.bottom);
        assertTrue(table.options.size == Small);
        assertFalse(table.isFocusRingEnabled());
        assertTrue(table.focusRing(true).isFocusRingEnabled());
    }

    function testDataTableDrawsTheFocusRingByDefault() {
        final cx = keyboardFocusedTable(true);
        assertTrue(hasFocusRing(cx), 'a keyboard-focused table draws its focus ring');
    }

    function testDataTableFocusRingCanBeTurnedOff() {
        final cx = keyboardFocusedTable(false);
        assertFalse(hasFocusRing(cx), '`focusRing(false)` must not draw a ring');
    }

/// state.rs

    function testScrollBounceTableKeepsHeadersFixedAndAcceptsNewWheelInput() {
        final opened = openWindow(1920, 1080, (window, cx:Context<BounceTable>) -> new BounceTable(cx.newEntity((c:Context<TableState<BounceDelegate>>) -> new TableState(new BounceDelegate(), window, c))));
        final cx = opened.cx;
        cx.update((window, _) -> window.draw());
        final state = opened.view.read(app).state;
        final header = state.read(app).colGroups[0].bounds;
        function wheel(dy:Float) {
            cx.simulateEvent(new ScrollEvent(new Point(100., 100.), ScrollDelta.Lines(new Point(0., dy)), Modifiers.none(), TouchPhase.Moved));
        }
        for (step in [{dy: -10000., phase: TouchPhase.Started}, {dy: 0., phase: TouchPhase.Ended}]) {
            cx.simulateEvent(new ScrollEvent(new Point(100., 100.), ScrollDelta.Pixels(new Point(0., step.dy)), Modifiers.none(), step.phase));
        }
        cx.update((window, _) -> window.draw());
        final end = state.read(app).verticalScrollHandle.state.baseHandle.offset().y;
        assertTrue(end < 0.);
        cx.advanceClock(0.2);
        cx.update((window, _) -> window.draw());
        assertTrue(state.read(app).colGroups[0].bounds.equals(header));
        wheel(2.);
        assertTrue(state.read(app).verticalScrollHandle.state.baseHandle.offset().y > end);
    }

    function testColumnResizeBoundsPreserveInitialWidths() {
        final opened = openWindow(1920, 1080, (window, cx:Context<TableView<WidthsDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<WidthsDelegate>>) -> new TableState(new WidthsDelegate(), window, c)), false));
        final state = opened.view.read(app).table;
        opened.cx.update((window, app) -> state.update(app, (table, cx) -> {
            assertEquals('40,300,10,2000,2000,100', widths(cast table));

            for (ix in 0...table.colGroups.length) {
                table.resizeCols(ix, 10000., window, cx);
            }
            assertEquals('1200,120,1200,1200,2400,100', widths(cast table));

            for (ix in 0...table.colGroups.length) {
                table.resizeCols(ix, -100., window, cx);
            }
            assertEquals('80,20,20,20,20,100', widths(cast table));
        }));
    }

/// table_dump_range.rs

    function dumpTable(rows:Int, columns:Int):{state:Entity<TableState<DumpDelegate>>, delegate:DumpDelegate, cx:VisualTestContext} {
        final delegate = new DumpDelegate(rows, columns);
        final opened = openWindow(1920, 1080, (window, cx:Context<TableView<DumpDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<DumpDelegate>>) -> new TableState(delegate, window, c)), false));
        return {state: opened.view.read(app).table, delegate: delegate, cx: opened.cx};
    }

    function testDumpRangeClampsAndOnlyMaterializesRequestedRows() {
        final t = dumpTable(100, 2);
        t.delegate.cellTextCalls = 0;

        final dump = t.state.read(app).dumpRange(new Range(98, 103), app);

        assertEquals('column-0,column-1', dump.headers.join(','));
        assertEquals('row-98-column-0,row-98-column-1|row-99-column-0,row-99-column-1', [for (row in dump.rows) row.join(',')].join('|'));
        assertEquals(4, t.delegate.cellTextCalls);
    }

    function testDumpStillMaterializesTheCompleteTable() {
        final t = dumpTable(3, 2);
        t.delegate.cellTextCalls = 0;

        final dump = t.state.read(app).dump(app);

        assertEquals('column-0,column-1', dump.headers.join(','));
        assertEquals('row-0-column-0,row-0-column-1|row-1-column-0,row-1-column-1|row-2-column-0,row-2-column-1', [for (row in dump.rows) row.join(',')].join('|'));
        assertEquals(6, t.delegate.cellTextCalls);
    }

/// table_fit_column.rs

    static inline final FREE = 0;
    static inline final CAPPED = 1;
    static inline final FIXED = 2;
    static inline final CAP:Float = 120.;
    /** Fractional on purpose, so the padding is rounded up as the content is. */
    static final PADDING:Float = glaze.SpringMath.f32(8.3);

    function fitTable():{state:Entity<TableState<FitDelegate>>, delegate:FitDelegate, cx:VisualTestContext, events:Array<Array<Pixels>>} {
        final delegate = new FitDelegate();
        final opened = openWindow(1920, 1080, (window, cx:Context<TableView<FitDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<FitDelegate>>) -> new TableState(delegate, window, c)), false));
        final state = opened.view.read(app).table;
        final events:Array<Array<Pixels>> = [];
        app.update(cx -> cx.subscribe(state, TableEvent, (_, event, _) -> switch event {
            case ColumnWidthsChanged(widths): events.push(widths);
            case _:
        }));
        return {state: state, delegate: delegate, cx: opened.cx, events: events};
    }

    function fit(t:{state:Entity<TableState<FitDelegate>>, delegate:FitDelegate, cx:VisualTestContext, events:Array<Array<Pixels>>}, colIx:Int, content:Null<Float>):{width:Float, scale:Float} {
        return t.cx.update((window, app) -> t.state.update(app, (table, cx) -> {
            table.delegateMut().content = content != null ? glaze.SpringMath.f32(content) : null;
            table.fitCol(colIx, window, cx);
            return {width: (table.colWidth(colIx) : Float), scale: window.scaleFactor()};
        }));
    }

    function testAFittedColumnHoldsItsContentOnWholeDevicePixels() {
        final t = fitTable();

        // Fractional scales divide back inexactly, which the fit has to survive.
        for (scaleFactor in [1., 1.25, 1.5, 2., 3.]) {
            t.cx.update((window, _) -> window.setScaleFactor(scaleFactor));

            // One content width per tenth of a pixel, so every rounding case is hit.
            for (tenth in 0...10) {
                final content = glaze.SpringMath.f32(100. + glaze.SpringMath.f32(tenth / 10.));
                final r = fit(t, FREE, content);
                final devicePixels = glaze.SpringMath.f32(r.width * r.scale);

                assertTrue(r.width >= glaze.SpringMath.f32(content + 2. * PADDING), '$content px of content got a ${r.width} column at ${r.scale}x');
                assertTrue(Math.abs(devicePixels - Math.fround(devicePixels)) < 1e-3, '${r.width} is not a whole number of device pixels at ${r.scale}x');
                assertTrue(devicePixels < (content + 2. * PADDING) * r.scale + 4., '$content px of content got ${r.width} at ${r.scale}x, more than rounding needs');
            }
        }

        assertTrue(t.events.length > 0, 'a fit that changes the width emits');
        assertEquals((t.events[t.events.length - 1][FREE] : Float), (t.state.read(app).colWidth(FREE) : Float), 'the event carries the width the table holds');
    }

    function testAFitStaysWithinTheColumnAndEmitsOnlyOnAChange() {
        final t = fitTable();
        final free:Float = t.state.read(app).colWidth(FREE);
        final fixed:Float = t.state.read(app).colWidth(FIXED);
        t.events.resize(0);

        // No answer from the delegate, and a column that cannot be resized.
        assertEquals(free, fit(t, FREE, null).width);
        assertEquals(fixed, fit(t, FIXED, 300.).width);
        assertEquals(0, t.events.length);

        assertEquals(CAP, fit(t, CAPPED, 500.).width);
        assertEquals(1, t.events.length);
        t.events.resize(0);

        // The same content again lands on the same width.
        final first = fit(t, FREE, 100.45).width;
        t.events.resize(0);
        final second = fit(t, FREE, 100.45).width;
        assertEquals(first, second);
        assertEquals(0, t.events.length);
    }

/// collections.rs (kit integration)

    function openRecords(build:(Window, Context<Dynamic>) -> TableState<RowsDelegate>, width:Float = 640, height:Float = 320):{table:Entity<TableState<RowsDelegate>>, cx:VisualTestContext} {
        final opened = openWindow(width, height, (window, cx:Context<TableView<RowsDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<RowsDelegate>>) -> build(window, c)), false));
        return {table: opened.view.read(app).table, cx: opened.cx};
    }

    static function selection(table:TableState<Dynamic>):String {
        final cell = table.selectedCell();
        return table.selection().describe() + ' ' + table.selectedRow() + ' ' + table.selectedCol() + ' ' + (cell != null ? cell.toString() : 'null');
    }

    function testTableSelectionGettersFollowTheActiveMode() {
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c).cellSelectable(true));
        app.update(cx -> r.table.update(cx, (table, cx) -> {
            final table:TableState<Dynamic> = cast table;
            assertEquals('None null null null', selection(table));
            table.setSelectedCell(5, 1, cx);
            assertEquals('Cell(5, 1) null null (5, 1)', selection(table));
            table.setSelectedRow(3, cx);
            assertEquals('Row(3) 3 null null', selection(table));
            table.setSelectedCell(4, 0, cx);
            assertEquals('Cell(4, 0) null null (4, 0)', selection(table));
            table.setSelectedCol(1, cx);
            assertEquals('Column(1) null 1 null', selection(table));
            table.setSelectedRow(2, cx);
            assertEquals('Row(2) 2 null null', selection(table));
            table.setSelectedCol(0, cx);
            assertEquals('Column(0) null 0 null', selection(table));
            table.setSelectedCell(1, 1, cx);
            assertEquals('Cell(1, 1) null null (1, 1)', selection(table));
            table.clearSelection(cx);
            assertEquals('None null null null', selection(table));

            // `setSelection` round-trips through `selection()`.
            for (value in [TableSelection.Row(7), TableSelection.Column(1), TableSelection.Cell(3, 0), TableSelection.None]) {
                table.setSelection(value, cx);
                assertTrue(table.selection().equals(value));
            }
            assertEquals('None null null null', selection(table));
        }));
    }

    function openPressRecords(cellSelectable:Bool):{table:Entity<TableState<PressDelegate>>, cx:VisualTestContext} {
        final opened = openWindow(640, 320, (window, cx:Context<TableView<PressDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<PressDelegate>>) -> new TableState(new PressDelegate(), window, c).cellSelectable(cellSelectable)), false));
        return {table: opened.view.read(app).table, cx: opened.cx};
    }

    function testTableKeepsFocusWhenACellSelectsItsRowOnMouseDown() {
        final r = openPressRecords(false);
        // Inside the second cell, past the row header and the first column.
        clickAt(r.cx, 1. + 260., rowTop(1) + 5.);
        assertEquals(1, r.table.read(app).selectedRow());
        assertTrue(r.cx.update((window, app) -> r.table.read(app).focusHandle(app).isFocused(window)));
    }

    function testTableRowHeaderClickSelectsItsRowOnce() {
        final r = openPressRecords(true);
        final selected:Array<Int> = [];
        app.update(cx -> cx.subscribe(r.table, TableEvent, (_, event, _) -> switch event {
            case SelectRow(row): selected.push(row);
            case _:
        }).detach());
        // The row header is the narrow column before the cells.
        clickAt(r.cx, 1. + 6., rowTop(2) + 5.);
        assertEquals(2, r.table.read(app).selectedRow());
        assertEquals('2', selected.join(','));
    }

    /** Right clicks the first cell of `row`, past the row header (the table is 40 px down). */
    static function rightClickRow(cx:VisualTestContext, row:Int):Void {
        final position = new Point(1. + 100., 40. + rowTop(row) + 5.);
        cx.simulateEvent(new MouseMoveEvent(position, null, Modifiers.none()));
        renderFrame(cx);
        cx.simulateEvent(new MouseDownEvent(Right, position, Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Right, position, Modifiers.none(), 1));
        renderFrame(cx);
    }

    function testTableForgetsARightClickedCellOnTheNextClick() {
        final opened = openWindow(640, 320, (window, cx:Context<TableView<RowsDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<RowsDelegate>>) -> new TableState(new RowsDelegate(200), window, c).cellSelectable(true)), true));
        final table = opened.view.read(app).table;
        final cx = opened.cx;

        rightClickRow(cx, 1);
        assertEquals('(1, 0)', Std.string(table.read(app).rightClickedCell()));
        clickAt(cx, 1. + 100., 40. + rowTop(2) + 5.);
        assertEquals(null, table.read(app).rightClickedCell(), 'selecting another cell must clear the right-click outline');

        rightClickRow(cx, 1);
        assertEquals('(1, 0)', Std.string(table.read(app).rightClickedCell()));
        clickAt(cx, 320., 20.);
        assertEquals(null, table.read(app).rightClickedCell(), 'a click outside the table must clear the right-click outline');
    }

    function testTableRetainsNavigationPositionsWhenSelectionModeChanges() {
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c));
        r.cx.update((window, app) -> r.table.read(app).focusHandle(app).focus(window, app));
        app.update(cx -> r.table.update(cx, (table, cx) -> {
            table.setSelectedRow(5, cx);
            table.setSelectedCol(0, cx);
        }));
        renderFrame(r.cx);
        press(r.cx, 'down');
        assertEquals(6, r.table.read(app).selectedRow());
        assertEquals(null, r.table.read(app).selectedCol());
        press(r.cx, 'right');
        assertEquals(1, r.table.read(app).selectedCol());
        assertEquals(null, r.table.read(app).selectedRow());
    }

    function testTableHomeAndEndSelectTheFirstAndLastRow() {
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c));
        clickRow(r.cx, 1);
        press(r.cx, 'end');
        assertEquals(199, r.table.read(app).selectedRow());
        press(r.cx, 'home');
        assertEquals(0, r.table.read(app).selectedRow());

        // A selected column still moves to the first or last column.
        app.update(cx -> r.table.update(cx, (table, cx) -> table.setSelectedCol(0, cx)));
        press(r.cx, 'end');
        assertEquals(1, r.table.read(app).selectedCol());

        // Without selectable rows, Home and End move the column as before.
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c).rowSelectable(false));
        r.cx.update((window, app) -> r.table.read(app).focusHandle(app).focus(window, app));
        renderFrame(r.cx);
        press(r.cx, 'end');
        assertEquals(1, r.table.read(app).selectedCol());
        assertEquals(null, r.table.read(app).selectedRow());
    }

    function testTableSelectsRowsAndKeyboardScrollsVirtualizedContent() {
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c).rowSelectable(true));
        final rendered = (row:Int) -> r.table.read(app).visibleRange().rows().contains(row);
        assertFalse(rendered(150));
        clickRow(r.cx, 1);
        assertEquals(1, r.table.read(app).selectedRow());
        press(r.cx, 'down');
        assertEquals(2, r.table.read(app).selectedRow());
        for (_ in 0...30) {
            press(r.cx, 'down');
        }
        assertEquals(32, r.table.read(app).selectedRow());
        final offset = r.table.read(app).verticalScrollHandle.state.baseHandle.offset().y;
        final top = rowTop(32) + offset;
        assertTrue(top >= 0.);
        assertTrue(top + 32. <= 320.);
        assertFalse(rendered(1));
        r.cx.simulateEvent(new ScrollEvent(new Point(320., 160.), ScrollDelta.Pixels(new Point(0., 2000.)), Modifiers.none(), TouchPhase.Moved));
        renderFrame(r.cx);
        assertTrue(rendered(1));
        assertFalse(rendered(32));
    }

    function testTableKeyboardLeavesRowsUnselectedWhenRowsAreNotSelectable() {
        final r = openRecords((window, c) -> new TableState(new RowsDelegate(200), window, c).rowSelectable(false));
        clickRow(r.cx, 1);
        assertTrue(r.cx.update((window, app) -> r.table.read(app).focusHandle(app).isFocused(window)));
        assertEquals(null, r.table.read(app).selectedRow());
        for (key in ['down', 'down', 'pagedown', 'up', 'pageup']) {
            press(r.cx, key);
            assertEquals(null, r.table.read(app).selectedRow(), '`$key` moved the row selection');
        }
        assertTrue(r.table.read(app).visibleRange().rows().contains(0));
    }

    function openTableProbe(delegate:ProbeDelegate, stripe:Bool):{table:Entity<TableState<ProbeDelegate>>, cx:VisualTestContext} {
        final opened = openWindow(640, 320, (window, cx:Context<TableView<ProbeDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<ProbeDelegate>>) -> new TableState(delegate, window, c)), false, stripe));
        return {table: opened.view.read(app).table, cx: opened.cx};
    }

    function testTableReportsOneRowAndEmptyVisibleRanges() {
        final r = openTableProbe(new ProbeDelegate(1), false);
        final ranges = r.table.read(app).delegate().visibleRowRanges;
        assertEquals('0..1', Std.string(ranges[ranges.length - 1]));

        app.update(cx -> r.table.update(cx, (table, cx) -> {
            table.delegateMut().rowsCount_ = 0;
            cx.notify();
        }));
        renderFrame(r.cx);
        final ranges = r.table.read(app).delegate().visibleRowRanges;
        assertEquals('0..0', Std.string(ranges[ranges.length - 1]));
    }

    function testTableVisibleRangeStopsAtTheLastRowUnderStripeFiller() {
        final r = openTableProbe(new ProbeDelegate(3), true);
        final reported = r.table.read(app).delegate().visibleRowRanges;
        assertTrue(reported.length > 0);
        for (range in reported) assertTrue(range.end <= 3, 'reported past the last row: $reported');
    }

    function testTableReportsOneScrollableColumnWithAndWithoutFixedColumns() {
        for (leftColumnsCount in [0, 1]) {
            final delegate = new ProbeDelegate(3);
            delegate.columnsCount_ = leftColumnsCount + 1;
            delegate.leftColumnsCount = leftColumnsCount;
            final r = openTableProbe(delegate, false);
            // Column ranges are relative to the scrollable columns, excluding
            // the fixed prefix. Repeated row rendering reports a change once.
            assertEquals('0..1', r.table.read(app).delegate().visibleColumnRanges.join(','));
            assertEquals('0..1', Std.string(r.table.read(app).visibleRange().cols()));

            renderFrame(r.cx);
            assertEquals('0..1', r.table.read(app).delegate().visibleColumnRanges.join(','));
        }
    }

    function testTableModifierClicksSelectRowsUnlessTurnedOff() {
        final secondary = Modifiers.secondaryKey();
        final shift = Modifiers.shiftKey();
        for (c in [{selectOnModifierClick: true, expected: 3}, {selectOnModifierClick: false, expected: 1}]) {
            for (cellSelectable in [false, true]) {
                final r = openRecords((window, ctx) -> new TableState(new RowsDelegate(200), window, ctx)
                    .cellSelectable(cellSelectable)
                    .selectOnModifierClick(c.selectOnModifierClick));
                if (cellSelectable) {
                    // The row header, shown in cell selection, is the narrow
                    // column before the cells.
                    clickAt(r.cx, 1. + 6., rowTop(1) + 5.);
                    clickAt(r.cx, 1. + 6., rowTop(3) + 5., secondary);
                    assertEquals(c.expected, r.table.read(app).selectedRow(), 'row header');
                    clickAt(r.cx, 1. + 6., rowTop(3) + 5.);
                } else {
                    clickRow(r.cx, 1);
                    clickRow(r.cx, 3, secondary);
                    assertEquals(c.expected, r.table.read(app).selectedRow());
                    clickRow(r.cx, 3, shift);
                    assertEquals(c.expected, r.table.read(app).selectedRow());
                    clickRow(r.cx, 3);
                }
                assertEquals(3, r.table.read(app).selectedRow());
            }
        }
    }

    function testTableModifierClicksOnTheSelectedCellEscalateUnlessTurnedOff() {
        // Without a row header, the first cell starts at the row's leading edge.
        for (c in [{selectOnModifierClick: true, expected: TableSelection.Row(1)}, {selectOnModifierClick: false, expected: TableSelection.Cell(1, 0)}]) {
            final r = openRecords((window, ctx) -> new TableState(new RowsDelegate(200), window, ctx)
                .cellSelectable(true)
                .rowHeader(false)
                .selectOnModifierClick(c.selectOnModifierClick));
            clickAt(r.cx, 1. + 6., rowTop(1) + 5.);
            assertEquals('Cell(1, 0)', r.table.read(app).selection().describe());
            clickAt(r.cx, 1. + 6., rowTop(1) + 5., Modifiers.secondaryKey());
            assertEquals(c.expected.describe(), r.table.read(app).selection().describe());
        }
    }

    function testTableSortIconIsALabelledButtonThatCyclesTheSort() {
        final opened = openWindow(640, 320, (window, cx:Context<TableView<SortableDelegate>>) -> new TableView(cx.newEntity((c:Context<TableState<SortableDelegate>>) -> new TableState(new SortableDelegate(), window, c)), false));
        final table = opened.view.read(app).table;

        // Rust checks the icon's accessible role and name (no accessibility
        // tree in the port): the name the table gives it, and that only the
        // sortable column has one.
        assertEquals('Sort by Name', TableState.sortByLabel('Name'));
        assertEquals(null, table.read(app).selectedCol());

        // The icon of column 0: 12 px plus 2 px of padding on each side, at
        // the end of the 180 px cell (8 px of right padding), in the 32 px header.
        for (_ in 0...3) {
            clickAt(opened.cx, 1. + 180. - 8. - 8., 1. + 16.);
        }
        assertEquals('0:Descending,0:Ascending,0:Default', table.read(app).delegate().sorts.join(','));
        // The click also reaches the column header, which selects the column.
        assertEquals(0, table.read(app).selectedCol());
    }

}

private class RowsDelegate extends TableDelegateBase {

    final rows:Int;

    public function new(rows:Int = 3) {
        this.rows = rows;
    }

    public function columnsCount(_:App):Int {
        return rows == 3 ? 1 : 2;
    }

    public function rowsCount(_:App):Int {
        return rows;
    }

    public function column(ix:Int, _:App):Column {
        if (rows == 3) return new Column('name', 'Name');
        return new Column('column-' + ix, ix == 0 ? 'Name' : 'Status').withWidth(180.);
    }

    public function renderTd(row:Int, col:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return rows == 3 ? div().child(Std.string(row)) : div().child('$row:$col');
    }

}

private class PressDelegate extends TableDelegateBase {

    public function new() {}

    public function columnsCount(_:App):Int {
        return 2;
    }

    public function rowsCount(_:App):Int {
        return 3;
    }

    public function column(ix:Int, _:App):Column {
        return new Column('column-' + ix, 'Column ' + ix).withWidth(180.);
    }

    public function renderTd(row:Int, col:Int, _:Window, cx:Context<TableState<Dynamic>>):IntoElement {
        final cell = div().sizeFull();
        if (col == 1) {
            cell.onMouseDown(Left, cx.listener((table:TableState<Dynamic>, _, _, cx) -> table.setSelectedRow(row, cx)));
        }
        return cell;
    }

}

private class BounceDelegate extends TableDelegateBase {

    public function new() {}

    public function columnsCount(_:App):Int {
        return 1;
    }

    public function rowsCount(_:App):Int {
        return 40;
    }

    public function column(_:Int, _:App):Column {
        return new Column('value', 'Value');
    }

    public function renderTd(row:Int, _:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div().child(Std.string(row));
    }

}

private class WidthsDelegate extends TableDelegateBase {

    public function new() {}

    public function columnsCount(_:App):Int {
        return 6;
    }

    public function rowsCount(_:App):Int {
        return 0;
    }

    public function column(colIx:Int, _:App):Column {
        return switch colIx {
            case 0: new Column('narrow', 'Narrow').withMinWidth(80.).withWidth(40.);
            case 1: new Column('wide', 'Wide').withMaxWidth(120.).withWidth(300.);
            // `width` alone below the default `minWidth` of 20px.
            case 2: new Column('tiny', 'Tiny').withWidth(10.);
            // The default resize protection does not limit initial width.
            case 3: new Column('wide_default', 'Wide Default').withWidth(2000.);
            // Applications can explicitly allow wider resize ranges.
            case 4: new Column('wide_explicit', 'Wide Explicit').withMaxWidth(2400.).withWidth(2000.);
            // `minWidth` above `maxWidth` must not panic.
            case _: new Column('inverted', 'Inverted').withMinWidth(200.).withMaxWidth(100.);
        }
    }

    public function renderTd(_:Int, _:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div();
    }

}

private class DumpDelegate extends TableDelegateBase {

    final rows:Int;

    final columns:Int;

    public var cellTextCalls:Int = 0;

    public function new(rows:Int, columns:Int) {
        this.rows = rows;
        this.columns = columns;
    }

    public function columnsCount(_:App):Int {
        return columns;
    }

    public function rowsCount(_:App):Int {
        return rows;
    }

    public function column(colIx:Int, _:App):Column {
        final name = 'column-' + colIx;
        return new Column(name, name);
    }

    public function renderTd(_:Int, _:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div();
    }

    override public function cellText(rowIx:Int, colIx:Int, _:App):String {
        cellTextCalls++;
        return 'row-$rowIx-column-$colIx';
    }

}

private class FitDelegate extends TableDelegateBase {

    public var content:Null<Float> = null;

    public function new() {}

    public function columnsCount(_:App):Int {
        return 3;
    }

    public function rowsCount(_:App):Int {
        return 1;
    }

    public function column(colIx:Int, _:App):Column {
        final padding = glaze.SpringMath.f32(8.3);
        final column = new Column('column-' + colIx, 'Column ' + colIx)
            .withWidth(80.)
            .withPaddings(new Edges(0., padding, 0., padding));
        return switch colIx {
            case 1: column.withMaxWidth(120.);
            case 2: column.withResizable(false);
            case _: column;
        }
    }

    public function renderTd(_:Int, _:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div();
    }

    override public function fitColumn(_:Int, _:Window, _:Context<TableState<Dynamic>>):Null<Pixels> {
        return content;
    }

}

/** A table recording the visible row and column ranges it reports to its delegate. */
private class ProbeDelegate extends TableDelegateBase {

    public var rowsCount_:Int;

    public var columnsCount_:Int = 2;

    public var leftColumnsCount:Int = 0;

    public final visibleRowRanges:Array<Range> = [];

    public final visibleColumnRanges:Array<Range> = [];

    public function new(rowsCount:Int) {
        rowsCount_ = rowsCount;
    }

    public function columnsCount(_:App):Int {
        return columnsCount_;
    }

    public function rowsCount(_:App):Int {
        return rowsCount_;
    }

    public function column(colIx:Int, _:App):Column {
        final column = new Column('column-' + colIx, 'Column ' + colIx).withWidth(180.);
        return colIx < leftColumnsCount ? column.fixedLeft() : column;
    }

    public function renderTd(rowIx:Int, colIx:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div().child('$rowIx:$colIx');
    }

    override public function visibleRowsChanged(visibleRange:Range, _:Window, _:Context<TableState<Dynamic>>):Void {
        visibleRowRanges.push(visibleRange);
    }

    override public function visibleColumnsChanged(visibleRange:Range, _:Window, _:Context<TableState<Dynamic>>):Void {
        visibleColumnRanges.push(visibleRange);
    }

}

private class SortableDelegate extends TableDelegateBase {

    public final sorts:Array<String> = [];

    public function new() {}

    public function columnsCount(_:App):Int {
        return 2;
    }

    public function rowsCount(_:App):Int {
        return 3;
    }

    public function column(ix:Int, _:App):Column {
        final column = new Column('column-' + ix, ix == 0 ? 'Name' : 'Status').withWidth(180.);
        return ix == 0 ? column.sortable() : column;
    }

    override public function performSort(colIx:Int, sort:ColumnSort, _:Window, _:Context<TableState<Dynamic>>):Void {
        sorts.push(colIx + ':' + sort.toString());
    }

    public function renderTd(row:Int, col:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div().child('$row:$col');
    }

}

/** `div().size_full().child(DataTable::new(&table))`, or below a 40 px "outside" label (`RecordsBelowLabel`). */
private class TableView<D:TableDelegate> extends Model implements Render {

    public final table:Entity<TableState<D>>;

    final belowLabel:Bool;

    final stripe:Bool;

    public function new(table:Entity<TableState<D>>, belowLabel:Bool, stripe:Bool = false) {
        super();
        this.table = table;
        this.belowLabel = belowLabel;
        this.stripe = stripe;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        if (belowLabel) {
            return div()
                .sizeFull()
                .child(div().id('outside').h(px(40.)).child('outside'))
                .child(div().h(px(280.)).child(new DataTable(table)));
        }
        return div().sizeFull().child(new DataTable(table).stripe(stripe));
    }

}

private class FocusRingHarness extends Model implements Render {

    public final state:Entity<TableState<RowsDelegate>>;

    final focusRing:Bool;

    public function new(state:Entity<TableState<RowsDelegate>>, focusRing:Bool) {
        super();
        this.state = state;
        this.focusRing = focusRing;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .w(px(240.))
            .h(px(160.))
            .child(new DataTable(state).focusRing(focusRing));
    }

}

private class BounceTable extends Model implements Render {

    public final state:Entity<TableState<BounceDelegate>>;

    public function new(state:Entity<TableState<BounceDelegate>>) {
        super();
        this.state = state;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .w(px(240.))
            .h(px(200.))
            .child(new DataTable(state).scrollBounce(true));
    }

}
