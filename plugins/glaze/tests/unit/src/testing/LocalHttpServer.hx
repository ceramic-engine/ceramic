package testing;

import haxe.io.Bytes;

/** A response of `LocalHttpServer` */
typedef LocalHttpResponse = {
    var status:Int;
    var headers:Array<String>;
    var body:Bytes;
}

/**
 * A small HTTP/1.1 server on 127.0.0.1 for tests (no network involved): a
 * Node `http` server on Node, a socket server on a background thread on
 * native targets. Every request is answered by `handler` (method, path with
 * its query string) and closes the connection.
 */
class LocalHttpServer {

    /** The port the server listens on (0 until started) */
    public var port(default, null):Int = 0;

    final handler:(method:String, path:String) -> LocalHttpResponse;

    final hits:Map<String, Int> = new Map();

    #if (sys && !js)
    final mutex = new sys.thread.Mutex();

    var socket:Null<sys.net.Socket> = null;

    var stopped = false;
    #elseif js
    var server:Dynamic = null;
    #end

    public function new(handler:(method:String, path:String) -> LocalHttpResponse) {
        this.handler = handler;
    }

    /** The base URL of the server, `http://127.0.0.1:port` */
    public function url(path:String):String {
        return 'http://127.0.0.1:$port$path';
    }

    /** How many requests of `path` (with its query string) were received */
    public function hitCount(path:String):Int {
        #if (sys && !js)
        mutex.acquire();
        #end
        final count = hits.exists(path) ? hits.get(path) : 0;
        #if (sys && !js)
        mutex.release();
        #end
        return count;
    }

    function hit(path:String):Void {
        #if (sys && !js)
        mutex.acquire();
        #end
        hits.set(path, (hits.exists(path) ? hits.get(path) : 0) + 1);
        #if (sys && !js)
        mutex.release();
        #end
    }

    /** Starts the server, then calls `ready` (on the main thread). */
    public function start(ready:() -> Void):Void {
        #if js
        final http:Dynamic = js.Syntax.code('require("http")');
        server = http.createServer((req:Dynamic, res:Dynamic) -> {
            final path:String = req.url;
            hit(path);
            final response = handler(req.method, path);
            final headers:Dynamic = {};
            var i = 0;
            while (i + 1 < response.headers.length) {
                Reflect.setField(headers, response.headers[i], response.headers[i + 1]);
                i += 2;
            }
            Reflect.setField(headers, 'Content-Length', '' + response.body.length);
            Reflect.setField(headers, 'Connection', 'close');
            res.writeHead(response.status, headers);
            res.end(js.Syntax.code('Buffer.from({0}, 0, {1})', response.body.getData(), response.body.length));
        });
        server.listen(0, '127.0.0.1', () -> {
            port = server.address().port;
            ready();
        });
        #elseif sys
        final socket = new sys.net.Socket();
        socket.bind(new sys.net.Host('127.0.0.1'), 0);
        socket.listen(16);
        this.socket = socket;
        port = socket.host().port;
        sys.thread.Thread.create(() -> {
            while (!stopped) {
                final client = try socket.accept() catch (e:Dynamic) null;
                if (client == null)
                    break;
                try {
                    serve(client);
                }
                catch (e:Dynamic) {}
                try client.close() catch (e:Dynamic) {}
            }
        });
        ready();
        #else
        throw 'LocalHttpServer is not supported on this target';
        #end
    }

    #if (sys && !js)
    function serve(client:sys.net.Socket):Void {
        client.setTimeout(10);
        final requestLine = client.input.readLine();
        while (true) {
            final line = StringTools.trim(client.input.readLine());
            if (line == '')
                break;
        }
        final parts = requestLine.split(' ');
        final path = parts.length > 1 ? parts[1] : '/';
        hit(path);
        final response = handler(parts[0], path);
        final head = new StringBuf();
        head.add('HTTP/1.1 ${response.status} ${response.status == 200 ? 'OK' : 'Status'}\r\n');
        var i = 0;
        while (i + 1 < response.headers.length) {
            head.add('${response.headers[i]}: ${response.headers[i + 1]}\r\n');
            i += 2;
        }
        head.add('Content-Length: ${response.body.length}\r\n');
        head.add('Connection: close\r\n\r\n');
        client.output.writeString(head.toString());
        client.output.writeFullBytes(response.body, 0, response.body.length);
        client.output.flush();
    }
    #end

    /** Stops the server. */
    public function stop():Void {
        #if js
        if (server != null) {
            server.close();
            server = null;
        }
        #elseif sys
        stopped = true;
        if (socket != null) {
            // Unblocks accept()
            try {
                final wake = new sys.net.Socket();
                wake.connect(new sys.net.Host('127.0.0.1'), port);
                wake.close();
            }
            catch (e:Dynamic) {}
            try socket.close() catch (e:Dynamic) {}
            socket = null;
        }
        #end
    }

}
