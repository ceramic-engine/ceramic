package ceramic;

/**
 * An object that can hold any value
 */
class Value<T> {

    public var value:T;

    public function new(?value:T) {

        if (value != null)
            this.value = value;

    }

}
