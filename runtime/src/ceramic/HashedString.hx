package ceramic;

import haxe.crypto.Md5;
import ceramic.Utils;
import ceramic.Shortcuts.*;

import haxe.Json;

using StringTools;

/** An utility to encode strings with hashes, allowing to check their validity on decode. */
class HashedString {

    /** Encode the given string `str` and return the result. */
    public static function encode(str:String):String {

        var hash = Md5.encode(str);
        var len = str.length;

        return hash + '' + len + ';' + str;

    } //encode

    /** Encode and append `str` to the already encoded string `encoded` and return the results. */
    public static function append(encoded:String, str:String):String {

        return encoded + encode(str);

    } //append

    /** Decode the given `encoded` string and return the result. */
    public static function decode(encoded:String):String {

        try {
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
                    warning('Failed to parse all encoded string: invalid section length');
                    break;
                }
                i = n + 1;

                // Retrieve section string
                var section = encoded.substring(i, i + sectionLen);
                if (section == null) {
                    warning('Failed to parse all encoded string: null section');
                    break;
                }
                if (Md5.encode(section) != hash) {
                    warning('Failed to parse all encoded string: section hash mismatch');
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
                error('Invalid encoded string');
                return null;
            }
        }
        catch (e:Dynamic) {
            error('Failed to parse encoded string: $e');
        }

        return null;

    } //decode

} //HashedString
