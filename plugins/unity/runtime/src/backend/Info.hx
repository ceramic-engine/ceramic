package backend;

class Info #if !completion implements spec.Info #end {

    public function new() {}

/// System

    inline public function storageDirectory():String {
        return null;
    }

/// Assets

    inline public function imageExtensions():Array<String> {
        return ['png'];
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
