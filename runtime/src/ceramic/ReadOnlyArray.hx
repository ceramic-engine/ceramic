package ceramic;

/**
* Copyright (c) 2012-2017 Alexander Gordeyko <axgord@gmail.com>. All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification, are
* permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this list of
*   conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this list
*   of conditions and the following disclaimer in the documentation and/or other materials
*   provided with the distribution.
*
* THIS SOFTWARE IS PROVIDED BY ALEXANDER GORDEYKO ``AS IS'' AND ANY EXPRESS OR IMPLIED
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
* FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL ALEXANDER GORDEYKO OR
* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
* CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
* ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 `ReadOnlyArray` is an abstract over an ordinary `Array` which only exposes
 APIs that don't modify the instance, hence "read-only".

 Note that this doesn't necessarily mean that the instance is *immutable*.
 Other code holding a reference to the underlying `Array` can still modify it,
 and the reference can be obtained with a `cast`.
 */
@:forward(get, concat, copy, filter, indexOf, iterator, keyValueIterator, join, lastIndexOf, map, slice, contains, toString)
abstract ReadOnlyArray<T>(Array<T>) from Array<T> to Iterable<T> to Array<T> {

    @:noCompletion @:arrayAccess extern inline public function arrayAccess(key:Int):T return this[key];

    /**
     * Returns the underlying (and mutable) data. Use at your own risk!
     */
    public var original(get,never):Array<T>;
    inline private function get_original():Array<T> return this;

    /**
        The length of `this` Array.
    **/
    public var length(get, never):Int;
    inline function get_length()
        return this.length;

/// Array extensions

    inline public function unsafeGet(index:Int):T {

        return Extensions.unsafeGet(this, index);

    }

}
