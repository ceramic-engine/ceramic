// Ported from gpui-kit 0.8.1: crates/base/src/focus_trap.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.Div;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

/**
 * Adds `focusTrap` to a `Div`, as a static extension:
 * `using glaze.kit.base.FocusTrap;` (Rust `FocusTrapElement`).
 */
class FocusTrap {

    /**
     * Initialize the focus trap manager as a global.
     */
    public static function init(cx:AppContext):Void {
        (cx:App).setGlobal(new FocusTrapManager(), FocusTrapManager);
    }

    /**
     * Enable focus trap for this element.
     *
     * When enabled, focus will automatically cycle within this container
     * instead of escaping to parent elements: Root intercepts Tab / Shift-Tab
     * and, if focus would leave the container, cycles back to its beginning
     * or end. Useful for modal dialogs, sheets and other overlays.
     */
    public static function focusTrap(self:Div, id:ElementIdArg, focusHandle:FocusHandle):FocusTrapContainer {
        return new FocusTrapContainer(id, focusHandle, self);
    }

    /**
     * Returns the focus handle for the active focus trap, if any.
     */
    public static function activeFocusTrap(window:Window, cx:App):Null<FocusHandle> {
        return FocusTrapManager.findActiveTrap(window, cx);
    }

}

/**
 * Global state to manage all focus trap containers.
 *
 * Rust keeps weak focus handles and drops the released ones; the port's
 * focus handles are never released, and a trap that is no longer rendered
 * never contains the focus, so it is never selected.
 */
class FocusTrapManager {

    /** Container element id (global key) to its focus handle, in registration order. */
    final traps:Map<String, FocusHandle> = new Map();

    final order:Array<String> = [];

    @:allow(glaze.kit.base.FocusTrap)
    function new() {}

    static function global(cx:App):Null<FocusTrapManager> {
        tracker.Autorun.unobserve();
        final manager = cx.tryGlobal(FocusTrapManager);
        tracker.Autorun.reobserve();
        return manager;
    }

    /**
     * Register a focus trap container.
     */
    @:allow(glaze.kit.base.FocusTrapContainer)
    static function registerTrap(id:GlobalElementId, containerHandle:FocusHandle, cx:App):Void {
        var manager = global(cx);
        if (manager == null) {
            manager = new FocusTrapManager();
            cx.setGlobal(manager, FocusTrapManager);
        }
        if (!manager.traps.exists(id.key)) {
            manager.order.push(id.key);
        }
        manager.traps.set(id.key, containerHandle);
    }

    /**
     * Find which focus trap contains the currently focused element: the
     * innermost one in the rendered focus tree.
     */
    public static function findActiveTrap(window:Window, cx:App):Null<FocusHandle> {
        final manager = global(cx);
        if (manager == null)
            return null;
        var active:Null<FocusHandle> = null;
        for (key in manager.order) {
            final container = manager.traps.get(key);
            if (container.containsFocused(window, cx) && (active == null || active.contains(container, window))) {
                // A child scope must confine navigation even if its ancestor
                // was registered first. Use the rendered focus tree so closing
                // and reopening a retained scope cannot leave registration
                // order in control.
                active = container;
            }
        }
        return active;
    }

}

/**
 * A wrapper element that implements focus trap behavior: it registers its
 * `Div` as a focus trap container and tracks the container's focus handle.
 */
class FocusTrapContainer extends Element implements Styled implements ParentElement {

    final id:ElementId;

    final focusHandle:FocusHandle;

    /** The wrapped element. */
    public final base:Div;

    @:allow(glaze.kit.base.FocusTrap)
    function new(id:ElementIdArg, focusHandle:FocusHandle, child:Div) {
        this.id = id;
        this.base = child.trackFocus(focusHandle);
        this.focusHandle = focusHandle;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        base.extend(elements);
    }

    public function child(child:IntoElement):FocusTrapContainer {
        if (child != null) base.child(child);
        return this;
    }

    public function children(children:Array<IntoElement>):FocusTrapContainer {
        base.children(children);
        return this;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // Register this focus trap with the manager
        FocusTrapManager.registerTrap(globalId, focusHandle, cx);
        return base.requestLayout(globalId, window, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        base.prepaint(globalId, bounds, window, cx);
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        base.paint(globalId, bounds, window, cx);
    }

}
