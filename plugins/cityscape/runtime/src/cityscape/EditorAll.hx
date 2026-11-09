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
        cityscape.contrib.clipboard.view.Clipboard.ClipboardRegistration.register(r);
        cityscape.contrib.find.view.FindController.FindRegistration.register(r);
        cityscape.contrib.folding.view.Folding.FoldingRegistration.register(r);
        cityscape.contrib.linesOperations.view.LinesOperations.LinesOperationsRegistration.register(r);
        cityscape.contrib.wordOperations.view.WordOperations.WordOperationsRegistration.register(r);
    }

}
