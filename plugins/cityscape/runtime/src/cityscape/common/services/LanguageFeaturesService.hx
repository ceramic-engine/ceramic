// Ported from vscode src/vs/editor/common/services/languageFeaturesService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;

/**
 * The registries of the language feature providers of a `Cityscape`
 * context (Monaco's `ILanguageFeaturesService`, one per context here).
 *
 * The registries Monaco has for features Cityscape does not port
 * (notebooks, inline values, evaluatable expressions, paste and drop
 * edits, mapped edits, inline edits, multi document highlights, linked
 * editing, new symbol names, selection ranges, on type formatting, inline
 * completions) are not here yet.
 */
class LanguageFeaturesService {

    public final referenceProvider:LanguageFeatureRegistry<ReferenceProvider> = new LanguageFeatureRegistry<ReferenceProvider>();
    public final renameProvider:LanguageFeatureRegistry<RenameProvider> = new LanguageFeatureRegistry<RenameProvider>();
    public final codeActionProvider:LanguageFeatureRegistry<CodeActionProvider> = new LanguageFeatureRegistry<CodeActionProvider>();
    public final definitionProvider:LanguageFeatureRegistry<DefinitionProvider> = new LanguageFeatureRegistry<DefinitionProvider>();
    public final typeDefinitionProvider:LanguageFeatureRegistry<TypeDefinitionProvider> = new LanguageFeatureRegistry<TypeDefinitionProvider>();
    public final declarationProvider:LanguageFeatureRegistry<DeclarationProvider> = new LanguageFeatureRegistry<DeclarationProvider>();
    public final implementationProvider:LanguageFeatureRegistry<ImplementationProvider> = new LanguageFeatureRegistry<ImplementationProvider>();
    public final codeLensProvider:LanguageFeatureRegistry<CodeLensProvider> = new LanguageFeatureRegistry<CodeLensProvider>();
    public final foldingRangeProvider:LanguageFeatureRegistry<FoldingRangeProvider> = new LanguageFeatureRegistry<FoldingRangeProvider>();
    public final linkProvider:LanguageFeatureRegistry<LinkProvider> = new LanguageFeatureRegistry<LinkProvider>();
    public final colorProvider:LanguageFeatureRegistry<DocumentColorProvider> = new LanguageFeatureRegistry<DocumentColorProvider>();
    public final signatureHelpProvider:LanguageFeatureRegistry<SignatureHelpProvider> = new LanguageFeatureRegistry<SignatureHelpProvider>();
    public final hoverProvider:LanguageFeatureRegistry<HoverProvider> = new LanguageFeatureRegistry<HoverProvider>();
    public final documentRangeSemanticTokensProvider:LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider> = new LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider>();
    public final documentSemanticTokensProvider:LanguageFeatureRegistry<DocumentSemanticTokensProvider> = new LanguageFeatureRegistry<DocumentSemanticTokensProvider>();
    public final documentFormattingEditProvider:LanguageFeatureRegistry<DocumentFormattingEditProvider> = new LanguageFeatureRegistry<DocumentFormattingEditProvider>();
    public final documentRangeFormattingEditProvider:LanguageFeatureRegistry<DocumentRangeFormattingEditProvider> = new LanguageFeatureRegistry<DocumentRangeFormattingEditProvider>();
    public final completionProvider:LanguageFeatureRegistry<CompletionItemProvider> = new LanguageFeatureRegistry<CompletionItemProvider>();
    public final inlayHintsProvider:LanguageFeatureRegistry<InlayHintsProvider> = new LanguageFeatureRegistry<InlayHintsProvider>();

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
