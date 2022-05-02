package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.IntMap;
import ceramic.Timer;
import rtmidi.RtMidiOut;

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
        settings.targetFps = 60;

        #if (linc_sdl && cpp)
        sdl.SDL.setHint("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1");
        #end

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
        bindMidi();

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

        if (message != null) {
            var index = message.indexOf(' ');
            if (index != -1) {
                var event = message.substring(0, index);
                var data = message.substring(index + 1);
                switch event {

                    case 'midiOutInit':
                        var spaceIndex = data.indexOf(' ');
                        var index = Std.parseInt(data.substring(0, spaceIndex));
                        var name = data.substring(spaceIndex + 1);
                        midiOutInit(index, name);

                    case 'midiOutSend':
                        var parts = data.split(' ');
                        var index = Std.parseInt(parts[0]);
                        var a = Std.parseInt(parts[1]);
                        var b = Std.parseInt(parts[2]);
                        var c = Std.parseInt(parts[3]);
                        midiOutSend(index, a, b, c);

                    case 'midiOutDestroy':
                        var index = Std.parseInt(data);
                        midiOutDestroy(index);

                    default:
                }
            }
        }

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

/// Gamepad Gyro

    function bindGamepadsGyro() {

        input.onGamepadGyro(this, function(gamepadId, dx, dy, dz) {
            send('gamepadGyro $gamepadId $dx $dy $dz');
        });

    }

/// Midi

    var midiOuts:IntMap<MidiOutRef> = new IntMap();

    var midiMessage:haxe.io.Bytes = haxe.io.Bytes.alloc(2);

    function bindMidi() {

        // TODO

    }

    function midiOutInit(index:Int, name:String) {

        var rtMidiOut = new RtMidiOut();
        rtMidiOut.openVirtualPort(name);

        var existing = midiOuts.get(index);
        if (existing != null) {
            existing.ref.destroy();
        }

        midiOuts.set(index, new MidiOutRef(rtMidiOut));

    }

    function midiOutSend(index:Int, a:Int, b:Int, c:Int) {

        var rtMidiOut = midiOuts.get(index);

        if (rtMidiOut != null) {

            midiMessage.set(0, a);
            midiMessage.set(1, b);
            midiMessage.set(2, c);

            rtMidiOut.ref.sendMessage(midiMessage.getData());
        }

    }

    function midiOutDestroy(index:Int) {

        var rtMidiOut = midiOuts.get(index);

        if (rtMidiOut != null) {
            rtMidiOut.ref.destroy();

            midiOuts.remove(index);
        }

    }

}

class MidiOutRef {

    public var ref(default, null):RtMidiOut;

    public function new(ref:RtMidiOut) {
        this.ref = ref;
    }

}
