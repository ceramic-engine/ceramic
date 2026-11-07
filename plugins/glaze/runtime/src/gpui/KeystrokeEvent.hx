// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A keystroke event, and potentially the associated action (given to
 * keystroke observers and interceptors). There is no text input handler
 * yet, so the input preference is always key bindings.
 */
class KeystrokeEvent {

    /** The keystroke that occurred */
    public final keystroke:Keystroke;

    /**
     * Whether this keystroke should prefer character input or key bindings.
     * `CharacterInput` when the platform prefers text for the key (e.g. AltGr)
     * and the focused input accepts text. Interceptors still receive these
     * keystrokes and can consume them. If the keystroke is part of a
     * multi-stroke binding, it still waits as pending input.
     */
    public final inputPreference:InputPreference;

    /** The action that was resolved for the keystroke, if any */
    public final action:Null<Action>;

    /** The context stack at the time */
    public final contextStack:Array<KeyContext>;

    public function new(keystroke:Keystroke, inputPreference:InputPreference, action:Null<Action>, contextStack:Array<KeyContext>) {
        this.keystroke = keystroke;
        this.inputPreference = inputPreference;
        this.action = action;
        this.contextStack = contextStack;
    }

}
