package spec;

import backend.LoadTextOptions;

interface Texts {

    function load(path:String, ?options:LoadTextOptions, done:String->Void):Void;

}
