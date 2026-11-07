// Ported from gpui-pre 0.3.10: src/platform/keystroke.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Represents a keystroke that can be used in keybindings and displayed to the user.
 *
 * GPUI only stores the display modifiers and key on Windows (compile time).
 * They are always stored here; `modifiers()`, `key()` and `unparse()` return
 * them when `OperatingSystem.current` is `Windows`, and the inner keystroke
 * otherwise. `setModifiers` / `setKey` keep both in sync on every platform.
 */
class KeybindingKeystroke {

    /**
     * The GPUI representation of the keystroke.
     */
    final _inner:Keystroke;

    /**
     * The modifiers to display (Windows).
     */
    var displayModifiers:Modifiers;

    /**
     * The key to display (Windows).
     */
    var displayKey:String;

    /**
     * Rust `KeybindingKeystroke::new`, which only exists on Windows.
     */
    public function new(inner:Keystroke, displayModifiers:Modifiers, displayKey:String) {
        this._inner = inner;
        this.displayModifiers = displayModifiers;
        this.displayKey = displayKey;
    }

    /**
     * Create a new keybinding keystroke from the given keystroke using the given keyboard mapper.
     */
    public static function newWithMapper(inner:Keystroke, useKeyEquivalents:Bool, keyboardMapper:PlatformKeyboardMapper):KeybindingKeystroke {
        return keyboardMapper.mapKeyEquivalent(inner, useKeyEquivalents);
    }

    /**
     * Create a new keybinding keystroke from the given keystroke, without any platform-specific mapping.
     */
    public static function fromKeystroke(keystroke:Keystroke):KeybindingKeystroke {
        return new KeybindingKeystroke(keystroke, keystroke.modifiers, keystroke.key);
    }

    /**
     * Formats this binding using the supplied host OS's key labels.
     */
    public function display(os:OperatingSystem):String {
        return Keystroke.displayKeystroke(modifiers(), key(), os);
    }

    /**
     * Returns the GPUI representation of the keystroke.
     */
    public inline function inner():Keystroke {
        return _inner;
    }

    /**
     * Returns the modifiers. On Windows, these are the display modifiers, for
     * example a `ctrl-@` keystroke has `inner.modifiers` control and display
     * modifiers control + shift. Elsewhere, `inner.modifiers`.
     */
    public function modifiers():Modifiers {
        return OperatingSystem.current == Windows ? displayModifiers : _inner.modifiers;
    }

    /**
     * Returns the key. On Windows, this is the display key, for example a
     * `ctrl-@` keystroke has `inner.key` "@" and display key "2". Elsewhere,
     * `inner.key`.
     */
    public function key():String {
        return OperatingSystem.current == Windows ? displayKey : _inner.key;
    }

    /**
     * Sets the modifiers, both inner and displayed.
     */
    public function setModifiers(modifiers:Modifiers):Void {
        _inner.modifiers = modifiers;
        displayModifiers = modifiers;
    }

    /**
     * Sets the key, both inner and displayed.
     */
    public function setKey(key:String):Void {
        displayKey = key;
        _inner.key = key;
    }

    /**
     * Serializes this binding with the supplied host OS's modifier spelling.
     */
    public function unparse(os:OperatingSystem):String {
        if (OperatingSystem.current == Windows) {
            return Keystroke.unparseKeystroke(displayModifiers, displayKey, os);
        }
        return Keystroke.unparseKeystroke(_inner.modifiers, _inner.key, os);
    }

    /**
     * Removes the keyChar.
     */
    public function removeKeyChar():Void {
        _inner.keyChar = null;
    }

    public function copy():KeybindingKeystroke {
        return new KeybindingKeystroke(_inner.copy(), displayModifiers, displayKey);
    }

    /**
     * Structural equality (Rust derived `PartialEq`).
     */
    public function equals(other:KeybindingKeystroke):Bool {
        return other != null
            && _inner.equals(other._inner)
            && displayModifiers == other.displayModifiers
            && displayKey == other.displayKey;
    }

    public function toString():String {
        return unparse(Mac);
    }

}
