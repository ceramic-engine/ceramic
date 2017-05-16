package spec;

interface Backend {

    function init(app:ceramic.App):Void;

    var audio(default,null):backend.Audio;

    var draw(default,null):backend.Draw;

    var texts(default,null):backend.Texts;

    var textures(default,null):backend.Textures;
    
} //Backend