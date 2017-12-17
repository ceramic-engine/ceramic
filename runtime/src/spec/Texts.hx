package spec;

#if !completion
import backend.Texts;
#else
typedef LoadTextOptions = Dynamic;
#end

interface Texts {

    function load(path:String, ?options:LoadTextOptions, done:String->Void):Void;

} //Texts
