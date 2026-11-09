// New code for Cityscape (not a port): the document symbol provider of an
// LSP client (`textDocument/documentSymbol`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.DocumentSymbolProvider;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server for the symbols of a document
 * (`LspConversions.toDocumentSymbols`).
 */
class LspDocumentSymbolProvider implements DocumentSymbolProvider {

    final client:LspClient;

    public var displayName(default, null):Null<String>;

    public function new(client:LspClient) {
        this.client = client;
        this.displayName = 'lsp';
    }

    public function provideDocumentSymbols(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<Array<DocumentSymbol>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/documentSymbol', {
            textDocument: client.textDocumentIdentifier(model)
        }, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toDocumentSymbols(result));
        });
    }

}
