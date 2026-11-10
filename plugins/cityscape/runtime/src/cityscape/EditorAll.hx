// Ported from vscode src/vs/editor/editor.all.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape;

import cityscape.view.EditorExtensions.EditorExtensionsRegistry;

/**
 * The editor contributions (Monaco's editor.all.ts, which imports every
 * contribution so that its module registers it): each line registers the
 * commands, actions, keybindings and contributions of one module in the
 * registry of a context. A new contribution adds its line here.
 */
class EditorAll {

    public static function registerAll(r:EditorExtensionsRegistry):Void {
        cityscape.view.CoreCommands.CoreCommandsRegistration.register(r);
        cityscape.contrib.bracketMatching.view.BracketMatching.BracketMatchingRegistration.register(r);
        cityscape.contrib.caretOperations.view.CaretOperations.CaretOperationsRegistration.register(r);
        cityscape.contrib.clipboard.view.Clipboard.ClipboardRegistration.register(r);
        cityscape.contrib.comment.view.Comment.CommentRegistration.register(r);
        cityscape.contrib.cursorUndo.view.CursorUndo.CursorUndoRegistration.register(r);
        cityscape.contrib.dnd.view.Dnd.DndRegistration.register(r);
        cityscape.contrib.find.view.FindController.FindRegistration.register(r);
        cityscape.contrib.folding.view.Folding.FoldingRegistration.register(r);
        cityscape.contrib.inPlaceReplace.view.InPlaceReplace.InPlaceReplaceRegistration.register(r);
        cityscape.contrib.indentation.view.Indentation.IndentationRegistration.register(r);
        cityscape.contrib.linesOperations.view.LinesOperations.LinesOperationsRegistration.register(r);
        cityscape.contrib.multicursor.view.Multicursor.MulticursorRegistration.register(r);
        cityscape.contrib.smartSelect.view.SmartSelect.SmartSelectRegistration.register(r);
        cityscape.contrib.stickyScroll.view.StickyScrollActions.StickyScrollRegistration.register(r);
        cityscape.contrib.wordHighlighter.view.WordHighlighter.WordHighlighterRegistration.register(r);
        cityscape.contrib.snippet.view.SnippetController2.SnippetRegistration.register(r);
        cityscape.contrib.suggest.view.SuggestController.SuggestRegistration.register(r);
        cityscape.contrib.hover.view.ContentHoverController.HoverRegistration.register(r);
        cityscape.contrib.codeAction.view.CodeActionController.CodeActionRegistration.register(r);
        cityscape.contrib.gotoError.view.GotoError.GotoErrorRegistration.register(r);
        cityscape.contrib.gotoSymbol.view.GoToCommands.GoToSymbolRegistration.register(r);
        cityscape.contrib.wordOperations.view.WordOperations.WordOperationsRegistration.register(r);
        // Links and colors (step 7, cs7-rest-links)
        cityscape.contrib.links.view.Links.LinksRegistration.register(r);
        cityscape.contrib.colorPicker.view.ColorContributions.ColorPickerRegistration.register(r);
        // Inlay hints and code lens (step 7, cs7-rest-inlay)
        cityscape.contrib.inlayHints.view.InlayHintsController.InlayHintsRegistration.register(r);
        cityscape.contrib.codelens.view.CodeLensController.CodeLensRegistration.register(r);
        // Parameter hints (step 7, cs7-rest-snip)
        cityscape.contrib.parameterHints.view.ParameterHints.ParameterHintsRegistration.register(r);
        // Inline completions (step 7, cs7-rest-inline)
        cityscape.contrib.inlineCompletions.view.controller.Commands.InlineCompletionsRegistration.register(r);
        // Semantic tokens and rename (step 7, cs7-rest-sem)
        cityscape.contrib.semanticTokens.view.ViewportSemanticTokens.ViewportSemanticTokensContribution.register(r);
        cityscape.contrib.rename.view.Rename.RenameRegistration.register(r);
    }

}
