package tools;

typedef IdeInfoTaskItem = {

    var name:String;

    var command:String;

    @:optional var args:Array<String>;

    /** The groups this task belongs to. */
    @:optional var groups:Array<String>;

    @:optional var select:IdeInfoTaskSelectItem;

} //IdeInfoTaskItem

typedef IdeInfoTaskSelectItem = {

    var command:String;

    @:optional var args:Array<String>;

} //IdeInfoTaskSelectItem

typedef IdeInfoVariantItem = {

    var name:String;

    @:optional var args:Array<String>;

    /** On which task group this variant can be used. */
    @:optional var group:String;

    /** We can only choose one variant for each role at a time. */
    @:optional var role:String;

    @:optional var select:IdeInfoVariantSelectItem;

} //IdeInfoVariantItem

typedef IdeInfoVariantSelectItem = {

    @:optional var args:Array<String>;

} //IdeInfoVariantSelectItem

