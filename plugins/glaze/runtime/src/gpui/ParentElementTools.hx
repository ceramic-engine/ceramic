// Ported from gpui-pre 0.3.10: src/element.rs (`ParentElement::child`, `ParentElement::children`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The default fluent methods of Rust's `ParentElement` trait, for elements
 * that don't write their own: attached to every `ParentElement` with
 * `@:using`, so `track.child(x)` works on any of them and returns the
 * element itself (its concrete type).
 */
class ParentElementTools {

    /**
     * Add a single child element to this element.
     */
    public static inline function child<T:ParentElement>(element:T, child:IntoElement):T {
        if (child != null) element.extend([child.intoAnyElement()]);
        return element;
    }

    /**
     * Add multiple child elements to this element.
     */
    public static function children<T:ParentElement>(element:T, children:Array<IntoElement>):T {
        element.extend([for (child in children) if (child != null) child.intoAnyElement()]);
        return element;
    }

}
