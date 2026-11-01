// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A rejected token operation never partially changes the document.
 */
enum abstract InlineTokenError(Int) {

    var InvalidRange = 0;
    var InvalidBoundary = 1;
    var InvalidToken = 2;
    var OverlappingTokens = 3;
    var TextMismatch = 4;
    var UnsupportedMode = 5;
    var ValidationRejected = 6;
    var CompositionActive = 7;

    /** Rust `Display`. */
    public function toString():String {
        return switch (cast this : InlineTokenError) {
            case InvalidRange: 'token range is outside the document or empty';
            case InvalidBoundary: 'token range splits a Unicode grapheme';
            case InvalidToken: 'token requires a nonempty ID, text and label without control characters';
            case OverlappingTokens: 'token ranges overlap';
            case TextMismatch: 'token text does not match its range or input normalization';
            case UnsupportedMode: 'tokens are not supported by this input mode';
            case ValidationRejected: 'input validation rejected the content';
            case CompositionActive: 'finish the active IME composition before editing tokens';
        }
    }

}
