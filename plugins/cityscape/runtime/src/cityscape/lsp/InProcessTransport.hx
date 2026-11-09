// New code for Cityscape (not a port): the transport of an LSP client to a
// language server written in Haxe, running in the same process.
package cityscape.lsp;

/**
 * Connects an `LspClient` to an `LspInProcessServer`: messages are passed
 * as they are (anonymous structures), without serialization. The server
 * may answer at once (inside `send`) or later.
 *
 * ```haxe
 * final client = new LspClient(context, new InProcessTransport(new MyServer()), {languageIds: ['mylang']});
 * client.start();
 * ```
 */
class InProcessTransport implements LspTransport {

    final server:LspInProcessServer;

    var onMessage:Null<(message:Dynamic) -> Void> = null;

    var disposed:Bool = false;

    public function new(server:LspInProcessServer) {
        this.server = server;
    }

    public function start(onMessage:(message:Dynamic) -> Void):Void {
        if (disposed) {
            return;
        }
        this.onMessage = onMessage;
        server.onNotification = deliver;
    }

    public function send(message:Dynamic):Void {
        if (disposed) {
            return;
        }
        server.handleMessage(message, deliver);
    }

    function deliver(message:Dynamic):Void {
        if (!disposed && message != null && onMessage != null) {
            onMessage(message);
        }
    }

    public function dispose():Void {
        if (disposed) {
            return;
        }
        disposed = true;
        onMessage = null;
        server.onNotification = null;
    }

}
