// Ported from vscode src/vs/editor/common/core/stringBuilder.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Strings;

/**
 * Builds a string from UTF-16 code units. Monaco fills a `Uint16Array`
 * decoded with a `TextDecoder`; here a `StringBuf`, with surrogate pairs
 * combined into one code point when appended (`StringBuf.addChar` takes
 * code points on every target). The UTF-16 decoders of stringBuilder.ts are
 * not ported (not used by the view).
 */
class StringBuilder {

    var _buf:StringBuf;
    var _pendingHighSurrogate:Int = -1;

    public function new(capacity:Int) {
        this._buf = new StringBuf();
    }

    public function reset():Void {
        this._buf = new StringBuf();
        this._pendingHighSurrogate = -1;
    }

    public function build():String {
        _flushPending();
        return this._buf.toString();
    }

    inline function _flushPending():Void {
        if (_pendingHighSurrogate != -1) {
            // A lone high surrogate: U+FFFD, like a TextDecoder
            this._buf.addChar(0xFFFD);
            _pendingHighSurrogate = -1;
        }
    }

    /**
     * Append a char code (<2^16)
     */
    public function appendCharCode(charCode:Int):Void {
        if (_pendingHighSurrogate != -1) {
            if (Strings.isLowSurrogate(charCode)) {
                this._buf.addChar(Strings.computeCodePoint(_pendingHighSurrogate, charCode));
                _pendingHighSurrogate = -1;
                return;
            }
            _flushPending();
        }
        if (Strings.isHighSurrogate(charCode)) {
            _pendingHighSurrogate = charCode;
            return;
        }
        if (Strings.isLowSurrogate(charCode)) {
            this._buf.addChar(0xFFFD);
            return;
        }
        this._buf.addChar(charCode);
    }

    /**
     * Append an ASCII char code (<2^8)
     */
    public function appendASCIICharCode(charCode:Int):Void {
        _flushPending();
        this._buf.addChar(charCode);
    }

    public function appendString(str:String):Void {
        _flushPending();
        this._buf.add(str);
    }

}
