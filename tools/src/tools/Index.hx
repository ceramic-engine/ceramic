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

#if !use_backend
        // Expose local haxe to ENV, so that other commands will find it
        if (Sys.systemName() == 'Mac') {
            untyped __js__("process.env.PATH = __dirname + '/vendor/mac/haxe' + ':' + process.env.PATH");
        }
        else if (Sys.systemName() == 'Windows') {
            untyped __js__("process.env.PATH = __dirname + '/vendor/windows/haxe' + ':' + process.env.PATH");
        }
        // TODO expose git as well
#end
    
    } //main

    static function run(cwd:String, args:Array<String>, ceramicPath:String):Void {

        if (args.length > 0 && args[0] != '--help') {

            var first = args[0];

            // Try module require
            if (~/^([a-zA-Z0-9_]+)$/.match(first) && sys.FileSystem.exists(Path.join([js.Node.__dirname, 'tools-' + first + '.js']))) {
                var tools = js.Node.require('./tools-' + first + '.js');
                tools(cwd, args, ceramicPath).run();
            }
            else {
                @:privateAccess new Tools(cwd, ['default'].concat(args), ceramicPath).run();
            }

        } else {
            @:privateAccess new Tools(cwd, ['default', 'help'], ceramicPath).run();
        }

    } //main
    
} //Index
