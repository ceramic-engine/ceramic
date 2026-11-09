// New code for Cityscape (not a port): the range formatting provider of an
// LSP client (`textDocument/rangeFormatting`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.DocumentRangeFormattingEditProvider;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;

/**
 * Asks the server to format a range of a document. Formatting several
 * ranges at once (`provideDocumentRangesFormattingEdits`) is not offered.
 */
class LspDocumentRangeFormattingProvider implements DocumentRangeFormattingEditProvider {

    final client:LspClient;

    public var displayName(default, null):Null<String>;

    public var provideDocumentRangesFormattingEdits(default, null):Null<(model:ITextModel, ranges:Array<Range>, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void) -> Void>;

    public function new(client:LspClient) {
        this.client = client;
        this.displayName = 'lsp';
        this.provideDocumentRangesFormattingEdits = null;
    }

    public function provideDocumentRangeFormattingEdits(model:ITextModel, range:Range, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/rangeFormatting', {
            textDocument: client.textDocumentIdentifier(model),
            range: LspConversions.toLspRange(range),
            options: LspConversions.toLspFormattingOptions(options)
        }, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toTextEdits(result));
        });
    }

}
