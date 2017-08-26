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

        // Setup required environment variables
        if (!js.Node.global.ceramicEnvReady) {
            js.Node.require('./ceramic-env');
            js.Node.global.ceramicEnvReady = true;
        }
    
    } //main

    static function run(cwd:String, args:Array<String>, ceramicPath:String):Void {

        // Electron proxy?
        var argIndex = args.indexOf('--electron-proxy');
        if (argIndex != -1) {
            js.Node.global.isElectronProxy = true;
            args.splice(argIndex, 1);
        }

        if (args.length > 0 && args[0] != '--help') {
            @:privateAccess Tools.runInFiber(cwd, [].concat(args), ceramicPath);
        } else {
            @:privateAccess Tools.runInFiber(cwd, ['help'], ceramicPath);
        }

    } //main
    
} //Index
