// Ported from gpui-pre 0.3.10: src/keymap.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A collection of key bindings for the user's application.
 */
class Keymap {

    final _bindings:Array<KeyBinding> = [];

    /**
     * Binding indices by action class name (Rust: by `TypeId`).
     */
    final bindingIndicesByActionId:Map<String, Array<Int>> = new Map();

    final disabledBindingIndices:Array<Int> = [];

    var _version:KeymapVersion = 0;

    /**
     * Create a new keymap with the given bindings (Rust: `Keymap::new`, and
     * `Keymap::default()` without argument).
     */
    public function new(?bindings:Array<KeyBinding>) {
        if (bindings != null) {
            addBindings(bindings);
        }
    }

    static inline function actionId(action:Action):String {
        return Type.getClassName(Type.getClass(action));
    }

    static inline function isNoAction(action:Action):Bool {
        return NoAction.isNoAction(action);
    }

    static inline function isUnbind(action:Action):Bool {
        return Unbind.isUnbind(action);
    }

    static function disabledBindingMatchesContext(disabledBinding:KeyBinding, binding:KeyBinding):Bool {
        final disabledPredicate = disabledBinding.contextPredicate;
        final predicate = binding.contextPredicate;
        if (disabledPredicate == null) return true;
        if (predicate == null) return false;
        return disabledPredicate.isSuperset(predicate);
    }

    static function bindingIsUnbound(disabledBinding:KeyBinding, binding:KeyBinding):Bool {
        return KeyBinding.keystrokesArrayEqual(disabledBinding.keystrokes, binding.keystrokes)
            && isUnbind(disabledBinding.action)
            && (cast disabledBinding.action : Unbind).actionName == binding.action.name();
    }

    /**
     * Get the current version of the keymap.
     */
    public inline function version():KeymapVersion {
        return _version;
    }

    /**
     * Add more bindings to the keymap.
     */
    public function addBindings(bindings:Array<KeyBinding>):Void {
        for (binding in bindings) {
            final id = actionId(binding.action);
            if (isNoAction(binding.action) || isUnbind(binding.action)) {
                disabledBindingIndices.push(_bindings.length);
            }
            else {
                var indices = bindingIndicesByActionId.get(id);
                if (indices == null) {
                    indices = [];
                    bindingIndicesByActionId.set(id, indices);
                }
                indices.push(_bindings.length);
            }
            _bindings.push(binding);
        }

        _version = _version + 1;
    }

    /**
     * Reset this keymap to its initial state.
     */
    public function clear():Void {
        _bindings.resize(0);
        bindingIndicesByActionId.clear();
        disabledBindingIndices.resize(0);
        _version = _version + 1;
    }

    /**
     * All bindings, in the order they were added. Do not modify the array.
     */
    public inline function bindings():Array<KeyBinding> {
        return _bindings;
    }

    /**
     * All bindings for the given action, in the order they were added. For
     * display, the last binding should take precedence.
     */
    public function bindingsForAction(action:Action):Array<KeyBinding> {
        final result:Array<KeyBinding> = [];
        final bindingIndices = bindingIndicesByActionId.get(actionId(action));
        if (bindingIndices == null) return result;

        for (ix in bindingIndices) {
            final binding = _bindings[ix];
            if (!binding.action.partialEq(action)) {
                continue;
            }

            var disabled = false;
            for (disabledIx in disabledBindingIndices) {
                if (disabledIx > ix) {
                    final disabledBinding = _bindings[disabledIx];
                    if (!KeyBinding.keystrokesArrayEqual(disabledBinding.keystrokes, binding.keystrokes)) {
                        continue;
                    }

                    if (isNoAction(disabledBinding.action)) {
                        if (disabledBindingMatchesContext(disabledBinding, binding)) {
                            disabled = true;
                            break;
                        }
                    }
                    else if (isUnbind(disabledBinding.action)
                        && disabledBindingMatchesContext(disabledBinding, binding)
                        && bindingIsUnbound(disabledBinding, binding)) {
                        disabled = true;
                        break;
                    }
                }
            }

            if (!disabled) {
                result.push(binding);
            }
        }
        return result;
    }

