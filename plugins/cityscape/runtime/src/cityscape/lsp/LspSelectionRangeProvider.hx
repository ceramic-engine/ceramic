// New code for Cityscape (not a port): the selection range provider of an
// LSP client (`textDocument/selectionRange`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for the ranges the selection expands to at each position
 * (smart select, `LspConversions.toSelectionRanges`).
 */
class LspSelectionRangeProvider implements SelectionRangeProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideSelectionRanges(model:ITextModel, positions:Array<Position>, token:CancellationToken, resolve:(ranges:Null<Array<Array<SelectionRange>>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/selectionRange', {
            textDocument: client.textDocumentIdentifier(model),
            positions: [for (p in positions) LspConversions.toLspPosition(p)]
        }, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toSelectionRanges(result));
        });
    }

}
