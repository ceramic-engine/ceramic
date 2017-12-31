package ceramic;

@:forward
abstract AssetId<T:String>(T) from T to T {

    inline public function new(value:T) {
        this = value;
    }

} //AssetId
