package spec;

interface Backend {

    function init(app:ceramic.App):Void;

#if completion

    var info(default,null):spec.Info;

    var audio(default,null):spec.Audio;

    var draw(default,null):spec.Draw;

    var texts(default,null):spec.Texts;

    var textures(default,null):spec.Textures;

    var screen(default,null):spec.Screen;

#else

    var info(default,null):backend.Info;

    var audio(default,null):backend.Audio;

    var draw(default,null):backend.Draw;

    var texts(default,null):backend.Texts;

    var textures(default,null):backend.Textures;

    var screen(default,null):backend.Screen;

#end
    
} //Backend