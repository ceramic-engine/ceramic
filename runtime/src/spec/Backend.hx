package spec;

interface Backend {

    function init(app:ceramic.App):Void;

    function setTargetFps(fps:Int):Void;

    var io(default,null):backend.IO;

    var info(default,null):backend.Info;

    var audio(default,null):backend.Audio;

    var draw(default,null):backend.Draw;

    var texts(default,null):backend.Texts;

    var binaries(default,null):backend.Binaries;

    var textures(default,null):backend.Textures;

    var screen(default,null):backend.Screen;

    var http(default,null):backend.Http;

    var textInput(default,null):backend.TextInput;

    var clipboard(default,null):backend.Clipboard;

} //Backend