package tools.tasks;

import tools.Helpers.*;
import js.node.Http;
import js.node.http.Server as HttpServer;
import haxe.Json;
import npm.WebSocket;

class Server extends tools.Task {

    var nextQueryId:Int = 1;

    var server:HttpServer;

    var wss:WebSocketServer;

    override public function info(cwd:String):String {

        return "Create a ceramic server to run consecutive commands with a single output";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var port = extractArgValue(args, 'port');
        if (port == null) {
            fail('Missing --port argument');
        }

        // Create HTTP server
        server = Http.createServer(function(req, res) {
            
            if (req.method == 'POST') {
                var body = '';

                req.on('data', function(data:Dynamic) {
                    body += data;
                });

                req.on('end', function() {

                    try {
                        var json = Json.parse(body);
                        if (json.query == 'command' && Std.is(json.args, Array)) {
                            var queryId = handleCommand(json.args);
                            res.writeHead(200, {'Content-Type': 'text/plain'});
                            res.end('$queryId\n');
                            return;

                        } else {
                            res.writeHead(404, {'Content-Type': 'text/plain'});
                            res.end('-3\n');
                            return;
                        }
                    }
                    catch (e:Dynamic) {
                        res.writeHead(404, {'Content-Type': 'text/plain'});
                        res.end('-2\n');
                        return;
                    }
                });

                return;
            }

            res.writeHead(404, {'Content-Type': 'text/plain'});
            res.end('-1\n');

        });

        // Create WebSocket server
        wss = new WebSocketServer({
            server: server
        });

        wss.on('error', function(err:Dynamic) {});
        wss.on('connection', function(ws:WebSocket) {
            ws.on('error', function(err:Dynamic) {});
            ws.on('message', function(message:String) {

                trace('RECEIVE MESSAGE: ' + message);

            });
        });

        // Listen to requested port
        Sync.run(function(done) {
            server.listen(port);
        });

    } //run

    function handleCommand(args:Array<String>) {

        var queryId = nextQueryId++;

        trace('HANDLE CERAMIC CMD ARGS: ' + Json.stringify(args));

        return queryId;

    } //handleCommand

} //Server
