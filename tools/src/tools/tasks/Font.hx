package tools.tasks;

import haxe.io.Path;

class Font extends tools.Task {

/// Properties

/// Lifecycle

    override public function new() {

        super();

    } //new

    override public function info(cwd:String):String {

        return "Generate a bitmap font from the given font.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var result = Fonts.generateBitmapFont('sample/assets/baloo.ttf', {fieldType: 'sdf'});

        var i = 1;
        for (texture in result.textures) {
            var file = Path.join([cwd, 'font' + (i > 1 ? ''+i : '') + '.png']);
            js.node.Fs.writeFileSync(file, texture);
            i++;
        }

    } //run

}