package ceramic;

/** A collection entry that can hold any value */
class ValueEntry<T> extends CollectionEntry {

    public var value:T;

    public function new(value:T, ?id:String, ?name:String) {

        super(id, name);

        this.value = value;

    }

}
