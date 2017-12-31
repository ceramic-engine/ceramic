package ceramic;

typedef FragmentItem = {

    /** Entity class (ex: ceramic.Visual, ceramic.Quad, ...). */
    public var entity:String;

    /** Entity identifier. */
    public var id:String;

    /** Entity name. */
    public var name:String;

    /** Properties assigned after creating entity. */
    public var props:Dynamic<Dynamic>;

    /** Arbitrary data hold by this item. */
    public var data:Dynamic<Dynamic>;

} //FragmentItem
