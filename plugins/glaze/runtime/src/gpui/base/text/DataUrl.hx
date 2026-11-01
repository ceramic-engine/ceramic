// Ported from data-url 0.3.2 (https://github.com/servo/rust-url/tree/main/data-url): src/lib.rs, src/mime.rs, src/forgiving_base64.rs
// Original code Copyright 2013-2025 The rust-url developers, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * Processing of `data:` URLs according to the Fetch Standard
 * (<https://fetch.spec.whatwg.org/#data-urls>), starting from a string
 * rather than a parsed URL to avoid extra copies.
 *
 * Rust works on UTF-8 bytes throughout (`&str` indexed by byte, with a few
 * algorithms that explicitly percent-encode individual bytes rather than
 * whole code points), so this port encodes the input once with
 * `haxe.io.Bytes.ofString` and keeps working on bytes, like the original.
 *
 * ```
 * final url = DataUrl.process("data:,Hello%20World!");
 * final decoded = url.decodeToVec();
 * trace(url.mimeType().matches("text", "plain"));
 * trace(url.mimeType().getParameter("charset")); // "US-ASCII"
 * trace(decoded.body); // "Hello World!" bytes
 * trace(decoded.fragment); // null
 * ```
 */
class DataUrl {

    final mimeType_:Mime;
    final base64_:Bool;
    final encodedBodyPlusFragment_:Bytes;

    function new(mimeType:Mime, base64:Bool, encodedBodyPlusFragment:Bytes) {
        mimeType_ = mimeType;
        base64_ = base64;
        encodedBodyPlusFragment_ = encodedBodyPlusFragment;
    }

    /**
     * `DataUrl::process`: similar to the URL Standard's basic URL parser
     * followed by its serializer, but starting from a string rather than a
     * parsed `Url`. `null` for both Rust error variants (`NotADataUrl`,
     * `NoComma`).
     */
    public static function process(input:String):Null<DataUrl> {
        final bytes = Bytes.ofString(input);
        final afterColon = pretendParseDataUrl(bytes, 0, bytes.length);
        if (afterColon == null)
            return null;
        final comma = findCommaBeforeFragment(bytes, afterColon.start, afterColon.end);
        if (comma == null)
            return null;
        final header = parseHeader(bytes, afterColon.start, comma.commaIndex);
        final restStart = comma.commaIndex + 1;
        final bodyPlusFragment = bytes.sub(restStart, afterColon.end - restStart);
        return new DataUrl(header.mime, header.base64, bodyPlusFragment);
    }

    public inline function mimeType():Mime {
        return mimeType_;
    }

    /**
     * Streaming-decode the data URL's body to `writeBodyBytes`.
     *
     * Rust returns `Result<Option<FragmentIdentifier>, DecodeError<E>>`: the
     * write callback can itself fail with a caller-chosen error `E`. This
     * port's callback is `Void`-returning (nothing in this codebase needs a
     * fallible sink), so the only failure this can report is
     * `InvalidBase64`.
     */
    public function decode(writeBodyBytes:Bytes->Void):DataUrlDecodeOutcome {
        return decodeInternal(writeBodyBytes);
    }

    /** `DataUrl::decode_to_vec`: the decoded body, and the fragment if any. `null` on `InvalidBase64`. */
    public function decodeToVec():Null<DataUrlBody> {
        final buffer = new BytesBuffer();
        final outcome = decodeInternal(bytes -> buffer.addBytes(bytes, 0, bytes.length));
        return switch outcome {
            case InvalidBase64: null;
            case Decoded(fragment): new DataUrlBody(buffer.getBytes(), fragment);
        }
    }

    /** `DataUrl::decode_to_vec` keeping only the body. `null` on `InvalidBase64`. */
    public function decodeToBytes():Null<Bytes> {
        final decoded = decodeToVec();
        return decoded == null ? null : decoded.body;
    }

    function decodeInternal(writeBodyBytes:Bytes->Void):DataUrlDecodeOutcome {
        if (base64_)
            return decodeWithBase64(encodedBodyPlusFragment_, writeBodyBytes);
        final result = decodeWithoutBase64(encodedBodyPlusFragment_, bytes -> {
            writeBodyBytes(bytes);
            return true;
        });
        return switch result {
            case NoFragment: Decoded(null);
            case Fragment(raw): Decoded(new FragmentIdentifier(raw));
            case WriteFailed: Decoded(null); // unreachable: the callback above never fails
        }
    }

    static function decodeWithBase64(encodedBodyPlusFragment:Bytes, writeBodyBytes:Bytes->Void):DataUrlDecodeOutcome {
        final decoder = new ForgivingBase64Decoder(writeBodyBytes);
        final result = decodeWithoutBase64(encodedBodyPlusFragment, bytes -> decoder.feed(bytes));
        return switch result {
            case WriteFailed:
                InvalidBase64;
            case NoFragment:
                decoder.finish() ? Decoded(null) : InvalidBase64;
            case Fragment(raw):
                decoder.finish() ? Decoded(new FragmentIdentifier(raw)) : InvalidBase64;
        }
    }

    /**
     * This is `string-percent-decode` (URL Standard) while also ignoring
     * ASCII tab or newlines, and stopping at the first `#` (the start of the
     * fragment). `writeBytes` returning `false` stops decoding immediately,
     * like the `?` operator on the Rust write callback's `Result`.
     */
    static function decodeWithoutBase64(encodedBodyPlusFragment:Bytes, writeBytes:Bytes->Bool):DecodeWithoutBase64Result {
        final len = encodedBodyPlusFragment.length;
        var sliceStart = 0;
        var i = 0;
        while (i < len) {
            final byte = encodedBodyPlusFragment.get(i);
            if (byte == '%'.code || byte == '#'.code || byte == '\t'.code || byte == '\n'.code || byte == '\r'.code) {
                if (i > sliceStart) {
                    if (!writeBytes(encodedBodyPlusFragment.sub(sliceStart, i - sliceStart)))
                        return WriteFailed;
                    sliceStart = i;
                }
                switch (byte) {
                    case '%'.code:
                        final h = i + 1 < len ? hexDigit(encodedBodyPlusFragment.get(i + 1)) : -1;
                        final l = i + 2 < len ? hexDigit(encodedBodyPlusFragment.get(i + 2)) : -1;
                        if (h >= 0 && l >= 0) {
                            final oneByte = Bytes.alloc(1);
                            oneByte.set(0, h * 0x10 + l);
                            if (!writeBytes(oneByte))
                                return WriteFailed;
                            sliceStart = i + 3;
                            i += 3;
                        } else {
                            // Do nothing: leave sliceStart unchanged, the '%' is part of the next slice.
                            i += 1;
                        }
                    case '#'.code:
                        final fragmentStart = i + 1;
                        return Fragment(encodedBodyPlusFragment.sub(fragmentStart, len - fragmentStart));
                    default:
                        // '\t' | '\n' | '\r'
                        sliceStart = i + 1;
                        i += 1;
                }
            } else {
                i += 1;
            }
        }
        if (!writeBytes(encodedBodyPlusFragment.sub(sliceStart, len - sliceStart)))
            return WriteFailed;
        return NoFragment;
    }

    static inline function hexDigit(b:Int):Int {
        if (b >= '0'.code && b <= '9'.code)
            return b - '0'.code;
        if (b >= 'a'.code && b <= 'f'.code)
            return b - 'a'.code + 10;
        if (b >= 'A'.code && b <= 'F'.code)
            return b - 'A'.code + 10;
        return -1;
    }

    /**
     * Similar to the URL Standard's basic URL parser followed by its
     * serializer, except: the `data:` prefix is removed, the fragment is
     * included, other components are not UTF-8 percent-encoded, and ASCII
     * tabs/newlines in the middle are not removed. `null` when `input` is
     * not a data URL.
     */
    static function pretendParseDataUrl(bytes:Bytes, start:Int, end:Int):Null<{start:Int, end:Int}> {
        // Trim leading C0 control or space.
        var i = start;
        while (i < end && bytes.get(i) <= 0x20)
            i++;

        var p = i;
        function nextForward():Int {
            while (p < end) {
                final b = bytes.get(p);
                p++;
                if (b == '\t'.code || b == '\n'.code || b == '\r'.code)
                    continue;
                return b;
            }
            return -1;
        }
        inline function eqIgnoreCase(b:Int, lower:Int):Bool {
            return b == lower || b == lower - 32;
        }

        var b = nextForward();
        if (!eqIgnoreCase(b, 'd'.code))
            return null;
        b = nextForward();
        if (!eqIgnoreCase(b, 'a'.code))
            return null;
        b = nextForward();
        if (!eqIgnoreCase(b, 't'.code))
            return null;
        b = nextForward();
        if (!eqIgnoreCase(b, 'a'.code))
            return null;
        b = nextForward();
        if (b != ':'.code)
            return null;

        final afterColonStart = p;
        // Trim trailing C0 control or space.
        var e = end;
        while (e > afterColonStart && bytes.get(e - 1) <= 0x20)
            e--;
        return {start: afterColonStart, end: e};
    }

    static function findCommaBeforeFragment(bytes:Bytes, start:Int, end:Int):Null<{commaIndex:Int}> {
        var i = start;
        while (i < end) {
            final b = bytes.get(i);
            if (b == ','.code)
                return {commaIndex: i};
            if (b == '#'.code)
                break;
            i++;
        }
        return null;
    }

    static function parseHeader(bytes:Bytes, start:Int, end:Int):{mime:Mime, base64:Bool} {
        // "Strip leading and trailing ASCII whitespace": \t, \n, \r would have
        // been filtered by the URL parser, \f percent-encoded by it; space is
        // the only remaining ASCII whitespace this library has to handle too.
        inline function isTrimChar(b:Int):Bool {
            return b == ' '.code || b == '\t'.code || b == '\n'.code || b == '\r'.code;
        }
        var s = start, e = end;
        while (s < e && isTrimChar(bytes.get(s)))
            s++;
        while (e > s && isTrimChar(bytes.get(e - 1)))
            e--;

        final suffixEnd = removeBase64Suffix(bytes, s, e);
        final base64 = suffixEnd >= 0;
        final mimeEnd = base64 ? suffixEnd : e;

        final buf = new StringBuf();
        if (mimeEnd > s && bytes.get(s) == ';'.code)
            buf.add('text/plain');
        var inQuery = false;
        var i = s;
        while (i < mimeEnd) {
            final byte = bytes.get(i);
            i++;
            if (byte == '\t'.code || byte == '\n'.code || byte == '\r'.code) {
                continue;
            } else if (byte <= 0x1F || byte >= 0x7F) {
                percentEncode(byte, buf);
            } else if (inQuery && (byte == ' '.code || byte == '"'.code || byte == '<'.code || byte == '>'.code)) {
                percentEncode(byte, buf);
            } else if (byte == '?'.code) {
                inQuery = true;
                buf.addChar(byte);
            } else {
                buf.addChar(byte);
            }
        }

        // FIXME (matches upstream): does Mime.parse match the MIME Sniffing
        // Standard's parsing algorithm?
        final parsed = Mime.parse(buf.toString());
        final mime = parsed != null ? parsed : new Mime('text', 'plain', [{name: 'charset', value: 'US-ASCII'}]);
        return {mime: mime, base64: base64};
    }

    /** `null` when there is no base64 suffix; otherwise the byte offset of the `;` that starts it. */
    static function removeBase64Suffix(bytes:Bytes, start:Int, end:Int):Int {
        var i = end;
        function nextBack():Int {
            while (i > start) {
                i--;
                final b = bytes.get(i);
                if (b == '\t'.code || b == '\n'.code || b == '\r'.code)
                    continue;
                return b;
            }
            return -1;
        }
        inline function eqIgnoreCase(b:Int, lower:Int):Bool {
            return b == lower || b == lower - 32;
        }

        var b = nextBack();
        if (b != '4'.code)
            return -1;
        b = nextBack();
        if (b != '6'.code)
            return -1;
        b = nextBack();
        if (!eqIgnoreCase(b, 'e'.code))
            return -1;
        b = nextBack();
        if (!eqIgnoreCase(b, 's'.code))
            return -1;
        b = nextBack();
        if (!eqIgnoreCase(b, 'a'.code))
            return -1;
        b = nextBack();
        if (!eqIgnoreCase(b, 'b'.code))
            return -1;
        b = nextBack();
        while (b == ' '.code)
            b = nextBack();
        if (b != ';'.code)
            return -1;
        return i;
    }

    static inline function hexUpper(n:Int):Int {
        return n < 10 ? '0'.code + n : 'A'.code + (n - 10);
    }

    public static function percentEncode(byte:Int, buf:StringBuf):Void {
        buf.addChar('%'.code);
        buf.addChar(hexUpper(byte >> 4));
        buf.addChar(hexUpper(byte & 0x0F));
    }

}

/** `DataUrl::decode`'s result: `InvalidBase64` collapses the Rust `DecodeError::InvalidBase64` case. */
enum DataUrlDecodeOutcome {
    Decoded(fragment:Null<FragmentIdentifier>);
    InvalidBase64;
}

/** `DataUrl::decode_to_vec`'s result. */
class DataUrlBody {

    public final body:Bytes;
    public final fragment:Null<FragmentIdentifier>;

    public function new(body:Bytes, fragment:Null<FragmentIdentifier>) {
        this.body = body;
        this.fragment = fragment;
    }

}

/** `decode_without_base64`'s private result (an `Option<FragmentIdentifier>` plus a write-failure case). */
private enum DecodeWithoutBase64Result {
    NoFragment;
    Fragment(raw:Bytes);
    WriteFailed;
}

/** The URL's fragment identifier (after `#`), unprocessed (not percent-decoded). */
class FragmentIdentifier {

    final raw:Bytes;

    public function new(raw:Bytes) {
        this.raw = raw;
    }

    /** Like in a parsed URL. */
    public function toPercentEncoded():String {
        final buf = new StringBuf();
        for (i in 0...raw.length) {
            final byte = raw.get(i);
            if (byte == '\t'.code || byte == '\n'.code || byte == '\r'.code) {
                continue;
            } else if (byte <= 0x20 || byte == '"'.code || byte == '<'.code || byte == '>'.code || byte == '`'.code || byte >= 0x7F) {
                // https://url.spec.whatwg.org/#fragment-percent-encode-set
                DataUrl.percentEncode(byte, buf);
            } else {
                buf.addChar(byte);
            }
        }
        return buf.toString();
    }

}

/** <https://mimesniff.spec.whatwg.org/#mime-type-representation> */
class Mime {

    public final type:String;
    public final subtype:String;

    /** (name, value) */
    public final parameters:Array<MimeParameter>;

    /** Constructs a `Mime` with the given `type` and `subtype` and an empty parameter list. */
    public function new(type:String, subtype:String, ?parameters:Array<MimeParameter>) {
        this.type = type;
        this.subtype = subtype;
        this.parameters = parameters != null ? parameters : [];
    }

    /** Whether this `Mime` matches a given type and subtype, regardless of what parameters it has. */
    public inline function matches(type:String, subtype:String):Bool {
        return this.type == type && this.subtype == subtype;
    }

    public function getParameter(name:String):Null<String> {
        for (p in parameters)
            if (p.name == name)
                return p.value;
        return null;
    }

    public function clone():Mime {
        return new Mime(type, subtype, [for (p in parameters) {name: p.name, value: p.value}]);
    }

    public function equals(other:Null<Mime>):Bool {
        if (other == null)
            return false;
        if (type != other.type || subtype != other.subtype || parameters.length != other.parameters.length)
            return false;
        for (i in 0...parameters.length) {
            if (parameters[i].name != other.parameters[i].name || parameters[i].value != other.parameters[i].value)
                return false;
        }
        return true;
    }

    /** <https://mimesniff.spec.whatwg.org/#serializing-a-mime-type> */
    public function toString():String {
        final buf = new StringBuf();
        buf.add(type);
        buf.add('/');
        buf.add(subtype);
        for (p in parameters) {
            buf.add(';');
            buf.add(p.name);
            buf.add('=');
            if (onlyHttpTokenCodePoints(p.value) && p.value != '') {
                buf.add(p.value);
            } else {
                buf.add('"');
                for (i in 0...p.value.length) {
                    final c = p.value.charAt(i);
                    if (c == '"' || c == '\\')
                        buf.add('\\');
                    buf.add(c);
                }
                buf.add('"');
            }
        }
        return buf.toString();
    }

    /**
     * <https://mimesniff.spec.whatwg.org/#parsing-a-mime-type> (Rust's
     * `FromStr` impl / private `parse` function combined): `null` on
     * `MimeParsingError`.
     *
     * Operates on the Haxe string directly (not raw UTF-8 bytes): every
     * separator this parser looks for (`/`, `;`, `=`, `"`, `\\`) is ASCII, so
     * splitting on it lands on the same place whether done by UTF-8 byte
     * offset or by Haxe string index, and the only Unicode-sensitive checks
     * (`onlyHttpTokenCodePoints`, `validValue`) only ever accept code points
     * up to U+00FF, each a single UTF-16 unit.
     */
    public static function parse(s:String):Null<Mime> {
        final trimmed = trimHttpWhitespace(s);
        final typeSplit = split2(trimmed, '/');
        final type_ = typeSplit.first;
        if (!(onlyHttpTokenCodePoints(type_) && type_ != ''))
            return null;
        if (typeSplit.rest == null)
            return null;
        final subtypeSplit = split2(typeSplit.rest, ';');
        final subtype = trimEndHttpWhitespace(subtypeSplit.first);
        if (!(onlyHttpTokenCodePoints(subtype) && subtype != ''))
            return null;

        final parameters:Array<MimeParameter> = [];
        if (subtypeSplit.rest != null)
            parseParameters(subtypeSplit.rest, parameters);

        return new Mime(asciiLowerCase(type_), asciiLowerCase(subtype), parameters);
    }

    static function parseParameters(s:String, parameters:Array<MimeParameter>):Void {
        final pieces = s.split(';');
        var pos = 0;
        function nextPiece():Null<String> {
            if (pos < pieces.length) {
                final p = pieces[pos];
                pos++;
                return p;
            }
            return null;
        }

        var piece = nextPiece();
        while (piece != null) {
            final trimmedPiece = trimStartHttpWhitespace(piece);
            final split = split2(trimmedPiece, '=');
            final name = split.first;
            final rawValue = split.rest;
            final nameValid = name != '' && onlyHttpTokenCodePoints(name) && !containsName(parameters, name);

            if (rawValue != null) {
                var finalValue:Null<String> = null;
                if (StringTools.startsWith(rawValue, '"')) {
                    final unescaped = new StringBuf();
                    var source = rawValue.substr(1);
                    var idx = 0;
                    var closed = false;
                    while (true) {
                        while (idx < source.length) {
                            final c = source.charAt(idx);
                            idx++;
                            if (c == '"') {
                                closed = true;
                                break;
                            } else if (c == '\\') {
                                if (idx < source.length) {
                                    unescaped.add(source.charAt(idx));
                                    idx++;
                                } else {
                                    final next = nextPiece();
                                    if (next != null) {
                                        unescaped.add(';');
                                        source = next;
                                        idx = 0;
                                    } else {
                                        unescaped.add('\\');
                                    }
                                }
                            } else {
                                unescaped.add(c);
                            }
                        }
                        if (closed)
                            break;
                        final next = nextPiece();
                        if (next != null) {
                            unescaped.add(';');
                            source = next;
                            idx = 0;
                        } else {
                            break;
                        }
                    }
                    final unescapedValue = unescaped.toString();
                    if (nameValid && validValue(unescapedValue))
                        finalValue = unescapedValue;
                } else {
                    final trimmedValue = trimEndHttpWhitespace(rawValue);
                    if (trimmedValue != '' && nameValid && validValue(trimmedValue))
                        finalValue = trimmedValue;
                }
                if (finalValue != null)
                    parameters.push({name: asciiLowerCase(name), value: finalValue});
            }
            piece = nextPiece();
        }
    }

    static function containsName(parameters:Array<MimeParameter>, name:String):Bool {
        for (p in parameters)
            if (p.name == name)
                return true;
        return false;
    }

    /** <https://mimesniff.spec.whatwg.org/#http-quoted-string-token-code-point> */
    static function validValue(s:String):Bool {
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (!(c == 0x09 || (c >= 0x20 && c <= 0x7E) || (c >= 0x80 && c <= 0xFF)))
                return false;
        }
        return true;
    }

    static inline function isHttpWhitespace(c:Int):Bool {
        return c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code;
    }

    static function trimHttpWhitespace(s:String):String {
        var start = 0, end = s.length;
        while (start < end && isHttpWhitespace(StringTools.fastCodeAt(s, start)))
            start++;
        while (end > start && isHttpWhitespace(StringTools.fastCodeAt(s, end - 1)))
            end--;
        return s.substring(start, end);
    }

    static function trimEndHttpWhitespace(s:String):String {
        var end = s.length;
        while (end > 0 && isHttpWhitespace(StringTools.fastCodeAt(s, end - 1)))
            end--;
        return s.substring(0, end);
    }

    static function trimStartHttpWhitespace(s:String):String {
        var start = 0;
        final len = s.length;
        while (start < len && isHttpWhitespace(StringTools.fastCodeAt(s, start)))
            start++;
        return s.substring(start);
    }

    static function split2(s:String, separator:String):{first:String, rest:Null<String>} {
        final idx = s.indexOf(separator);
        if (idx == -1)
            return {first: s, rest: null};
        return {first: s.substring(0, idx), rest: s.substring(idx + 1)};
    }

    static function onlyHttpTokenCodePoints(s:String):Bool {
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (c > 255 || !IS_HTTP_TOKEN[c])
                return false;
        }
        return true;
    }

    static function asciiLowerCase(s:String):String {
        final buf = new StringBuf();
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            buf.addChar(c >= 'A'.code && c <= 'Z'.code ? c + 32 : c);
        }
        return buf.toString();
    }

    // Copied from https://github.com/hyperium/mime/blob/v0.3.5/src/parse.rs#L293
    static final IS_HTTP_TOKEN:Array<Bool> = [
        for (i in 0...256)
            (i >= 0x30 && i <= 0x39) // 0-9
            || (i >= 0x41 && i <= 0x5A) // A-Z
            || (i >= 0x61 && i <= 0x7A) // a-z
            || i == '!'.code || i == '#'.code || i == '$'.code || i == '%'.code || i == '&'.code || i == '\''.code || i == '*'.code
            || i == '+'.code || i == '-'.code || i == '.'.code || i == '^'.code || i == '_'.code || i == '`'.code || i == '|'.code
            || i == '~'.code
    ];

}

