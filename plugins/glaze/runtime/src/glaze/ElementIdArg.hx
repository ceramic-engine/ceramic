// Ported from gpui-pre 0.3.10: src/window.rs (`impl Into<ElementId>` arguments)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Haxe counterpart of Rust's `impl Into<ElementId>`: accepts an `ElementId`,
 * a `String` (`Name`) or an `Int` (`Integer`).
 */
abstract ElementIdArg(ElementId) from ElementId to ElementId {

    @:from static inline function fromString(name:String):ElementIdArg {
        return ElementId.Name(name);
    }

    @:from static inline function fromInt(id:Int):ElementIdArg {
        return ElementId.Integer(id);
    }

}
