// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollActions.ts
// and stickyScrollContribution.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.common.EditorContextKeys;
import cityscape.common.config.EditorOptions;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Cityscape has no configuration service: `editor.action.toggleStickyScroll`
 * toggles the `stickyScroll.enabled` option of the focused (or active)
 * editor, and `focusStickyScroll` is enabled when the widget shows lines
 * (Monaco also checks `config.editor.stickyScroll.enabled`, which the
 * visible widget implies).
 */

class ToggleStickyScroll extends Action2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.toggleStickyScroll',
            title: r.localize('toggleEditorStickyScroll', "Toggle Editor Sticky Scroll"),
            metadata: {
                description: r.localize('toggleEditorStickyScroll.description', "Toggle/enable the editor sticky scroll which shows the nested scopes at the top of the viewport"),
            },
            menu: [
                {menuId: 'CommandPalette', group: '', order: 0, title: r.localize('toggleEditorStickyScroll', "Toggle Editor Sticky Scroll")},
                {menuId: 'MenubarAppearanceMenu', group: '4_editor', order: 3, title: r.localize('mitoggleStickyScroll', "&&Toggle Editor Sticky Scroll")},
                {menuId: 'StickyScrollContext', group: '', order: 0, title: r.localize('toggleEditorStickyScroll', "Toggle Editor Sticky Scroll")}
            ]
        });
    }

    public function run(accessor:Null<Cityscape>, args:Array<Any>):Void {
        if (accessor == null) {
            return;
        }
        var editor = accessor.codeEditorService.getFocusedCodeEditor();
        if (editor == null) {
            editor = accessor.codeEditorService.getActiveCodeEditor();
        }
        if (editor == null) {
            return;
        }
        final newValue = !editor.getOption(EditorOption.stickyScroll).enabled;
        editor.updateOptions({stickyScroll: {enabled: newValue}});
    }

}

class FocusStickyScroll extends EditorAction2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.focusStickyScroll',
            title: r.localize('focusStickyScroll', "Focus on the editor sticky scroll"),
            precondition: EditorContextKeys.stickyScrollVisible,
            menu: [
                {menuId: 'CommandPalette', group: '', order: 0, title: r.localize('focusStickyScroll', "Focus on the editor sticky scroll")},
            ]
        });
    }

    public function runEditorCommand(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void {
        final controller = StickyScrollController.get(editor);
        if (controller != null) {
            controller.focus();
        }
    }

}

class SelectNextStickyScrollLine extends EditorAction2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.selectNextStickyScrollLine',
            title: r.localize('selectNextStickyScrollLine.title', "Select the next editor sticky scroll line"),
            precondition: EditorContextKeys.stickyScrollFocused.isEqualTo(true),
            keybinding: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyCode.DownArrow
            }
        });
    }

    public function runEditorCommand(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void {
        final controller = StickyScrollController.get(editor);
        if (controller != null) {
            controller.focusNext();
        }
    }

}

class SelectPreviousStickyScrollLine extends EditorAction2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.selectPreviousStickyScrollLine',
            title: r.localize('selectPreviousStickyScrollLine.title', "Select the previous sticky scroll line"),
            precondition: EditorContextKeys.stickyScrollFocused.isEqualTo(true),
            keybinding: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyCode.UpArrow
            }
        });
    }

    public function runEditorCommand(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void {
        final controller = StickyScrollController.get(editor);
        if (controller != null) {
            controller.focusPrevious();
        }
    }

}

class GoToStickyScrollLine extends EditorAction2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.goToFocusedStickyScrollLine',
            title: r.localize('goToFocusedStickyScrollLine.title', "Go to the focused sticky scroll line"),
            precondition: EditorContextKeys.stickyScrollFocused.isEqualTo(true),
            keybinding: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyCode.Enter
            }
        });
    }

    public function runEditorCommand(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void {
        final controller = StickyScrollController.get(editor);
        if (controller != null) {
            controller.goToFocused();
        }
    }

}

class SelectEditor extends EditorAction2 {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.selectEditor',
            title: r.localize('selectEditor.title', "Select Editor"),
            precondition: EditorContextKeys.stickyScrollFocused.isEqualTo(true),
            keybinding: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyCode.Escape
            }
        });
    }

    public function runEditorCommand(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void {
        final controller = StickyScrollController.get(editor);
        if (controller != null) {
            controller.selectEditor();
        }
    }

}

/**
 * stickyScrollContribution.ts.
 */
class StickyScrollRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(StickyScrollController.ID, editor -> new StickyScrollController(editor), EditorContributionInstantiation.AfterFirstRender);
        r.registerAction2(new ToggleStickyScroll(r));
        r.registerAction2(new FocusStickyScroll(r));
        r.registerAction2(new SelectPreviousStickyScrollLine(r));
        r.registerAction2(new SelectNextStickyScrollLine(r));
        r.registerAction2(new GoToStickyScrollLine(r));
        r.registerAction2(new SelectEditor(r));
    }

}
