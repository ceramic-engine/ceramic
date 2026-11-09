// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * What the input can offer to its context menu, at the moment it is opened.
 *
 * Built by the input and read by the menu, the fields are private and
 * reached through the methods below, so that a new capability can be added
 * without breaking the menu builders. The builders return a new value (Rust
 * `Copy` by value).
 */
class InputContextMenuCapabilities {

    final _disabled:Bool;
    final _readonly:Bool;
    final _selection:Bool;
    final _masked:Bool;

    public function new(disabled:Bool = false, readonly:Bool = false, selection:Bool = false, masked:Bool = false) {
        _disabled = disabled;
        _readonly = readonly;
        _selection = selection;
        _masked = masked;
    }

    public function disabled(disabled:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(disabled, _readonly, _selection, _masked);
    }

    public function readonly(readonly:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, readonly, _selection, _masked);
    }

    /** Set whether the input has a non-empty selection. */
    public function selection(selection:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, selection, _masked);
    }

    /** Set whether the input renders its value masked. */
    public function masked(masked:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, _selection, masked);
    }

    public inline function isDisabled():Bool {
        return _disabled;
    }

    public inline function isReadonly():Bool {
        return _readonly;
    }

    /**
     * Returns true if the user is allowed to change the text.
     *
     * The items that write to the input (Cut, Paste) belong to this, the
     * reading ones (Copy) do not.
     */
    public inline function isEditable():Bool {
        return !_disabled && !_readonly;
    }

    public inline function hasSelection():Bool {
        return _selection;
    }

    public inline function isMasked():Bool {
        return _masked;
    }

    /**
     * Returns true if the user is allowed to copy the text out.
     *
     * A masked input keeps its value out of the clipboard, so Copy and Cut
     * are both unavailable while the value is hidden.
     */
    public inline function isCopyable():Bool {
        return _selection && !_masked;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<InputContextMenuCapabilities>):Bool {
        return other != null && other._disabled == _disabled && other._readonly == _readonly && other._selection == _selection
            && other._masked == _masked;
    }

}
