package spec;

interface Backend {

    function init(app:ceramic.App):Void;

    var io(default,null):backend.IO;

    var info(default,null):backend.Info;

    var audio(default,null):backend.Audio;

    var draw(default,null):backend.Draw;

    var texts(default,null):backend.Texts;

    var images(default,null):backend.Images;

    var screen(default,null):backend.Screen;

    var http(default,null):backend.Http;
    
} //Backend