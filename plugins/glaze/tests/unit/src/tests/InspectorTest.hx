// Ported from gpui-pre 0.3.10: src/window.rs (`inspector_tests`), src/inspector.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

#if gpui_inspector

import gpui.App;
import gpui.Context;
import gpui.DivInspectorState;
import gpui.Entity;
import gpui.InspectorElementId;
import gpui.IntoElement;
import gpui.Length;
import gpui.LengthTools;
import gpui.Model;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.StyleBuilder;
import gpui.TestDispatcher;
import gpui.Window;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * GPUI's inspector (Rust feature `inspector`, define `gpui_inspector`):
 * the test of `window.rs` (`inspector_only_tracks_its_open_window`), plus
 * checks of picking, hover depth and the inspector panel's layout.
 *
 * Differences with the Rust test: the port's `Div` has no
 * `with_dynamic_prepaint_order`, so the children are prepainted in order
 * (the assertions do not depend on it: instance ids follow the request
 * layout order, and the prepaint listener reports the bounds in child order).
 */
class InspectorTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function addWindow(width:Float = 1024, height:Float = 768):{window:Window, root:InspectorTestRoot} {
        final child = app.newEntity((_:Context<InspectorTestView>) -> new InspectorTestView());
        final root = app.newEntity((_:Context<InspectorTestRoot>) -> new InspectorTestRoot(child));
        final window = Window.open(app, {width: width, height: height, scaleFactor: 1, autoDraw: false, bindInput: false}, (_, _) -> root);
        windows.push(window);
        return {window: window, root: root};
    }

    static function pixelsLength(value:Float):Length {
        return Length.Definite(gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(value)));
    }

    function widths(root:InspectorTestRoot):String {
        return root.child.childWidths.join(',');
    }

    function assertClosedInspector(window:Window, root:InspectorTestRoot):Void {
        window.draw();
        window.draw();
        assertEquals('10,10,10', widths(root));
        for (frame in [@:privateAccess window.renderedFrame, @:privateAccess window.nextFrame]) {
            assertFalse(frame.nextInspectorInstanceIds.iterator().hasNext());
            assertFalse(frame.inspectorHitboxes.iterator().hasNext());
        }
    }

    function testInspectorOnlyTracksItsOpenWindow() {
        final windows = [addWindow(), addWindow()];
        for (w in windows) {
            assertClosedInspector(w.window, w.root);
        }
        for (_ in 0...2) {
            final window = windows[0].window;
            final root = windows[0].root;
            window.toggleInspector(app);
            window.draw();
            assertEquals('10,10,10', widths(root));

            final rendered = @:privateAccess window.renderedFrame;
            var path:Null<gpui.InspectorElementId.InspectorElementPath> = null;
            for (entry in rendered.nextInspectorInstanceIds) {
                if (entry.count == 3) path = entry.path;
            }
            assertTrue(path != null, 'anonymous siblings share an inspector path');
            final selectedId = new InspectorElementId(path, 1);
            var position = null;
            for (hitbox in rendered.hitboxes) {
                if (selectedId.equals(rendered.inspectorHitboxes.get(hitbox.id))) {
                    position = hitbox.bounds.center();
                    break;
                }
            }
            assertTrue(position != null, 'middle sibling is pickable');

            window.dispatchEvent(new MouseMoveEvent(position));
            window.dispatchEvent(new MouseDownEvent(MouseButton.Left, position));
            window.dispatchEvent(new MouseUpEvent(MouseButton.Left, position));
            assertFalse(window.isInspectorPicking(app));
            assertTrue(selectedId.equals(window.inspectorEntity().activeElementId()));

            window.draw();
            window.withInspectorState(selectedId, DivInspectorState, app, (state, _) -> {
                assertTrue(state.value != null, 'selected div has style state');
                assertTrue(LengthTools.equals(pixelsLength(10), state.value.baseStyle.sizeWidth));
                state.value.baseStyle.sizeWidth = pixelsLength(25);
                return null;
            });
            window.refresh();
            window.draw();
            assertEquals('10,25,10', widths(root));

            assertClosedInspector(windows[1].window, windows[1].root);
            window.toggleInspector(app);
            assertClosedInspector(window, root);
        }
    }

    function testInspectorTakesThirtyRemsOnTheRight() {
        var panel:Null<gpui.Bounds> = null;
        app.setInspectorRenderer((inspector, window, cx) -> {
            return div().sizeFull().child(canvas((bounds, _, _) -> {
                panel = bounds;
                return null;
            }, (_, _, _, _) -> {}).sizeFull()).intoAnyElement();
        });
        final w = addWindow(1024, 768);
        w.window.toggleInspector(app);
        w.window.draw();
        // Prepainted at the right of the viewport, 30 rems wide
        assertEquals(544.0, panel.origin.x);
        assertEquals(0.0, panel.origin.y + 0.0);
        assertEquals(480.0, panel.size.width);
        assertEquals(768.0, panel.size.height);
        assertTrue(w.window.isInspectorPicking(app));
        assertEquals(null, w.window.inspectorEntity().activeElementId());
    }

    function testHoverPicksAndScrollChangesDepth() {
        final w = addWindow();
        w.window.toggleInspector(app);
        w.window.draw();
        final rendered = @:privateAccess w.window.renderedFrame;
        var middle = null;
        var middleId:InspectorElementId = null;
        for (hitbox in rendered.hitboxes) {
            final id = rendered.inspectorHitboxes.get(hitbox.id);
            if (id != null && id.instanceId == 1) {
                middle = hitbox.bounds.center();
                middleId = id;
            }
        }
        assertTrue(middle != null);
        w.window.dispatchEvent(new MouseMoveEvent(middle));
        final inspector = w.window.inspectorEntity();
        assertTrue(middleId.equals(inspector.activeElementId()));
        assertTrue(inspector.isPicking());

        // Scrolling down one layer picks the element below (the root div)
        w.window.draw();
        w.window.dispatchEvent(new ScrollEvent(middle, ScrollDelta.Pixels(point(px(0), px(36)))));
        final active = inspector.activeElementId();
        assertTrue(active != null);
        assertFalse(middleId.equals(active));
        assertTrue(inspector.isPicking());

        // A click selects and ends picking; mouse moves no longer change the selection
        w.window.dispatchEvent(new MouseDownEvent(MouseButton.Left, middle));
        assertFalse(inspector.isPicking());
        w.window.dispatchEvent(new MouseMoveEvent(point(px(1), px(1))));
        assertTrue(active.equals(inspector.activeElementId()));

        // Start picking again
        inspector.startPicking();
        assertTrue(inspector.isPicking());
    }

    function testInspectorStatesAreRenderedByTheRegisteredRenderer() {
        final rendered:Array<String> = [];
        app.registerInspectorElement(DivInspectorState, (window, cx) -> {
            return (id, state:DivInspectorState, window, cx) -> {
                rendered.push(id.instanceId + ':' + state.bounds.size.width);
                return div();
            };
        });
        var states = 0;
        app.setInspectorRenderer((inspector, window, cx) -> {
            states += inspector.renderInspectorStates(window, cx).length;
            return div().intoAnyElement();
        });
        final w = addWindow();
        w.window.toggleInspector(app);
        w.window.draw();
        final frame = @:privateAccess w.window.renderedFrame;
        var target = null;
        for (hitbox in frame.hitboxes) {
            final id = frame.inspectorHitboxes.get(hitbox.id);
            if (id != null && id.instanceId == 2) target = hitbox.bounds.center();
        }
        w.window.dispatchEvent(new MouseMoveEvent(target));
        w.window.draw();
        w.window.draw();
        assertTrue(states > 0);
        assertEquals('2:10', rendered[rendered.length - 1]);
    }

}

private class InspectorTestRoot extends Model implements Render {

    public final child:InspectorTestView;

    public function new(child:Entity<InspectorTestView>) {
        super();
        this.child = child;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return (child : Entity<InspectorTestView>).cached(StyleBuilder.build(s -> s.size(px(100))));
    }

}

private class InspectorTestView extends Model implements Render {

    public var childWidths:Array<Float> = [];

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .onChildrenPrepainted((bounds, _, _) -> {
                childWidths = [for (b in bounds) b.size.width];
            })
            .id('inspector-root')
            .flex()
            .children([for (_ in 0...3) div().size(px(10)).flexShrink0()]);
    }

}

#end
