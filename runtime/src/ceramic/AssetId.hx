package ceramic;

@:forward
abstract AssetId<T>(T) from T to T {

    inline public function new(value:T) {
        this = value;
    }

}