typedef MimeParameter = {name:String, value:String};

/** <https://infra.spec.whatwg.org/#forgiving-base64-decode> */
class ForgivingBase64 {

    /** `input` is assumed to be in an ASCII-compatible encoding. `null` on `InvalidBase64`. */
    public static function decodeToVec(input:Bytes):Null<Bytes> {
        final buffer = new BytesBuffer();
        final decoder = new ForgivingBase64Decoder(bytes -> buffer.addBytes(bytes, 0, bytes.length));
        if (!decoder.feed(input))
            return null;
        if (!decoder.finish())
            return null;
        return buffer.getBytes();
    }

}

/**
 * <https://infra.spec.whatwg.org/#forgiving-base64-decode>
 *
 * Rust's `Decoder<F, E>` threads a generic write-error `E` through `feed` /
 * `finish`'s `Result`; this port's `writeBytes` callback cannot fail, so
 * `feed` / `finish` only ever report `InvalidBase64` (as `false`).
 */
class ForgivingBase64Decoder {

    final writeBytes:Bytes->Void;
    var bitBuffer:Int = 0;
    var bufferBitLength:Int = 0;
    var paddingSymbols:Int = 0;

    public function new(writeBytes:Bytes->Void) {
        this.writeBytes = writeBytes;
    }

