// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * The exception thrown where Rust returns `Err(InlineTokenError)` from a
 * builder (`InputContent.withToken`).
 */
class InlineTokenException extends haxe.Exception {

    public final error:InlineTokenError;

    public function new(error:InlineTokenError) {
        super(error.toString());
        this.error = error;
    }

}
