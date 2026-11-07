// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language_config.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * An automatic closing pair and the syntax contexts in which insertion is disabled.
 * Empty delimiters are ignored. Delimiters can be several characters long
 * (a block comment opener and closer, for example).
 */
class AutoClosingPair {

    public final open:String;

    public final close:String;

    public var notIn:Array<SyntaxContext>;

    public function new(open:String, close:String) {
        this.open = open;
        this.close = close;
        this.notIn = [];
    }

    /** Rust builder `not_in` (renamed: the field has that name) */
    public function withNotIn(contexts:Array<SyntaxContext>):AutoClosingPair {
        notIn = contexts.copy();
        return this;
    }

    public function equals(other:AutoClosingPair):Bool {
        if (other == null || open != other.open || close != other.close || notIn.length != other.notIn.length)
            return false;
        for (i in 0...notIn.length) {
            if (notIn[i] != other.notIn[i])
                return false;
        }
        return true;
    }

}
