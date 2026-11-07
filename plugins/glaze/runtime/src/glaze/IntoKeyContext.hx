// Ported from gpui-pre 0.3.10: src/keymap/context.rs (`TryFrom<&str> for KeyContext`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A `KeyContext`, or a string parsed into one (Rust `TryInto<KeyContext>`):
 * `div().keyContext("Editor mode=full")`.
 */
@:forward
abstract IntoKeyContext(KeyContext) from KeyContext to KeyContext {

    @:from static inline function fromString(source:String):IntoKeyContext {
        return KeyContext.parse(source);
    }

}
