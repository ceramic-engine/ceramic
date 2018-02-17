package backend;

#if mac
import backend.NativeMac;
#end

@:allow(Main)
@:allow(backend.Textures)
class Backend implements ceramic.Events #if !completion implements spec.Backend #end {

/// Public API

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var images(default,null) = new backend.Images();

    public var shaders(default,null) = new backend.Shaders();

    public var screen(default,null) = new backend.Screen();

    public function new() {}

    public function init(app:ceramic.App) {

#if mac
        NativeMac.setAppleMomentumScrollSupported(true);
#end

    } //init

/// Events

    @event function ready();

    @event function update(delta:Float);

    @event function keyDown(key:ceramic.Key);
    @event function keyUp(key:ceramic.Key);

/// Internal update logic

    inline function willEmitUpdate(delta:Float) {

        draw.begin();

    } //willEmitUpdate

    inline function didEmitUpdate(delta:Float) {

        draw.end();

    } //didEmitUpdate

} //Backend
