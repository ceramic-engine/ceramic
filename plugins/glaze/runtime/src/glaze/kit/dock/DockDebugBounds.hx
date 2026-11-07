// New code for the Haxe port of gpui-kit 0.8.1: stands for gpui-pre 0.3.10's
// `debug_selector` / `debug_bounds` (src/elements/div.rs, src/window.rs, Zed
// Industries, Apache-2.0) in the dock skin of crates/component/src/dock. See NOTICE.md.
package gpui.component.dock;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Element;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Window;
import gpui.component.tab.Tab;

/**
 * The dock skin's `debug_selector` calls.
 *
 * GPUI records the bounds of an element under its debug selector in test
 * builds only, and `Div.debugSelector` records nothing in this port. The
 * skin's tests need to find the controls it draws (the zoom button, the
 * close buttons, the tabs, the dock toggles), so while `enabled` is set the
 * skin wraps each of them in an element that records its bounds per window,
 * read back with `bounds`. The wrapper has no id and lays out its child as
 * its own, so the element tree the skin builds is otherwise unchanged. Off by
 * default, like a normal GPUI build.
 */
class DockDebugBounds {

    /**
     * Whether the skin records its debug selectors (tests set it).
     */
    public static var enabled:Bool = false;

    static final recorded:Map<Int, Map<String, {draw:Int, bounds:Array<Bounds>}>> = new Map();

    /**
     * The bounds `selector` was drawn at by the last frame of `window`, or
     * `null` when that frame did not draw it (Rust
     * `VisualTestContext::debug_bounds`, which reads the frame GPUI rebuilds
     * on every draw: the element drawn last under the selector). A view the
     * port reused from its cache records nothing, so tests that read these
     * turn the default view caching off (`window.viewCaching`), like GPUI,
     * which does not cache these views.
     */
    public static function bounds(window:Window, selector:String):Null<Bounds> {
        final all = all(window, selector);
        return all.length > 0 ? all[all.length - 1] : null;
    }

    /**
     * Every element the last frame of `window` drew under `selector`, in
     * prepaint order (a tab bar per group draws the same selectors).
     */
    public static function all(window:Window, selector:String):Array<Bounds> {
        final map = recorded.get(window.id);
        final entry = map != null ? map.get(selector) : null;
        return entry != null && entry.draw == window.drawCount - 1 ? entry.bounds.copy() : [];
    }

    /**
     * Forget everything recorded, in every window.
     */
    public static function clear():Void {
        recorded.clear();
    }

    @:allow(gpui.component.dock)
    static function record(window:Window, selector:String, bounds:Bounds):Void {
        var map = recorded.get(window.id);
        if (map == null) {
            map = new Map();
            recorded.set(window.id, map);
        }
        final entry = map.get(selector);
        if (entry == null || entry.draw != window.drawCount) {
            map.set(selector, {draw: window.drawCount, bounds: [bounds]});
        } else {
            entry.bounds.push(bounds);
        }
    }

    /**
     * `element.debug_selector(selector)`.
     */
    @:allow(gpui.component.dock)
    static function wrap(selector:() -> String, element:IntoElement):IntoElement {
        return enabled ? new DebugSelectorElement(selector(), element) : element;
    }

}

/**
 * Records the bounds of its child in prepaint.
 */
private class DebugSelectorElement extends Element {

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        DockDebugBounds.record(window, selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}

/**
 * A `Tab` carrying a debug selector (Rust `Tab::debug_selector`, which the
 * `TabBar` keeps on the tab element).
 */
class DebugSelectorTab extends Tab {

    final selector:() -> String;

    public function new(selector:() -> String) {
        super();
        this.selector = selector;
    }

    override public function render(window:Window, cx:App):IntoElement {
        return DockDebugBounds.wrap(selector, super.render(window, cx));
    }

}
