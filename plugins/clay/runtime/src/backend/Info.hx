package backend;

class Info #if !completion implements spec.Info #end {

    public function new() {}

/// System

    inline public function storageDirectory():String {
        #if (cpp && linc_sdl && !macro)
        return clay.Clay.app.io.appPathPrefs();
        #else
        return null;
        #end
    }

/// Assets

    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt', 'atlas'];
    }

    inline public function soundExtensions():Array<String> {
        return ['ogg', 'wav'];
    }

    inline public function shaderExtensions():Array<String> {
        return ['frag', 'vert'];
    }

}
