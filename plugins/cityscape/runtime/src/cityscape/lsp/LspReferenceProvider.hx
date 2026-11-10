// New code for Cityscape (not a port): the reference provider of an LSP
// client (`textDocument/references`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Location;
import cityscape.common.Languages.ReferenceContext;
import cityscape.common.Languages.ReferenceProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the references of a symbol
 * (`LspConversions.toLocations`).
 */
class LspReferenceProvider implements ReferenceProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void {
        final params:Dynamic = client.textDocumentPosition(model, position);
        params.context = {includeDeclaration: context.includeDeclaration};
        client.sendCancellableRequest('textDocument/references', params, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toLocations(result));
        });
    }

}