    /**
     * Returns all bindings that might match the input without checking context.
     * The bindings returned in precedence order (reverse of the order they were
     * added to the keymap).
     */
    public function allBindingsForInput(input:Array<Keystroke>):Array<KeyBinding> {
        final result:Array<KeyBinding> = [];
        var i = _bindings.length - 1;
        while (i >= 0) {
            final binding = _bindings[i];
            if (binding.matchKeystrokes(input) == false) {
                result.push(binding.clone());
            }
            i--;
        }
        return result;
    }

    /**
     * Returns a list of bindings that match the given input, and a boolean
     * indicating whether or not more bindings might match if the input was
     * longer. Bindings are returned in precedence order (higher precedence
     * first, reverse of the order they were added to the keymap).
     *
     * Precedence is defined by the depth in the tree (matches on the Editor take
     * precedence over matches on the Pane, then the Workspace, etc.). Bindings
     * with no context are treated as the same as the deepest context.
     *
     * In the case of multiple bindings at the same depth, the ones added to the
     * keymap later take precedence. User bindings are added after built-in
     * bindings so that they take precedence.
     *
     * If a binding has been disabled with `"x": null` it will not be returned.
     * Disabled bindings are evaluated with the same precedence rules so you can
     * disable a rule in a given context only. A disabled binding only suppresses
     * bindings from sources with equal or weaker precedence: a base keymap null
     * hides default bindings, but user bindings still apply.
     *
     * Rust returns clones of the bindings; the bindings of the keymap are
     * returned here (they are not modified by the keymap).
     */
    public function bindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>):BindingsForInput {
        final indices = [];
        var i = _bindings.length - 1;
        while (i >= 0) {
            indices.push(i);
            i--;
        }
        final resolved = resolveBindingsForInput(input, contextStack, indices);
        return new BindingsForInput([for (ix in resolved.indices) _bindings[ix]], resolved.pending);
    }

    /**
     * Same as `bindingsForInput`, but only looks at the `keymapBindings`
     * indices instead of the whole keymap, and returns binding indices.
     *
     * `keymapBindings` must be in reverse keymap order and include every
     * binding that could match `input`. For example, leaving out a `null`
     * binding would make the binding it disables look like it wins.
     */
    function resolveBindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>, keymapBindings:Array<Int>):{indices:Array<Int>, pending:Bool} {
        final matchedDepths:Array<Int> = [];
        final matchedIndices:Array<Int> = [];
        final pendingIndices:Array<Int> = [];

        for (ix in keymapBindings) {
            final binding = _bindings[ix];
            final depth = bindingEnabled(binding, contextStack);
            if (depth == null) {
                continue;
            }
            final pending = binding.matchKeystrokes(input);
            if (pending == null) {
                continue;
            }

            if (!pending) {
                matchedDepths.push(depth);
                matchedIndices.push(ix);
            }
            else {
                pendingIndices.push(ix);
            }
        }

        // Sort by depth, then index, both descending
        final order = [for (i in 0...matchedIndices.length) i];
        order.sort((a, b) -> {
            final depthA = matchedDepths[a];
            final depthB = matchedDepths[b];
            if (depthA != depthB) return depthB - depthA;
            return matchedIndices[b] - matchedIndices[a];
        });

        final bindings:Array<Int> = [];
        var firstBindingIndex:Null<Int> = null;
        final unboundBindings:Array<KeyBinding> = [];
        // A `NoAction` binding suppresses out-ranked bindings from sources with
        // equal or weaker precedence, while bindings from stronger sources (a
        // smaller meta, e.g. a user binding vs a base keymap null) still apply.
        // Bindings without a meta are treated as user bindings.
        var noActionMeta:Null<Int> = null;

        for (o in order) {
            final ix = matchedIndices[o];
            final binding = _bindings[ix];
            final meta:Int = binding.meta != null ? (binding.meta : Int) : 0;
            if (isNoAction(binding.action)) {
                noActionMeta = noActionMeta == null ? meta : (meta < noActionMeta ? meta : noActionMeta);
                continue;
            }

            if (noActionMeta != null && meta >= noActionMeta) {
                continue;
            }

            if (isUnbind(binding.action)) {
                unboundBindings.push(binding);
                continue;
            }

            var unbound = false;
            for (disabledBinding in unboundBindings) {
                if (bindingIsUnbound(disabledBinding, binding)) {
                    unbound = true;
                    break;
                }
            }
            if (unbound) {
                continue;
            }

            bindings.push(ix);
            if (firstBindingIndex == null) {
                firstBindingIndex = ix;
            }
        }

        // Set of pending keystroke sequences
        final pending = new Map<String, Bool>();
        var pendingCount = 0;
        var p = pendingIndices.length - 1;
        while (p >= 0) {
            final ix = pendingIndices[p--];
            final binding = _bindings[ix];
            if (firstBindingIndex != null && firstBindingIndex > ix) {
                continue;
            }
            final key = keystrokesKey(binding.keystrokes);
            if (isNoAction(binding.action) || isUnbind(binding.action)) {
                if (pending.remove(key)) pendingCount--;
                continue;
            }
            if (!pending.exists(key)) {
                pending.set(key, true);
                pendingCount++;
            }
        }

        return {indices: bindings, pending: pendingCount > 0};
    }

    /**
     * A string identifying a keystroke sequence (Rust hashes the keystrokes).
     */
    static function keystrokesKey(keystrokes:Array<KeybindingKeystroke>):String {
        final buf = new StringBuf();
        for (k in keystrokes) {
            final inner = k.inner();
            buf.add(inner.modifiers.toInt());
            buf.add('\x01');
            buf.add(inner.key);
            buf.add('\x01');
            if (inner.keyChar != null) {
                buf.add('\x02');
                buf.add(inner.keyChar);
            }
            buf.add('\x01');
            buf.add(k.modifiers().toInt());
            buf.add('\x01');
            buf.add(k.key());
            buf.add('\x03');
        }
        return buf.toString();
    }

    /**
     * Check if the given binding is enabled, given a certain key context.
     * Returns the deepest depth at which the binding matches, or null if it
     * doesn't match.
     */
    @:allow(glaze)
    function bindingEnabled(binding:KeyBinding, contexts:Array<KeyContext>):Null<Int> {
        final predicate = binding.contextPredicate;
        if (predicate != null) {
            return predicate.depthOf(contexts);
        }
        return contexts.length;
    }

    /**
     * Find the bindings that can follow the current input sequence, in
     * precedence order. Only includes bindings that dispatch would run for their
     * full keystrokes, so bindings disabled with `null` or `Unbind` are left out.
     */
    public function possibleNextBindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>):Array<KeyBinding> {
        // Keeps `null` and `Unbind` bindings, which can disable candidates.
        final bindingsExtendingInput:Array<Int> = [];
        var i = _bindings.length - 1;
        while (i >= 0) {
            if (_bindings[i].matchKeystrokes(input) == true) {
                bindingsExtendingInput.push(i);
            }
            i--;
        }

        final candidateDepths:Array<Int> = [];
        final candidateIndices:Array<Int> = [];
        for (ix in bindingsExtendingInput) {
            final binding = _bindings[ix];
            if (isNoAction(binding.action) || isUnbind(binding.action)) {
                continue;
            }
            final depth = bindingEnabled(binding, contextStack);
            if (depth == null) {
                continue;
            }
            // Use the typed input rather than the binding's own keystrokes. A typed keystroke
            // can match through its physical key, like `alt-s`, or the character it produced,
            // like `ß`.
            final fullInput = input.copy();
            for (k in input.length...binding.keystrokes.length) {
                fullInput.push(binding.keystrokes[k].inner());
            }
            final dispatched = resolveBindingsForInput(fullInput, contextStack, bindingsExtendingInput);
            if (dispatched.indices.indexOf(ix) != -1) {
                candidateDepths.push(depth);
                candidateIndices.push(ix);
            }
        }

        final order = [for (c in 0...candidateIndices.length) c];
        order.sort((a, b) -> {
            final depthA = candidateDepths[a];
            final depthB = candidateDepths[b];
            if (depthA != depthB) return depthB - depthA;
            return candidateIndices[b] - candidateIndices[a];
        });

        return [for (o in order) _bindings[candidateIndices[o]].clone()];
    }

}

/**
 * An opaque identifier of which version of the keymap is currently active.
 * The keymap's version is changed whenever bindings are added or removed.
 */
abstract KeymapVersion(Int) from Int to Int {}

/**
 * Result of `Keymap.bindingsForInput` (Rust: a `(bindings, pending)` tuple).
 */
class BindingsForInput {

    /**
     * The matching bindings, highest precedence first.
     */
    public final bindings:Array<KeyBinding>;

    /**
     * Whether more bindings might match if the input was longer.
     */
    public final pending:Bool;

    public function new(bindings:Array<KeyBinding>, pending:Bool) {
        this.bindings = bindings;
        this.pending = pending;
    }

}
