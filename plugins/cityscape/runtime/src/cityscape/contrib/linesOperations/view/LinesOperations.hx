// Ported from vscode src/vs/editor/contrib/linesOperations/browser/linesOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.linesOperations.view;

import cityscape.Cityscape;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.RegExp;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorContextKeys;
import cityscape.common.Model.IIdentifiedSingleEditOperation;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.commands.TrimTrailingWhitespaceCommand;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorTypeEditOperations.EnterOperation;
import cityscape.common.cursor.CursorTypeOperations;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.CoreCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * The action constructors take the registry of the context for `localize`;
 * without one (vscode's tests create the actions with `new X()`), the
 * labels are Monaco's English texts.
 */

private class Nls {

    public static inline function localize(r:Null<EditorExtensionsRegistry>, key:String, defaultMessage:String):String {
        return r != null ? r.localize(key, defaultMessage) : defaultMessage;
    }

}

private typedef CopyLinesSelection = {
    final selection:Selection;
    final index:Int;
    var ignore:Bool;
}

// copy lines

abstract class AbstractCopyLinesAction extends EditorAction {

    final down:Bool;

    public function new(down:Bool, opts:IActionOptions) {
        super(opts);
        this.down = down;
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final editorSelections = editor.getSelections();
        final selections:Array<CopyLinesSelection> = [for (index in 0...editorSelections.length) {selection: editorSelections[index], index: index, ignore: false}];
        haxe.ds.ArraySort.sort(selections, (a, b) -> Range.compareRangesUsingStarts(a.selection, b.selection));

        // Remove selections that would result in copying the same line
        var prev = selections[0];
        for (i in 1...selections.length) {
            final curr = selections[i];
            if (prev.selection.endLineNumber == curr.selection.startLineNumber) {
                // these two selections would copy the same line
                if (prev.index < curr.index) {
                    // prev wins
                    curr.ignore = true;
                }
                else {
                    // curr wins
                    prev.ignore = true;
                    prev = curr;
                }
            }
        }

        final commands:Array<Null<ICommand>> = [];
        for (selection in selections) {
            commands.push(new CopyLinesCommand(selection.selection, this.down, selection.ignore));
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class CopyLinesUpAction extends AbstractCopyLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.copyLinesUpAction',
            label: Nls.localize(r, 'lines.copyUp', "Copy Line Up"),
            alias: 'Copy Line Up',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Alt | KeyMod.Shift | KeyCode.UpArrow,
                linux: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyMod.Shift | KeyCode.UpArrow},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '2_line',
                title: Nls.localize(r, 'miCopyLinesUp', "&&Copy Line Up"),
                order: 1
            }
        });
    }

}

class CopyLinesDownAction extends AbstractCopyLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.copyLinesDownAction',
            label: Nls.localize(r, 'lines.copyDown', "Copy Line Down"),
            alias: 'Copy Line Down',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Alt | KeyMod.Shift | KeyCode.DownArrow,
                linux: {primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyMod.Shift | KeyCode.DownArrow},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '2_line',
                title: Nls.localize(r, 'miCopyLinesDown', "Co&&py Line Down"),
                order: 2
            }
        });
    }

}

class DuplicateSelectionAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.duplicateSelection',
            label: Nls.localize(r, 'duplicateSelection', "Duplicate Selection"),
            alias: 'Duplicate Selection',
            precondition: EditorContextKeys.writable,
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '2_line',
                title: Nls.localize(r, 'miDuplicateSelection', "&&Duplicate Selection"),
                order: 5
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final commands:Array<Null<ICommand>> = [];
        final selections = editor.getSelections();
        final model = editor.getModel();

        for (selection in selections) {
            if (selection.isEmpty()) {
                commands.push(new CopyLinesCommand(selection, true));
            }
            else {
                final insertSelection = new Selection(selection.endLineNumber, selection.endColumn, selection.endLineNumber, selection.endColumn);
                commands.push(new ReplaceCommandThatSelectsText(insertSelection, model.getValueInRange(selection)));
            }
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

// move lines

abstract class AbstractMoveLinesAction extends EditorAction {

    final down:Bool;

    public function new(down:Bool, opts:IActionOptions) {
        super(opts);
        this.down = down;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final languageConfigurationService = (accessor != null ? accessor : editor.context).languageConfigurationService;

        final commands:Array<Null<ICommand>> = [];
        final editorSelections = editor.getSelections();
        final selections = editorSelections != null ? editorSelections : [];
        final autoIndent = editor.getOption(EditorOption.autoIndent);

        for (selection in selections) {
            commands.push(new MoveLinesCommand(selection, this.down, autoIndent, languageConfigurationService));
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class MoveLinesUpAction extends AbstractMoveLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.moveLinesUpAction',
            label: Nls.localize(r, 'lines.moveUp', "Move Line Up"),
            alias: 'Move Line Up',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Alt | KeyCode.UpArrow,
                linux: {primary: KeyMod.Alt | KeyCode.UpArrow},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '2_line',
                title: Nls.localize(r, 'miMoveLinesUp', "Mo&&ve Line Up"),
                order: 3
            }
        });
    }

}

class MoveLinesDownAction extends AbstractMoveLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.moveLinesDownAction',
            label: Nls.localize(r, 'lines.moveDown', "Move Line Down"),
            alias: 'Move Line Down',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Alt | KeyCode.DownArrow,
                linux: {primary: KeyMod.Alt | KeyCode.DownArrow},
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '2_line',
                title: Nls.localize(r, 'miMoveLinesDown', "Move &&Line Down"),
                order: 4
            }
        });
    }

}

