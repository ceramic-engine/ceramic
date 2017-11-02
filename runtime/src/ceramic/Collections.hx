package ceramic;

class CollectionEntry {

    public var id:String;

    public var name:String;

} //CollectionEntry

class Collection<T> {

    public function new() {}

} //Collection

#if !macro
@:build(ceramic.macros.CollectionsMacro.build())
#end
class Collections {

    public function new() {}

} //Collections
