package spec;

import backend.Texts;

interface Texts {

    function load(path:String, ?options:LoadTextOptions, done:String->Void):Void;

} //Texts
