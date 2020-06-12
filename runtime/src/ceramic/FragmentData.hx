package ceramic;

import haxe.DynamicAccess;

typedef FragmentData = {

    /** Identifier of the fragment. */
    public var id:String;

    /** Arbitrary data hold by this fragment. */
    public var data:Dynamic<Dynamic>;

    /** Fragment width */
    public var width:Float;

    /** Fragment height */
    public var height:Float;

    /** Fragment-level components */
    public var components:DynamicAccess<String>;

    /** Fragment color (if not transparent, default `BLACK`) */
    @:optional public var color:Color;

    /** Fragment being transparent or not (default `true`) */
    @:optional public var transparent:Bool;

    /** Fragment items (visuals or other entities) */
    @:optional public var items:Array<FragmentItem>;

}
