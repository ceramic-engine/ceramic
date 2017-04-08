package tools;

import haxe.io.Path;

class Index {

    static function main():Void {

        // Expose run(cwd, args)
        var module:Dynamic = js.Node.module;
        module.exports = run;
    
    } //main

    static function run(cwd:String, args:Array<String>):Void {

        if (args.length > 0) {

            var first = args[0];

            // Try module require
            if (~/^([a-zA-Z0-9_]+)$/.match(first) && sys.FileSystem.exists(Path.join([cwd, 'tools-' + first + '.js']))) {
                var tools = js.Node.require('./tools-' + first + '.js');
                tools(cwd, args);
            }
            else {
                @:privateAccess Tools.boot(cwd, ['default'].concat(args));
            }

        } else {
            @:privateAccess Tools.boot(cwd, ['default', 'help']);
        }

    } //main
    
} //Index
