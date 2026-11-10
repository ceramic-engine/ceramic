// New code for Cityscape (not a port): the on type formatting provider of
// an LSP client (`textDocument/onTypeFormatting`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.FormattingOptions;
import cityscape.common.Languages.OnTypeFormattingEditProvider;
import cityscape.common.Languages.TextEdit;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server to format after a trigger character was typed. The
 * trigger characters are the server's `firstTriggerCharacter` and
 * `moreTriggerCharacter`.
 */
class LspOnTypeFormattingProvider implements OnTypeFormattingEditProvider {

    final client:LspClient;

    public var autoFormatTriggerCharacters(default, null):Array<String>;

    /**
     * `capability`: the server's `documentOnTypeFormattingProvider`
     * (`{firstTriggerCharacter, moreTriggerCharacter}`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.autoFormatTriggerCharacters = [];
        final first = LspConversions.asString(capability.firstTriggerCharacter);
        if (first != null) {
            this.autoFormatTriggerCharacters.push(first);
        }
        final more = LspConversions.asArray(capability.moreTriggerCharacter);
        if (more != null) {
            for (c in more) {
                this.autoFormatTriggerCharacters.push(Std.string(c));
            }
        }
    }

    public function provideOnTypeFormattingEdits(model:ITextModel, position:Position, ch:String, options:FormattingOptions, token:CancellationToken, resolve:(edits:Null<Array<TextEdit>>) -> Void):Void {
        final params:Dynamic = client.textDocumentPosition(model, position);
        params.ch = ch;
        params.options = LspConversions.toLspFormattingOptions(options);
        client.sendCancellableRequest('textDocument/onTypeFormatting', params, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toTextEdits(result));
        });
    }

}