    /** Feed partial input, in an ASCII-compatible encoding. Returns `false` on `InvalidBase64`. */
    public function feed(input:Bytes):Bool {
        final len = input.length;
        for (i in 0...len) {
            final byte = input.get(i);
            final value = BASE64_DECODE_TABLE[byte];
            if (value < 0) {
                // A character that's not part of the alphabet: remove ASCII whitespace.
                if (byte == ' '.code || byte == '\t'.code || byte == '\n'.code || byte == '\r'.code || byte == 0x0C)
                    continue;
                if (byte == '='.code) {
                    paddingSymbols++;
                    continue;
                }
                return false; // UnexpectedSymbol
            }
            if (paddingSymbols > 0)
                return false; // AlphabetSymbolAfterPadding
            bitBuffer = (bitBuffer << 6) | value;
            // 18 before incrementing means we've just reached 24.
            if (bufferBitLength < 18) {
                bufferBitLength += 6;
            } else {
                // Four times 6 bits accumulated, which equals three times 8 bits.
                final byteBuffer = Bytes.alloc(3);
                byteBuffer.set(0, (bitBuffer >> 16) & 0xFF);
                byteBuffer.set(1, (bitBuffer >> 8) & 0xFF);
                byteBuffer.set(2, bitBuffer & 0xFF);
                writeBytes(byteBuffer);
                bufferBitLength = 0;
                // No need to reset bitBuffer: next time only the relevant low bits are read.
            }
        }
        return true;
    }

