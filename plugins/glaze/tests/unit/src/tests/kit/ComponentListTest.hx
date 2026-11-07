// Ported from gpui-kit 0.8.1: crates/component/src/list/cache.rs, crates/component/src/list/list.rs,
// crates/component/src/list/list_item.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.Component;
import glaze.kit.list.List;
import glaze.kit.list.ListDelegate.ListDelegateBase;
import glaze.kit.list.ListDelegate.ListDelegateItem;
import glaze.kit.list.ListItem;
import glaze.kit.list.ListState;
import glaze.kit.list.RowsCache;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The tests of gpui-component's list: the flattened rows cache
 * (`cache.rs`), the row measurement and the scroll bounce of `ListState`
 * (`list.rs`), and the interactivity of `ListItem` (`list_item.rs`).
 *
 * `list_state_has_list_role` is not ported: the port has no accessibility
 * tree (the role is a comment in `ListState.render`).
 */
class ComponentListTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    static function buildEntities(sections:Array<Int>):Array<RowEntry> {
        final result:Array<RowEntry> = [];
        for (section in 0...sections.length) {
            final itemsCount = sections[section];
            if (itemsCount == 0) continue;

            result.push(SectionHeader(section));
            for (row in 0...itemsCount) {
                result.push(Entry(new IndexPath(row, section)));
            }
            result.push(SectionFooter(section));
        }
        return result;
    }

    static inline function ip(row:Int, section:Int):IndexPath {
        return new IndexPath(row).withSection(section);
    }

    function assertPath(expected:IndexPath, actual:IndexPath, ?pos:haxe.PosInfos) {
        assertEquals(expected.toString(), actual.toString(), pos);
    }

    /// cache.rs

    function testFirstEntryPositionSkipsSectionHeaders() {
        final rowCache = new RowsCache();
        rowCache.entities = buildEntities([2]);

        assertEquals(1, rowCache.firstEntryPosition());
    }

    function testPrevNext() {
        final rowCache = new RowsCache();
        rowCache.sections = [2, 4, 3];
        rowCache.entities = buildEntities([2, 4, 3]);

        assertPath(ip(1, 0), rowCache.next(ip(0, 0)));
        assertPath(ip(0, 1), rowCache.next(ip(1, 0)));
        assertPath(ip(1, 1), rowCache.next(ip(0, 1)));
        assertPath(ip(0, 2), rowCache.next(ip(3, 1)));
        assertPath(ip(1, 2), rowCache.next(ip(0, 2)));
        assertPath(ip(2, 2), rowCache.next(ip(1, 2)));
        assertPath(ip(0, 0), rowCache.next(ip(2, 2)));

        assertPath(ip(2, 2), rowCache.prev(ip(0, 0)));
        assertPath(ip(0, 0), rowCache.prev(ip(1, 0)));
        assertPath(ip(1, 0), rowCache.prev(ip(0, 1)));
        assertPath(ip(0, 1), rowCache.prev(ip(1, 1)));
        assertPath(ip(2, 1), rowCache.prev(ip(3, 1)));
        assertPath(ip(3, 1), rowCache.prev(ip(0, 2)));
    }

    function testPrevNextWithEmptySections() {
        final rowCache = new RowsCache();
        rowCache.sections = [2, 0, 3, 0, 1];
        rowCache.entities = buildEntities([2, 0, 3, 0, 1]);

        // Test next: should skip empty sections
        assertPath(ip(1, 0), rowCache.next(ip(0, 0)));
        assertPath(ip(0, 2), rowCache.next(ip(1, 0)));
        assertPath(ip(1, 2), rowCache.next(ip(0, 2)));
        assertPath(ip(0, 4), rowCache.next(ip(2, 2)));
        assertPath(ip(0, 0), rowCache.next(ip(0, 4)));

        // Test prev: should skip empty sections
        assertPath(ip(0, 4), rowCache.prev(ip(0, 0)));
        assertPath(ip(1, 0), rowCache.prev(ip(0, 2)));
        assertPath(ip(2, 2), rowCache.prev(ip(0, 4)));
        assertPath(ip(0, 2), rowCache.prev(ip(1, 2)));
        assertPath(ip(1, 2), rowCache.prev(ip(2, 2)));
    }

    /// list.rs

    function openView<V:Model & Render>(build:(Window, Context<V>) -> V, width:Float = 300, height:Float = 300):Entity<V> {
        var view:Entity<V> = null;
        app.update(cx -> {
            window = Window.open(cx, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                view = cx.newEntity((c:Context<V>) -> build(window, c));
                return view;
            });
        });
        dispatcher.runUntilParked();
        return view;
    }

    function draw():Void {
        app.update(_ -> {
            window.refresh();
            window.draw();
        });
        dispatcher.runUntilParked();
    }

    function testScrollBounceListAcceptsAReverseWheelDuringReturn() {
        final view = openView((window, cx:Context<BounceList>) -> new BounceList(cx.newEntity((c:Context<ListState<CountsDelegate>>) -> new ListState(new CountsDelegate([40]), window, c))), 640, 480);
        draw();
        final state = view.read(app).state;
        final position = new Point(100., 100.);
        for (step in [{dy: -10000., phase: TouchPhase.Started}, {dy: 0., phase: TouchPhase.Ended}]) {
            app.update(cx -> window.dispatchEvent(new ScrollEvent(position, ScrollDelta.Pixels(new Point(0., step.dy)), Modifiers.none(), step.phase), cx));
            dispatcher.runUntilParked();
        }
        draw();
        final end = state.read(app).scrollHandle.offset().y;
        assertTrue(end < 0.);
        dispatcher.advanceClock(0.2);
        draw();
        app.update(cx -> window.dispatchEvent(new ScrollEvent(position, ScrollDelta.Lines(new Point(0., 2.)), Modifiers.none(), TouchPhase.Moved), cx));
        dispatcher.runUntilParked();
        assertTrue(state.read(app).scrollHandle.offset().y > end);
    }

    function testMeasuresAnExistingRowWhenTheRequestedItemIsAbsent() {
        openView((window, cx:Context<ProbeView>) -> new ProbeView());
        app.update(cx -> {
            final list = cx.newEntity((c:Context<ListState<CountsDelegate>>) -> new ListState(new CountsDelegate([0, 2]), window, c));
            list.update(cx, (list, cx) -> {
                for (step in [
                    {requested: IndexPath.defaultValue(), expectedHeight: 36.},
                    {requested: ip(1, 1), expectedHeight: 48.},
                    {requested: ip(99, 1), expectedHeight: 36.},
                    {requested: ip(0, 99), expectedHeight: 36.},
                ]) {
                    list.setItemToMeasureIndex(step.requested, window, cx);
                    list.prepareItemsIfNeeded(window, cx);
                    final position = list.rowsCache.positionOf(ip(0, 1));
                    assertEquals(step.expectedHeight, list.rowsCache.entriesSizes[position].height);
                    assertTrue(list.itemToMeasureIndex.equals(step.requested));
                }
                final requested = ip(1, 1);
                list.setItemToMeasureIndex(requested, window, cx);
                // Filtering removes the requested row, then all rows, before restoring it.
                for (step in [
                    {counts: [0, 2], expectedHeight: (48. : Null<Float>)},
                    {counts: [0, 1], expectedHeight: (36. : Null<Float>)},
                    {counts: [0, 0], expectedHeight: (null : Null<Float>)},
                    {counts: [0, 2], expectedHeight: (48. : Null<Float>)},
                ]) {
                    list.delegate().counts = step.counts;
                    list.prepareItemsIfNeeded(window, cx);
                    if (step.expectedHeight != null) {
                        final position = list.rowsCache.positionOf(ip(0, 1));
                        assertEquals(step.expectedHeight, list.rowsCache.entriesSizes[position].height);
                    } else {
                        assertEquals(0, list.rowsCache.itemsCount());
                        assertEquals(0, list.rowsCache.entriesSizes.length);
                    }
                    assertTrue(list.itemToMeasureIndex.equals(requested));
                }
            });
        });
    }

    /// list_item.rs

    function testListItemInteractivity() {
        final item = new ListItem('item');
        item.base
            .onDrag(0, (_, _, _, cx) -> (cx.newEntity((c:Context<ProbeView>) -> new ProbeView()) : glaze.AnyView))
            .onHover((_, _, _) -> {});

        assertEquals('Name(item)', Std.string(item.base.elementId()));
    }

}

private class CountsDelegate extends ListDelegateBase {

    public var counts:Array<Int>;

    public function new(counts:Array<Int>) {
        this.counts = counts;
    }

    override public function sectionsCount(_:App):Int {
        return counts.length;
    }

    public function itemsCount(section:Int, _:App):Int {
        return counts[section];
    }

    public function setSelectedIndex(_:Null<IndexPath>, _:Window, _:Context<ListState<Dynamic>>):Void {}

    public function renderItem(index:IndexPath, _:Window, _:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        if (index.section >= counts.length) return null;
        return index.row < counts[index.section] ? new ListItem(index.row).h(px(index.row == 0 ? 36. : 48.)) : null;
    }

}

private class BounceList extends Model implements Render {

    public final state:Entity<ListState<CountsDelegate>>;

    public function new(state:Entity<ListState<CountsDelegate>>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .w(px(240.))
            .h(px(200.))
            .child(new List(state).scrollBounce(true).sizeFull());
    }

}

private class ProbeView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}
