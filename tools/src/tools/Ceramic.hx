package tools;

import haxe.io.Path;

using StringTools;

class Ceramic {

    static function main():Void {

        var cwd = Path.normalize(Sys.getCwd());
        while (cwd.endsWith('/')) cwd = cwd.substring(0, cwd.length - 1);

        run(
            cwd,
            Sys.args(),
            Path.directory(
                Native.executablePath()
            )
        );

    }

    static function run(cwd:String, args:Array<String>, ceramicPath:String):Void {

        if (args.length > 0 && args[0] != '--help') {
            @:privateAccess Tools.run(cwd, [].concat(args), ceramicPath);
        } else {
            @:privateAccess Tools.run(cwd, ['help'], ceramicPath);
        }

    }

}
