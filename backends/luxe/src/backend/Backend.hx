package backend;

@:allow(Main)
class Backend implements spec.Backend implements ceramic.Events {

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var textures(default,null) = new backend.Textures();

    public var screen(default,null) = new backend.Screen();

    public function new() {}

    public function init(app:ceramic.App) {

    } //init

/// Events

    @event function ready();

    @event function update(delta:Float);

/// Internal update logic

    inline function willEmitUpdate(delta:Float) {

        draw.begin();

    } //willEmitUpdate

    inline function didEmitUpdate(delta:Float) {

        draw.end();

    } //didEmitUpdate

} //Backend
