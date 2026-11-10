// New code for Cityscape (not a port): the document highlight provider of
// an LSP client (`textDocument/documentHighlight`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.DocumentHighlight;
import cityscape.common.Languages.DocumentHighlightProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the highlights of the symbol at a position
 * (`LspConversions.toDocumentHighlights`: the LSP kinds start at 1,
 * Monaco's at 0).
 */
class LspDocumentHighlightProvider implements DocumentHighlightProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideDocumentHighlights(model:ITextModel, position:Position, token:CancellationToken, resolve:(highlights:Null<Array<DocumentHighlight>>) -> Void):Void {
        client.sendCancellableRequest('textDocument/documentHighlight', client.textDocumentPosition(model, position), token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toDocumentHighlights(result));
        });
    }

}