abstract class AbstractSortLinesAction extends EditorAction {

    final descending:Bool;

    public function new(descending:Bool, opts:IActionOptions) {
        super(opts);
        this.descending = descending;
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final model = editor.getModel();
        var selections = editor.getSelections();
        if (selections.length == 1 && selections[0].isEmpty()) {
            // Apply to whole document.
            selections = [new Selection(1, 1, model.getLineCount(), model.getLineMaxColumn(model.getLineCount()))];
        }

        for (selection in selections) {
            if (!SortLinesCommand.canRun(editor.getModel(), selection, this.descending)) {
                return;
            }
        }

        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            commands[i] = new SortLinesCommand(selections[i], this.descending);
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

class SortLinesAscendingAction extends AbstractSortLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.sortLinesAscending',
            label: Nls.localize(r, 'lines.sortAscending', "Sort Lines Ascending"),
            alias: 'Sort Lines Ascending',
            precondition: EditorContextKeys.writable
        });
    }

}

class SortLinesDescendingAction extends AbstractSortLinesAction {

    public function new(?r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.sortLinesDescending',
            label: Nls.localize(r, 'lines.sortDescending', "Sort Lines Descending"),
            alias: 'Sort Lines Descending',
            precondition: EditorContextKeys.writable
        });
    }

}

class DeleteDuplicateLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.removeDuplicateLines',
            label: Nls.localize(r, 'lines.deleteDuplicates', "Delete Duplicate Lines"),
            alias: 'Delete Duplicate Lines',
            precondition: EditorContextKeys.writable
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final model:ITextModel = editor.getModel();
        if (model.getLineCount() == 1 && model.getLineMaxColumn(1) == 1) {
            return;
        }

        final edits:Array<IIdentifiedSingleEditOperation> = [];
        final endCursorState:Array<Selection> = [];

        var linesDeleted = 0;
        var updateSelection = true;

        var selections = editor.getSelections();
        if (selections.length == 1 && selections[0].isEmpty()) {
            // Apply to whole document.
            selections = [new Selection(1, 1, model.getLineCount(), model.getLineMaxColumn(model.getLineCount()))];
            updateSelection = false;
        }

        for (selection in selections) {
            final uniqueLines = new Map<String, Bool>();
            final lines:Array<String> = [];

            for (i in selection.startLineNumber...selection.endLineNumber + 1) {
                final line = model.getLineContent(i);

                if (uniqueLines.exists(line)) {
                    continue;
                }

                lines.push(line);
                uniqueLines.set(line, true);
            }

            final selectionToReplace = new Selection(
                selection.startLineNumber,
                1,
                selection.endLineNumber,
                model.getLineMaxColumn(selection.endLineNumber)
            );

            final adjustedSelectionStart = selection.startLineNumber - linesDeleted;
            final finalSelection = new Selection(
                adjustedSelectionStart,
                1,
                adjustedSelectionStart + lines.length - 1,
                lines[lines.length - 1].length
            );

            edits.push(EditOperation.replace(selectionToReplace, lines.join('\n')));
            endCursorState.push(finalSelection);

            linesDeleted += (selection.endLineNumber - selection.startLineNumber + 1) - lines.length;
        }

        editor.pushUndoStop();
        editor.executeEdits(this.id, edits, updateSelection ? endCursorState : null);
        editor.pushUndoStop();
    }

}

/**
 * Monaco reads `files.trimTrailingWhitespaceInRegexAndStrings` from its
 * configuration service; Cityscape has none and uses the setting's default
 * (true, see DEVIATIONS.md).
 */
class TrimTrailingWhitespaceAction extends EditorAction {

    public static inline final ID = 'editor.action.trimTrailingWhitespace';

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: TrimTrailingWhitespaceAction.ID,
            label: Nls.localize(r, 'lines.trimTrailingWhitespace', "Trim Trailing Whitespace"),
            alias: 'Trim Trailing Whitespace',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyX),
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {

        var cursors:Array<Position> = [];
        final reason:Any = JsValues.isObject(args) ? JsValues.field(args, 'reason') : null;
        if (JsValues.isString(reason) && (reason : String) == 'auto-save') {
            // See https://github.com/editorconfig/editorconfig-vscode/issues/47
            // It is very convenient for the editor config extension to invoke this action.
            // So, if we get a reason:'auto-save' passed in, let's preserve cursor positions.
            final selections = editor.getSelections();
            cursors = [for (s in (selections != null ? selections : [])) new Position(s.positionLineNumber, s.positionColumn)];
        }

        final selection = editor.getSelection();
        if (selection == null) {
            return;
        }

        final trimInRegexAndStrings = true;

        final command = new TrimTrailingWhitespaceCommand(selection, cursors, trimInRegexAndStrings);

        editor.pushUndoStop();
        editor.executeCommands(this.id, [command]);
        editor.pushUndoStop();
    }

}

// delete lines

private typedef IDeleteLinesOperation = {
    var startLineNumber:Int;
    var selectionStartColumn:Int;
    var endLineNumber:Int;
    var positionColumn:Int;
}

class DeleteLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.deleteLines',
            label: Nls.localize(r, 'lines.delete', "Delete Line"),
            alias: 'Delete Line',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyK,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }

        final ops = this._getLinesToRemove(editor);

        final model:ITextModel = editor.getModel();
        if (model.getLineCount() == 1 && model.getLineMaxColumn(1) == 1) {
            // Model is empty
            return;
        }

        var linesDeleted = 0;
        final edits:Array<IIdentifiedSingleEditOperation> = [];
        final cursorState:Array<Selection> = [];
        for (i in 0...ops.length) {
            final op = ops[i];

            var startLineNumber = op.startLineNumber;
            var endLineNumber = op.endLineNumber;

            var startColumn = 1;
            var endColumn = model.getLineMaxColumn(endLineNumber);
            if (endLineNumber < model.getLineCount()) {
                endLineNumber += 1;
                endColumn = 1;
            }
            else if (startLineNumber > 1) {
                startLineNumber -= 1;
                startColumn = model.getLineMaxColumn(startLineNumber);
            }

            edits.push(EditOperation.replace(new Selection(startLineNumber, startColumn, endLineNumber, endColumn), ''));
            cursorState.push(new Selection(startLineNumber - linesDeleted, op.positionColumn, startLineNumber - linesDeleted, op.positionColumn));
            linesDeleted += (op.endLineNumber - op.startLineNumber + 1);
        }

        editor.pushUndoStop();
        editor.executeEdits(this.id, edits, cursorState);
        editor.pushUndoStop();
    }

    function _getLinesToRemove(editor:ICodeEditor):Array<IDeleteLinesOperation> {
        // Construct delete operations
        final operations:Array<IDeleteLinesOperation> = editor.getSelections().map((s) -> {

            var endLineNumber = s.endLineNumber;
            if (s.startLineNumber < s.endLineNumber && s.endColumn == 1) {
                endLineNumber -= 1;
            }

            final op:IDeleteLinesOperation = {
                startLineNumber: s.startLineNumber,
                selectionStartColumn: s.selectionStartColumn,
                endLineNumber: endLineNumber,
                positionColumn: s.positionColumn
            };
            return op;
        });

        // Sort delete operations
        haxe.ds.ArraySort.sort(operations, (a, b) -> {
            if (a.startLineNumber == b.startLineNumber) {
                return a.endLineNumber - b.endLineNumber;
            }
            return a.startLineNumber - b.startLineNumber;
        });

        // Merge delete operations which are adjacent or overlapping
        final mergedOperations:Array<IDeleteLinesOperation> = [];
        var previousOperation = operations[0];
        for (i in 1...operations.length) {
            if (previousOperation.endLineNumber + 1 >= operations[i].startLineNumber) {
                // Merge current operations into the previous one
                previousOperation.endLineNumber = operations[i].endLineNumber;
            }
            else {
                // Push previous operation
                mergedOperations.push(previousOperation);
                previousOperation = operations[i];
            }
        }
        // Push the last operation
        mergedOperations.push(previousOperation);

        return mergedOperations;
    }

}

class IndentLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.indentLines',
            label: Nls.localize(r, 'lines.indent', "Indent Line"),
            alias: 'Indent Line',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.BracketRight,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            return;
        }
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast TypeOperations.indent(viewModel.cursorConfig, editor.getModel(), editor.getSelections()));
        editor.pushUndoStop();
    }

}

class OutdentLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.outdentLines',
            label: Nls.localize(r, 'lines.outdent', "Outdent Line"),
            alias: 'Outdent Line',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.BracketLeft,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        CoreEditingCommands.Outdent.runEditorCommand(_accessor, editor, null);
    }

}

class InsertLineBeforeAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.insertLineBefore',
            label: Nls.localize(r, 'lines.insertBefore', "Insert Line Above"),
            alias: 'Insert Line Above',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Enter,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            return;
        }
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast EnterOperation.lineInsertBefore(viewModel.cursorConfig, editor.getModel(), editor.getSelections()));
    }

}

class InsertLineAfterAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.insertLineAfter',
            label: Nls.localize(r, 'lines.insertAfter', "Insert Line Below"),
            alias: 'Insert Line Below',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Enter,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final viewModel = editor._getViewModel();
        if (viewModel == null) {
            return;
        }
        editor.pushUndoStop();
        editor.executeCommands(this.id, cast EnterOperation.lineInsertAfter(viewModel.cursorConfig, editor.getModel(), editor.getSelections()));
    }

}

abstract class AbstractDeleteAllToBoundaryAction extends EditorAction {

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (!editor.hasModel()) {
            return;
        }
        final primaryCursor = editor.getSelection();

        final rangesToDelete = this._getRangesToDelete(editor);
        // merge overlapping selections
        final effectiveRanges:Array<Range> = [];

        for (i in 0...rangesToDelete.length - 1) {
            final range = rangesToDelete[i];
            final nextRange = rangesToDelete[i + 1];

            if (Range.intersectRangesStatic(range, nextRange) == null) {
                effectiveRanges.push(range);
            }
            else {
                rangesToDelete[i + 1] = Range.plusRangeStatic(range, nextRange);
            }
        }

        effectiveRanges.push(rangesToDelete[rangesToDelete.length - 1]);

        final endCursorState = this._getEndCursorState(primaryCursor, effectiveRanges);

        final edits:Array<IIdentifiedSingleEditOperation> = effectiveRanges.map(range -> {
            return EditOperation.replace(range, '');
        });

        editor.pushUndoStop();
        editor.executeEdits(this.id, edits, endCursorState);
        editor.pushUndoStop();
    }

    /**
     * Compute the cursor state after the edit operations were applied.
     */
    abstract function _getEndCursorState(primaryCursor:Range, rangesToDelete:Array<Range>):Array<Selection>;

    abstract function _getRangesToDelete(editor:ICodeEditor):Array<Range>;

}

