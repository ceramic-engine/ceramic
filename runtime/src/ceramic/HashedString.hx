package ceramic;

import haxe.crypto.Md5;
import ceramic.Utils;
import ceramic.Shortcuts.*;

import haxe.Json;

using StringTools;

/**
 * A utility class for encoding and decoding strings with integrity verification using MD5 hashes.
 * 
 * HashedString provides a way to encode strings with embedded hash values that allow
 * verification of data integrity when decoding. This is useful for scenarios where
 * you need to ensure that string data hasn't been corrupted or tampered with.
 * 
 * The encoding format is: `[32-char MD5 hash][length];[original string]`
 * 
 * Key features:
 * - Integrity verification: Each encoded section includes an MD5 hash for validation
 * - Concatenation support: Multiple encoded strings can be safely concatenated
 * - Partial decode detection: Can detect if decoding was incomplete due to corruption
 * - Section-based encoding: Each string is encoded as an independent section
 * 
 * Common use cases:
 * - Storing critical string data with integrity checks
 * - Transmitting text data where corruption detection is important
 * - Creating tamper-evident string storage
 * - Verifying saved game data or configuration strings
 * 
 * Example usage:
 * ```haxe
 * // Encode a string
 * var encoded = HashedString.encode("Hello, World!");
 * trace(encoded); // Outputs: [hash][13];Hello, World!
 * 
 * // Decode and verify
 * var decoded = HashedString.decode(encoded);
 * if (decoded != null) {
 *     trace(decoded); // Outputs: Hello, World!
 * }
 * 
 * // Append multiple encoded strings
 * var combined = HashedString.encode("First");
 * combined = HashedString.append(combined, "Second");
 * 
 * // Decode concatenated strings
 * var result = HashedString.decode(combined); // Returns: "FirstSecond"
 * ```
 * 
 * @see ceramic.PersistentData For storing encoded data persistently
 * @see ceramic.Utils For other utility functions
 */
class HashedString {

    /**
     * Internal flag tracking whether the last decode operation was incomplete.
     * Set to true when decoding fails due to corruption or invalid format.
     */
    static var _lastDecodeIncomplete:Bool = false;

    /**
     * Encodes a string with an MD5 hash for integrity verification.
     * 
     * The encoded format consists of:
     * 1. A 32-character MD5 hash of the string
     * 2. The length of the original string
     * 3. A semicolon separator
     * 4. The original string
     * 
     * This format allows the decoder to verify that the string hasn't been
     * corrupted or tampered with.
     * 
     * @param str The string to encode
     * @return The encoded string in format: `[hash][length];[string]`
     */
    public static function encode(str:String):String {

        var hash = Md5.encode(str);
        var len = str.length;

        return hash + '' + len + ';' + str;

    }

    /**
     * Encodes a string and appends it to an existing encoded string.
     * 
     * This is a convenience method that allows building up multiple encoded
     * sections in a single string. Each section remains independently verifiable.
     * 
     * Example:
     * ```haxe
     * var result = HashedString.encode("First");
     * result = HashedString.append(result, "Second");
     * result = HashedString.append(result, "Third");
     * // result now contains three independently encoded sections
     * ```
     * 
     * @param encoded The existing encoded string to append to
     * @param str The new string to encode and append
     * @return The combined encoded string
     */
    public static function append(encoded:String, str:String):String {

        return encoded + encode(str);

    }

    /**
     * Decodes an encoded string, verifying integrity using embedded hashes.
     * 
     * This method processes one or more encoded sections, verifying each section's
     * hash before including it in the result. If any section fails verification,
     * decoding stops at that point and the incomplete flag is set.
     * 
     * The decoder can handle:
     * - Single encoded strings
     * - Multiple concatenated encoded strings
     * - Partial/corrupted data (stops at first invalid section)
     * 
     * @param encoded The encoded string to decode
     * @return The decoded string if successful, or null if the encoded string is invalid.
     *         Use `isLastDecodeIncomplete()` to check if decoding was partially successful.
     */
    public static function decode(encoded:String):String {

        _lastDecodeIncomplete = false;

        var i = 0;
        var len = encoded.length;
        var result:StringBuf = null;

        while (i < len) {
            // Retrieve hash (MD5 hashes are always 32 characters)
            var hash = encoded.substring(i, i + 32);

            // Retrieve section length
            i += 32;
            var n = i;
            // Find the semicolon separator
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
            // Verify integrity by comparing hashes
            if (Md5.encode(section) != hash) {
                log.warning('Failed to parse all encoded string: section hash mismatch');
                _lastDecodeIncomplete = true;
                break;
            }
            i += sectionLen;

            // Append verified section to result
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

    /**
     * Checks if the last decode operation was incomplete.
     * 
     * This method returns true if the last call to `decode()` encountered
     * corrupted data or an invalid format and couldn't process the entire
     * encoded string. This can help distinguish between:
     * - Complete failure (invalid format from the start)
     * - Partial success (some sections decoded before encountering corruption)
     * 
     * @return `true` if the last decode was incomplete, `false` if it was successful
     */
    inline public static function isLastDecodeIncomplete():Bool {

        return _lastDecodeIncomplete;

    }

}
