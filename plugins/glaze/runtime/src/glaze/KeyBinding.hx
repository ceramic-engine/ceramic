// Ported from gpui-pre 0.3.10: src/keymap/binding.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A keybinding and its associated metadata, from the keymap.
 *
 * Rust's crate-visible fields and their accessors (`action()`,
 * `keystrokes()`, `meta()`, `action_input()`) cannot share names in Haxe: they
 * are read-only fields here (`binding.action`, `binding.keystrokes`...).
 */
class KeyBinding {

    /**
     * The action of this binding.
     */
    public var action(default, null):Action;

    /**
     * The keystrokes of this binding.
     */
    public var keystrokes(default, null):Array<KeybindingKeystroke>;

    /**
     * The predicate used to match this binding (null: matches every context).
     */
    public var contextPredicate(default, null):Null<KeyBindingContextPredicate>;

    /**
     * The metadata of this binding, such as its source.
     */
    public var meta(default, null):Null<KeyBindingMetaIndex>;

    /**
     * The json input string used when building the keybinding, if any.
     */
    public var actionInput(default, null):Null<String>;

    /**
     * Constructs a static keybinding with explicit modifiers. Throws on parse error
     * (Rust panics).
     *
     * Use `KeyBinding.load` for dynamic input or to resolve `secondary-` using the host OS.
     */
    public function new(keystrokes:String, action:Action, ?context:String) {
        this.action = action;
        this.contextPredicate = context != null ? KeyBindingContextPredicateTools.parse(context) : null;
        this.meta = null;
        this.actionInput = null;
        this.keystrokes = parseKeystrokes(keystrokes, false, DummyKeyboardMapper.instance, null);
    }

    /**
     * Load a keybinding from the given raw data. `secondary-` resolves with
     * `os` (GPUI: `cx.platform_info().os`, default `OperatingSystem.current`),
     * keys go through `keyboardMapper` (GPUI: `cx.keyboard_mapper()`, default
     * `DummyKeyboardMapper`). Throws `InvalidKeystrokeError`.
     */
    public static function load(keystrokes:String, action:Action, contextPredicate:Null<KeyBindingContextPredicate>, useKeyEquivalents:Bool, ?actionInput:String, ?keyboardMapper:PlatformKeyboardMapper, ?os:OperatingSystem):KeyBinding {
        if (os == null) os = OperatingSystem.current;
        if (keyboardMapper == null) keyboardMapper = DummyKeyboardMapper.instance;
        final binding = new KeyBinding('', action);
        binding.keystrokes = parseKeystrokes(keystrokes, useKeyEquivalents, keyboardMapper, os);
        binding.contextPredicate = contextPredicate;
        binding.actionInput = actionInput;
        return binding;
    }

    static function parseKeystrokes(source:String, useKeyEquivalents:Bool, keyboardMapper:PlatformKeyboardMapper, os:Null<OperatingSystem>):Array<KeybindingKeystroke> {
        final result:Array<KeybindingKeystroke> = [];
        // Rust `split_whitespace`
        var pos = 0;
        final len = source.length;
        while (pos < len) {
            pos = glaze.KeyContext.ContextScanner.skipWhitespace(source, pos);
            if (pos >= len) break;
            final start = pos;
            while (pos < len && !glaze.KeyContext.ContextScanner.isWhitespace(StringTools.fastCodeAt(source, pos))) {
                pos++;
            }
            final part = source.substring(start, pos);
            final keystroke = os != null ? Keystroke.parseWithOs(part, os) : Keystroke.parse(part);
            result.push(KeybindingKeystroke.newWithMapper(keystroke, useKeyEquivalents, keyboardMapper));
        }
        return result;
    }

    /**
     * Rust `Clone`: clones the action (`boxedClone`), shares the rest.
     */
    public function clone():KeyBinding {
        final binding = new KeyBinding('', action.boxedClone());
        binding.keystrokes = keystrokes.copy();
        binding.contextPredicate = contextPredicate;
        binding.meta = meta;
        binding.actionInput = actionInput;
        return binding;
    }

    /**
     * Set the metadata for this binding.
     */
    public function withMeta(meta:KeyBindingMetaIndex):KeyBinding {
        this.meta = meta;
        return this;
    }

    /**
     * Set the metadata for this binding.
     */
    public function setMeta(meta:KeyBindingMetaIndex):Void {
        this.meta = meta;
    }

    /**
     * Check if the given keystrokes match this binding: null if they do not,
     * true if they match a prefix (more keystrokes are pending), false if they
     * match exactly.
     */
    public function matchKeystrokes(typed:Array<Keystroke>):Null<Bool> {
        if (keystrokes.length < typed.length) {
            return null;
        }

        for (i in 0...typed.length) {
            if (!typed[i].shouldMatch(keystrokes[i])) {
                return null;
            }
        }

        return keystrokes.length > typed.length;
    }

    /**
     * Get the predicate used to match this binding.
     */
    public inline function predicate():Null<KeyBindingContextPredicate> {
        return contextPredicate;
    }

    /**
     * Whether both bindings have the same keystrokes (Rust compares the
     * keystroke vectors with `==`).
     */
    public function keystrokesEqual(other:KeyBinding):Bool {
        return keystrokesArrayEqual(keystrokes, other.keystrokes);
    }

    @:allow(glaze)
    static function keystrokesArrayEqual(a:Array<KeybindingKeystroke>, b:Array<KeybindingKeystroke>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i])) return false;
        }
        return true;
    }

    public function toString():String {
        return 'KeyBinding(keystrokes: ' + [for (k in keystrokes) k.unparse(Mac)].join(' ')
            + ', context_predicate: ' + (contextPredicate != null ? contextPredicate.toString() : 'None')
            + ', action: ' + action.name() + ')';
    }

}
