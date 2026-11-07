// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * This is a helper trait to provide a uniform interface for constructing
 * elements that can accept any number of any kind of child elements.
 *
 * The fluent `child()` / `children()` methods are written on most elements
 * (Haxe has no `Self` return type); the others get the trait's default ones
 * from `ParentElementTools` (`@:using`).
 */
@:using(gpui.ParentElementTools)
interface ParentElement {

    /**
     * Extend this element's children with the given child elements.
     */
    function extend(elements:Array<AnyElement>):Void;

}
