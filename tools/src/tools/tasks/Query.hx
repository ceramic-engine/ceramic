package tools.tasks;

import tools.Helpers.*;
import haxe.Json;
import npm.WebSocket;

class Query extends tools.Task {

    override public function info(cwd:String):String {

        return "Query an active ceramic server";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var port = extractArgValue(args, 'port', true);
        if (port == null) {
            fail('Missing --port argument');
        }

        var cmdArgs = [].concat(args.slice(1));
        var customCwd = extractArgValue(cmdArgs, 'cwd');
        if (customCwd == null) {
            cmdArgs = ['--cwd', context.cwd].concat(cmdArgs);
        }

        Sync.run(function(done) {

            var ws = new WebSocket('ws://127.0.0.1:$port');
            ws.on('error', untyped console.error);

            ws.on('open', function() {
                trace('WS OPEN');
                ws.send(Json.stringify({
                    query: 'command',
                    args: cmdArgs
                }), untyped console.error);
            });

            ws.on('message', function(data:String) {
                trace('WS MESSAGE: ' + data);
            });

        });

    } //run

} //Query
