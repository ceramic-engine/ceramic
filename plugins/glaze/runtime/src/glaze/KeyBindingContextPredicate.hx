// Ported from gpui-pre 0.3.10: src/keymap/context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A datastructure for resolving whether an action should be dispatched.
 * Representing a small language for describing which contexts correspond to
 * which actions.
 *
 * Methods (`parse`, `depthOf`, `eval`, `isSuperset`, `equals`, `toString`)
 * live in `KeyBindingContextPredicateTools`. Parse with
 * `KeyBindingContextPredicateTools.parse(source)`.
 */
@:using(glaze.KeyBindingContextPredicateTools)
enum KeyBindingContextPredicate {

    /**
     * A predicate that will match a given identifier.
     */
    Identifier(name:String);

    /**
     * A predicate that will match a given key-value pair.
     */
    Equal(left:String, right:String);

    /**
     * A predicate that will match a given key-value pair not being present.
     */
    NotEqual(left:String, right:String);

    /**
     * A predicate that will match a given predicate appearing below another
     * predicate in the element tree.
     */
    Descendant(parent:KeyBindingContextPredicate, child:KeyBindingContextPredicate);

    /**
     * Predicate that will invert another predicate.
     */
    Not(predicate:KeyBindingContextPredicate);

    /**
     * A predicate that will match if both of its children match.
     */
    And(left:KeyBindingContextPredicate, right:KeyBindingContextPredicate);

    /**
     * A predicate that will match if either of its children match.
     */
    Or(left:KeyBindingContextPredicate, right:KeyBindingContextPredicate);

}
