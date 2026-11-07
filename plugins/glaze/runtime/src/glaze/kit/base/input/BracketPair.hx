// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language_config.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A structural pair, used for indentation and splitting Enter between delimiters.
 */
class BracketPair {

    public final open:String;

    public final close:String;

    public function new(open:String, close:String) {
        this.open = open;
        this.close = close;
    }

    public inline function equals(other:BracketPair):Bool {
        return other != null && open == other.open && close == other.close;
    }

}
