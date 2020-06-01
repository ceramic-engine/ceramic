package ceramic;

class Task extends Entity {

    /// Events
    @event function done();

    @event function fail(reason:String);

    /// Helpers

    public function done():Void {

        emitDone();

    }

    public function fail(reason:String):Void {

        emitFail(reason);

    }

    /// Lifecycle

    public function run():Void {

        fail('Script.run() method must be overrided in subclasses.');

    }

}
