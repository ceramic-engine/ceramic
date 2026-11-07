// Ported from gpui-pre 0.3.10: src/tab_stop.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.FocusHandle;
import gpui.TabStopMap;
import gpui.TestDispatcher;
import testing.TestCase;

/**
 * Tests of the tab order (`TabStopMap`).
 */
class TabStopTest extends TestCase {

    var app:App;

    override function setup() {
        app = new App(new TestDispatcher());
    }

    function handle():FocusHandle {
        return app.focusHandle();
    }

    static function idOf(handle:Null<FocusHandle>):Int {
        return handle == null ? -1 : handle.id;
    }

    function testTabHandles() {
        final tabIndexMap = new TabStopMap();

        final focusHandles = [
            handle().tabStop(true).tabIndex(0),
            handle().tabStop(true).tabIndex(1),
            handle().tabStop(true).tabIndex(1),
            handle(),
            handle().tabIndex(2),
            handle().tabStop(true).tabIndex(0),
            handle().tabStop(true).tabIndex(2),
        ];

        for (h in focusHandles) {
            tabIndexMap.insert(h);
        }
        final expected = [
            focusHandles[0],
            focusHandles[5],
            focusHandles[1],
            focusHandles[2],
            focusHandles[6],
        ];

        var prev = -1;
        final found:Array<Int> = [];
        for (_ in 0...expected.length) {
            final h = tabIndexMap.next(prev);
            prev = h.id;
            found.push(h.id);
        }
        assertEquals([for (h in expected) h.id].join(','), found.join(','));

        // Select first tab index if no handle is currently focused.
        assertEquals(expected[0], tabIndexMap.next(-1));
        // Select last tab index if no handle is currently focused.
        assertEquals(expected[expected.length - 1], tabIndexMap.prev(-1));

        assertEquals(expected[1], tabIndexMap.next(expected[0].id));
        assertEquals(expected[2], tabIndexMap.next(expected[1].id));
        assertEquals(expected[3], tabIndexMap.next(expected[2].id));
        assertEquals(expected[4], tabIndexMap.next(expected[3].id));
        assertEquals(expected[0], tabIndexMap.next(expected[4].id));

        // prev
        assertEquals(expected[4], tabIndexMap.prev(-1));
        assertEquals(expected[4], tabIndexMap.prev(expected[0].id));
        assertEquals(expected[0], tabIndexMap.prev(expected[1].id));
        assertEquals(expected[1], tabIndexMap.prev(expected[2].id));
        assertEquals(expected[2], tabIndexMap.prev(expected[3].id));
        assertEquals(expected[3], tabIndexMap.prev(expected[4].id));
    }

    function testTabNonStopFiltering() {
        final tabIndexMap = new TabStopMap();

        // Check that we can query next from a non-stop tab
        final tabNonStop1 = handle().tabStop(false).tabIndex(1);
        final tabStop2 = handle().tabStop(true).tabIndex(2);
        tabIndexMap.insert(tabNonStop1);
        tabIndexMap.insert(tabStop2);
        assertEquals(tabStop2.id, idOf(tabIndexMap.next(tabNonStop1.id)));

        // Check that we skip over non-stop tabs
        final tabStop0 = handle().tabStop(true).tabIndex(0);
        final tabNonStop0 = handle().tabStop(false).tabIndex(0);
        tabIndexMap.insert(tabStop0);
        tabIndexMap.insert(tabNonStop0);
        assertEquals(tabStop2.id, idOf(tabIndexMap.next(tabStop0.id)));
    }

    function testWithDisabledTabStop() {
        new TabStopMapTest(this, app)
            .tabStop(0, 0)
            .tabNonStop(1)
            .tabStop(2, 1)
            .tabStop(3, 2)
            .check();
    }

    function testWithMultipleDisabledTabStops() {
        new TabStopMapTest(this, app)
            .tabNonStop(0)
            .tabStop(1, 0)
            .tabNonStop(3)
            .tabStop(3, 1)
            .tabNonStop(4)
            .check();
    }

    function testTabGroupFunctionality() {
        new TabStopMapTest(this, app)
            .tabStop(0, 0)
            .tabStop(0, 1)
            .tabGroup(2, t -> t.tabStop(0, 2).tabStop(1, 3))
            .tabStop(3, 4)
            .tabStop(4, 5)
            .check();
    }

