package tools;

typedef IdeInfoTaskItem = {

    var name:String;

    var command:String;

    @:optional var args:Array<String>;

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

    @:optional var group:String;

    @:optional var role:String;

    @:optional var select:IdeInfoVariantSelectItem;

} //IdeInfoVariantItem

typedef IdeInfoVariantSelectItem = {

    @:optional var args:Array<String>;

} //IdeInfoVariantSelectItem

