// Ported from vscode src/vs/editor/common/cursor/cursorDeleteOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.config.EditorOptions.EditorAutoClosingEditStrategy;
import cityscape.common.config.EditorOptions.EditorAutoClosingStrategy;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.CursorMoveOperations;
import cityscape.common.languages.LanguageConfiguration.StandardAutoClosingPairConditional;

/**
 * Monaco's `[shouldPushStackElementBefore, commands]` tuple.
 */
class DeleteOperationsResult {

    public final shouldPushStackElementBefore:Bool;
    public final commands:Array<Null<ICommand>>;

    public function new(shouldPushStackElementBefore:Bool, commands:Array<Null<ICommand>>) {
        this.shouldPushStackElementBefore = shouldPushStackElementBefore;
        this.commands = commands;
    }

}

class DeleteOperations {

    public static function deleteRight(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>):DeleteOperationsResult {
        final commands:Array<Null<ICommand>> = [];
        var shouldPushStackElementBefore = (prevEditOperationType != EditOperationType.DeletingRight);
        for (i in 0...selections.length) {
            final selection = selections[i];

            var deleteSelection:Range = selection;

            if (deleteSelection.isEmpty()) {
                final position = selection.getPosition();
                final rightOfPosition = MoveOperations.right(config, model, position);
                deleteSelection = new Range(
                    rightOfPosition.lineNumber,
                    rightOfPosition.column,
                    position.lineNumber,
                    position.column
                );
            }

            if (deleteSelection.isEmpty()) {
                // Probably at end of file => ignore
                commands[i] = null;
                continue;
            }

            if (deleteSelection.startLineNumber != deleteSelection.endLineNumber) {
                shouldPushStackElementBefore = true;
            }

            commands[i] = new ReplaceCommand(deleteSelection, '');
        }
        return new DeleteOperationsResult(shouldPushStackElementBefore, commands);
    }

    public static function isAutoClosingPairDelete(
        autoClosingDelete:EditorAutoClosingEditStrategy,
        autoClosingBrackets:EditorAutoClosingStrategy,
        autoClosingQuotes:EditorAutoClosingStrategy,
        autoClosingPairsOpen:Map<String, Array<StandardAutoClosingPairConditional>>,
        model:ICursorSimpleModel,
        selections:Array<Selection>,
        autoClosedCharacters:Array<Range>
    ):Bool {
        if (autoClosingBrackets == 'never' && autoClosingQuotes == 'never') {
            return false;
        }
        if (autoClosingDelete == 'never') {
            return false;
        }

        for (i in 0...selections.length) {
            final selection = selections[i];
            final position = selection.getPosition();

            if (!selection.isEmpty()) {
                return false;
            }

            final lineText = model.getLineContent(position.lineNumber);
            if (position.column < 2 || position.column >= lineText.length + 1) {
                return false;
            }
            final character = lineText.charAt(position.column - 2);

            final autoClosingPairCandidates = autoClosingPairsOpen.get(character);
            if (autoClosingPairCandidates == null) {
                return false;
            }

            if (CursorCommon.isQuote(character)) {
                if (autoClosingQuotes == 'never') {
                    return false;
                }
            }
            else {
                if (autoClosingBrackets == 'never') {
                    return false;
                }
            }

            final afterCharacter = lineText.charAt(position.column - 1);

            var foundAutoClosingPair = false;
            for (autoClosingPairCandidate in autoClosingPairCandidates) {
                if (autoClosingPairCandidate.open == character && autoClosingPairCandidate.close == afterCharacter) {
                    foundAutoClosingPair = true;
                }
            }
            if (!foundAutoClosingPair) {
                return false;
            }

            // Must delete the pair only if it was automatically inserted by the editor
            if (autoClosingDelete == 'auto') {
                var found = false;
                for (j in 0...autoClosedCharacters.length) {
                    final autoClosedCharacter = autoClosedCharacters[j];
                    if (position.lineNumber == autoClosedCharacter.startLineNumber && position.column == autoClosedCharacter.startColumn) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    return false;
                }
            }
        }

        return true;
    }

