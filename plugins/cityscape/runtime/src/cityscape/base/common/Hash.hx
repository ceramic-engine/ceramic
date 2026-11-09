// Ported from vscode src/vs/base/common/hash.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of hash.ts, for strings and numbers only so far (the
 * object, array and SHA-1 hashes are not ported). The values are Monaco's:
 * 32 bit integers, wrapping like JavaScript's `| 0`.
 */
class Hash {

    /**
     * Return a hash value for a string (Monaco's `hash(obj)` for a string).
     */
    public static inline function hashString(s:String):Int {
        return stringHash(s, 0);
    }

    public static inline function numberHash(val:Int, initialHashVal:Int):Int {
        return toInt32(((initialHashVal << 5) - initialHashVal) + val); // hashVal * 31 + ch, keep as int32
    }

    public static function stringHash(s:String, hashVal:Int):Int {
        hashVal = numberHash(149417, hashVal);
        for (i in 0...s.length) {
            hashVal = numberHash(StringTools.fastCodeAt(s, i), hashVal);
        }
        return hashVal;
    }

    static inline function toInt32(value:Int):Int {
        #if js
        return js.Syntax.code('({0}) | 0', value);
        #else
        return value;
        #end
    }

}
