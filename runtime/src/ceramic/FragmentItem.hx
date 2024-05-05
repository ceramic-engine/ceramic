package ceramic;

typedef FragmentItem = {

    /**
     * Entity class (ex: ceramic.Visual, ceramic.Quad, ...).
     */
    var entity:String;

    /**
     * Entity identifier.
     */
    var id:String;

    /**
     * Entity components.
     */
    var components:Dynamic<String>;

    /**
     * Entity name.
     */
    @:optional var name:String;

    /**
     * Properties assigned after creating entity.
     */
    var props:Dynamic<Dynamic>;

    /**
     * Arbitrary data hold by this item.
     */
    @:optional var data:Dynamic<Dynamic>;

    /**
     * Schema of this fragment item providing
     * a mapping of field names and their respective type.
     */
    @:optional var schema:Dynamic<String>;

}
