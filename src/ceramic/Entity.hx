package ceramic;

#if !macro
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
class Entity implements Events implements Shortcuts implements Lazy {

/// Properties

    @lazy public var data:Dynamic<Dynamic> = {};

    public var destroyed:Bool;

/// Events

    @event private function destroy();

/// Lifecycle

    function destroy():Void {

        if (destroyed) return;
        destroyed = true;

        emitDestroy();

    } //destroy

}

