// New code for Cityscape (not a port): the definition provider of an LSP
// client (`textDocument/definition`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Definition;
import cityscape.common.Languages.DefinitionProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the definition of a symbol
 * (`LspConversions.toDefinition`).
 */
class LspDefinitionProvider implements DefinitionProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/definition', {
            textDocument: client.textDocumentIdentifier(model),
            position: LspConversions.toLspPosition(position)
        }, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toDefinition(result));
        });
    }

}
