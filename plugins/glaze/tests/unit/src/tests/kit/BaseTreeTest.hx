// Ported from gpui-kit 0.8.1: crates/base/src/tree.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.ScrollStrategy;
import glaze.StyleBuilder;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Tree;
import glaze.kit.base.Tree.TreeEvent;
import glaze.kit.base.Tree.TreeItem;
import glaze.kit.base.Tree.TreeState;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tests of gpui-base's `tree.rs`. `debug_bounds` lookups use
 * `DebugProbe`.
 */
class BaseTreeTest extends TestCase {

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

    function newState(items:Array<TreeItem>):Entity<TreeState> {
        return app.update(cx -> cx.newEntity((c:Context<TreeState>) -> new TreeState(c).items(items)));
    }

    function ids(state:TreeState):Array<String> {
        return [for (entry in state.entries) entry.item().id + ':' + entry.depth()];
    }

    function testClonesShareStateAndAncestorsKeepNearestFirstOrder() {
        final leaf = new TreeItem('leaf', 'Leaf');
        final branch = new TreeItem('branch', 'Branch').child(leaf.clone());
        final root = new TreeItem('root', 'Root').child(branch.clone());

        leaf.clone().disabled(true).expanded(true);
        assertTrue(leaf.isDisabled());
        assertTrue(leaf.isExpanded());

        final ancestors = root.ancestors('leaf');
        assertEquals('branch,root', [for (item in ancestors) item.id].join(','));
    }

    function testStateFlattensExpandedItemsAndResetsSelection() {
        final items = [
            new TreeItem('src', 'src')
                .expanded(true)
                .child(new TreeItem('src/lib.rs', 'lib.rs')),
            new TreeItem('README.md', 'README.md'),
        ];
        final state = newState(items);

        app.update(cx -> state.update(cx, (state, cx) -> {
            assertEquals(3, state.entries.length);
            assertEquals(1, state.entries[1].depth());
            state.setSelectedIndex(1, cx);
            state.setItems([new TreeItem('Cargo.toml', 'Cargo.toml')], cx);
            assertEquals(null, state.selectedIndex());
            assertEquals(1, state.entries.length);
        }));
    }

    function testSelectingHiddenItemExpandsItsAncestors() {
        final target = new TreeItem('src/ui/tree.rs', 'tree.rs');
        final root = new TreeItem('src', 'src').child(new TreeItem('src/ui', 'ui').child(target.clone()));
        final state = newState([root]);

        app.update(cx -> state.update(cx, (state, cx) -> {
            state.setSelectedItem(target, cx);
            assertEquals(3, state.entries.length);
            assertEquals('src/ui/tree.rs', state.selectedItem().id);
        }));
    }

    function testRevealingItemUnderLaterRootKeepsOtherSubtrees() {
        final guide = new TreeItem('docs/guide', 'guide').child(new TreeItem('docs/guide/a', 'a'));
        final docs = new TreeItem('docs', 'docs').expanded(true).child(guide);
        final ui = new TreeItem('src/ui', 'ui').child(new TreeItem('src/ui/tree.rs', 'tree.rs'));
        final src = new TreeItem('src', 'src').child(ui);
        final state = newState([docs, src]);

        app.update(cx -> state.update(cx, (state, cx) -> {
            assertEquals(3, state.entries.length);
            state.revealItem('src/ui/tree.rs', ScrollStrategy.Top, cx);
            assertEquals('docs:0,docs/guide:1,src:0,src/ui:1,src/ui/tree.rs:2', ids(state).join(','));
            assertTrue(state.entries[0].isFolder());
            assertEquals(1, state.entries[0].item().children.length);

            state.toggleExpand(1, cx);
            assertEquals(2, state.indexOf('docs/guide/a'));
        }));
    }

