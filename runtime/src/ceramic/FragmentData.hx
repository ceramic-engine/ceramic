package ceramic;

import haxe.DynamicAccess;

typedef FragmentData = {

    /** Identifier of the fragment. */
    public var id:String;

    /** Name of the fragment. */
    public var name:String;

    /** Arbitrary data hold by this fragment. */
    public var data:Dynamic<Dynamic>;

    /** Fragment width */
    public var width:Float;

    /** Fragment height */
    public var height:Float;

    /** Fragment-level components */
    public var components:DynamicAccess<String>;

    /** Fragment items (visuals or other entities) */
    @:optional public var items:Array<FragmentItem>;

}
