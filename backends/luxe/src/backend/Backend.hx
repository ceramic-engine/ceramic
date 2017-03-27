package backend;

@:allow(backend.Main)
class Backend implements spec.Backend implements ceramic.Events {

    public function new() {}

/// Events

    @event function update(delta:Float);

} //Backend
