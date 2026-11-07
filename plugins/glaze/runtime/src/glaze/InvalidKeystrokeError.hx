// Ported from gpui-pre 0.3.10: src/platform/keystroke.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Error thrown by `Keystroke.parse`.
 */
class InvalidKeystrokeError extends haxe.Exception {

    /**
     * Sentence explaining what keystroke parser expects, starting with "Expected ..."
     */
    public static final KEYSTROKE_PARSE_EXPECTED_MESSAGE = "Expected a sequence of modifiers "
        + "(`ctrl`, `alt`, `shift`, `fn`, `cmd`, `super`, or `win`) "
        + "followed by a key, separated by `-`.";

    /**
     * The invalid keystroke.
     */
    public final keystroke:String;

    public function new(keystroke:String) {
        super('Invalid keystroke "' + keystroke + '". ' + KEYSTROKE_PARSE_EXPECTED_MESSAGE);
        this.keystroke = keystroke;
    }

}
