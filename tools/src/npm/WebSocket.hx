package npm;

@:jsRequire('ws')
extern class WebSocket {

    var clientId:String;

    var persistentId:String;

    function new(host:String, ?options:Dynamic);

    function on(event:String, callback:Dynamic):Void;

    function send(data:String, ?onError:Dynamic):Void;

    function terminate():Void;

} //WebSocket

@:jsRequire('ws', 'Server')
extern class WebSocketServer {

    var clients:WebSocketSet<WebSocket>;

    function new(options:Dynamic);

    function on(event:String, callback:Dynamic):Void;

} //WebSocketServer

extern class WebSocketSet<T> {

    function forEach(cb:T->Void):Void;

} //WebSocketSet
