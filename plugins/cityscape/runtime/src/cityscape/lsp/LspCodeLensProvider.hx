// New code for Cityscape (not a port): the code lens provider of an LSP
// client (`textDocument/codeLens`, `codeLens/resolve`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeLensList;
import cityscape.common.Languages.CodeLensProvider;
import cityscape.common.Model.ITextModel;

/**
 * Asks the server for the code lenses of a document
 * (`LspConversions.toCodeLenses`; the arguments of the well known VS Code
 * commands are converted, see `LspConversions.toCommandArguments`).
 * `resolveCodeLens` is set when the server declares `resolveProvider` (it
 * sends the original LSP lens). `onDidChange` fires when the server sends
 * `workspace/codeLens/refresh`.
 */
class LspCodeLensProvider implements CodeLensProvider {

    final client:LspClient;
    final emitter:Emitter<CodeLensProvider>;

    public var onDidChange(default, null):Null<Event<CodeLensProvider>>;

    public var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void>;

    /**
     * `capability`: the server's `codeLensProvider` (`{resolveProvider}`).
     */
    public function new(client:LspClient, capability:Dynamic, emitter:Emitter<CodeLensProvider>) {
        this.client = client;
        this.emitter = emitter;
        this.onDidChange = emitter.event;
        this.resolveCodeLens = null;
        if (capability != null && JsValues.isObject(capability) && LspConversions.asBool(capability.resolveProvider)) {
            this.resolveCodeLens = resolveLens;
        }
    }

    /**
     * Tells the editors that the lenses changed.
     */
    public function refresh():Void {
        emitter.fire(this);
    }

    public function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/codeLens', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            final lenses = error != null ? null : LspConversions.toCodeLenses(result);
            resolve(lenses == null ? null : {lenses: lenses});
        });
    }

    function resolveLens(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void):Void {
        final original = LspConversions.originalOf(codeLens);
        if (original == null) {
            resolve(null);
            return;
        }
        client.sendCancellableRequest('codeLens/resolve', original, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toCodeLens(result));
        });
    }

}
