package spec;

interface Backend {

    var audio(default,null):backend.Audio;

    var draw(default,null):backend.Draw;

    var fonts(default,null):backend.Fonts;

    var texts(default,null):backend.Texts;

    var textures(default,null):backend.Textures;
    
} //Backend