    /** Call this to signal the end of the input. Returns `false` on `InvalidBase64`. */
    public function finish():Bool {
        if (bufferBitLength == 0 && paddingSymbols == 0) {
            // A multiple of four of alphabet symbols, and nothing else.
            return true;
        } else if (bufferBitLength == 12 && (paddingSymbols == 2 || paddingSymbols == 0)) {
            final byteBuffer = Bytes.alloc(1);
            byteBuffer.set(0, (bitBuffer >> 4) & 0xFF);
            writeBytes(byteBuffer);
            return true;
        } else if (bufferBitLength == 18 && (paddingSymbols == 1 || paddingSymbols == 0)) {
            final byteBuffer = Bytes.alloc(2);
            byteBuffer.set(0, (bitBuffer >> 10) & 0xFF);
            byteBuffer.set(1, (bitBuffer >> 2) & 0xFF);
            writeBytes(byteBuffer);
            return true;
        } else if (bufferBitLength == 6) {
            return false; // LoneAlphabetSymbol
        } else {
            return false; // Padding
        }
    }

    /**
     * Generated by `make_base64_decode_table.py` based on "Table 1: The Base
     * 64 Alphabet" at <https://tools.ietf.org/html/rfc4648#section-4>.
     *
     * Array indices are the byte value of symbols. Array values are their
     * position in the base64 alphabet, or -1 for symbols not in the
     * alphabet. The position contributes 6 bits to the decoded bytes.
     */
    static final BASE64_DECODE_TABLE:Array<Int> = [
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
        52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
        -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    ];

}
