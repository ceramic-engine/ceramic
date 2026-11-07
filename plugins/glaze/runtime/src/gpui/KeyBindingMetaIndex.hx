// Ported from gpui-pre 0.3.10: src/keymap/binding.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A unique identifier for retrieval of metadata associated with a key binding.
 * Intended to be used as an index or key into a user-defined store of metadata
 * associated with the binding, such as the source of the binding.
 */
abstract KeyBindingMetaIndex(Int) from Int to Int {

    public inline function new(value:Int) {
        this = value;
    }

}
