package spec;

import backend.Texts;

interface Texts {

    function load(name:String, ?options:LoadTextOptions, done:String->Void):Void;

} //Texts
