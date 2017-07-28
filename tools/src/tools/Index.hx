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
        // Setup required environment variables
        js.Node.require('./ceramic-env');
#end

        js.Node.require('./ceramic-stdio');
    
    } //main

    static function run(cwd:String, args:Array<String>, ceramicPath:String):Void {

        // Electron proxy?
        var argIndex = args.indexOf('--electron-proxy');
        if (argIndex != -1) {
            js.Node.global.isElectronProxy = true;
            args.splice(argIndex, 1);
        }

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
