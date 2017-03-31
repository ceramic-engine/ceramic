package ceramic;

@:allow(ceramic.App)
class Screen extends Entity {

/// Events

    @event function update(delta:Float);

/// Lifecycle

    function new() {

    } //new

    function backendReady():Void {

    } //backendReady
}
