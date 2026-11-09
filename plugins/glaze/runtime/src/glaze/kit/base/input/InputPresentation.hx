// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`InputPresentation`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.FocusHandle;
import glaze.TextAlign;

/**
 * Read-only styling data exposed to presentation facades.
 *
 * The fields are private and read through the methods below, so that a new
 * one can be added without breaking the facades.
 */
class InputPresentation {

    final _focusHandle:FocusHandle;
    final _disabled:Bool;
    final _readonly:Bool;
    final _loading:Bool;
    final _masked:Bool;
    final _multiLine:Bool;
    final _textAlign:TextAlign;
    final _placeholder:String;
    final _maskPlaceholder:Null<String>;

    @:allow(glaze.kit.base.input)
    function new(focusHandle:FocusHandle, disabled:Bool, readonly:Bool, loading:Bool, masked:Bool, multiLine:Bool, textAlign:TextAlign, placeholder:String, maskPlaceholder:Null<String>) {
        _focusHandle = focusHandle;
        _disabled = disabled;
        _readonly = readonly;
        _loading = loading;
        _masked = masked;
        _multiLine = multiLine;
        _textAlign = textAlign;
        _placeholder = placeholder;
        _maskPlaceholder = maskPlaceholder;
    }

    public inline function focusHandle():FocusHandle {
        return _focusHandle;
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
     * See also: `InputBaseState.isEditable`.
     */
    public inline function isEditable():Bool {
        return !_disabled && !_readonly;
    }

    public inline function isLoading():Bool {
        return _loading;
    }

    public inline function isMasked():Bool {
        return _masked;
    }

    public inline function isMultiLine():Bool {
        return _multiLine;
    }

    public inline function textAlign():TextAlign {
        return _textAlign;
    }

    public inline function placeholder():String {
        return _placeholder;
    }

    /** The placeholder derived from the mask pattern, e.g.: `(___) ___-____`. */
    public inline function maskPlaceholder():Null<String> {
        return _maskPlaceholder;
    }

}
