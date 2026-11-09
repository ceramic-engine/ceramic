// Ported from vscode src/vs/editor/contrib/documentSymbols/browser/documentSymbols.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.documentSymbols.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Promise;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Model.ITextModel;
import cityscape.contrib.documentSymbols.view.OutlineModel.OutlineModelService;

/**
 * documentSymbols.ts: Monaco registers the command
 * `_executeDocumentSymbolProvider` (a resource in, the top level symbols of
 * its outline out). Cityscape has no text model resolver service: the
 * command body is `getDocumentSymbols`, which takes the model itself.
 */
class DocumentSymbols {

    /**
     * The top level symbols of the outline of `model` (with their children),
     * from the cache of `outlineService`.
     */
    public static function getDocumentSymbols(outlineService:OutlineModelService, model:ITextModel, ?token:CancellationToken):Promise<Array<DocumentSymbol>> {
        return outlineService.getOrCreate(model, token != null ? token : CancellationTokens.None).then(outline -> outline.getTopLevelSymbols());
    }

}
