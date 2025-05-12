package backend;

#if (ios || tvos || android)
import haxe.atomic.AtomicBool;
#end

#if clay_sdl
import clay.sdl.SDL;
#end

#if clay_sdl
@:headerCode('#include "linc_sdl.h"')
#end
@:allow(backend.Main)
@:allow(backend.Textures)
@:allow(backend.ClayEvents)
class Backend implements tracker.Events implements spec.Backend {

/// Public API

    public var io(default,null) = new backend.IO();

    public var info(default,null) = new backend.Info();

    public var audio(default,null) = new backend.Audio();

    public var draw(default,null) = new backend.Draw();

    public var texts(default,null) = new backend.Texts();

    public var binaries(default,null) = new backend.Binaries();

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

        #if clay_sdl
        SDL.bind();
        #end

        #if mac
        NativeMac.setAppleMomentumScrollSupported(false);
        #end

        #if windows
        NativeWindows.init();
        #end

        #if android
        NativeAndroid.init();
        #end

    }

    public function setTargetFps(fps:Int):Void {

        clay.Clay.app.config.updateRate = fps > 0 ? 1.0 / fps : 0;

        #if (mac || windows || linux)
        clay.Clay.app.runtime.minFrameTime = fps > 0 ? (1.0 / fps) * 0.75 : 0.005;
        #end

    }

/// Events

    @event function ready();

    @event function update(delta:Float);

    @event function render();

#if clay_sdl
    @event function sdlEvent(event:SDLEvent);
#end

/// Internal flags

#if (ios || tvos || android)
    var mobileInBackground:AtomicBool = new AtomicBool(false);
#end

}
