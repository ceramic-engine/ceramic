package ceramic;

class Script extends Entity {

    /// Events
    @event function done();

    @event function fail(reason:String);

    /// Helpers

    public function done():Void {

        emitDone();

    } //done

    public function fail(reason:String):Void {

        emitFail(reason);

    } //done

    /// Lifecycle

    public function run():Void {

        fail('Script.run() method must be overrided in subclasses.');

    } //run

} //Script
