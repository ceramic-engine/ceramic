package ceramic;

// Based on code from Luxe Engine https://github.com/underscorediscovery/luxe/blob/66bed0cf1a38e58355c65497f8b97de5732467c5/luxe/utils/Random.hx
// itself based on code from http://blog.gskinner.com/archives/2008/01/source_code_see.html
// with license:

// Rndm by Grant Skinner. Jan 15, 2008
// Visit www.gskinner.com/blog for documentation, updates and more free code.

// Incorporates implementation of the Park Miller (1988) "minimal standard" linear
// congruential pseudo-random number generator by Michael Baczynski, www.polygonal.de.
// (seed * 16807) % 2147483647

// Copyright (c) 2008 Grant Skinner

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

/**
 * Seeded random number generator to get reproducible sequences of values.
 * 
 * SeedRandom provides a deterministic pseudo-random number generator that produces
 * the same sequence of random values for a given seed. This is essential for:
 * - Procedural generation that needs to be reproducible
 * - Multiplayer games requiring synchronized random events
 * - Testing scenarios that need predictable randomness
 * - Save/load systems that need to recreate random sequences
 * 
 * The implementation uses the Park Miller (1988) "minimal standard" linear
 * congruential generator algorithm: (seed * 16807) % 2147483647
 * 
 * Example usage:
 * ```haxe
 * // Create a seeded random generator
 * var rng = new SeedRandom(12345);
 * 
 * // Generate random values
 * var randomFloat = rng.random();           // [0, 1)
 * var randomInt = rng.between(1, 100);      // [1, 100)
 * 
 * // Shuffle an array deterministically
 * var items = [1, 2, 3, 4, 5];
 * rng.shuffle(items);
 * 
 * // Reset to initial seed to replay sequence
 * rng.reset();
 * var sameFloat = rng.random(); // Same as first randomFloat
 * ```
 * 
 * Note: This is not cryptographically secure and should not be used for
 * security-sensitive applications.
 * 
 * @see Math.random() For non-deterministic random numbers
 */
class SeedRandom {

    /**
     * The current seed value.
     * This value changes with each random number generation.
     */
    public var seed(default,null):Float;

    /**
     * The initial seed value used when creating this generator.
     * Used by reset() to restore the original sequence.
     */
    public var initialSeed(default,null):Float;

    /**
     * Creates a new seeded random number generator.
     * 
     * @param seed The seed value. Must be a positive number.
     *             Same seed values will produce identical random sequences.
     */
    inline public function new(seed:Float) {

        Assert.assert(seed >= 0, 'Seed must be a positive value');

        this.seed = seed;
        initialSeed = this.seed;

    }

// Public API

    /**
     * Shuffle an Array in place using the Fisher-Yates algorithm.
     * 
     * This operation modifies the original array. The shuffle is deterministic
     * based on the current seed state, so the same seed will always produce
     * the same shuffle order.
     * 
     * Example:
     * ```haxe
     * var deck = ["A", "K", "Q", "J", "10", "9", "8", "7"];
     * rng.shuffle(deck);
     * // deck is now shuffled in a reproducible way
     * ```
     * 
     * @param arr The array to shuffle. Modified in place.
     */
    public function shuffle<T>(arr:Array<T>):Void
    {
        inline function int(from:Int, to:Int):Int
        {
            return from + Math.floor(((to - from + 1) * random()));
        }

        if (arr != null) {
            for (i in 0...arr.length) {
                var j = int(0, arr.length - 1);
                var a = arr[i];
                var b = arr[j];
                arr[i] = b;
                arr[j] = a;
            }
        }

    }

    /**
     * Returns a pseudo-random float in the range [0, 1).
     * 
     * The value is uniformly distributed and will be >= 0 and < 1.
     * Each call advances the internal seed state.
     * 
     * @return A pseudo-random float between 0 (inclusive) and 1 (exclusive)
     */
    public inline function random():Float {
        return (seed = (seed * 16807) % 0x7FFFFFFF) / 0x7FFFFFFF + 0.000000000233;
    }

    /**
     * Returns a pseudo-random integer in the range [min, max).
     * 
     * The value will be >= min and < max. The distribution is uniform
     * across the range.
     * 
     * Example:
     * ```haxe
     * var diceRoll = rng.between(1, 7);    // 1-6
     * var percent = rng.between(0, 101);   // 0-100
     * ```
     * 
     * @param min The minimum value (inclusive)
     * @param max The maximum value (exclusive)
     * @return A pseudo-random integer in the specified range
     */
    public inline function between(min:Int, max:Int):Int {
        return Math.floor(min + (max - min) * random());
    }

    /**
     * Resets the generator to its initial seed value.
     * 
     * This allows replaying the same sequence of random values.
     * Optionally, a new initial seed can be provided.
     * 
     * Example:
     * ```haxe
     * var rng = new SeedRandom(100);
     * var a = rng.random();
     * var b = rng.random();
     * 
     * rng.reset();           // Back to seed 100
     * var a2 = rng.random(); // Same as 'a'
     * var b2 = rng.random(); // Same as 'b'
     * 
     * rng.reset(200);        // Change to new seed
     * ```
     * 
     * @param initialSeed Optional new seed to use. If not provided,
     *                   resets to the original seed from construction.
     */
    public inline function reset(?initialSeed:Float) {
        if (initialSeed != null) {
            this.initialSeed = initialSeed;
        }
        seed = this.initialSeed;
    }

}
