// New code for Cityscape (not a port): the code action provider of an LSP
// client (`textDocument/codeAction`, `codeAction/resolve`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.CodeAction;
import cityscape.common.Languages.CodeActionContext;
import cityscape.common.Languages.CodeActionList;
import cityscape.common.Languages.CodeActionProvider;
import cityscape.common.Languages.CodeActionProviderDocumentation;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;

/**
 * Asks the server for code actions. The request's `context.diagnostics`
 * are the original LSP diagnostics of the markers of the context
 * (`LspClient.findDiagnostics`: the provider is registered with
 * `Cityscape.registerCodeActionProvider`, which gives it the markers
 * touching the range). `providedCodeActionKinds` are the server's
 * `codeActionKinds`; `resolveCodeAction` is set when the server declares
 * `resolveProvider` (it sends the original LSP action).
 */
class LspCodeActionProvider implements CodeActionProvider {

    final client:LspClient;

    public var displayName(default, null):Null<String>;

    public var resolveCodeAction(default, null):Null<(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void) -> Void>;

    public var providedCodeActionKinds(default, null):Null<Array<String>>;

    public var documentation(default, null):Null<Array<CodeActionProviderDocumentation>>;

    /**
     * `capability`: the server's `codeActionProvider` (`{codeActionKinds,
     * resolveProvider}`, or `true`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.displayName = 'lsp';
        this.resolveCodeAction = null;
        this.providedCodeActionKinds = null;
        this.documentation = null;
        if (capability != null && JsValues.isObject(capability)) {
            final kinds = LspConversions.asArray(capability.codeActionKinds);
            if (kinds != null) {
                this.providedCodeActionKinds = [for (k in kinds) Std.string(k)];
            }
            if (LspConversions.asBool(capability.resolveProvider)) {
                this.resolveCodeAction = resolveAction;
            }
        }
    }

    public function provideCodeActions(model:ITextModel, range:Range, context:CodeActionContext, token:CancellationToken, resolve:(list:Null<CodeActionList>) -> Void):Void {
        client.syncModel(model);
        final lspContext:Dynamic = {
            diagnostics: client.findDiagnostics(model, context.markers, range),
            triggerKind: LspConversions.toLspCodeActionTriggerKind(context.trigger)
        };
        if (context.only != null) {
            lspContext.only = [context.only];
        }
        client.sendCancellableRequest('textDocument/codeAction', {
            textDocument: client.textDocumentIdentifier(model),
            range: LspConversions.toLspRange(range),
            context: lspContext
        }, token, (result, error) -> {
            if (error != null) {
                resolve(null);
                return;
            }
            final list = LspConversions.asArray(result);
            final actions:Array<CodeAction> = list == null ? [] : [for (action in list) LspConversions.toCodeAction(action)];
            resolve({actions: actions, dispose: () -> {}});
        });
    }

    function resolveAction(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void):Void {
        final original = LspConversions.originalOf(codeAction);
        if (original == null || JsValues.isString(original.command)) {
            // not from the server, or a bare command (nothing to resolve)
            resolve(null);
            return;
        }
        client.sendCancellableRequest('codeAction/resolve', original, token, (result, error) -> {
            resolve(error != null || result == null ? null : LspConversions.toCodeAction(result));
        });
    }

}
