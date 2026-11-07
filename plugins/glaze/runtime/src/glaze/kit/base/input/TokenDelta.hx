// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * The tokens an edit removed and inserted. Only affected records are
 * retained in history. Ranges are relative to the edit start.
 */
class TokenDelta {

    @:allow(gpui.base.input)
    final removed:Array<InlineTokenSpan>;

    @:allow(gpui.base.input)
    final inserted:Array<InlineTokenSpan>;

    @:allow(gpui.base.input)
    function new(removed:Array<InlineTokenSpan>, inserted:Array<InlineTokenSpan>) {
        this.removed = removed;
        this.inserted = inserted;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<TokenDelta>):Bool {
        return other != null && InlineTokenSpan.sameAll(other.removed, removed) && InlineTokenSpan.sameAll(other.inserted, inserted);
    }

}
