// Ported from gpui-pre 0.3.10: src/elements/div.rs (`DivInspectorState`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

#if gpui_inspector

/**
 * The state of a `Div` (or `Img`, `Svg`) while it is the inspector's active
 * element: its base style, which the inspector may edit, and its bounds.
 */
class DivInspectorState {

    /**
     * The inspected element's base style. This is used for both inspecting and modifying the
     * state. In the future it will make sense to separate the read and write, possibly tracking
     * the modifications.
     */
    public var baseStyle:StyleRefinement;

    /** Inspects the bounds of the element. */
    public var bounds:Bounds;

    /** Size of the children of the element, or `bounds.size` if it has no children. */
    public var contentSize:Size;

    public function new(baseStyle:StyleRefinement, bounds:Bounds, contentSize:Size) {
        this.baseStyle = baseStyle;
        this.bounds = bounds;
        this.contentSize = contentSize;
    }

    public function clone():DivInspectorState {
        return new DivInspectorState(baseStyle.clone(), bounds, contentSize);
    }

}

#end
