package spec;

import haxe.io.Bytes;
import backend.LoadBinaryOptions;

interface Binaries {

    function load(path:String, ?options:LoadBinaryOptions, done:Bytes->Void):Void;

    /**
     * Returns `true` if paths with `?hot=...` are supported on this backend
     * @return Bool
     */
    function supportsHotReloadPath():Bool;

}
