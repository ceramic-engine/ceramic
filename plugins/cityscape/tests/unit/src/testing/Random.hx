// Ported from vscode src/vs/editor/test/common/core/random.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

/**
 * Seeded random numbers of the tests.
 *
 * TODO(step 1): `nextMultiLineString`, `nextConsecutivePositions`,
 * `nextRange` and `nextTextEdit` come with `OffsetRange.ofLength`,
 * `PositionOffsetTransformer` and textEdit.ts (`AbstractText`,
 * `SingleTextEdit`, `TextEdit`).
 */
class Random {

    public static final basicAlphabet:String = '      abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    public static final basicAlphabetMultiline:String = '      \n\n\nabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    public static function create(seed:Int):Random {
        return new MersenneTwister(seed);
    }

    function new() {}

    public function nextIntRange(start:Int, endExclusive:Int):Int {
        throw 'abstract';
    }

    public function nextString(length:Int, ?alphabet:String):String {
        if (alphabet == null) {
            alphabet = Random.basicAlphabet;
        }
        var randomText:String = '';
        for (i in 0...length) {
            final characterIndex = nextIntRange(0, alphabet.length);
            randomText += alphabet.charAt(characterIndex);
        }
        return randomText;
    }

}

/**
 * The 32 bit words are kept as `Int` bit patterns: `^`, `&`, `<<` and `>>>`
 * give the same bits as JavaScript's on every target.
 */
private class MersenneTwister extends Random {

    final mt:Array<Int> = [for (_ in 0...624) 0];
    var index = 0;

    public function new(seed:Int) {
        super();

        mt[0] = seed >>> 0;
        for (i in 1...624) {
            final s = mt[i - 1] ^ (mt[i - 1] >>> 30);
            mt[i] = (((((s & 0xffff0000) >>> 16) * 0x6c078965) << 16) + (s & 0x0000ffff) * 0x6c078965 + i) >>> 0;
        }
    }

    function _nextInt():Float {
        if (index == 0) {
            generateNumbers();
        }

        var y = mt[index];
        y = y ^ (y >>> 11);
        y = y ^ ((y << 7) & 0x9d2c5680);
        y = y ^ ((y << 15) & 0xefc60000);
        y = y ^ (y >>> 18);

        index = (index + 1) % 624;

        // y >>> 0 (an unsigned 32 bit number)
        return y < 0 ? y + 4294967296.0 : y;
    }

    override public function nextIntRange(start:Int, endExclusive:Int):Int {
        final range = endExclusive - start;
        return Std.int(Math.ffloor(_nextInt() / (4294967296.0 / range))) + start;
    }

    function generateNumbers():Void {
        for (i in 0...624) {
            final y = (mt[i] & 0x80000000) + (mt[(i + 1) % 624] & 0x7fffffff);
            mt[i] = mt[(i + 397) % 624] ^ (y >>> 1);
            if ((y % 2) != 0) {
                mt[i] = mt[i] ^ 0x9908b0df;
            }
        }
    }

}
