package spec;

import backend.Fonts;

interface Fonts {

    function load(name:String, ?options:LoadFontOptions, done:Font->Void):Void;  
    
    function destroy(font:Font):Void;

    function measureWidth(font:Font, text:String, size:Float):Float;

    function measureHeight(font:Font, text:String, size:Float):Float;

} //Fonts
