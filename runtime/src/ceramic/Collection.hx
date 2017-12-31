package ceramic;

@:forward
abstract Collection<T:CollectionEntry>(Array<T>) from Array<T> to Array<T> {

    public function new() {
        this = [];
    }

} //Collection
