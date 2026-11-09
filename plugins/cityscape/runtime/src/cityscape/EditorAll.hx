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
        cityscape.contrib.find.view.FindController.FindRegistration.register(r);
        cityscape.contrib.folding.view.Folding.FoldingRegistration.register(r);
        cityscape.contrib.inPlaceReplace.view.InPlaceReplace.InPlaceReplaceRegistration.register(r);
        cityscape.contrib.indentation.view.Indentation.IndentationRegistration.register(r);
        cityscape.contrib.linesOperations.view.LinesOperations.LinesOperationsRegistration.register(r);
        cityscape.contrib.multicursor.view.Multicursor.MulticursorRegistration.register(r);
        cityscape.contrib.smartSelect.view.SmartSelect.SmartSelectRegistration.register(r);
        cityscape.contrib.stickyScroll.view.StickyScrollActions.StickyScrollRegistration.register(r);
        cityscape.contrib.wordHighlighter.view.WordHighlighter.WordHighlighterRegistration.register(r);
        cityscape.contrib.wordOperations.view.WordOperations.WordOperationsRegistration.register(r);
    }

}
