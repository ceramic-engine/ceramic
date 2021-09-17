package ceramic;

@:allow(ceramic.App)
class AppXUpdatesHandler {

    public var owner:Entity = null;

    public var numUpdates:Int = -1;

    public var callback:Void->Void = null;

    private function new() {}

    function reset() {

        owner = null;
        numUpdates = -1;
        callback = null;

    }

}