class DeleteAllLeftAction extends AbstractDeleteAllToBoundaryAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'deleteAllLeft',
            label: Nls.localize(r, 'lines.deleteAllLeft', "Delete All Left"),
            alias: 'Delete All Left',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: 0,
                mac: {primary: KeyMod.CtrlCmd | KeyCode.Backspace},
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    function _getEndCursorState(primaryCursor:Range, rangesToDelete:Array<Range>):Array<Selection> {
        var endPrimaryCursor:Null<Selection> = null;
        final endCursorState:Array<Selection> = [];
        var deletedLines = 0;

        for (range in rangesToDelete) {
            var endCursor;
            if (range.endColumn == 1 && deletedLines > 0) {
                final newStartLine = range.startLineNumber - deletedLines;
                endCursor = new Selection(newStartLine, range.startColumn, newStartLine, range.startColumn);
            }
            else {
                endCursor = new Selection(range.startLineNumber, range.startColumn, range.startLineNumber, range.startColumn);
            }

            deletedLines += range.endLineNumber - range.startLineNumber;

            if (range.intersectRanges(primaryCursor) != null) {
                endPrimaryCursor = endCursor;
            }
            else {
                endCursorState.push(endCursor);
            }
        }

        if (endPrimaryCursor != null) {
            endCursorState.unshift(endPrimaryCursor);
        }

        return endCursorState;
    }

    function _getRangesToDelete(editor:ICodeEditor):Array<Range> {
        final selections = editor.getSelections();
        if (selections == null) {
            return [];
        }

        var rangesToDelete:Array<Range> = cast selections;
        final model = editor.getModel();

        if (model == null) {
            return [];
        }

        haxe.ds.ArraySort.sort(rangesToDelete, Range.compareRangesUsingStarts);
        rangesToDelete = rangesToDelete.map(range -> {
            final selection:Selection = cast range;
            if (selection.isEmpty()) {
                if (selection.startColumn == 1) {
                    final deleteFromLine = Std.int(Math.max(1, selection.startLineNumber - 1));
                    final deleteFromColumn = selection.startLineNumber == 1 ? 1 : model.getLineLength(deleteFromLine) + 1;
                    return new Range(deleteFromLine, deleteFromColumn, selection.startLineNumber, 1);
                }
                else {
                    return new Range(selection.startLineNumber, 1, selection.startLineNumber, selection.startColumn);
                }
            }
            else {
                return new Range(selection.startLineNumber, 1, selection.endLineNumber, selection.endColumn);
            }
        });

        return rangesToDelete;
    }

}

class DeleteAllRightAction extends AbstractDeleteAllToBoundaryAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'deleteAllRight',
            label: Nls.localize(r, 'lines.deleteAllRight', "Delete All Right"),
            alias: 'Delete All Right',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: 0,
                mac: {primary: KeyMod.WinCtrl | KeyCode.KeyK, secondary: [KeyMod.CtrlCmd | KeyCode.Delete]},
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    function _getEndCursorState(primaryCursor:Range, rangesToDelete:Array<Range>):Array<Selection> {
        var endPrimaryCursor:Null<Selection> = null;
        final endCursorState:Array<Selection> = [];
        final offset = 0;
        for (i in 0...rangesToDelete.length) {
            final range = rangesToDelete[i];
            final endCursor = new Selection(range.startLineNumber - offset, range.startColumn, range.startLineNumber - offset, range.startColumn);

            if (range.intersectRanges(primaryCursor) != null) {
                endPrimaryCursor = endCursor;
            }
            else {
                endCursorState.push(endCursor);
            }
        }

        if (endPrimaryCursor != null) {
            endCursorState.unshift(endPrimaryCursor);
        }

        return endCursorState;
    }

    function _getRangesToDelete(editor:ICodeEditor):Array<Range> {
        final model = editor.getModel();
        if (model == null) {
            return [];
        }

        final selections = editor.getSelections();

        if (selections == null) {
            return [];
        }

        final rangesToDelete:Array<Range> = selections.map((sel) -> {
            if (sel.isEmpty()) {
                final maxColumn = model.getLineMaxColumn(sel.startLineNumber);

                if (sel.startColumn == maxColumn) {
                    return new Range(sel.startLineNumber, sel.startColumn, sel.startLineNumber + 1, 1);
                }
                else {
                    return new Range(sel.startLineNumber, sel.startColumn, sel.startLineNumber, maxColumn);
                }
            }
            return (sel : Range);
        });

        haxe.ds.ArraySort.sort(rangesToDelete, Range.compareRangesUsingStarts);
        return rangesToDelete;
    }

}

class JoinLinesAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.joinLines',
            label: Nls.localize(r, 'lines.joinLines', "Join Lines"),
            alias: 'Join Lines',
            precondition: EditorContextKeys.writable,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 0,
                mac: {primary: KeyMod.WinCtrl | KeyCode.KeyJ},
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    /**
     * Monaco's `str.replace(/[\s﻿\xA0]+$/g, ' ')`.
     */
    static function replaceTrailingWhitespace(str:String):String {
        var end = str.length;
        while (end > 0 && isJsWhitespace(StringTools.fastCodeAt(str, end - 1))) {
            end--;
        }
        return end == str.length ? str : str.substring(0, end) + ' ';
    }

    static function isJsWhitespace(c:Int):Bool {
        return (c >= 9 && c <= 13) || c == 32 || c == 0xA0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 || c == 0xFEFF;
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final selections = editor.getSelections();
        if (selections == null) {
            return;
        }

        var primaryCursor = editor.getSelection();
        if (primaryCursor == null) {
            return;
        }

        haxe.ds.ArraySort.sort(selections, Range.compareRangesUsingStarts);
        final reducedSelections:Array<Selection> = [];

        var previousValue = selections[0];
        for (i in 1...selections.length) {
            final currentValue = selections[i];
            previousValue = {
                if (previousValue.isEmpty()) {
                    if (previousValue.endLineNumber == currentValue.startLineNumber) {
                        if (primaryCursor.equalsSelection(previousValue)) {
                            primaryCursor = currentValue;
                        }
                        currentValue;
                    }
                    else if (currentValue.startLineNumber > previousValue.endLineNumber + 1) {
                        reducedSelections.push(previousValue);
                        currentValue;
                    }
                    else {
                        new Selection(previousValue.startLineNumber, previousValue.startColumn, currentValue.endLineNumber, currentValue.endColumn);
                    }
                }
                else {
                    if (currentValue.startLineNumber > previousValue.endLineNumber) {
                        reducedSelections.push(previousValue);
                        currentValue;
                    }
                    else {
                        new Selection(previousValue.startLineNumber, previousValue.startColumn, currentValue.endLineNumber, currentValue.endColumn);
                    }
                }
            };
        }
        final lastSelection = previousValue;

        reducedSelections.push(lastSelection);

        final model = editor.getModel();
        if (model == null) {
            return;
        }

        final edits:Array<IIdentifiedSingleEditOperation> = [];
        final endCursorState:Array<Selection> = [];
        var endPrimaryCursor = primaryCursor;
        var lineOffset = 0;

        for (i in 0...reducedSelections.length) {
            final selection = reducedSelections[i];
            final startLineNumber = selection.startLineNumber;
            final startColumn = 1;
            var columnDeltaOffset = 0;
            var endLineNumber:Int;
            var endColumn:Int;

            final selectionEndPositionOffset = model.getLineLength(selection.endLineNumber) - selection.endColumn;

            if (selection.isEmpty() || selection.startLineNumber == selection.endLineNumber) {
                final position = selection.getStartPosition();
                if (position.lineNumber < model.getLineCount()) {
                    endLineNumber = startLineNumber + 1;
                    endColumn = model.getLineMaxColumn(endLineNumber);
                }
                else {
                    endLineNumber = position.lineNumber;
                    endColumn = model.getLineMaxColumn(position.lineNumber);
                }
            }
            else {
                endLineNumber = selection.endLineNumber;
                endColumn = model.getLineMaxColumn(endLineNumber);
            }

            var trimmedLinesContent = model.getLineContent(startLineNumber);

            for (i in startLineNumber + 1...endLineNumber + 1) {
                final lineText = model.getLineContent(i);
                final firstNonWhitespaceIdx = model.getLineFirstNonWhitespaceColumn(i);

                if (firstNonWhitespaceIdx >= 1) {
                    var insertSpace = true;
                    if (trimmedLinesContent == '') {
                        insertSpace = false;
                    }

                    if (insertSpace && (trimmedLinesContent.charAt(trimmedLinesContent.length - 1) == ' ' ||
                        trimmedLinesContent.charAt(trimmedLinesContent.length - 1) == '\t')) {
                        insertSpace = false;
                        trimmedLinesContent = replaceTrailingWhitespace(trimmedLinesContent);
                    }

                    final lineTextWithoutIndent = lineText.substr(firstNonWhitespaceIdx - 1);

                    trimmedLinesContent += (insertSpace ? ' ' : '') + lineTextWithoutIndent;

                    if (insertSpace) {
                        columnDeltaOffset = lineTextWithoutIndent.length + 1;
                    }
                    else {
                        columnDeltaOffset = lineTextWithoutIndent.length;
                    }
                }
                else {
                    columnDeltaOffset = 0;
                }
            }

            final deleteSelection = new Range(startLineNumber, startColumn, endLineNumber, endColumn);

            if (!deleteSelection.isEmpty()) {
                var resultSelection:Selection;

                if (selection.isEmpty()) {
                    edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
                    resultSelection = new Selection(deleteSelection.startLineNumber - lineOffset, trimmedLinesContent.length - columnDeltaOffset + 1, startLineNumber - lineOffset, trimmedLinesContent.length - columnDeltaOffset + 1);
                }
                else {
                    if (selection.startLineNumber == selection.endLineNumber) {
                        edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
                        resultSelection = new Selection(selection.startLineNumber - lineOffset, selection.startColumn,
                            selection.endLineNumber - lineOffset, selection.endColumn);
                    }
                    else {
                        edits.push(EditOperation.replace(deleteSelection, trimmedLinesContent));
                        resultSelection = new Selection(selection.startLineNumber - lineOffset, selection.startColumn,
                            selection.startLineNumber - lineOffset, trimmedLinesContent.length - selectionEndPositionOffset);
                    }
                }

                if (Range.intersectRangesStatic(deleteSelection, primaryCursor) != null) {
                    endPrimaryCursor = resultSelection;
                }
                else {
                    endCursorState.push(resultSelection);
                }
            }

            lineOffset += deleteSelection.endLineNumber - deleteSelection.startLineNumber;
        }

        endCursorState.unshift(endPrimaryCursor);
        editor.pushUndoStop();
        editor.executeEdits(this.id, edits, endCursorState);
        editor.pushUndoStop();
    }

}

