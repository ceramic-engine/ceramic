package ceramic;

#if !macro
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
class Entity implements Events implements Lazy implements Observable {

/// Properties

    @lazy public var data:Dynamic<Dynamic> = {};

    public var name:String = null;

    public var destroyed:Bool = false;

/// Events

    @event function destroy();

/// Lifecycle

    public function destroy():Void {

        if (destroyed) return;
        destroyed = true;

        emitDestroy();

    } //destroy

/// Print

    function toString():String {

        var className = Type.getClassName(Type.getClass(this));
        var dotIndex = className.lastIndexOf('.');
        if (dotIndex != -1) className = className.substr(dotIndex + 1);

        if (name != null) {
            return '$className($name)';
        } else {
            return '$className';
        }

    } //toString

}

