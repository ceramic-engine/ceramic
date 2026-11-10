// New code for Cityscape (not a port): the rename provider of an LSP client
// (`textDocument/rename`, `textDocument/prepareRename`).
package cityscape.lsp;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.RenameLocation;
import cityscape.common.Languages.RenameProvider;
import cityscape.common.Languages.WorkspaceEditAndRejection;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;

/**
 * Asks the server to rename a symbol. `resolveRenameLocation` is set when
 * the server declares `prepareProvider`: it sends `prepareRename`
 * (`LspConversions.toRenameLocation`). A failed request rejects the rename
 * with the server's error message, like vscode-languageclient and vscode's
 * extension host.
 */
class LspRenameProvider implements RenameProvider {

    final client:LspClient;

    public var resolveRenameLocation(default, null):Null<(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void>;

    /**
     * `capability`: the server's `renameProvider` (`true` or
     * `{prepareProvider}`).
     */
    public function new(client:LspClient, capability:Dynamic) {
        this.client = client;
        this.resolveRenameLocation = null;
        if (capability != null && JsValues.isObject(capability) && LspConversions.asBool(capability.prepareProvider)) {
            this.resolveRenameLocation = prepare;
        }
    }

    function prepare(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void):Void {
        client.sendCancellableRequest('textDocument/prepareRename', client.textDocumentPosition(model, position), token, (result, error) -> {
            if (token.isCancellationRequested) {
                resolve(null);
                return;
            }
            if (error != null) {
                resolve(LspConversions.rejectedRenameLocation(position, LspConversions.asString(error.message)));
                return;
            }
            resolve(LspConversions.toRenameLocation(result, model, position));
        });
    }

    public function provideRenameEdits(model:ITextModel, position:Position, newName:String, token:CancellationToken, resolve:(edit:Null<WorkspaceEditAndRejection>) -> Void):Void {
        final params:Dynamic = client.textDocumentPosition(model, position);
        params.newName = newName;
        client.sendCancellableRequest('textDocument/rename', params, token, (result, error) -> {
            if (token.isCancellationRequested) {
                resolve(null);
                return;
            }
            if (error != null) {
                final message = LspConversions.asString(error.message);
                resolve({edits: [], rejectReason: message != null && message.length > 0 ? message : "The element can't be renamed."});
                return;
            }
            if (result == null) {
                resolve(null);
                return;
            }
            final edit:WorkspaceEditAndRejection = cast LspConversions.toWorkspaceEdit(result);
            resolve(edit);
        });
    }

}
