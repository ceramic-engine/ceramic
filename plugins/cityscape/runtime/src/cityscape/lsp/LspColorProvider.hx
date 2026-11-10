// New code for Cityscape (not a port): the color provider of an LSP client
// (`textDocument/documentColor`, `textDocument/colorPresentation`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.DocumentColorProvider;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.Languages.IColorPresentation;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server for the colors of a document and for the texts of a
 * color picked in the color picker.
 */
class LspColorProvider implements DocumentColorProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideDocumentColors(model:ITextModel, token:CancellationToken, resolve:(colors:Null<Array<IColorInformation>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/documentColor', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toColorInformations(result));
        });
    }

    public function provideColorPresentations(model:ITextModel, colorInfo:IColorInformation, token:CancellationToken, resolve:(presentations:Null<Array<IColorPresentation>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/colorPresentation', {
            textDocument: client.textDocumentIdentifier(model),
            color: LspConversions.toLspColor(colorInfo.color),
            range: LspConversions.toLspRange(colorInfo.range)
        }, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toColorPresentations(result));
        });
    }

}
