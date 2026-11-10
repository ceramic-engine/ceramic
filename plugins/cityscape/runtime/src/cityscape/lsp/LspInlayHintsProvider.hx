// New code for Cityscape (not a port): the inlay hints provider of an LSP
// client (`textDocument/inlayHint`, `inlayHint/resolve`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.InlayHint;
import cityscape.common.Languages.InlayHintList;
import cityscape.common.Languages.InlayHintsProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;

/**
 * Asks the server for the inlay hints of a range
 * (`LspConversions.toInlayHints`). `resolveInlayHint` is set when the
 * server declares `resolveProvider` (it sends the original LSP hint).
 * `onDidChangeInlayHints` fires when the server sends
 * `workspace/inlayHint/refresh`.
 */
class LspInlayHintsProvider implements InlayHintsProvider {

    final client:LspClient;
    final emitter:VoidEmitter;

    public var displayName(default, null):Null<String>;

    public var onDidChangeInlayHints(default, null):Null<VoidEvent>;

    public var resolveInlayHint(default, null):Null<(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void) -> Void>;

    /**
     * `capability`: the server's `inlayHintProvider` (`true` or
     * `{resolveProvider}`).
     */
    public function new(client:LspClient, capability:Dynamic, emitter:VoidEmitter) {
        this.client = client;
        this.emitter = emitter;
        this.displayName = 'lsp';
        this.onDidChangeInlayHints = emitter.event;
        this.resolveInlayHint = null;
        if (capability != null && JsValues.isObject(capability) && LspConversions.asBool(capability.resolveProvider)) {
            this.resolveInlayHint = resolveHint;
        }
    }

    /**
     * Tells the editors that the hints changed.
     */
    public function refresh():Void {
        emitter.fire();
    }

    public function provideInlayHints(model:ITextModel, range:Range, token:CancellationToken, resolve:(hints:Null<InlayHintList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/inlayHint', {
            textDocument: client.textDocumentIdentifier(model),
            range: LspConversions.toLspRange(range)
        }, token, (result, error) -> {
            final hints = error != null ? null : LspConversions.toInlayHints(result);
            resolve(hints == null ? null : {hints: hints});
        });
    }

    function resolveHint(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void):Void {
        final original = LspConversions.originalOf(hint);
        if (original == null) {
            resolve(null);
            return;
        }
        client.sendCancellableRequest('inlayHint/resolve', original, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toInlayHint(result));
        });
    }

}
