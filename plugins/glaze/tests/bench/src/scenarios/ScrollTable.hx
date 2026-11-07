package scenarios;

import Scenario;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Modifiers;
import glaze.Point;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.Window;
import glaze.kit.table.Column;
import glaze.kit.table.DataTable;
import glaze.kit.table.TableDelegate.TableDelegateBase;
import glaze.kit.table.TableState;

import glaze.Prelude.*;

/**
 * A gpui-kit `DataTable` of 10 000 rows and 8 columns of deterministic data
 * (computed from the row and column indices, no random, no dates) filling
 * the standard window. `step` dispatches a scroll wheel event of one row
 * height (32 px, the medium table row) at the table center, like the golden
 * `scroll` steps.
 */
class ScrollTable extends BaseScenario {

    public static inline final ROW_COUNT = 10000;

    public static inline final COLUMN_COUNT = 8;

    /** The medium table row height (`Size.tableRowHeight`). */
    public static inline final ROW_HEIGHT:Float = 32;

    public static inline final PADDING:Float = 12;

    /** Elements created by a full draw (needs `glaze_count_allocations`). */
    public var elementCount:Int = 0;

    var app:App;

    var window:Window;

    var table:Entity<TableState<BenchGrid>>;

    var center:Point;

    public function new() {
        super('scroll-table');
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        KitBench.initKit(app);
        window = KitBench.openWindow(app, caching, (window, cx) -> {
            table = cx.newEntity((c:Context<TableState<BenchGrid>>) -> new TableState(new BenchGrid(), window, c));
            final table = this.table;
            return cx.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
                div().sizeFull().p(px(PADDING)).child(new DataTable(table))
            ));
        });
        center = new Point(KitBench.WIDTH / 2, KitBench.HEIGHT / 2);
        elementCount = KitBench.countElements(window);
        return window;
    }

    override function step(frame:Int):Void {
        KitBench.dispatch(app, window, new ScrollEvent(center, ScrollDelta.Pixels(new Point(0, -ROW_HEIGHT)), Modifiers.none()));
    }

    /** The text of one cell, computed from its indices. */
    public static function cell(rowIx:Int, colIx:Int):String {
        return switch (colIx) {
            case 0: Std.string(rowIx);
            case 1: 'Item $rowIx';
            case 2: 'Group ${rowIx % 17}';
            case 3: BenchGrid.STATUSES[rowIx % BenchGrid.STATUSES.length];
            case 4: Std.string((rowIx * 37) % 1000);
            case 5: Std.string((rowIx % 100) / 100);
            case 6: 'C-${StringTools.hex((rowIx * 7919) & 0xFFFFFF, 6)}';
            case _: 'Row $rowIx of ${ROW_COUNT}, column $colIx';
        }
    }

}

/** The table data: 10 000 rows, 8 columns, every cell computed from its indices. */
class BenchGrid extends TableDelegateBase {

    static final NAMES = ['#', 'Name', 'Group', 'Status', 'Count', 'Ratio', 'Code', 'Note'];

    public static final STATUSES = ['active', 'paused', 'closed', 'pending', 'archived'];

    public function new() {}

    public function columnsCount(_:App):Int {
        return ScrollTable.COLUMN_COUNT;
    }

    public function rowsCount(_:App):Int {
        return ScrollTable.ROW_COUNT;
    }

    public function column(colIx:Int, _:App):Column {
        if (colIx == 0) return new Column('n', NAMES[0]).withWidth(70.).fixedLeft();
        return new Column('c' + colIx, NAMES[colIx]).withWidth(colIx == 7 ? 300. : 130.);
    }

    public function renderTd(rowIx:Int, colIx:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return div().child(ScrollTable.cell(rowIx, colIx));
    }

}
