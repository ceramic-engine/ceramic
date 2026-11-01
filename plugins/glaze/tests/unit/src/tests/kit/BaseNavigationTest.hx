// Ported from gpui-kit 0.8.1: crates/base/src/pagination.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Range;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Pagination;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.Pagination.PaginationItemTools;

/**
 * The tests of gpui-base's `pagination.rs`.
 */
class BaseNavigationTest extends TestCase {

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

    /** `cx.add_empty_window()` then `window.update(f)`. */
    function withWindow(f:(Window, App) -> Void):Void {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> div()));
        contexts.push(opened.cx);
        opened.cx.update(f);
    }

    static function describe(items:Array<PaginationItem>):String {
        return [for (item in items) item.toString()].join(', ');
    }

    function testClampsControlledValuesAndNavigationBoundaries() {
        final first = new PaginationState(0, 0);
        assertEquals(1, first.currentPage());
        assertEquals(1, first.totalPages());
        assertNull(first.previousPage());
        assertNull(first.nextPage());

        final last = new PaginationState(20, 10);
        assertEquals(10, last.currentPage());
        assertEquals(9, last.previousPage());
        assertNull(last.nextPage());
        assertNull(last.clone().disabled(true).previousPage());
    }

    function testCreatesPagesAndNavigableEllipsisRanges() {
        final expected = [
            Page(1),
            Ellipsis(new Range(2, 3)),
            Page(3),
            Page(4),
            Page(5),
            Page(6),
            Page(7),
            Ellipsis(new Range(8, 10)),
            Page(10),
        ];
        final items = new PaginationState(5, 10).visiblePages(7).items();
        assertEquals(describe(expected), describe(items));
        assertEquals(expected.length, items.length);
        for (i in 0...expected.length) assertTrue(expected[i].equals(items[i]));
    }

    function testValidatesEveryPageChangeRequest() {
        withWindow((window, cx) -> {
            var requested:Null<Int> = null;
            final state = new PaginationState(3, 5).onChange((page, _, _) -> requested = page);

            state.requestPage(3, window, cx);
            state.requestPage(0, window, cx);
            state.requestPage(6, window, cx);
            assertNull(requested);

            state.requestPage(4, window, cx);
            assertEquals(4, requested);
            requested = null;
            state.clone().disabled(true).requestPage(2, window, cx);
            assertNull(requested);
        });
    }

    function testExposesANamedNavigationLandmark() {
        final pagination = new Pagination('pagination', new PaginationState(1, 5))
            .accessibilityLabel('Search results pages');
        withWindow((window, cx) -> {
            pagination.render(window, cx);
        });

        assertEquals(Role.Navigation, pagination.a11y.role);
        assertEquals('Search results pages', pagination.a11y.label);
    }

}
