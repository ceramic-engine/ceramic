package spec;

import backend.LoadTextOptions;

interface Texts {

    function load(path:String, ?options:LoadTextOptions, done:String->Void):Void;

    /**
     * Returns `true` if paths with `?hot=...` are supported on this backend
     * @return Bool
     */
    function supportsHotReloadPath():Bool;

}
