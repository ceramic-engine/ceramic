// New code for Cityscape (not a port): the link provider of an LSP client
// (`textDocument/documentLink`, `documentLink/resolve`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.ILink;
import cityscape.common.Languages.ILinksList;
import cityscape.common.Languages.LinkProvider;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server for the links of a document (`LspConversions.toLinks`).
 * `resolveLink` is set when the server declares `resolveProvider` (it
 * sends the original LSP link, for its target).
 */
class LspLinkProvider implements LinkProvider {

    final client:LspClient;

    public var resolveLink(default, null):Null<(link:ILink, token:CancellationToken, resolve:(link:Null<ILink>) -> Void) -> Void>;

    /**
     * `capability`: the server's `documentLinkProvider`
     * (`{resolveProvider}`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.resolveLink = null;
        if (capability != null && JsValues.isObject(capability) && LspConversions.asBool(capability.resolveProvider)) {
            this.resolveLink = resolveOne;
        }
    }

    public function provideLinks(model:ITextModel, token:CancellationToken, resolve:(links:Null<ILinksList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/documentLink', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            final links = error != null ? null : LspConversions.toLinks(result);
            resolve(links == null ? null : {links: links});
        });
    }

    function resolveOne(link:ILink, token:CancellationToken, resolve:(link:Null<ILink>) -> Void):Void {
        final original = LspConversions.originalOf(link);
        if (original == null) {
            resolve(null);
            return;
        }
        client.sendCancellableRequest('documentLink/resolve', original, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toLink(result));
        });
    }

}