    /**
     * Paints a tree of `items` in a test window and returns the center of
     * its first entry.
     */
    function openTree(items:Array<TreeItem>, draggable:Bool):{state:Entity<TreeState>, cx:VisualTestContext, entry:Point} {
        final state = newState(items);
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new TreeHarness(state, draggable));
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        final bounds = DebugProbe.bounds('tree-entry-0');
        assertNotNull(bounds, 'the first entry is painted');
        return {state: state, cx: opened.cx, entry: bounds.center()};
    }

    static function folder():TreeItem {
        return new TreeItem('src', 'src').child(new TreeItem('src/lib.rs', 'lib.rs'));
    }

    function testEntriesSelectAndToggleOnClickNotMouseDown() {
        final t = openTree([folder()], false);
        final cx = t.cx;

        // A press alone (e.g. the start of a drag) must not select or expand.
        cx.simulateMouseDown(t.entry, MouseButton.Left);
        assertEquals(null, t.state.read(app).selectedIndex());
        assertEquals(1, t.state.read(app).entries.length);
        // Releasing away from the entry cancels the click.
        cx.simulateEvent(new MouseUpEvent(Left, new Point(10., 500.), Modifiers.none(), 1));
        cx.update((window, _) -> window.draw());
        assertEquals(null, t.state.read(app).selectedIndex());

        cx.simulateClick(t.entry);
        assertEquals(0, t.state.read(app).selectedIndex());
        assertEquals(2, t.state.read(app).entries.length);
    }

    function testDraggingAnEntryWithOnDragDoesNotSelectOrToggleIt() {
        final t = openTree([folder()], true);
        final cx = t.cx;

        // Start a drag, then drop it back on the entry it started from.
        cx.simulateMouseDown(t.entry, MouseButton.Left);
        cx.simulateMouseMove(t.entry.add(new Point(8., 0.)), MouseButton.Left);
        cx.update((window, _) -> window.draw());
        cx.simulateMouseUp(t.entry, MouseButton.Left);

        assertEquals(null, t.state.read(app).selectedIndex());
        assertEquals(1, t.state.read(app).entries.length);
    }

    function testRightClickNeitherSelectsNorToggles() {
        final t = openTree([folder()], false);
        final cx = t.cx;

        cx.simulateMouseDown(t.entry, MouseButton.Right);
        cx.simulateMouseUp(t.entry, MouseButton.Right);

        assertEquals(0, t.state.read(app).rightClickedIx);
        assertEquals(null, t.state.read(app).selectedIndex());
        assertEquals(1, t.state.read(app).entries.length);
    }

    function testClickingADisabledEntryDoesNothing() {
        final t = openTree([folder().disabled(true)], false);

        t.cx.simulateClick(t.entry);

        assertEquals(null, t.state.read(app).selectedIndex());
        assertEquals(1, t.state.read(app).entries.length);
    }

    function testTogglingFolderRebuildsVisibleEntries() {
        final root = new TreeItem('src', 'src').child(new TreeItem('src/lib.rs', 'lib.rs'));
        final state = newState([root]);

        app.update(cx -> state.update(cx, (state, cx) -> {
            state.toggleExpand(0, cx);
            assertEquals(2, state.entries.length);
            state.toggleExpand(0, cx);
            assertEquals(1, state.entries.length);
        }));
    }

    function testExpansionEventsPreserveIdsAndSetItemsStaysSilent() {
        final root = new TreeItem('src', 'src').child(new TreeItem('src/lib.rs', 'lib.rs'));
        final state = newState([root]);
        final events:Array<String> = [];
        final subscription = app.update(cx -> cx.subscribe(state, TreeEvent, (_, event, _) -> events.push(Std.string(event))));

        app.update(cx -> state.update(cx, (state, cx) -> {
            state.toggleExpand(0, cx);
            state.toggleExpand(0, cx);
            state.setItems([new TreeItem('README.md', 'README.md')], cx);
        }));

        assertEquals('Expanded(src),Collapsed(src)', events.join(','));
        subscription.dispose();
    }

}

private class DraggedEntry extends Model implements Render {

    public function new() {
        super();
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div();
    }

}

private class TreeHarness extends Model implements Render {

    final state:Entity<TreeState>;

    final draggable:Bool;

    public function new(state:Entity<TreeState>, draggable:Bool) {
        super();
        this.state = state;
        this.draggable = draggable;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final draggable = this.draggable;
        return div().sizeFull().child(new Tree(state)
            .sizeFull()
            .listStyle(StyleBuilder.build(s -> s.sizeFull()))
            .item((ix, _, _, _, _) -> {
                final entry = div()
                    .id(glaze.ElementId.NamedInteger('tree-entry', ix))
                    .h(px(20.))
                    .wFull();
                if (draggable) {
                    entry.onDrag(ix, (_, _, _, cx) -> (cx.newEntity((_:Context<DraggedEntry>) -> new DraggedEntry()) : AnyView));
                }
                return new DebugProbe('tree-entry-' + ix, entry).intoAnyElement();
            }));
    }

}
