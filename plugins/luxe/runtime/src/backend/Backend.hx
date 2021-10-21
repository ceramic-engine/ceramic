package backend;

#if mac
import backend.NativeMac;
#end
#if windows
import backend.NativeWindows;
#end

@:allow(backend.Textures)
@:allow(backend.Draw)
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    public var io(default,null) = new backend.IO();

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var textures(default,null) = new backend.Textures();

    public var shaders(default,null) = new backend.Shaders();

    public var screen(default,null) = new backend.Screen();

    #if plugin_http
    public var http(default,null) = new backend.Http();
    #end

    public var input(default,null) = new backend.Input();

    public var textInput(default,null) = new backend.TextInput();

    public var clipboard(default,null) = new backend.Clipboard();

    public function new() {}

    public function init(app:ceramic.App) {

#if mac
        NativeMac.setAppleMomentumScrollSupported(false);
#end

#if windows
        NativeWindows.init();
#end

    }

    public function setTargetFps(fps:Int):Void {

        Luxe.core.update_rate = fps > 0 ? 1.0 / fps : 0;

    }

/// Events

    @event function ready();

    @event function update(delta:Float);

#if (linc_sdl && cpp)
    @event function sdlEvent(event:sdl.Event);
#end

/// Internal update logic

    inline function willEmitUpdate(delta:Float) {

        draw.begin();

    }

    inline function didEmitUpdate(delta:Float) {

        draw.end();

    }

}
