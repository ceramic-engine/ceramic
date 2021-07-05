package ceramic;

import haxe.crypto.Md5;
import ceramic.Utils;
import ceramic.Shortcuts.*;

import haxe.Json;

using StringTools;

/**
 * An utility to encode strings with hashes, allowing to check their validity on decode.
 */
class HashedString {

    static var _lastDecodeIncomplete:Bool = false;

    /**
     * Encode the given string `str` and return the result.
     */
    public static function encode(str:String):String {

        var hash = Md5.encode(str);
        var len = str.length;

        return hash + '' + len + ';' + str;

    }

    /**
     * Encode and append `str` to the already encoded string `encoded` and return the results.
     * This is equivalent to `result = encoded + HashedString.encode(str)`
     */
    public static function append(encoded:String, str:String):String {

        return encoded + encode(str);

    }

    /**
     * Decode the given `encoded` string and return the result.
     */
    public static function decode(encoded:String):String {

        _lastDecodeIncomplete = false;

        var i = 0;
        var len = encoded.length;
        var result:StringBuf = null;

        while (i < len) {
            // Retrieve hash
            var hash = encoded.substring(i, i + 32);

            // Retrieve section length
            i += 32;
            var n = i;
            while (n < len && encoded.charCodeAt(n) != ';'.code) {
                n++;
            }
            var sectionLen = Std.parseInt(encoded.substring(i, n));
            if (sectionLen == null || sectionLen <= 0) {
                log.warning('Failed to parse all encoded string: invalid section length');
                _lastDecodeIncomplete = true;
                break;
            }
            i = n + 1;

            // Retrieve section string
            var section = encoded.substring(i, i + sectionLen);
            if (section == null) {
                log.warning('Failed to parse all encoded string: null section');
                _lastDecodeIncomplete = true;
                break;
            }
            if (Md5.encode(section) != hash) {
                log.warning('Failed to parse all encoded string: section hash mismatch');
                _lastDecodeIncomplete = true;
                break;
            }
            i += sectionLen;

            // Append section
            if (result == null) {
                result = new StringBuf();
            }
            result.add(section);

        }

        if (result != null) {
            return result.toString();
        }
        else {
            log.error('Invalid encoded string');
            _lastDecodeIncomplete = true;
            return null;
        }

    }

    inline public function isLastDecodeIncomplete():Bool {

        return _lastDecodeIncomplete;

    }

}
