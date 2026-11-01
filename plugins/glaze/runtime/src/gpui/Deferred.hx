// Ported from gpui-pre 0.3.10: src/elements/deferred.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An element which delays the painting of its child until after all of
 * its ancestors, while keeping its layout as part of the current element tree.
 * Create one with `Prelude.deferred(child)`.
 */
class Deferred extends Element {

    var childElement:Null<AnyElement>;

    var priorityValue:Int = 0;

    public function new(child:IntoElement) {
        this.childElement = child;
    }

    /**
     * Sets the `priority` value of the `deferred` element, which
     * determines the drawing order relative to other deferred elements,
     * with higher values being drawn on top.
     */
    public function withPriority(priority:Int):Deferred {
        priorityValue = priority;
        return this;
    }

    /**
     * Sets a priority for the element. A higher priority conceptually means painting the element
     * on top of deferred draws with a lower priority (i.e. closer to the viewer).
     */
    public inline function priority(priority:Int):Deferred {
        return withPriority(priority);
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return childElement.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final child = childElement;
        childElement = null;
        final elementOffset = window.elementOffset();
        window.deferDraw(child, elementOffset, priorityValue, null);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

}
