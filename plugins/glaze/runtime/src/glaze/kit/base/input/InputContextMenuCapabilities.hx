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
    final _codeEditor:Bool;
    final _selection:Bool;
    final _masked:Bool;
    final _goToDefinition:Bool;
    final _codeActions:Bool;

    public function new(disabled:Bool = false, readonly:Bool = false, codeEditor:Bool = false, selection:Bool = false, masked:Bool = false,
            goToDefinition:Bool = false, codeActions:Bool = false) {
        _disabled = disabled;
        _readonly = readonly;
        _codeEditor = codeEditor;
        _selection = selection;
        _masked = masked;
        _goToDefinition = goToDefinition;
        _codeActions = codeActions;
    }

    public function disabled(disabled:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(disabled, _readonly, _codeEditor, _selection, _masked, _goToDefinition, _codeActions);
    }

    public function readonly(readonly:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, readonly, _codeEditor, _selection, _masked, _goToDefinition, _codeActions);
    }

    public function codeEditor(codeEditor:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, codeEditor, _selection, _masked, _goToDefinition, _codeActions);
    }

    /** Set whether the input has a non-empty selection. */
    public function selection(selection:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, _codeEditor, selection, _masked, _goToDefinition, _codeActions);
    }

    /** Set whether the input renders its value masked. */
    public function masked(masked:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, _codeEditor, _selection, masked, _goToDefinition, _codeActions);
    }

    public function goToDefinition(goToDefinition:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, _codeEditor, _selection, _masked, goToDefinition, _codeActions);
    }

    public function codeActions(codeActions:Bool):InputContextMenuCapabilities {
        return new InputContextMenuCapabilities(_disabled, _readonly, _codeEditor, _selection, _masked, _goToDefinition, codeActions);
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
     * The items that write to the input (Cut, Paste, Code Actions) belong to
     * this, the reading ones (Copy, Go to Definition) do not.
     */
    public inline function isEditable():Bool {
        return !_disabled && !_readonly;
    }

    public inline function isCodeEditor():Bool {
        return _codeEditor;
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

    public inline function hasDefinition():Bool {
        return _goToDefinition;
    }

    public inline function hasCodeActions():Bool {
        return _codeActions;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<InputContextMenuCapabilities>):Bool {
        return other != null && other._disabled == _disabled && other._readonly == _readonly && other._codeEditor == _codeEditor
            && other._selection == _selection && other._masked == _masked && other._goToDefinition == _goToDefinition
            && other._codeActions == _codeActions;
    }

}
