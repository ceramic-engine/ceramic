// New code for Cityscape (not a port): the transport of the LSP client (the
// channel carrying JSON-RPC messages to and from a language server).
package cityscape.lsp;

/**
 * Carries JSON-RPC messages between an `LspClient` and a language server.
 *
 * Messages are already parsed JSON: anonymous structures (requests
 * `{jsonrpc, id, method, params}`, notifications `{jsonrpc, method,
 * params}`, responses `{jsonrpc, id, result}` or `{jsonrpc, id, error}`).
 * A transport talking to a process or a socket serializes them
 * (`haxe.Json.stringify`) with the `Content-Length` header of the protocol,
 * and parses what it receives (`haxe.Json.parse`).
 *
 * A transport may deliver a message synchronously, from inside `send`
 * (an in-process server answering at once), or later: the client handles
 * both.
 */
interface LspTransport {

    /**
     * Starts the transport: from now on, every message of the server
     * (responses, notifications, requests to the client) goes to
     * `onMessage`. Called once by `LspClient.start`, before the first `send`.
     */
    function start(onMessage:(message:Dynamic) -> Void):Void;

    /**
     * Sends a message (request, response or notification) to the server.
     */
    function send(message:Dynamic):Void;

    /**
     * Stops the transport: no message is delivered after this.
     */
    function dispose():Void;

}
