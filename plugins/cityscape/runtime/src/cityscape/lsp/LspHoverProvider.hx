// New code for Cityscape (not a port): the hover provider of an LSP client
// (`textDocument/hover`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.Hover;
import cityscape.common.Languages.HoverContext;
import cityscape.common.Languages.HoverProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for a hover (`LspConversions.toHover`).
 */
class LspHoverProvider implements HoverProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideHover(model:ITextModel, position:Position, token:CancellationToken, context:Null<HoverContext>, resolve:(hover:Null<Hover>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/hover', {
            textDocument: client.textDocumentIdentifier(model),
            position: LspConversions.toLspPosition(position)
        }, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toHover(result));
        });
    }

}
