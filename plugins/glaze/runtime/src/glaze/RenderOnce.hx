// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * You can derive `IntoElement` on any type that implements this trait.
 * It is used to construct reusable `components` out of plain data. Think of
 * components as a recipe for a certain pattern of elements. RenderOnce allows
 * you to invoke this pattern, without breaking the fluent builder pattern of
 * the element APIs.
 *
 * Observable fields read by `render()` subscribe the view being drawn.
 *
 * Every implementation with a public constructor gets a static
 * `component(...)` with the constructor's parameters (`RenderOnceMacro`):
 * `Button.component('save')` is `new Button('save')`, the notation of
 * `glaze.Component`. A `glaze.Component` is a `RenderOnce` too, rendered
 * under the same element id path.
 */
@:autoBuild(glaze.RenderOnceMacro.build())
interface RenderOnce {

    /**
     * Render this component into an element tree. Note that this method
     * takes ownership of self, as compared to `Render.render()`.
     */
    function render(window:Window, cx:App):IntoElement;

}
