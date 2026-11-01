// Ported from gpui-pre 0.3.10: src/styled.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A trait for elements that can be styled.
 * Use this to opt-in to a utility CSS-like styling API.
 *
 * Implementing classes only provide `style()`: the fluent methods (`flex()`,
 * `gap2()`, `roundedMd()`, `bg(...)`, about 900 of them) are added by
 * `StyledMacro.build()` as `extern inline` methods returning the class.
 */
@:autoBuild(gpui.StyledMacro.build())
interface Styled {

    /**
     * Returns a reference to the style refinement of this element.
     */
    function style():StyleRefinement;

}
