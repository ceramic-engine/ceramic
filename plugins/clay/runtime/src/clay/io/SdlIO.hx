package clay.io;

import sdl.SDL;

import clay.buffers.Uint8Array;

class SdlIO extends BaseIO {

    function new() {}
    
    override function appPath():String {

        var path = SDL.getBasePath();
        if (path == null) path = '';

        return path;

    }

}
