package backend;

class Info #if !completion implements spec.Info #end {

    var _storageDirectory:String = null;

    public function new() {

        #if (cs && unity)
        _storageDirectory = untyped __cs__('UnityEngine.Application.persistentDataPath');
        #end

    }

/// System

    public function storageDirectory():String {

        return _storageDirectory;

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
        return ['shader'];
    }

}
