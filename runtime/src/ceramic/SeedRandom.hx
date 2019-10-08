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

/** Seeded random number generator to get reproducible sequences of values. */
class SeedRandom {

    public var seed(default,null):Float;

    public var initialSeed(default,null):Float;

    inline public function new(seed:Float) {

        Assert.assert(seed >= 0, 'Seed must be a positive value');

        this.seed = seed;
        initialSeed = this.seed;

    } //new

// Public API

    /** Returns a float number between [0,1) */
    public inline function random():Float {
        return (seed = (seed * 16807) % 0x7FFFFFFF) / 0x7FFFFFFF + 0.000000000233;
    }

    /** Return an integer between [min, max). */
    public inline function between(min:Int, max:Int):Int {
        return Math.floor(min + (max - min) * random());
    }

    /** Reset the initial value to that of the current seed. */
    public inline function reset(?initialSeed:Float) {
        if (initialSeed != null) {
            this.initialSeed = initialSeed;
        }
        seed = this.initialSeed;
    }

} //SeedRandom
