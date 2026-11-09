// New code for Cityscape (not a port): the completion provider of an LSP
// client (`textDocument/completion`, `completionItem/resolve`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItem;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server for completions. `triggerCharacters` are the server's;
 * `resolveCompletionItem` is set when the server declares
 * `resolveProvider`: it sends the original LSP item
 * (`LspConversions.originalOf`) and gives back the fields to add to the
 * item (`LspConversions.toResolvedCompletionFields`).
 */
class LspCompletionProvider implements CompletionItemProvider {

    final client:LspClient;

    public var _debugDisplayName(default, null):Null<String>;

    public var triggerCharacters(default, null):Null<Array<String>>;

    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void>;

    /**
     * `capability`: the server's `completionProvider` (`{triggerCharacters,
     * resolveProvider}`, or `true`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this._debugDisplayName = 'lsp';
        this.triggerCharacters = null;
        this.resolveCompletionItem = null;
        final chars = LspConversions.asArray(JsValues.field(capability, 'triggerCharacters'));
        if (chars != null) {
            this.triggerCharacters = [for (c in chars) Std.string(c)];
        }
        if (LspConversions.asBool(JsValues.field(capability, 'resolveProvider'))) {
            this.resolveCompletionItem = resolveItem;
        }
    }

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/completion', {
            textDocument: client.textDocumentIdentifier(model),
            position: LspConversions.toLspPosition(position),
            context: LspConversions.toLspCompletionContext(context)
        }, token, (result, error) -> {
            if (error != null) {
                resolve(null);
                return;
            }
            resolve(LspConversions.toCompletionList(result));
        });
    }

    function resolveItem(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void):Void {
        final original = LspConversions.originalOf(item);
        if (original == null) {
            resolve(null);
            return;
        }
        client.sendCancellableRequest('completionItem/resolve', original, token, (result, error) -> {
            if (error != null || result == null) {
                resolve(null);
                return;
            }
            resolve(LspConversions.toResolvedCompletionFields(result));
        });
    }

}
