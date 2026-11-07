// Ported from gpui-pre 0.3.10: src/key_dispatch.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.keymap;

import gpui.Action;
import gpui.KeyBinding;
import gpui.KeyContext;
import gpui.Keymap;
import gpui.Keystroke;

/**
 * The keystroke matching part of GPUI's `DispatchTree`, independent of the
 * element tree.
 *
 * GPUI derives the context stack from a dispatch path (the `KeyContext` of
 * each dispatch node from the root to the focused node, skipping nodes
 * without context). The dispatch tree computes that stack and calls these
 * methods with it: the results are the same as `DispatchTree`'s.
 *
 * ```haxe
 * final dispatch = new KeyDispatch(app.keyBindings());
 * var pending:Array<Keystroke> = [];
 * final result = dispatch.dispatchKey(pending, keystroke, contextStack);
 * pending = result.pending;
 * // replay result.toReplay, then run result.bindings (highest precedence first)
 * ```
 */
class KeyDispatch {

    public final keymap:Keymap;

    public function new(keymap:Keymap) {
        this.keymap = keymap;
    }

    /**
     * Returns key bindings that invoke an action on the currently focused
     * element. Bindings are returned in the order they were added. For display,
     * the last binding should take precedence.
     *
     * Bindings are only included if they are the highest precedence match for
     * their keystrokes, so shadowed bindings are not included.
     */
    public function bindingsForAction(action:Action, contextStack:Array<KeyContext>):Array<KeyBinding> {
        return [
            for (binding in keymap.bindingsForAction(action))
                if (bindingMatchesPredicateAndNotShadowed(keymap, binding, contextStack)) binding.clone()
        ];
    }

    /**
     * Returns the highest precedence binding for the given action and context
     * stack. This is the same as the last result of `bindingsForAction`, but
     * more efficient than getting all bindings.
     */
    public function highestPrecedenceBindingForAction(action:Action, contextStack:Array<KeyContext>):Null<KeyBinding> {
        final bindings = keymap.bindingsForAction(action);
        var i = bindings.length - 1;
        while (i >= 0) {
            final binding = bindings[i];
            if (bindingMatchesPredicateAndNotShadowed(keymap, binding, contextStack)) {
                return binding.clone();
            }
            i--;
        }
        return null;
    }

    static function bindingMatchesPredicateAndNotShadowed(keymap:Keymap, binding:KeyBinding, contextStack:Array<KeyContext>):Bool {
        final input = [for (k in binding.keystrokes) k.inner()];
        final bindings = keymap.bindingsForInput(input, contextStack).bindings;
        if (bindings.length > 0) {
            return bindings[0].action.partialEq(binding.action);
        }
        return false;
    }

    /**
     * Bindings matching the input in the given context stack.
     */
    public inline function bindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>):BindingsForInput {
        return keymap.bindingsForInput(input, contextStack);
    }

    /**
     * Find the bindings that can follow the current input sequence.
     */
    public function possibleNextBindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>):Array<KeyBinding> {
        return keymap.possibleNextBindingsForInput(input, contextStack);
    }

    /**
     * Processes the keystroke. `input` should be set to the value of `pending`
     * from the previous call to `dispatchKey` (it is not modified). This returns
     * three instructions to the input handler:
     * - bindings: any bindings to execute before processing this keystroke
     * - pending: the new set of pending keystrokes to store
     * - toReplay: any keystroke that had been pushed to pending, but are no
     *   longer matched, these should be replayed first.
     */
    public function dispatchKey(input:Array<Keystroke>, keystroke:Keystroke, contextStack:Array<KeyContext>):DispatchResult {
        input = input.copy();
        input.push(keystroke.copy());
        final matched = keymap.bindingsForInput(input, contextStack);

        if (matched.pending) {
            final result = new DispatchResult();
            result.pending = input;
            result.pendingHasBinding = matched.bindings.length > 0;
            result.contextStack = contextStack;
            return result;
        }
        else if (matched.bindings.length > 0) {
            final result = new DispatchResult();
            result.bindings = matched.bindings;
            result.contextStack = contextStack;
            return result;
        }
        else if (input.length == 1) {
            final result = new DispatchResult();
            result.contextStack = contextStack;
            return result;
        }
        input.pop();

        final prefix = replayPrefix(input, contextStack);

        final result = dispatchKey(prefix.suffix, keystroke, contextStack);
        result.toReplay = prefix.toReplay.concat(result.toReplay);
        return result;
    }

    /**
     * If the user types a matching prefix of a binding and then waits for a
     * timeout, `flushDispatch()` converts any previously pending input to replay
     * events.
     */
    public function flushDispatch(input:Array<Keystroke>, contextStack:Array<KeyContext>):Array<Replay> {
        final prefix = replayPrefix(input.copy(), contextStack);
        var toReplay = prefix.toReplay;

        if (prefix.suffix.length > 0) {
            toReplay = toReplay.concat(flushDispatch(prefix.suffix, contextStack));
        }

        return toReplay;
    }

    /**
     * Converts the longest prefix of input to a replay event and returns the
     * rest. `input` is modified.
     */
    function replayPrefix(input:Array<Keystroke>, contextStack:Array<KeyContext>):{suffix:Array<Keystroke>, toReplay:Array<Replay>} {
        final toReplay:Array<Replay> = [];
        var last = input.length - 1;
        while (last >= 0) {
            final bindings = keymap.bindingsForInput(input.slice(0, last + 1), contextStack).bindings;
            if (bindings.length > 0) {
                final drained = input.splice(0, last + 1);
                toReplay.push(new Replay(drained[drained.length - 1], bindings));
                break;
            }
            last--;
        }
        if (toReplay.length == 0) {
            toReplay.push(new Replay(input.shift()));
        }
        return {suffix: input, toReplay: toReplay};
    }

}
