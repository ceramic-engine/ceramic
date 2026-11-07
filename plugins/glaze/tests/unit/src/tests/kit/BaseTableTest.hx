// Ported from gpui-kit 0.8.1: crates/base/src/table.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Point;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Table;
import gpui.base.Table.TableBody;
import gpui.base.Table.TableCell;
import gpui.base.Table.TableHead;
import gpui.base.Table.TableRow;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The tests of gpui-base's `table.rs`.
 *
 * The accessibility tests read the `A11y` data the parts export after
 * rendering (the port has no accesskit tree). `debug_bounds` lookups use
 * `DebugProbe`.
 */
class BaseTableTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        DebugProbe.clear();
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        return opened.cx;
    }

    function testTableProjectsItsAccessibleName() {
        final table = new Table('positions').accessibilityLabel('Open positions');
        open((_, _) -> div().child(table));

        assertEquals(Role.Table, table.a11y.role);
        assertEquals('Open positions', table.a11y.label);
    }

    function testRowAndCellsProjectAccessibilityIndices() {
        final row = new TableRow('row', 3);
        final head = new TableHead('head', 2);
        final cell = new TableCell('cell', 4);
        open((_, _) -> div().child(row).child(head).child(cell));

        assertEquals(3, row.a11y.rowIndex);
        assertEquals(2, head.a11y.columnIndex);
        assertEquals(4, cell.a11y.columnIndex);
    }

    function testTableForwardsChildrenInstanceStyleAndPointerInteraction() {
        var clicks = 0;
        final cx = open((_, _) -> new DebugProbe('base-table', new Table('table')
            .w(px(120.))
            .h(px(60.))
            .onClick((_, _, _) -> clicks++)
            .child(new TableBody('body').child(new TableRow('row', 1)
                .child(new TableCell('cell', 1).child(new DebugProbe('table-child', div().size(px(20.)))))))));

        final table = DebugProbe.bounds('base-table');
        assertNotNull(table, 'table is rendered');
        assertEquals(120., table.size.width);
        assertEquals(60., table.size.height);
        final child = DebugProbe.bounds('table-child');
        assertNotNull(child, 'child is rendered');
        assertEquals(20., child.size.width);
        assertEquals(20., child.size.height);

        cx.simulateClick(new Point(10., 10.));
        cx.simulateClick(new Point(100., 50.));
        assertEquals(2, clicks);
    }

}
