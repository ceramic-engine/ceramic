// New code for Cityscape (not a port): the document formatting provider of
// an LSP client (`textDocument/formatting`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.DocumentFormattingEditProvider;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server to format a whole document.
 */
class LspDocumentFormattingProvider implements DocumentFormattingEditProvider {

    final client:LspClient;

    public var displayName(default, null):Null<String>;

    public function new(client:LspClient) {
        this.client = client;
        this.displayName = 'lsp';
    }

    public function provideDocumentFormattingEdits(model:ITextModel, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/formatting', {
            textDocument: client.textDocumentIdentifier(model),
            options: LspConversions.toLspFormattingOptions(options)
        }, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toTextEdits(result));
        });
    }

}
