// Ported from vscode src/vs/editor/contrib/comment/browser/comment.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.comment.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorContextKeys;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.contrib.comment.view.LineCommentCommand;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

private typedef CommentSelection = {
    final selection:Selection;
    final index:Int;
    var ignoreFirstLine:Bool;
}

/**
 * The language configuration service of an action: the accessor's (the
 * context), or the editor's context when the action runs without one
 * (vscode's tests run actions with a null accessor).
 */
private class CommentUtils {

    public static function languageConfigurationServiceOf(accessor:Null<Cityscape>, editor:ICodeEditor):ILanguageConfigurationService {
        return (accessor != null ? accessor : editor.context).languageConfigurationService;
    }

}

abstract class CommentLineAction extends EditorAction {

    final _type:Type;

    public function new(type:Type, opts:IActionOptions) {
        super(opts);
        this._type = type;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final languageConfigurationService = CommentUtils.languageConfigurationServiceOf(accessor, editor);

        final model = editor.getModel();
        final commands:Array<ICommand> = [];
        final modelOptions = model.getOptions();
        final commentsOptions = editor.getOption(EditorOption.comments);

        final editorSelections = editor.getSelections();
        final selections:Array<CommentSelection> = [for (index in 0...editorSelections.length) {selection: editorSelections[index], index: index, ignoreFirstLine: false}];
        haxe.ds.ArraySort.sort(selections, (a, b) -> Range.compareRangesUsingStarts(a.selection, b.selection));

        // Remove selections that would result in copying the same line
        var prev = selections[0];
        for (i in 1...selections.length) {
            final curr = selections[i];
            if (prev.selection.endLineNumber == curr.selection.startLineNumber) {
                // these two selections would copy the same line
                if (prev.index < curr.index) {
                    // prev wins
                    curr.ignoreFirstLine = true;
                }
                else {
                    // curr wins
                    prev.ignoreFirstLine = true;
                    prev = curr;
                }
            }
        }

        for (selection in selections) {
            commands.push(new LineCommentCommand(
                languageConfigurationService,
                selection.selection,
                modelOptions.indentSize,
                this._type,
                commentsOptions.insertSpace,
                commentsOptions.ignoreEmptyLines,
                selection.ignoreFirstLine
            ));
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class ToggleCommentLineAction extends CommentLineAction {

    public function new(r:EditorExtensionsRegistry) {
        super(Type.Toggle, {
            id: 'editor.action.commentLine',
            label: r.localize('comment.line', "Toggle Line Comment"),
            alias: 'Toggle Line Comment',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Slash,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarEditMenu',
                group: '5_insert',
                title: r.localize('miToggleLineComment', "&&Toggle Line Comment"),
                order: 1
            }
        });
    }

}

class AddLineCommentAction extends CommentLineAction {

    public function new(r:EditorExtensionsRegistry) {
        super(Type.ForceAdd, {
            id: 'editor.action.addCommentLine',
            label: r.localize('comment.line.add', "Add Line Comment"),
            alias: 'Add Line Comment',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyC),
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

}

class RemoveLineCommentAction extends CommentLineAction {

    public function new(r:EditorExtensionsRegistry) {
        super(Type.ForceRemove, {
            id: 'editor.action.removeCommentLine',
            label: r.localize('comment.line.remove', "Remove Line Comment"),
            alias: 'Remove Line Comment',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyU),
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

}

class BlockCommentAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.blockComment',
            label: r.localize('comment.block', "Toggle Block Comment"),
            alias: 'Toggle Block Comment',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.KeyA,
                linux: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyA},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarEditMenu',
                group: '5_insert',
                title: r.localize('miToggleBlockComment', "Toggle &&Block Comment"),
                order: 2
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final languageConfigurationService = CommentUtils.languageConfigurationServiceOf(accessor, editor);

        final commentsOptions = editor.getOption(EditorOption.comments);
        final commands:Array<ICommand> = [];
        final selections = editor.getSelections();
        for (selection in selections) {
            commands.push(new BlockCommentCommand(selection, commentsOptions.insertSpace, languageConfigurationService));
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class CommentRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorAction(new ToggleCommentLineAction(r));
        r.registerEditorAction(new AddLineCommentAction(r));
        r.registerEditorAction(new RemoveLineCommentAction(r));
        r.registerEditorAction(new BlockCommentAction(r));
    }

}
