// New code for Cityscape (not a port): the range semantic tokens provider of
// an LSP client (`textDocument/semanticTokens/range`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.DocumentRangeSemanticTokensProvider;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensLegend;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;

/**
 * Asks the server for the semantic tokens of a range, when its
 * `semanticTokensProvider` declares `range` (`true`, or an object).
 */
class LspDocumentRangeSemanticTokensProvider implements DocumentRangeSemanticTokensProvider {

    final client:LspClient;
    final legend:SemanticTokensLegend;

    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.legend = LspConversions.toSemanticTokensLegend(capability.legend);
    }

    /**
     * Whether a server's `semanticTokensProvider` offers the tokens of
     * ranges.
     */
    public static function supportsRange(capability:Dynamic):Bool {
        final range:Dynamic = capability.range;
        return range != null && (JsValues.isBoolean(range) ? (range : Bool) : true);
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentRangeSemanticTokens(model:ITextModel, range:Range, token:CancellationToken, resolve:(result:Null<SemanticTokens>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/semanticTokens/range', {
            textDocument: client.textDocumentIdentifier(model),
            range: LspConversions.toLspRange(range)
        }, token, (result, error) -> {
            resolve(error != null ? null : LspConversions.toSemanticTokens(result));
        });
    }

}
