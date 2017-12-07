package ceramic;

#if !macro
@:autoBuild(ceramic.macros.ComponentMacro.build())
#end
class Component extends Entity {

    /** If this component was created from an initializer,
        its initializer name is provided to retrieve the
        initializer from the component. */
    public var initializerName(default,null):String = null;

    public function new() {

    } //new

    function init():Void {

    } //init

} //Component
