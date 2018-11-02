package ceramic;

import haxe.ds.Vector;

/** A reusable array to use in places that need a temporary array many times.
    Changing array size only increases the backing array size but never decreases it. */
class ReusableArray<T> {

    @:noCompletion
    var _poolIndex:Int = -1;

    var vector:Vector<T>;

    public var length(default,set):Int;

    inline public function new(length:Int) {

        this.length = length;

    } //new

    function set_length(length:Int):Int {
        if (vector == null) {
            vector = new Vector(length);
            this.length == length;
            return length;
        }
        if (length == this.length) return length;

        if (length > vector.length) {
            var newVector = new Vector<T>(length);
            for (i in 0...this.length) {
                newVector.set(i, vector.get(i));
                vector.set(i, null);
            }
            vector = newVector;
            for (i in this.length...length) {
                vector.set(i, null);
            }
        }
        else {
            for (i in length...this.length) {
                vector.set(i, null);
            }
        }

        this.length = length;

        return length;
    }

    inline public function get(index:Int):T {

        return vector.get(index);

    } //get

    inline public function set(index:Int, value:T):Void {

        vector.set(index, value);

    } //set

} //ReusableArray
