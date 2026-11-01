// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A change in the state of the focused text input.
 */
enum abstract TextInputStateChange(Int) {

    /** The window changed from having no active text input to having one. */
    var FocusGained = 0;

    /** The window no longer has an active text input. */
    var FocusLost = 1;

    /** The selection or caret moved */
    var SelectionChanged = 2;

    /** The document content changed outside of platform-initiated edits. */
    var ContentChanged = 3;

    public function toString():String {
        return switch (cast this : TextInputStateChange) {
            case FocusGained: 'FocusGained';
            case FocusLost: 'FocusLost';
            case SelectionChanged: 'SelectionChanged';
            case ContentChanged: 'ContentChanged';
        }
    }

}
