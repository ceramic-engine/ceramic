// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Implemented by every element (Rust trait `Element`). Elements are built
 * by `Render.render()`, laid out with taffy, then prepainted and painted
 * once per frame, in three phases:
 *
 * - `requestLayout`: request a layout node from the window (usually after
 *   requesting the layout of the children), return its id;
 * - `prepaint`: given the final bounds, compute what painting needs;
 * - `paint`: add primitives to the scene.
 *
 * Differences with GPUI: Rust returns `RequestLayoutState` and
 * `PrepaintState` values that GPUI stores and hands back in the next
 * phases. An element instance is drawn exactly once, so here elements keep
 * that state in their own fields. The trait method `id()` is named
 * `elementId()` because `id(...)` is the builder giving an element its id.
 */
abstract class Element {

    /**
     * The id of this element, used to keep state across frames, or `null`.
     */
    public function elementId():Null<ElementId> {
        return null;
    }

    #if gpui_inspector
    /**
     * The inspector id of this element, given by `AnyElement` before
     * `requestLayout` (Rust passes it to every draw phase), or `null`.
     */
    public var inspectorId:Null<InspectorElementId> = null;

    /**
     * Where this element was built (Rust `source_location`, from
     * `#[track_caller]`), or `null` for elements the inspector cannot pick.
     */
    public function sourceLocation():Null<haxe.PosInfos> {
        return null;
    }
    #end

    /**
     * Before an element can be painted, we need to know where it's going to be and how big it is.
     * Use this method to request a layout from Taffy and initialize the element's state.
     */
    public abstract function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId;

    /**
     * After laying out an element, we need to commit its bounds to the current frame for hitbox
     * purposes. The state argument is the same state that was returned from `requestLayout()`.
     */
    public abstract function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void;

    /**
     * Once layout has been completed, this method will be called to paint the element to the screen.
     */
    public abstract function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void;

    /**
     * Convert into a dynamically-typed `AnyElement`.
     */
    public function intoAnyElement():AnyElement {
        return AnyElement.create(this);
    }

}