    function testSiblingGroups() {
        new TabStopMapTest(this, app)
            .tabStop(0, 0)
            .tabStop(1, 1)
            .tabGroup(2, t -> t.tabStop(0, 2).tabStop(1, 3))
            .tabStop(3, 4)
            .tabStop(4, 5)
            .tabGroup(6, t -> t.tabStop(0, 6).tabStop(1, 7))
            .tabStop(7, 8)
            .tabStop(8, 9)
            .check();
    }

    function testNestedGroup() {
        new TabStopMapTest(this, app)
            .tabStop(0, 0)
            .tabStop(1, 1)
            .tabGroup(2, t -> t.tabGroup(0, t -> t.tabStop(0, 2).tabStop(1, 3)).tabStop(1, 4))
            .tabStop(3, 5)
            .tabStop(4, 6)
            .check();
    }

    function testSiblingNestedGroups() {
        new TabStopMapTest(this, app)
            .tabStop(0, 0)
            .tabStop(1, 1)
            .tabGroup(2, builder -> builder
                .tabStop(0, 2)
                .tabStop(2, 5)
                .tabGroup(1, builder -> builder.tabStop(0, 3).tabStop(1, 4))
                .tabGroup(3, builder -> builder.tabStop(0, 6).tabStop(1, 7))
            )
            .tabStop(3, 8)
            .tabStop(4, 9)
            .check();
    }

    function testSiblingNestedGroupsOutOfOrder() {
        new TabStopMapTest(this, app)
            .tabStop(9, 9)
            .tabStop(8, 8)
            .tabGroup(7, builder -> builder
                .tabStop(0, 2)
                .tabStop(2, 5)
                .tabGroup(3, builder -> builder.tabStop(1, 7).tabStop(0, 6))
                .tabGroup(1, builder -> builder.tabStop(0, 3).tabStop(1, 4))
            )
            .tabStop(3, 0)
            .tabStop(4, 1)
            .check();
    }

    @:allow(tests.TabStopMapTest)
    function checkEquals(expected:String, actual:String, message:String):Void {
        assertEquals(expected, actual, message);
    }

}

/**
 * Builds a tab order and checks its traversal in both directions (Rust `TabStopMapTest`).
 */
private class TabStopMapTest {

    final test:TabStopTest;

    final app:App;

    final tabMap:TabStopMap = new TabStopMap();

    final expected:Array<{order:Int, id:Int}> = [];

    public function new(test:TabStopTest, app:App) {
        this.test = test;
        this.app = app;
    }

    public function tabNonStop(index:Int):TabStopMapTest {
        final handle = app.focusHandle().tabStop(false).tabIndex(index);
        tabMap.insert(handle);
        return this;
    }

    public function tabStop(index:Int, expectedOrder:Int):TabStopMapTest {
        final handle = app.focusHandle().tabStop(true).tabIndex(index);
        tabMap.insert(handle);
        expected.push({order: expectedOrder, id: handle.id});
        // Stable sort by expected order, like Rust `sort_by_key`
        haxe.ds.ArraySort.sort(expected, (a, b) -> a.order - b.order);
        return this;
    }

    public function tabGroup(tabIndex:Int, children:(TabStopMapTest) -> TabStopMapTest):TabStopMapTest {
        tabMap.beginGroup(tabIndex);
        children(this);
        tabMap.endGroup();
        return this;
    }

    function traverseTabMap(traverse:(TabStopMap, Int) -> Null<FocusHandle>):Array<Int> {
        var lastFocusId = -1;
        final found:Array<Int> = [];
        for (_ in 0...expected.length) {
            final handle = traverse(tabMap, lastFocusId);
            lastFocusId = handle.id;
            found.push(handle.id);
        }
        return found;
    }

    public function check():Void {
        final expectedIds = [for (e in expected) e.id];

        // Check next order
        final forwardFound = traverseTabMap((tabMap, prev) -> tabMap.next(prev));
        test.checkEquals(expectedIds.join(','), forwardFound.join(','), 'next order');

        // Test overflow. Last to first
        test.checkEquals(Std.string(expectedIds[0]), Std.string(idOf(tabMap.next(forwardFound[forwardFound.length - 1]))), 'next overflow');

        // Check previous order
        final reversedFound = traverseTabMap((tabMap, prev) -> tabMap.prev(prev));
        expectedIds.reverse();
        test.checkEquals(expectedIds.join(','), reversedFound.join(','), 'prev order');

        // Test overflow. First to last
        test.checkEquals(Std.string(expectedIds[0]), Std.string(idOf(tabMap.prev(reversedFound[reversedFound.length - 1]))), 'prev overflow');
    }

    static function idOf(handle:Null<FocusHandle>):Int {
        return handle == null ? -1 : handle.id;
    }

}
