// Ported from gpui-pre 0.3.10: src/key_dispatch.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.keymap;

import gpui.KeyBinding;
import gpui.KeyContext;
import gpui.Keystroke;

/**
 * What `KeyDispatch.dispatchKey` tells the input handler to do.
 */
class DispatchResult {

    /**
     * The new set of pending keystrokes to store.
     */
    public var pending:Array<Keystroke> = [];

    /**
     * Whether the pending input also fully matches a binding (which runs if the
     * pending input times out).
     */
    public var pendingHasBinding:Bool = false;

    /**
     * Bindings to execute, highest precedence first.
     */
    public var bindings:Array<KeyBinding> = [];

    /**
     * Keystrokes that had been pushed to pending but are no longer matched:
     * they should be replayed first.
     */
    public var toReplay:Array<Replay> = [];

    /**
     * The context stack the input was matched against.
     */
    public var contextStack:Array<KeyContext> = [];

    public function new() {}

}
