// New code for Cityscape (not a port): the implementation provider of an LSP client
// (`textDocument/implementation`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.ImplementationProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the implementations of a symbol (`Location`,
 * `Location[]` or `LocationLink[]`, `LspConversions.toDefinition`).
 */
class LspImplementationProvider implements ImplementationProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideImplementation(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        client.sendCancellableRequest('textDocument/implementation', client.textDocumentPosition(model, position), token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toDefinition(result));
        });
    }

}
