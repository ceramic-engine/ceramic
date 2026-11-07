// Ported from gpui-kit 0.8.1: crates/component/src/tree.rs (tests)
// and crates/kit/tests/integration/collections.rs (tree_pointer_and_keyboard_expand_collapse_and_select_nodes)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.Component;
import glaze.kit.list.ListItem;
import glaze.kit.tree.Tree;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The test of gpui-component's `tree.rs` and the tree test of gpui-kit's
 * `collections` integration test.
 *
 * The kit test finds entries by id (`window.find(0usize)`); the port has no
 * UI query layer, so it clicks inside the first entry and reads the state
 * the queries reflect (expanded, label, selected).
 */
class ComponentTreeTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function testLegacyTreeTypesAreBaseTypes() {
        function acceptsBase(item:glaze.kit.base.Tree.TreeItem):String {
            return item.id;
        }
        assertEquals('id', acceptsBase(new TreeItem('id', 'Label')));
    }

    static function renderFrame(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.runUntilParked();
    }

    function testTreePointerAndKeyboardExpandCollapseAndSelectNodes() {
        var tree:Null<Entity<TreeState>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final content = rootCx.newEntity((c:Context<Files>) -> {
                tree = c.newEntity((tc:Context<TreeState>) -> new TreeState(tc).items([
                    new TreeItem('src', 'src').child(new TreeItem('main', 'main.rs')),
                    new TreeItem('tests', 'tests'),
                ]));
                tree.update(c, (tree, cx) -> tree.focus(window, cx));
                return new Files(tree);
            });
            return new Root(content, window, rootCx);
        }, 480, 320);
        contexts.push(opened.cx);
        final cx = opened.cx;
        renderFrame(cx);

        final state = () -> tree.read(app);
        assertEquals(false, state().entry(0).isExpanded());
        // Rust `window.click(0usize)`: inside the first entry.
        final position = new Point(20., 8.);
        cx.simulateEvent(new MouseMoveEvent(position, null, Modifiers.none()));
        cx.simulateEvent(new MouseDownEvent(Left, position, Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, position, Modifiers.none(), 1));
        renderFrame(cx);
        assertEquals(true, state().entry(0).isExpanded());
        assertEquals('main.rs', state().entry(1).item().label);
        cx.simulateKeystrokes('left');
        renderFrame(cx);
        assertEquals(false, state().entry(0).isExpanded());
        assertEquals('tests', state().entry(1).item().label);
        cx.simulateKeystrokes('right');
        renderFrame(cx);
        cx.simulateKeystrokes('down');
        renderFrame(cx);
        assertEquals(1, state().selectedIndex());
    }

}

private class Files extends Model implements Render {

    final tree:Entity<TreeState>;

    public function new(tree:Entity<TreeState>) {
        super();
        this.tree = tree;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(new Tree(tree, (ix, entry, _, _, _) -> new ListItem(ElementId.NamedInteger('file', ix)).child(entry.item().label)));
    }

}
