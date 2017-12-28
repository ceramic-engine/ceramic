package backend;

import snow.Snow;
import snow.types.Types;

#if cpp
import ceramic.internal.Worker;
#end

@:allow(Main)
@:allow(backend.Textures)
class Backend implements spec.Backend implements ceramic.Events {

/// Internal

#if cpp

    var worker:Worker = null;

#end

/// Public API

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var textures(default,null) = new backend.Textures();

    public var shaders(default,null) = new backend.Shaders();

    public var screen(default,null) = new backend.Screen();

/// Backend specifics

    public var snow(default,null):Snow = null;

/// Lifecycle

    public function new() {}

    public function init(app:ceramic.App) {

#if cpp
        // Init background worker
        Worker.init();
        worker = new Worker();
        app.onUpdate(function(delta) {
            Worker.flush();
        });
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
