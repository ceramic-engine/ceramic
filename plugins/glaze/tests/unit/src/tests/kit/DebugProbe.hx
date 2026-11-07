// New code for the Haxe port of gpui-kit: stands for GPUI's `debug_selector` /
// `debug_bounds` test helpers (gpui-pre 0.3.10, Zed Industries, Apache-2.0),
// used by the form, setting, sidebar and resizable tests. See NOTICE.md.
package tests.kit;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Element;
import gpui.GlobalElementId;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Window;

/**
 * Records the bounds of its child in prepaint under a selector. GPUI's
 * `debug_selector` records nothing in the port (like Rust outside of debug
 * test builds), so tests wrap the element they query in a probe and read
 * `DebugProbe.bounds(selector)`. Call `clear()` before each draw that checks
 * that an element is gone.
 */
class DebugProbe extends Element {

    static final recorded:Map<String, Bounds> = new Map();

    final selector:String;

    final child:AnyElement;

    public function new(selector:String, child:IntoElement) {
        this.selector = selector;
        this.child = child.intoAnyElement();
    }

    public static function bounds(selector:String):Null<Bounds> {
        return recorded.get(selector);
    }

    public static function clear():Void {
        recorded.clear();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        recorded.set(selector, bounds);
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}
