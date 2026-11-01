// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * An application-defined reference rendered as one inline editing unit. The
 * ID names the referenced resource; the same ID may occur more than once.
 */
class InlineToken {

    final _id:String;

    final _text:String;

    var _label:String;

    public function new(id:String, text:String) {
        this._id = id;
        this._label = text;
        this._text = text;
    }

    /** A copy with another label (Rust `with_label`, by value). */
    public function withLabel(label:String):InlineToken {
        final token = new InlineToken(_id, _text);
        token._label = label;
        return token;
    }

    public inline function id():String {
        return _id;
    }

    public inline function text():String {
        return _text;
    }

    public inline function label():String {
        return _label;
    }

    /** The validation error, or null when the token is valid. */
    @:allow(gpui.base.input)
    function validate():Null<InlineTokenError> {
        if (StringTools.trim(_id).length == 0 || isInvalidText(_text) || isInvalidText(_label)) {
            return InlineTokenError.InvalidToken;
        }
        return null;
    }

    static function isInvalidText(s:String):Bool {
        if (s.length == 0) return true;
        for (c in new haxe.iterators.StringIteratorUnicode(s)) {
            // Rust `char::is_control` (general category Cc), and the line and paragraph separators.
            if (c <= 0x1F || (c >= 0x7F && c <= 0x9F) || c == 0x2028 || c == 0x2029) return true;
        }
        return false;
    }

    /** Rust `PartialEq` (also stands for `Hash`: see `hashKey`). */
    public function equals(other:Null<InlineToken>):Bool {
        return other != null && other._id == _id && other._text == _text && other._label == _label;
    }

    /** A string key equal for equal tokens (Rust `Hash`, for maps keyed by token). */
    public function hashKey():String {
        return _id.length + ':' + _id + _text.length + ':' + _text + _label;
    }

    public function toString():String {
        return 'InlineToken { id: ' + _id + ', text: ' + _text + ', label: ' + _label + ' }';
    }

}
