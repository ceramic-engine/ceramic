// New code for Cityscape (not a port): the folding range provider of an LSP
// client (`textDocument/foldingRange`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.common.Languages.FoldingContext;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server for the folding ranges of a document
 * (`LspConversions.toFoldingRanges`). `onDidChange` fires when the server
 * sends `workspace/foldingRange/refresh`.
 */
class LspFoldingRangeProvider implements FoldingRangeProvider {

    final client:LspClient;
    final emitter:Emitter<FoldingRangeProvider>;

    public var id(default, null):Null<String>;

    public var onDidChange(default, null):Null<Event<FoldingRangeProvider>>;

    public function new(client:LspClient, emitter:Emitter<FoldingRangeProvider>) {
        this.client = client;
        this.emitter = emitter;
        this.id = 'lsp';
        this.onDidChange = emitter.event;
    }

    /**
     * Tells the editors that the ranges changed.
     */
    public function refresh():Void {
        emitter.fire(this);
    }

    public function provideFoldingRanges(model:ITextModel, context:FoldingContext, token:CancellationToken, resolve:(ranges:Null<Array<FoldingRange>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/foldingRange', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toFoldingRanges(result));
        });
    }

}