    static function _runAutoClosingPairDelete(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>):DeleteOperationsResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            final position = selections[i].getPosition();
            final deleteSelection = new Range(
                position.lineNumber,
                position.column - 1,
                position.lineNumber,
                position.column + 1
            );
            commands[i] = new ReplaceCommand(deleteSelection, '');
        }
        return new DeleteOperationsResult(true, commands);
    }

    public static function deleteLeft(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>, autoClosedCharacters:Array<Range>):DeleteOperationsResult {
        if (isAutoClosingPairDelete(config.autoClosingDelete, config.autoClosingBrackets, config.autoClosingQuotes, config.autoClosingPairs.autoClosingPairsOpenByEnd, model, selections, autoClosedCharacters)) {
            return _runAutoClosingPairDelete(config, model, selections);
        }

        final commands:Array<Null<ICommand>> = [];
        var shouldPushStackElementBefore = (prevEditOperationType != EditOperationType.DeletingLeft);
        for (i in 0...selections.length) {
            final deleteRange = DeleteOperations.getDeleteRange(selections[i], model, config);

            // Ignore empty delete ranges, as they have no effect
            // They happen if the cursor is at the beginning of the file.
            if (deleteRange.isEmpty()) {
                commands[i] = null;
                continue;
            }

            if (deleteRange.startLineNumber != deleteRange.endLineNumber) {
                shouldPushStackElementBefore = true;
            }

            commands[i] = new ReplaceCommand(deleteRange, '');
        }
        return new DeleteOperationsResult(shouldPushStackElementBefore, commands);
    }

    static function getDeleteRange(selection:Selection, model:ICursorSimpleModel, config:CursorConfiguration):Range {
        if (!selection.isEmpty()) {
            return selection;
        }

        final position = selection.getPosition();

        // Unintend when using tab stops and cursor is within indentation
        if (config.useTabStops && position.column > 1) {
            final lineContent = model.getLineContent(position.lineNumber);

            final firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(lineContent);
            final lastIndentationColumn = (
                firstNonWhitespaceIndex == -1
                    ? /* entire string is whitespace */ lineContent.length + 1
                    : firstNonWhitespaceIndex + 1
            );

            if (position.column <= lastIndentationColumn) {
                final fromVisibleColumn = config.visibleColumnFromColumn(model, position);
                final toVisibleColumn = CursorColumns.prevIndentTabStop(fromVisibleColumn, config.indentSize);
                final toColumn = config.columnFromVisibleColumn(model, position.lineNumber, toVisibleColumn);
                return new Range(position.lineNumber, toColumn, position.lineNumber, position.column);
            }
        }

        return Range.fromPositions(DeleteOperations.getPositionAfterDeleteLeft(position, model), position);
    }

    static function getPositionAfterDeleteLeft(position:Position, model:ICursorSimpleModel):Position {
        if (position.column > 1) {
            // Convert 1-based columns to 0-based offsets and back.
            final idx = Strings.getLeftDeleteOffset(position.column - 1, model.getLineContent(position.lineNumber));
            return position.with(null, idx + 1);
        }
        else if (position.lineNumber > 1) {
            final newLine = position.lineNumber - 1;
            return new Position(newLine, model.getLineMaxColumn(newLine));
        }
        else {
            return position;
        }
    }

    public static function cut(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        var lastCutRange:Null<Range> = null;
        haxe.ds.ArraySort.sort(selections, (a, b) -> Position.compare(a.getStartPosition(), b.getEndPosition()));
        for (i in 0...selections.length) {
            final selection = selections[i];

            if (selection.isEmpty()) {
                if (config.emptySelectionClipboard) {
                    // This is a full line cut

                    final position = selection.getPosition();

                    var startLineNumber:Int;
                    var startColumn:Int;
                    var endLineNumber:Int;
                    var endColumn:Int;

                    if (position.lineNumber < model.getLineCount()) {
                        // Cutting a line in the middle of the model
                        startLineNumber = position.lineNumber;
                        startColumn = 1;
                        endLineNumber = position.lineNumber + 1;
                        endColumn = 1;
                    }
                    else if (position.lineNumber > 1 && (lastCutRange == null || lastCutRange.endLineNumber != position.lineNumber)) {
                        // Cutting the last line & there are more than 1 lines in the model & a previous cut operation does not touch the current cut operation
                        startLineNumber = position.lineNumber - 1;
                        startColumn = model.getLineMaxColumn(position.lineNumber - 1);
                        endLineNumber = position.lineNumber;
                        endColumn = model.getLineMaxColumn(position.lineNumber);
                    }
                    else {
                        // Cutting the single line that the model contains
                        startLineNumber = position.lineNumber;
                        startColumn = 1;
                        endLineNumber = position.lineNumber;
                        endColumn = model.getLineMaxColumn(position.lineNumber);
                    }

                    final deleteSelection = new Range(
                        startLineNumber,
                        startColumn,
                        endLineNumber,
                        endColumn
                    );
                    lastCutRange = deleteSelection;

                    if (!deleteSelection.isEmpty()) {
                        commands[i] = new ReplaceCommand(deleteSelection, '');
                    }
                    else {
                        commands[i] = null;
                    }
                }
                else {
                    // Cannot cut empty selection
                    commands[i] = null;
                }
            }
            else {
                commands[i] = new ReplaceCommand(selection, '');
            }
        }
        return new EditOperationResult(EditOperationType.Other, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    }

}
