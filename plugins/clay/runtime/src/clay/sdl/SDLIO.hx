package clay.sdl;

import sdl.SDL;

import clay.buffers.Uint8Array;

class SDLIO extends clay.base.BaseIO {

    function new() {}
    
    override function appPath():String {

        var path = SDL.getBasePath();
        if (path == null) path = '';

        return path;

    }

}
