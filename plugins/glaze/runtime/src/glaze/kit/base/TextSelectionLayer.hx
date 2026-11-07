// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Element;
import glaze.ElementId;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.LayoutId;
import glaze.Style;
import glaze.Window;

/**
 * A zero-sized root layer which enables text selection for a window.
 *
 * Mount one as the root's first child. Its stable `"window-text-selection"`
 * element identity retains the window-local selection entity across frames.
 */
class TextSelectionLayer extends Element {

    var state:Null<Entity<WindowSelectionState>> = null;

    public function new() {}

    override public function elementId():Null<ElementId> {
        return ElementId.Name('window-text-selection');
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(@:privateAccess glaze.Style.sharedDefaultStyle(), [], cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        GlobalState.init(cx);
        final state = TextSelection.retainTextSelectionState(globalId, window, cx);
        state.read(cx).layerPainted = true;
        // The handles and the menu register again as they paint this frame.
        if (state.read(cx).touch.paintedAny()) {
            state.update(cx, (state, _) -> state.touch.beginFrame());
        }
        this.state = state;
    }

    public function paint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        TextSelection.paintTextSelection(state, window, cx);
    }

}

/**
 * Runs an element inside a text selection scope (Rust `TextSelectionScopeMarker`):
 * participants registering while it lays out, prepaints or paints take its scope.
 */
class TextSelectionScopeMarker extends Element {

    final scope:TextSelectionScopeId;

    final element:AnyElement;

    public function new(scope:TextSelectionScopeId, element:AnyElement) {
        this.scope = scope;
        this.element = element;
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return TextSelection.withTextSelectionScope(window.id, scope, cx, cx -> element.requestLayout(window, cx));
    }

    public function prepaint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        TextSelection.withTextSelectionScope(window.id, scope, cx, cx -> {
            element.prepaint(window, cx);
            return true;
        });
    }

    public function paint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        TextSelection.withTextSelectionScope(window.id, scope, cx, cx -> {
            element.paint(window, cx);
            return true;
        });
    }

}
