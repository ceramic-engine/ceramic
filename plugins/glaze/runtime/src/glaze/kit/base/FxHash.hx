// Ported from gpui-pre 0.3.10: src/asset_cache.rs (`hash`), which hashes with rustc-hash 2.1.3's FxHasher
// (https://github.com/rust-lang/rustc-hash, Copyright The Rust Project Developers, MIT / Apache-2.0)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import haxe.Int64;
import haxe.io.Bytes;

/**
 * GPUI's `hash()` of a string (`FxBuildHasher.hash_one(&SharedString)`) on
 * a 64-bit target: rustc-hash 2's FxHasher, fed the string bytes then the
 * `0xff` terminator `str::hash` writes. gpui-kit uses it to pick stable
 * colors (avatar initials).
 */
class FxHash {

    static final K:Int64 = Int64.make(0xf1357aea, 0x2e62a9c5);
    static final SEED1:Int64 = Int64.make(0x243f6a88, 0x85a308d3);
    static final SEED2:Int64 = Int64.make(0x13198a2e, 0x03707344);
    static final PREVENT_TRIVIAL_ZERO_COLLAPSE:Int64 = Int64.make(0xa4093822, 0x299f31d0);

    /** `gpui::hash(&SharedString::from(text))`. */
    public static function hashString(text:String):Int64 {
        var hash:Int64 = 0;
        hash = addToHash(hash, hashBytes(Bytes.ofString(text)));
        hash = addToHash(hash, 0xff);
        return rotateLeft(hash, 26);
    }

    /** Unsigned remainder of a 64-bit hash by a small divisor. */
    public static function modulo(hash:Int64, divisor:Int):Int {
        // (high * 2^32 + low) mod d, with unsigned 32-bit halves
        final high = unsigned(hash.high) % divisor;
        final low = unsigned(hash.low) % divisor;
        final base = 4294967296.0 % divisor;
        return Std.int((high * base + low) % divisor);
    }

    static inline function unsigned(value:Int):Float {
        return value < 0 ? value + 4294967296.0 : value;
    }

    static inline function addToHash(hash:Int64, i:Int64):Int64 {
        return (hash + i) * K;
    }

    static inline function rotateLeft(x:Int64, n:Int):Int64 {
        return (x << n) | (x >>> (64 - n));
    }

    static function readLe(bytes:Bytes, pos:Int, count:Int):Int64 {
        var low = 0;
        var high = 0;
        for (i in 0...count) {
            final b = bytes.get(pos + i);
            if (i < 4) low |= b << (8 * i);
            else high |= b << (8 * (i - 4));
        }
        return Int64.make(high, low);
    }

    /** Low and high 64 bits of the 128-bit product, xored. */
    static function multiplyMix(x:Int64, y:Int64):Int64 {
        // Split into 32-bit limbs and multiply as 16-bit pieces to stay exact
        final xs = limbs16(x);
        final ys = limbs16(y);
        final prod = [for (_ in 0...8) 0.0];
        final out = [for (_ in 0...8) 0];
        // schoolbook multiplication on 16-bit limbs with carries
        var carry = 0.0;
        for (k in 0...8) {
            var sum = carry;
            for (i in 0...4) {
                final j = k - i;
                if (j >= 0 && j < 4) sum += xs[i] * ys[j];
            }
            out[k] = Std.int(sum % 65536);
            carry = Math.ffloor(sum / 65536);
        }
        final lo = Int64.make((out[3] << 16) | out[2], (out[1] << 16) | out[0]);
        final hi = Int64.make((out[7] << 16) | out[6], (out[5] << 16) | out[4]);
        return lo ^ hi;
    }

    static function limbs16(x:Int64):Array<Float> {
        final low = x.low;
        final high = x.high;
        return [low & 0xffff, (low >>> 16) & 0xffff, high & 0xffff, (high >>> 16) & 0xffff];
    }

    static function hashBytes(bytes:Bytes):Int64 {
        final len = bytes.length;
        var s0 = SEED1;
        var s1 = SEED2;
        if (len <= 16) {
            if (len >= 8) {
                s0 = s0 ^ readLe(bytes, 0, 8);
                s1 = s1 ^ readLe(bytes, len - 8, 8);
            }
            else if (len >= 4) {
                s0 = s0 ^ readLe(bytes, 0, 4);
                s1 = s1 ^ readLe(bytes, len - 4, 4);
            }
            else if (len > 0) {
                final lo = bytes.get(0);
                final mid = bytes.get(len >> 1);
                final hi = bytes.get(len - 1);
                s0 = s0 ^ Int64.ofInt(lo);
                s1 = s1 ^ Int64.ofInt((hi << 8) | mid);
            }
        }
        else {
            var pos = 0;
            while (len - 1 - pos >= 16) {
                final x = readLe(bytes, pos, 8);
                final y = readLe(bytes, pos + 8, 8);
                final t = multiplyMix(s0 ^ x, PREVENT_TRIVIAL_ZERO_COLLAPSE ^ y);
                s0 = s1;
                s1 = t;
                pos += 16;
            }
            s0 = s0 ^ readLe(bytes, len - 16, 8);
            s1 = s1 ^ readLe(bytes, len - 8, 8);
        }
        return multiplyMix(s0, s1) ^ Int64.ofInt(len);
    }

}
