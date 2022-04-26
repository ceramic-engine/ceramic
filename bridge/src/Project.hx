package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.Timer;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Ceramic Native Bridge';
        settings.antialiasing = 0;
        settings.background = Color.BLACK;
        settings.targetWidth = 64;
        settings.targetHeight = 48;
        settings.scaling = FIT;
        settings.resizable = false;

        app.onceReady(this, ready);

    }

    var port:Int = 49113;

    var ws:hx.ws.WebSocket = null;

    var wsReady:Bool = false;

    function ready() {

        extractArgs();

        connectWebSocketClient();
        setupHeartBeat();

        bindGamepadsGyro();

        #if debug
        trace('Port: $port');
        #end

    }

    function extractArgs() {

        #if sys
        var argv = Sys.args();
        var i = 0;
        while (i < argv.length - 1) {
            var arg = argv[i];
            if (arg == '--port') {
                i++;
                port = Std.parseInt(argv[i]);
            }
            i++;
        }
        #end

    }

    function send(message:String) {

        if (ws != null && wsReady) {
            ws.send(message);
        }

    }

    function receive(message:String) {

        #if debug
        trace('received message: $message');
        #end

    }

    function connectWebSocketClient() {

        //hx.ws.Log.mask = hx.ws.Log.INFO | hx.ws.Log.DEBUG | hx.ws.Log.DATA;

        #if debug
        trace('try connect... (${app.frame})');
        #end

        try {

            var _ws = new hx.ws.WebSocket("ws://127.0.0.1:" + port);
            wsReady = false;
            ws = _ws;

            ws.onopen = function() {
                #if debug
                trace('ws client open');
                #end
                if (ws != _ws) return;
                wsReady = true;

                // // ceramic.Timer.interval(this, 1.0, () -> {
                // //     ws.send("message! " + app.frame);
                // // });
                // app.onUpdate(this, delta -> {
                //     trace(app.frame);
                //     ws.send("message! " + app.frame);
                // });
                // //ws.send(haxe.io.Bytes.ofString("alice bytes"));
            };

            ws.onclose = function() {
                #if debug
                trace('ws client close');
                #end
                if (ws != _ws) return;
                ws = null;

                // Try to reconnect later
                Timer.delay(this, 1.0, connectWebSocketClient);
            };

            ws.onerror = function(error:Dynamic) {
                #if debug
                trace('ws client error: ' + error);
                #end
                if (ws != _ws) return;
                ws = null;

                // Try to reconnect later
                Timer.delay(this, 1.0, connectWebSocketClient);
            };

            ws.onmessage = function(message:hx.ws.Types.MessageType) {
                if (ws != _ws) return;
                switch message {
                    case BytesMessage(content):
                    case StrMessage(content):
                        receive(content);
                }
            };

        }
        catch (e:Dynamic) {

            // Try to reconnect later
            Timer.delay(this, 1.0, connectWebSocketClient);

        }

    }

    function setupHeartBeat() {

        Timer.interval(this, 1.0, function() {
            send('ping ${app.frame}');
        });

    }

    function bindGamepadsGyro() {

        input.onGamepadGyro(this, function(gamepadId, dx, dy, dz) {
            send('gamepadGyro $gamepadId $dx $dy $dz');
        });

    }

}
