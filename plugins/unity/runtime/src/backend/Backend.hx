package backend;

// Import needed to make reflection work as expected
import backend.FieldLookup;

using ceramic.Extensions;

@:allow(Main)
@:allow(backend.Textures)
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    public var io(default,null) = new backend.IO();

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var binaries(default,null):backend.Binaries;

    public var textures(default,null) = new backend.Textures();

    public var shaders(default,null) = new backend.Shaders();

    public var screen(default,null) = new backend.Screen();

    public var http(default,null) = new backend.Http();

    public var input(default, null) = new backend.Input();

    public var textInput(default,null) = new backend.TextInput();

    public var clipboard(default,null) = new backend.Clipboard();

    public function new() {}

    public function init(app:ceramic.App) {

        FieldLookup.keep();

    }

/// Events

    @event function ready();

    @event function update(delta:Float);

/// Internal update logic

    inline function willEmitUpdate(delta:Float) {

        screen.update();
        input.update();
        flushNextUpdateCallbacks();

    }

    inline function didEmitUpdate(delta:Float) {

        //

    }

    var _nextUpdateCallbacks:Array<Void->Void> = [];
    var _nextUpdateCallbacksIterate:Array<Void->Void> = [];

    function onceNextUpdate(cb:Void->Void):Void {

        _nextUpdateCallbacks.push(cb);

    }

    function flushNextUpdateCallbacks():Void {

        var len = _nextUpdateCallbacks.length;
        for (i in 0...len) {
            _nextUpdateCallbacksIterate[i] = _nextUpdateCallbacks.unsafeGet(i);
        }
        _nextUpdateCallbacks.setArrayLength(0);
        for (i in 0...len) {
            var cb = _nextUpdateCallbacksIterate.unsafeGet(i);
            _nextUpdateCallbacksIterate.unsafeSet(i, null);
            cb();
        }

    }

}
