package cityscape.common.tokens;

import haxe.io.UInt32Array;

/**
 * `UInt32Array` values built from `Array<Int>` (token data, the arrays the
 * ported code and its tests write as plain integer literals).
 *
 * `UInt32Array.fromArray` takes an `Array<UInt>`: on hxcpp and JS `UInt` is
 * `Int`, so an `Array<Int>` is accepted, but on C# (Unity) `UInt` is its own
 * type and `Array<UInt>` is `uint[]`, so the same call does not compile.
 * Elements are converted one by one there (an `Int` converts to `UInt`,
 * negative values wrap as a `Uint32Array` would).
 */
class UInt32Arrays {

    public static function fromInts(a:Array<Int>):UInt32Array {
        return UInt32Array.fromArray(a);
    }

}
