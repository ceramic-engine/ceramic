package backend;

class Info #if !completion implements spec.Info #end {

    public function new() {}

/// System

    public function storageDirectory():String {

        #if cs
        return untyped __cs__('UnityEngine.Application.persistentDataPath');
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
        return ['shader'];
    }

}
