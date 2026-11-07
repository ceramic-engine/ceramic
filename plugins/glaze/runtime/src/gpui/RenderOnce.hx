// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * You can derive `IntoElement` on any type that implements this trait.
 * It is used to construct reusable `components` out of plain data. Think of
 * components as a recipe for a certain pattern of elements. RenderOnce allows
 * you to invoke this pattern, without breaking the fluent builder pattern of
 * the element APIs.
 *
 * Observable fields read by `render()` subscribe the view being drawn.
 */
interface RenderOnce {

    /**
     * Render this component into an element tree. Note that this method
     * takes ownership of self, as compared to `Render.render()`.
     */
    function render(window:Window, cx:App):IntoElement;

}
