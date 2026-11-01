// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The empty element, which renders nothing.
 */
class Empty extends Element {

    public function new() {}

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.display = Display.None;
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

}
