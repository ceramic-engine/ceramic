// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An object that can be drawn to the screen. This is the trait that
 * distinguishes "views" from other entities. Views are `Model` subclasses
 * implementing `Render`, rendered through `render()` every time the window
 * draws them.
 *
 * Every observable (`@observe`) field read during `render()`, and during
 * the layout and paint of the returned elements, subscribes the view: it is
 * drawn again when one of them changes, without calling `cx.notify()`.
 *
 * Rust passes a `Context<Self>`: Haxe interfaces have no `Self` type, so
 * the context is a `Context<Dynamic>` (cast it if a typed one is needed).
 */
interface Render {

    /**
     * Render this view into an element tree.
     */
    function render(window:Window, cx:Context<Dynamic>):IntoElement;

}
