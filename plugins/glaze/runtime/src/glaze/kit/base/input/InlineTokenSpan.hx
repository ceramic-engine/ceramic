// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * A token and its current half-open UTF-8 byte range.
 */
class InlineTokenSpan {

    @:allow(gpui.base.input)
    final _range:Range;

    @:allow(gpui.base.input)
    final _token:InlineToken;

    @:allow(gpui.base.input)
    function new(range:Range, token:InlineToken) {
        this._range = range;
        this._token = token;
    }

    public inline function range():Range {
        return _range;
    }

    public inline function token():InlineToken {
        return _token;
    }

    @:allow(gpui.base.input)
    function shifted(delta:Int):InlineTokenSpan {
        final start = _range.start + delta;
        final end = _range.end + delta;
        if (start < 0) throw 'valid token start';
        if (end < 0) throw 'valid token end';
        return new InlineTokenSpan(new Range(start, end), _token);
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<InlineTokenSpan>):Bool {
        return other != null && other._range.equals(_range) && other._token.equals(_token);
    }

    public static function sameAll(a:Array<InlineTokenSpan>, b:Array<InlineTokenSpan>):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) if (!a[i].equals(b[i])) return false;
        return true;
    }

    public function toString():String {
        return 'InlineTokenSpan { range: ' + _range + ', token: ' + _token + ' }';
    }

}
