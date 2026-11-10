// New code for Cityscape (not a port): the document semantic tokens provider
// of an LSP client (`textDocument/semanticTokens/full`, `.../full/delta`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.DocumentSemanticTokensProvider;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensEdits;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.Model.ITextModel;
import haxe.extern.EitherType;

/**
 * Asks the server for the semantic tokens of a whole document, with the
 * legend of the server's `semanticTokensProvider`. When the server declares
 * `full: {delta: true}` and the editor gives the id of the previous result,
 * the request is `full/delta` and the answer may be edits of the previous
 * tokens (`LspConversions.toSemanticTokensOrEdits`). `onDidChange` fires
 * when the server sends `workspace/semanticTokens/refresh`.
 */
class LspDocumentSemanticTokensProvider implements DocumentSemanticTokensProvider {

    final client:LspClient;
    final legend:SemanticTokensLegend;
    final delta:Bool;
    final emitter:VoidEmitter;

    public var onDidChange(default, null):Null<VoidEvent>;

    /**
     * `capability`: the server's `semanticTokensProvider` (`{legend, full,
     * range}`).
     */
    public function new(client:LspClient, capability:Dynamic, emitter:VoidEmitter) {
        this.client = client;
        this.emitter = emitter;
        this.legend = LspConversions.toSemanticTokensLegend(capability.legend);
        final full:Dynamic = capability.full;
        this.delta = full != null && JsValues.isObject(full) && LspConversions.asBool(full.delta);
        this.onDidChange = emitter.event;
    }

    /**
     * Whether a server's `semanticTokensProvider` offers the tokens of
     * whole documents (`full: true` or `full: {...}`).
     */
    public static function supportsFull(capability:Dynamic):Bool {
        final full:Dynamic = capability.full;
        return full != null && (JsValues.isBoolean(full) ? (full : Bool) : true);
    }

    /**
     * Tells the editors that the tokens changed.
     */
    public function refresh():Void {
        emitter.fire();
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void):Void {
        client.syncModel(model);
        if (delta && lastResultId != null) {
            client.sendCancellableRequest('textDocument/semanticTokens/full/delta', {
                textDocument: client.textDocumentIdentifier(model),
                previousResultId: lastResultId
            }, token, (result, error) -> {
                resolve(error != null ? null : LspConversions.toSemanticTokensOrEdits(result));
            });
            return;
        }
        client.sendCancellableRequest('textDocument/semanticTokens/full', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toSemanticTokens(result));
        });
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}

}
