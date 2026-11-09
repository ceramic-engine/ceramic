// Ported from vscode src/vs/editor/common/services/languageFeaturesService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;

/**
 * The registries of the language feature providers of a `Cityscape`
 * context (Monaco's `ILanguageFeaturesService`, one per context here).
 *
 * TODO(step 4): the other registries (hover, completion, definition...)
 * come with the contributions that use them.
 */
class LanguageFeaturesService {

    public final foldingRangeProvider:LanguageFeatureRegistry<FoldingRangeProvider> = new LanguageFeatureRegistry<FoldingRangeProvider>();

    /**
     * Chooses the folding range providers of a model among the registered
     * ones (Monaco's global `FoldingController.setFoldingRangeProviderSelector`,
     * per context here). Null: all of them.
     */
    public var foldingRangeSelector:Null<(providers:Array<FoldingRangeProvider>, document:ITextModel) -> Null<Array<FoldingRangeProvider>>> = null;

    /**
     * The document highlight providers (contrib/wordHighlighter, Monaco's
     * `documentHighlightProvider`).
     */
    public final documentHighlightProvider:LanguageFeatureRegistry<cityscape.common.Languages.DocumentHighlightProvider> = new LanguageFeatureRegistry<cityscape.common.Languages.DocumentHighlightProvider>();

    /**
     * The multi document highlight providers (Monaco's
     * `multiDocumentHighlightProvider`).
     */
    public final multiDocumentHighlightProvider:LanguageFeatureRegistry<cityscape.common.Languages.MultiDocumentHighlightProvider> = new LanguageFeatureRegistry<cityscape.common.Languages.MultiDocumentHighlightProvider>();

    /**
     * The document symbol providers (Monaco's `documentSymbolProvider`:
     * the outline model of the sticky scroll).
     */
    public final documentSymbolProvider:LanguageFeatureRegistry<cityscape.common.Languages.DocumentSymbolProvider> = new LanguageFeatureRegistry<cityscape.common.Languages.DocumentSymbolProvider>();

    public function new() {}

    // Smart select (cs4-edit): Monaco's `selectionRangeProvider` registry.

    public final selectionRangeProvider:LanguageFeatureRegistry<SelectionRangeProvider> = new LanguageFeatureRegistry<SelectionRangeProvider>();

}
