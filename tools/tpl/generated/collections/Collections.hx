package collections;

@:keep
@:keepSub
class Collections implements ceramic.AutoCollections {

    public static var collections(default, null):Collections;

    public function new() {

        collections = this;

    }

}
