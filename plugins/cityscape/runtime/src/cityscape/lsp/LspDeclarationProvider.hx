// New code for Cityscape (not a port): the declaration provider of an LSP client
// (`textDocument/declaration`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.DeclarationProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the declaration of a symbol (`Location`,
 * `Location[]` or `LocationLink[]`, `LspConversions.toDefinition`).
 */
class LspDeclarationProvider implements DeclarationProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideDeclaration(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        client.sendCancellableRequest('textDocument/declaration', client.textDocumentPosition(model, position), token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toDefinition(result));
        });
    }

}
