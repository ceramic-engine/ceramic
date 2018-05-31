package ceramic;

@:forward
abstract Collection<T:CollectionEntry>(CollectionImpl<T>) {

    inline public function new() {

        this = new CollectionImpl();

    } //new

	@:arrayAccess public inline function arrayAccess(index:Int) {
        
        return this.entries[index];
    
    } //arrayAccess

    /** Return a random element contained in the collection */
    inline public function randomElement():T {

        return Extensions.randomElement(this.entries);

    } //randomElement

    /** Return a random element contained in the given array that is not equal to the `except` arg.
        @param except The element we don't want
        @param unsafe If set to `true`, will prevent allocating a new array (and may be faster) but will loop forever if there is no element except the one we don't want
        @return The random element or `null` if nothing was found */
    inline public function randomElementExcept(except:T, unsafe:Bool = false):T {

        return Extensions.randomElementExcept(this.entries, except, unsafe);

    } //randomElementExcept

} //Collection

@:allow(ceramic.Collection)
class CollectionImpl<T:CollectionEntry> {

    var entries:Array<T> = [];

    var indexDirty:Bool = true;

    var byId:Map<String,T> = null;
    
	public var length(get,never):Int;
    inline function get_length():Int return entries.length;

    public function new() {}

	public function pushAll(entries:Array<T>) {

        for (entry in entries) {
            this.entries.push(entry);
        }

        indexDirty = true;

    } //pushAll

	public function push(entry:T) {

        this.entries.push(entry);
        indexDirty = true;

    } //push

    public function get(id:String):T {

        if (indexDirty) computeIndex();

        return byId.get(id);

    } //get

	inline public function iterator():Iterator<T> {

		return entries.iterator();

	} //iterator

/// Internal

    function computeIndex() {

        byId = new Map();
        
        for (entry in entries) {
            byId.set(entry.id, entry);
        }

        indexDirty = false;

    } //computeIndex

} //CollectionImpl
