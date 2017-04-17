package tools;

import haxe.io.Path;

class Index {

    static function main():Void {

        // Better source map support for node
        var sourceMapSupport:Dynamic = js.Node.require('source-map-support');
        sourceMapSupport.install();

        // Expose run(cwd, args)
        var module:Dynamic = js.Node.module;
        module.exports = run;
    
    } //main

    static function run(cwd:String, args:Array<String>):Void {

        if (args.length > 0 && args[0] != '--help') {

            var first = args[0];

            // Try module require
            if (~/^([a-zA-Z0-9_]+)$/.match(first) && sys.FileSystem.exists(Path.join([js.Node.__dirname, 'tools-' + first + '.js']))) {
                var tools = js.Node.require('./tools-' + first + '.js');
                tools(cwd, args).run();
            }
            else {
                @:privateAccess new Tools(cwd, ['default'].concat(args)).run();
            }

        } else {
            @:privateAccess new Tools(cwd, ['default', 'help']).run();
        }

    } //main
    
} //Index
