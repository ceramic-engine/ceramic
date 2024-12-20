package tools.tasks;

import haxe.io.Path;
import sys.io.File;
import timestamp.Timestamp;
import tools.DetectPort;
import tools.Helpers.*;

using StringTools;
using tools.Colors;

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

        port = DetectPort.detect(port);

        print('Start Haxe compilation server on port $port');
        haxe(['--version']);

        var homedir:String = homedir();

        // Start server
        var haxeArgs = ['--wait', '' + port];
        if (verbose) {
            haxeArgs.unshift('-v');
        }

        var didCreate = false;
        var checkpoint = Timestamp.now();

        haxe(haxeArgs, {
            tick: () -> {
                // Keep a file updated in home directory to let other ceramic scripts detect
                // that a haxe server is running
                final now = Timestamp.now();
                if (!didCreate) {
                    if (now - checkpoint >= 0.1) {
                        checkpoint = now;
                        didCreate = true;
                        File.saveContent(Path.join([homedir, '.ceramic-haxe-server']), '' + port);
                    }
                }
                else {
                    if (now - checkpoint >= 1.0) {
                        checkpoint = now;
                        Files.touch(Path.join([homedir, '.ceramic-haxe-server']));
                    }
                }
            }
        });

    }

}
