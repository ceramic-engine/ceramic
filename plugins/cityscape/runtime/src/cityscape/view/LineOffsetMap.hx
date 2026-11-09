// New code for Cityscape (not a port): UTF-16 offsets (Monaco columns) to
// UTF-8 byte offsets (Glaze's text system) of one rendered line, in one pass
// (AUDIT A.6.2).
package cityscape.view;

import cityscape.base.common.Strings;

/**
 * The offset maps of one line: `utf16ToByte(i)` for every UTF-16 offset
 * (`text.length + 1` entries), `byteToUtf16(b)` for every byte offset.
 * Identity (no arrays) for ASCII lines. A lone surrogate counts 3 bytes
 * (U+FFFD), like `ttf.Utf8`.
 */
class LineOffsetMap {

    public var isAscii(default, null):Bool = true;

    public var utf16Length(default, null):Int = 0;

    public var byteLength(default, null):Int = 0;

    final _utf16ToByte:Array<Int> = [];
    final _byteToUtf16:Array<Int> = [];

    public function new() {}

    public function reset(text:String):Void {
        final len = text.length;
        utf16Length = len;
        var ascii = true;
        for (i in 0...len) {
            if (StringTools.fastCodeAt(text, i) >= 0x80) {
                ascii = false;
                break;
            }
        }
        isAscii = ascii;
        if (ascii) {
            byteLength = len;
            _utf16ToByte.resize(0);
            _byteToUtf16.resize(0);
            return;
        }
        _utf16ToByte.resize(len + 1);
        _byteToUtf16.resize(0);
        var bytes = 0;
        var i = 0;
        while (i < len) {
            final c = StringTools.fastCodeAt(text, i);
            _utf16ToByte[i] = bytes;
            var units = 1;
            var size:Int;
            if (c < 0x80) {
                size = 1;
            } else if (c < 0x800) {
                size = 2;
            } else if (Strings.isHighSurrogate(c) && i + 1 < len && Strings.isLowSurrogate(StringTools.fastCodeAt(text, i + 1))) {
                size = 4;
                units = 2;
                // the low surrogate maps to the start of the code point
                _utf16ToByte[i + 1] = bytes;
            } else {
                size = 3;
            }
            for (_ in 0...size) {
                _byteToUtf16.push(i);
            }
            bytes += size;
            i += units;
        }
        _utf16ToByte[len] = bytes;
        _byteToUtf16.push(len);
        byteLength = bytes;
    }

    public inline function utf16ToByte(offset:Int):Int {
        if (isAscii) {
            return offset;
        }
        if (offset <= 0) {
            return 0;
        }
        if (offset >= utf16Length) {
            return byteLength;
        }
        return _utf16ToByte[offset];
    }

    public inline function byteToUtf16(offset:Int):Int {
        if (isAscii) {
            return offset;
        }
        if (offset <= 0) {
            return 0;
        }
        if (offset >= byteLength) {
            return utf16Length;
        }
        return _byteToUtf16[offset];
    }

}