class TransposeAction extends EditorAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transpose',
            label: Nls.localize(r, 'editor.transpose', "Transpose Characters around the Cursor"),
            alias: 'Transpose Characters around the Cursor',
            precondition: EditorContextKeys.writable
        });
    }

    /**
     * Monaco's `str.split('').reverse().join('')` (UTF-16 code units).
     */
    static function reverseString(str:String):String {
        final buf = new StringBuf();
        var i = str.length - 1;
        while (i >= 0) {
            buf.addChar(StringTools.fastCodeAt(str, i));
            i--;
        }
        return buf.toString();
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final selections = editor.getSelections();
        if (selections == null) {
            return;
        }

        final model = editor.getModel();
        if (model == null) {
            return;
        }

        final commands:Array<Null<ICommand>> = [];

        for (i in 0...selections.length) {
            final selection = selections[i];

            if (!selection.isEmpty()) {
                continue;
            }

            final cursor = selection.getStartPosition();
            final maxColumn = model.getLineMaxColumn(cursor.lineNumber);

            if (cursor.column >= maxColumn) {
                if (cursor.lineNumber == model.getLineCount()) {
                    continue;
                }

                // The cursor is at the end of current line and current line is not empty
                // then we transpose the character before the cursor and the line break if there is any following line.
                final deleteSelection = new Range(cursor.lineNumber, Std.int(Math.max(1, cursor.column - 1)), cursor.lineNumber + 1, 1);
                final chars = reverseString(model.getValueInRange(deleteSelection));

                commands.push(new ReplaceCommand(new Selection(cursor.lineNumber, Std.int(Math.max(1, cursor.column - 1)), cursor.lineNumber + 1, 1), chars));
            }
            else {
                final deleteSelection = new Range(cursor.lineNumber, Std.int(Math.max(1, cursor.column - 1)), cursor.lineNumber, cursor.column + 1);
                final chars = reverseString(model.getValueInRange(deleteSelection));
                commands.push(new ReplaceCommandThatPreservesSelection(deleteSelection, chars,
                    new Selection(cursor.lineNumber, cursor.column + 1, cursor.lineNumber, cursor.column + 1)));
            }
        }

        editor.pushUndoStop();
        editor.executeCommands(this.id, commands);
        editor.pushUndoStop();
    }

}

abstract class AbstractCaseAction extends EditorAction {

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final selections = editor.getSelections();
        if (selections == null) {
            return;
        }

        final model = editor.getModel();
        if (model == null) {
            return;
        }

        final wordSeparators = editor.getOption(EditorOption.wordSeparators);
        final textEdits:Array<IIdentifiedSingleEditOperation> = [];

        for (selection in selections) {
            if (selection.isEmpty()) {
                final cursor = selection.getStartPosition();
                final word = editor.getConfiguredWordAtPosition(cursor);

                if (word == null) {
                    continue;
                }

                final wordRange = new Range(cursor.lineNumber, word.startColumn, cursor.lineNumber, word.endColumn);
                final text = model.getValueInRange(wordRange);
                textEdits.push(EditOperation.replace(wordRange, this._modifyText(text, wordSeparators)));
            }
            else {
                final text = model.getValueInRange(selection);
                textEdits.push(EditOperation.replace(selection, this._modifyText(text, wordSeparators)));
            }
        }

        editor.pushUndoStop();
        editor.executeEdits(this.id, textEdits);
        editor.pushUndoStop();
    }

    abstract function _modifyText(text:String, wordSeparators:String):String;

}

class UpperCaseAction extends AbstractCaseAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToUppercase',
            label: Nls.localize(r, 'editor.transformToUppercase', "Transform to Uppercase"),
            alias: 'Transform to Uppercase',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        return JsStringRegExp.toLocaleUpperCase(text);
    }

}

class LowerCaseAction extends AbstractCaseAction {

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToLowercase',
            label: Nls.localize(r, 'editor.transformToLowercase', "Transform to Lowercase"),
            alias: 'Transform to Lowercase',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        return JsStringRegExp.toLocaleLowerCase(text);
    }

}

class BackwardsCompatibleRegExp {

    var _actual:Null<RegExp>;
    var _evaluated:Bool;
    final _pattern:String;
    final _flags:String;

    public function new(pattern:String, flags:String) {
        this._pattern = pattern;
        this._flags = flags;
        this._actual = null;
        this._evaluated = false;
    }

    public function get():Null<RegExp> {
        if (!this._evaluated) {
            this._evaluated = true;
            try {
                this._actual = new RegExp(this._pattern, this._flags);
            }
            catch (err:Dynamic) {
                // this browser does not support this regular expression
            }
        }
        return this._actual;
    }

    public function isSupported():Bool {
        return (this.get() != null);
    }

}

class TitleCaseAction extends AbstractCaseAction {

    public static final titleBoundary = new BackwardsCompatibleRegExp('(^|[^\\p{L}\\p{N}\']|((^|\\P{L})\'))\\p{L}', 'gmu');

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToTitlecase',
            label: Nls.localize(r, 'editor.transformToTitlecase', "Transform to Title Case"),
            alias: 'Transform to Title Case',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        final titleBoundary = TitleCaseAction.titleBoundary.get();
        if (titleBoundary == null) {
            // cannot support this
            return text;
        }
        return JsStringRegExp.replaceWith(JsStringRegExp.toLocaleLowerCase(text), titleBoundary, (b) -> JsStringRegExp.toLocaleUpperCase(b));
    }

}

