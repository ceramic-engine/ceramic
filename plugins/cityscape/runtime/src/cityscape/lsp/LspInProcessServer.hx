// New code for Cityscape (not a port): the interface of a language server
// written in Haxe and run in the same process as the editor.
package cityscape.lsp;

/**
 * A language server running in the editor's process, talking to an
 * `LspClient` through an `InProcessTransport`. Messages are JSON-RPC
 * messages as anonymous structures (parsed JSON), never serialized.
 *
 * A server written as a Haxe class implements this interface:
 *
 * ```haxe
 * class MyServer implements LspInProcessServer {
 *     public var onNotification:Null<(notification:Dynamic) -> Void> = null;
 *     public function new() {}
 *     public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
 *         if (message.method == 'initialize') {
 *             onResponse({jsonrpc: '2.0', id: message.id, result: {capabilities: {hoverProvider: true}}});
 *         }
 *         ...
 *     }
 * }
 * ```
 */
interface LspInProcessServer {

    /**
     * Handles a message of the client: a request (it has an `id` and a
     * `method`: answer it by calling `onResponse` once with
     * `{jsonrpc: '2.0', id, result}` or `{jsonrpc: '2.0', id, error: {code,
     * message}}`, at once or later), a notification (no `id`: `onResponse`
     * is not called), or the client's response to a request of the server
     * (an `id` and no `method`).
     */
    function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void;

    /**
     * Set by the transport: the server calls it for every message it sends
     * on its own, notifications (`textDocument/publishDiagnostics`,
     * `window/logMessage`...) and requests to the client
     * (`workspace/configuration`... with an `id`: the client's response
     * comes back through `handleMessage`). Null when no client listens.
     */
    var onNotification:Null<(notification:Dynamic) -> Void>;

}
