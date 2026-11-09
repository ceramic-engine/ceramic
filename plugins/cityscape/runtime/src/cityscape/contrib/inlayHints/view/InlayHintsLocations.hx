// Ported from vscode src/vs/editor/contrib/inlayHints/browser/inlayHintsLocations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlayHints.view;

import cityscape.base.common.Async;
import cityscape.common.Languages.Location;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkMouseEvent;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * Module functions of inlayHintsLocations.ts. `showGoToContextMenu` (the
 * context menu of a part with a location: the symbol navigation actions and
 * the command of the part) is not ported: there is no context menu service.
 */
class InlayHintsLocations {

    /**
     * Goes to the definition at the location of a label part (Cmd+click on
     * the part): Monaco's `DefinitionAction` run with a
     * `SymbolNavigationAnchor` at the location (in the peek view with
     * `definitionLinkOpensInPeek`). Monaco resolves the model of the
     * location with its text model service; the context's models are used
     * here, and a location in a model the context does not know is opened
     * directly through `codeEditorService.openCodeEditor`.
     */
    public static function goToDefinitionWithLocation(event:ClickLinkMouseEvent, editor:ICodeEditor, location:Location):Void {
        final openToSide = event.hasSideBySideModifier;
        final range = Range.lift(location.range);
        final model = cityscape.contrib.gotoSymbol.view.GoToCommands.SymbolNavigation.findModel(editor.context, location.uri);
        if (model == null) {
            editor.context.codeEditorService.openCodeEditor({
                resource: location.uri,
                options: {selection: Range.collapseToStartStatic(range)}
            }, editor, openToSide);
            return;
        }
        final isInPeek = cityscape.contrib.peekView.view.PeekView.PeekViewEditors.isEmbedded(editor);
        final canPeek = !openToSide && editor.getOption(EditorOption.definitionLinkOpensInPeek) && !isInPeek;
        final action = new cityscape.contrib.gotoSymbol.view.GoToCommands.DefinitionAction(editor.context.editorExtensions, null, {openToSide: openToSide, openInPeek: canPeek, muteMessage: true});
        action.runEditorCommandWith(editor, new cityscape.contrib.gotoSymbol.view.GoToCommands.SymbolNavigationAnchor(model, range.getStartPosition()), range);
    }

}
