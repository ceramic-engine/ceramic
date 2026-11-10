// New code for Cityscape (not a port): the typeDefinition provider of an LSP client
// (`textDocument/typeDefinition`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.TypeDefinitionProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the definition of the type of a symbol (`Location`,
 * `Location[]` or `LocationLink[]`, `LspConversions.toDefinition`).
 */
class LspTypeDefinitionProvider implements TypeDefinitionProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideTypeDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        client.sendCancellableRequest('textDocument/typeDefinition', client.textDocumentPosition(model, position), token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toDefinition(result));
        });
    }

}
