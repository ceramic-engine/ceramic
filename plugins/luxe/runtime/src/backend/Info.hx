package backend;

class Info implements spec.Info {

    public function new() {}

/// System

    inline public function storageDirectory():String {
#if (cpp && !macro)
        return Luxe.io.app_path_prefs;
#else
        return null;
#end
    }

/// Assets

    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt'];
    }

    inline public function soundExtensions():Array<String> {
        return ['ogg', 'wav'];
    }

    inline public function shaderExtensions():Array<String> {
        return ['glsl', 'frag', 'vert'];
    }

}
