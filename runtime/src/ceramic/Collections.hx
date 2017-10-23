package ceramic;

class CollectionEntry {

    public var id:String;

    public var name:String;

} //CollectionEntry

class Collection<T> {

} //Collection

#if !macro
//@:build(ceramic.macros.CollectionsMacro.buildLists())
#end
class Collections {

} //Collections
