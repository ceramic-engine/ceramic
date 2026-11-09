// New code for Cityscape (not a port): the signature help provider of an
// LSP client (`textDocument/signatureHelp`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.SignatureHelpContext;
import cityscape.common.Languages.SignatureHelpProvider;
import cityscape.common.Languages.SignatureHelpResult;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for signature help. The trigger and retrigger characters
 * are the server's.
 */
class LspSignatureHelpProvider implements SignatureHelpProvider {

    final client:LspClient;

    public var signatureHelpTriggerCharacters(default, null):Null<Array<String>>;

    public var signatureHelpRetriggerCharacters(default, null):Null<Array<String>>;

    /**
     * `capability`: the server's `signatureHelpProvider`
     * (`{triggerCharacters, retriggerCharacters}`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.signatureHelpTriggerCharacters = null;
        this.signatureHelpRetriggerCharacters = null;
        if (JsValues.isObject(capability)) {
            final trigger = LspConversions.asArray(capability.triggerCharacters);
            if (trigger != null) {
                this.signatureHelpTriggerCharacters = [for (c in trigger) Std.string(c)];
            }
            final retrigger = LspConversions.asArray(capability.retriggerCharacters);
            if (retrigger != null) {
                this.signatureHelpRetriggerCharacters = [for (c in retrigger) Std.string(c)];
            }
        }
    }

    public function provideSignatureHelp(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/signatureHelp', {
            textDocument: client.textDocumentIdentifier(model),
            position: LspConversions.toLspPosition(position),
            context: LspConversions.toLspSignatureHelpContext(context)
        }, token, (result, error) -> {
            final help = error != null ? null : LspConversions.toSignatureHelp(result);
            resolve(help == null ? null : {value: help, dispose: () -> {}});
        });
    }

}
