package ceramic;

#if !macro
@:autoBuild(ceramic.macros.ComponentMacro.build())
#end
class Component extends Entity implements Events {

    public function new() {

    } //new

    function init():Void {

    } //Void

} //Component