class SnakeCaseAction extends AbstractCaseAction {

    public static final caseBoundary = new BackwardsCompatibleRegExp('(\\p{Ll})(\\p{Lu})', 'gmu');
    public static final singleLetters = new BackwardsCompatibleRegExp('(\\p{Lu}|\\p{N})(\\p{Lu})(\\p{Ll})', 'gmu');

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToSnakecase',
            label: Nls.localize(r, 'editor.transformToSnakecase', "Transform to Snake Case"),
            alias: 'Transform to Snake Case',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        final caseBoundary = SnakeCaseAction.caseBoundary.get();
        final singleLetters = SnakeCaseAction.singleLetters.get();
        if (caseBoundary == null || singleLetters == null) {
            // cannot support this
            return text;
        }
        return JsStringRegExp.toLocaleLowerCase(
            JsStringRegExp.replace(
                JsStringRegExp.replace(text, caseBoundary, '$1_$2'),
                singleLetters, '$1_$2$3'
            )
        );
    }

}

class CamelCaseAction extends AbstractCaseAction {

    public static final wordBoundary = new BackwardsCompatibleRegExp('[_\\s-]', 'gm');

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToCamelcase',
            label: Nls.localize(r, 'editor.transformToCamelcase', "Transform to Camel Case"),
            alias: 'Transform to Camel Case',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        final wordBoundary = CamelCaseAction.wordBoundary.get();
        if (wordBoundary == null) {
            // cannot support this
            return text;
        }
        final words = JsStringRegExp.split(text, wordBoundary);
        final firstWord = words.shift();
        return firstWord + words.map((word:String) -> JsStringRegExp.toLocaleUpperCase(word.substring(0, 1)) + word.substring(1))
            .join('');
    }

}

class PascalCaseAction extends AbstractCaseAction {

    public static final wordBoundary = new BackwardsCompatibleRegExp('[_\\s-]', 'gm');
    public static final wordBoundaryToMaintain = new BackwardsCompatibleRegExp('(?<=\\.)', 'gm');

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToPascalcase',
            label: Nls.localize(r, 'editor.transformToPascalcase', "Transform to Pascal Case"),
            alias: 'Transform to Pascal Case',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, wordSeparators:String):String {
        final wordBoundary = PascalCaseAction.wordBoundary.get();
        final wordBoundaryToMaintain = PascalCaseAction.wordBoundaryToMaintain.get();

        if (wordBoundary == null || wordBoundaryToMaintain == null) {
            // cannot support this
            return text;
        }

        final wordsWithMaintainBoundaries = JsStringRegExp.split(text, wordBoundaryToMaintain);
        final words:Array<String> = [];
        for (word in wordsWithMaintainBoundaries) {
            for (w in JsStringRegExp.split(word, wordBoundary)) {
                words.push(w);
            }
        }
        return words.map((word:String) -> JsStringRegExp.toLocaleUpperCase(word.substring(0, 1)) + word.substring(1))
            .join('');
    }

}

class KebabCaseAction extends AbstractCaseAction {

    public static function isSupported():Bool {
        final areAllRegexpsSupported = [
            caseBoundary,
            singleLetters,
            underscoreBoundary,
        ].filter((regexp) -> !regexp.isSupported()).length == 0;

        return areAllRegexpsSupported;
    }

    static final caseBoundary = new BackwardsCompatibleRegExp('(\\p{Ll})(\\p{Lu})', 'gmu');
    static final singleLetters = new BackwardsCompatibleRegExp('(\\p{Lu}|\\p{N})(\\p{Lu}\\p{Ll})', 'gmu');
    static final underscoreBoundary = new BackwardsCompatibleRegExp('(\\S)(_)(\\S)', 'gm');

    public function new(?r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.transformToKebabcase',
            label: Nls.localize(r, 'editor.transformToKebabcase', 'Transform to Kebab Case'),
            alias: 'Transform to Kebab Case',
            precondition: EditorContextKeys.writable
        });
    }

    function _modifyText(text:String, _:String):String {
        final caseBoundary = KebabCaseAction.caseBoundary.get();
        final singleLetters = KebabCaseAction.singleLetters.get();
        final underscoreBoundary = KebabCaseAction.underscoreBoundary.get();

        if (caseBoundary == null || singleLetters == null || underscoreBoundary == null) {
            // one or more regexps aren't supported
            return text;
        }

        return JsStringRegExp.toLocaleLowerCase(
            JsStringRegExp.replace(
                JsStringRegExp.replace(
                    JsStringRegExp.replace(text, underscoreBoundary, '$1-$3'),
                    caseBoundary, '$1-$2'
                ),
                singleLetters, '$1-$2'
            )
        );
    }

}

/**
 * JavaScript's `String.prototype.replace`, `split` (with a global regular
 * expression) and `toLocaleUpperCase`/`toLocaleLowerCase`, as the case
 * actions use them.
 */
private class JsStringRegExp {

    public static function toLocaleUpperCase(text:String):String {
        #if js
        return js.Syntax.code('{0}.toLocaleUpperCase()', text);
        #else
        return text.toUpperCase();
        #end
    }

    public static function toLocaleLowerCase(text:String):String {
        #if js
        return js.Syntax.code('{0}.toLocaleLowerCase()', text);
        #else
        return text.toLowerCase();
        #end
    }

