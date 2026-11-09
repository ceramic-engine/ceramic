// Ported from vscode src/vs/editor/contrib/clipboard/browser/clipboard.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.clipboard.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.common.EditorContextKeys;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorExtensions;

/**
 * The clipboard commands. Monaco binds their keys only in native builds
 * (Electron: a browser handles them itself); Cityscape draws the text
 * itself on every target, so the keybindings are always registered, and the
 * command runs the editor's clipboard action (Monaco's
 * `document.execCommand('cut')` and the textarea handlers) through
 * `ICodeEditor._executeClipboardAction`.
 */
class ClipboardRegistration {

    static inline final CLIPBOARD_CONTEXT_MENU_GROUP = '9_cutcopypaste';

    static function registerExecCommandImpl(target:Null<MultiCommand>, browserCommand:String):Void {
        if (target == null) {
            return;
        }

        // 1. handle case when focus is in editor.
        target.addImplementation(10000, 'code-editor', (accessor:Null<Cityscape>, args:Any) -> {
            // Only if editor text focus (i.e. not if editor has widget focus).
            final focusedEditor = accessor != null ? accessor.codeEditorService.getFocusedCodeEditor() : null;
            if (focusedEditor != null && focusedEditor.hasTextFocus()) {
                // Do not execute if there is no selection and empty selection clipboard is off
                final emptySelectionClipboard = focusedEditor.getOption(EditorOption.emptySelectionClipboard);
                final selection = focusedEditor.getSelection();
                if (selection != null && selection.isEmpty() && !emptySelectionClipboard) {
                    return true;
                }
                focusedEditor._executeClipboardAction(browserCommand);
                return true;
            }
            return false;
        });
    }

    public static function register(r:EditorExtensionsRegistry):Void {
        final cutAction = r.registerCommand(new MultiCommand({
            id: 'editor.action.clipboardCutAction',
            precondition: null,
            kbOpts: {
                primary: KeyMod.CtrlCmd | KeyCode.KeyX,
                win: {primary: KeyMod.CtrlCmd | KeyCode.KeyX, secondary: [KeyMod.Shift | KeyCode.Delete]},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: [{
                menuId: 'MenubarEditMenu',
                group: '2_ccp',
                title: r.localize('miCut', "Cu&&t"),
                order: 1
            }, {
                menuId: 'EditorContext',
                group: CLIPBOARD_CONTEXT_MENU_GROUP,
                title: r.localize('actions.clipboard.cutLabel', "Cut"),
                when: EditorContextKeys.writable,
                order: 1,
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: r.localize('actions.clipboard.cutLabel', "Cut"),
                order: 1
            }]
        }));

        final copyAction = r.registerCommand(new MultiCommand({
            id: 'editor.action.clipboardCopyAction',
            precondition: null,
            kbOpts: {
                primary: KeyMod.CtrlCmd | KeyCode.KeyC,
                win: {primary: KeyMod.CtrlCmd | KeyCode.KeyC, secondary: [KeyMod.CtrlCmd | KeyCode.Insert]},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: [{
                menuId: 'MenubarEditMenu',
                group: '2_ccp',
                title: r.localize('miCopy', "&&Copy"),
                order: 2
            }, {
                menuId: 'EditorContext',
                group: CLIPBOARD_CONTEXT_MENU_GROUP,
                title: r.localize('actions.clipboard.copyLabel', "Copy"),
                order: 2,
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: r.localize('actions.clipboard.copyLabel', "Copy"),
                order: 1
            }]
        }));

        final pasteAction = r.registerCommand(new MultiCommand({
            id: 'editor.action.clipboardPasteAction',
            precondition: null,
            kbOpts: {
                primary: KeyMod.CtrlCmd | KeyCode.KeyV,
                win: {primary: KeyMod.CtrlCmd | KeyCode.KeyV, secondary: [KeyMod.Shift | KeyCode.Insert]},
                linux: {primary: KeyMod.CtrlCmd | KeyCode.KeyV, secondary: [KeyMod.Shift | KeyCode.Insert]},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: [{
                menuId: 'MenubarEditMenu',
                group: '2_ccp',
                title: r.localize('miPaste', "&&Paste"),
                order: 4
            }, {
                menuId: 'EditorContext',
                group: CLIPBOARD_CONTEXT_MENU_GROUP,
                title: r.localize('actions.clipboard.pasteLabel', "Paste"),
                when: EditorContextKeys.writable,
                order: 4,
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: r.localize('actions.clipboard.pasteLabel', "Paste"),
                order: 1
            }]
        }));

        registerExecCommandImpl(cutAction, 'cut');
        registerExecCommandImpl(copyAction, 'copy');

        // 1. Paste: handle case when focus is in editor.
        pasteAction.addImplementation(10000, 'code-editor', (accessor:Null<Cityscape>, args:Any) -> {
            // Only if editor text focus (i.e. not if editor has widget focus).
            final focusedEditor = accessor != null ? accessor.codeEditorService.getFocusedCodeEditor() : null;
            if (focusedEditor != null && focusedEditor.hasTextFocus()) {
                focusedEditor._executeClipboardAction('paste');
                return true;
            }
            return false;
        });
    }

}
