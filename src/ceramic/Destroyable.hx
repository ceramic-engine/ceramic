package ceramic;

interface Destroyable {

    var destroyed:Bool;

    function destroy():Void;

    function onDestroy(handle:Void->Void, ?owner:Destroyable):Void;

    function onceDestroy(handle:Void->Void, ?owner:Destroyable):Void;

} //Destroyable