    /**
     * JavaScript's `AdvanceStringIndex`.
     */
    static function advance(str:String, index:Int, unicode:Bool):Int {
        if (!unicode || index + 1 >= str.length) {
            return index + 1;
        }
        final c = StringTools.fastCodeAt(str, index);
        if (c >= 0xD800 && c <= 0xDBFF) {
            final d = StringTools.fastCodeAt(str, index + 1);
            if (d >= 0xDC00 && d <= 0xDFFF) {
                return index + 2;
            }
        }
        return index + 1;
    }

    /**
     * `str.replace(re, fn)` with a global `re`: `fn` takes the match.
     */
    public static function replaceWith(str:String, re:RegExp, fn:(match:String) -> String):String {
        return replaceAll(str, re, (m) -> fn(m[0]));
    }

    /**
     * `str.replace(re, replacement)` with a global `re`: `replacement`
     * takes `$1` to `$9` and `$$`.
     */
    public static function replace(str:String, re:RegExp, replacement:String):String {
        return replaceAll(str, re, (m) -> {
            final buf = new StringBuf();
            var i = 0;
            final len = replacement.length;
            while (i < len) {
                final c = StringTools.fastCodeAt(replacement, i);
                if (c == '$'.code && i + 1 < len) {
                    final d = StringTools.fastCodeAt(replacement, i + 1);
                    if (d == '$'.code) {
                        buf.addChar('$'.code);
                        i += 2;
                        continue;
                    }
                    if (d >= '1'.code && d <= '9'.code && (d - '0'.code) < m.length) {
                        final group = m[d - '0'.code];
                        if (group != null) {
                            buf.add(group);
                        }
                        i += 2;
                        continue;
                    }
                }
                buf.addChar(c);
                i++;
            }
            return buf.toString();
        });
    }

    static function replaceAll(str:String, re:RegExp, fn:(m:RegExpExecArray) -> String):String {
        re.lastIndex = 0;
        final buf = new StringBuf();
        var last = 0;
        while (true) {
            final m = re.exec(str);
            if (m == null) {
                break;
            }
            final matched:String = m[0];
            buf.add(str.substring(last, m.index));
            buf.add(fn(m));
            last = m.index + matched.length;
            if (matched.length == 0) {
                re.lastIndex = advance(str, re.lastIndex, re.unicode);
            }
        }
        buf.add(str.substring(last));
        re.lastIndex = 0;
        return buf.toString();
    }

    /**
     * `str.split(re)`, with the captured groups of each separator in the
     * result.
     */
    public static function split(str:String, re:RegExp):Array<String> {
        final result:Array<String> = [];
        final size = str.length;
        if (size == 0) {
            re.lastIndex = 0;
            final m = re.exec(str);
            re.lastIndex = 0;
            if (m != null && m.index == 0) {
                return result;
            }
            result.push(str);
            return result;
        }
        var p = 0;
        var q = 0;
        while (q < size) {
            re.lastIndex = q;
            final m = re.exec(str);
            if (m == null || m.index >= size) {
                break;
            }
            final matched:String = m[0];
            final e = m.index + matched.length;
            if (e == p || (matched.length == 0 && m.index >= size)) {
                q = advance(str, m.index, re.unicode);
                continue;
            }
            result.push(str.substring(p, m.index));
            for (i in 1...m.length) {
                result.push(m[i]);
            }
            p = e;
            q = p;
        }
        re.lastIndex = 0;
        result.push(str.substring(p));
        return result;
    }

}

class LinesOperationsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorAction(new CopyLinesUpAction(r));
        r.registerEditorAction(new CopyLinesDownAction(r));
        r.registerEditorAction(new DuplicateSelectionAction(r));
        r.registerEditorAction(new MoveLinesUpAction(r));
        r.registerEditorAction(new MoveLinesDownAction(r));
        r.registerEditorAction(new SortLinesAscendingAction(r));
        r.registerEditorAction(new SortLinesDescendingAction(r));
        r.registerEditorAction(new DeleteDuplicateLinesAction(r));
        r.registerEditorAction(new TrimTrailingWhitespaceAction(r));
        r.registerEditorAction(new DeleteLinesAction(r));
        r.registerEditorAction(new IndentLinesAction(r));
        r.registerEditorAction(new OutdentLinesAction(r));
        r.registerEditorAction(new InsertLineBeforeAction(r));
        r.registerEditorAction(new InsertLineAfterAction(r));
        r.registerEditorAction(new DeleteAllLeftAction(r));
        r.registerEditorAction(new DeleteAllRightAction(r));
        r.registerEditorAction(new JoinLinesAction(r));
        r.registerEditorAction(new TransposeAction(r));
        r.registerEditorAction(new UpperCaseAction(r));
        r.registerEditorAction(new LowerCaseAction(r));

        if (SnakeCaseAction.caseBoundary.isSupported() && SnakeCaseAction.singleLetters.isSupported()) {
            r.registerEditorAction(new SnakeCaseAction(r));
        }
        if (CamelCaseAction.wordBoundary.isSupported()) {
            r.registerEditorAction(new CamelCaseAction(r));
        }
        if (PascalCaseAction.wordBoundary.isSupported()) {
            r.registerEditorAction(new PascalCaseAction(r));
        }
        if (TitleCaseAction.titleBoundary.isSupported()) {
            r.registerEditorAction(new TitleCaseAction(r));
        }

        if (KebabCaseAction.isSupported()) {
            r.registerEditorAction(new KebabCaseAction(r));
        }
    }

}
