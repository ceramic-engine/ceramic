// Ported from gpui-pre 0.3.10: src/styled.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A trait for elements that can be styled.
 * Use this to opt-in to a utility CSS-like styling API.
 *
 * Implementing classes only provide `style()`: the fluent methods (`flex()`,
 * `gap2()`, `roundedMd()`, `bg(...)`, about 900 of them) are `extern inline`
 * static extensions of `StyledMethods`, generated once by `StyledMacro` and
 * returning the element with its own type. Inside a class body, call them
 * on `this` explicitly (`this.flex()`).
 */
@:using(glaze.StyledMethods)
interface Styled {

    /**
     * Returns a reference to the style refinement of this element.
     */
    function style():StyleRefinement;

}
