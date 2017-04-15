package ceramic;

#if !macro
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
class Entity implements Events implements Shortcuts implements Lazy implements Destroyable {

/// Properties

    @lazy public var data:Dynamic<Dynamic> = {};

    public var destroyed:Bool = false;

/// Events

    @event function destroy();

/// Lifecycle

    public function destroy():Void {

        if (destroyed) return;
        destroyed = true;

        emitDestroy();

    } //destroy

}

