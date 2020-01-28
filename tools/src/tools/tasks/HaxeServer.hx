package tools.tasks;

import tools.Helpers.*;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import npm.DetectPort;

using tools.Colors;
using StringTools;

class HaxeServer extends tools.Task {

    override public function info(cwd:String):String {

        return "Run a haxe compilation server to build projects faster.";

    }

    override function run(cwd:String, args:Array<String>):Void {
        
        // Find a free port
        //
        var port:Int = 7000;
        var customPort = extractArgValue(args, 'port');
        var verbose = extractArgFlag(args, 'verbose');
        if (customPort != null && customPort.trim() != '') {
            port = Std.parseInt(customPort);
        }

        Sync.run(function(done) {
            // Listen to a free port
            DetectPort.detect(port, function(err:Dynamic, _port) {

                if (err) {
                    fail(err);
                }

                if (port != _port) {
                    // Other port suggested
                    port = _port;
                }

                done();

            });
        });

        print('Start Haxe compilation server on port $port');
        haxe(['--version']);

        // Keep a file updated in home directory to let other ceramic scripts detect
        // that a haxe server is running
        var homedir:String = untyped __js__("require('os').homedir()");
        js.Node.setTimeout(function() {
            File.saveContent(Path.join([homedir, '.ceramic-haxe-server']), '' + port);
        }, 100);
        js.Node.setInterval(function() {
            Files.touch(Path.join([homedir, '.ceramic-haxe-server']));
        }, 1000);

        // Start server
        var haxeArgs = ['--wait', '' + port];
        if (verbose) {
            haxeArgs.unshift('-v');
        }
        haxe(haxeArgs);

    }

}
