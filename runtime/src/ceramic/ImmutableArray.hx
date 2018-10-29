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
 * ImmutableArray
 * @see https://github.com/AxGord/Pony/blob/d4334fa606289505d047735543936334ad8060ab/pony/ImmutableArray.hx
 */
@:forward(length, concat, join, toString, indexOf, lastIndexOf, copy, iterator, map, filter)
abstract ImmutableArray<T>(Array<T>) from Array<T> to Iterable<T> {

    @:arrayAccess @:extern inline public function arrayAccess(key:Int):T return this[key];

    /** Returns the underlying (and mutable) data. Use at your own risk! */
    public var mutable(get,never):Array<T>;
    inline private function get_mutable():Array<T> return this;

/// Array extensions

    inline public function unsafeGet(index:Int):T {

        return Extensions.unsafeGet(this, index);

    } //unsafeGet

} //ImmutableArray
