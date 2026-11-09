// Ported from vscode src/vs/editor/common/cursor/cursorTypeEditOperations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.cursor;

import cityscape.base.common.CharCode;
import cityscape.base.common.Errors;
import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ReplaceCommand;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.commands.SurroundSelectionCommand;
import cityscape.common.config.EditorOptions.EditorAutoClosingStrategy;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.WordCharacterClassifier;
import cityscape.common.languages.AutoIndent;
import cityscape.common.languages.EnterAction.EnterActionUtils;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.LanguageConfigurationRegistry;
import cityscape.common.languages.Supports;
import cityscape.common.languages.supports.ElectricCharacter.IElectricAction;

/**
 * Monaco's `{ range, text }` edits of the auto indentation.
 */
typedef RangeAndText = {
    var range:Range;
    var text:String;
}

private typedef IndentationForSelection = {
    var selection:Selection;
    var indentation:String;
}

class AutoIndentOperation {

    public static function getEdits(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, isDoingComposition:Bool):Null<EditOperationResult> {
        if (!isDoingComposition && _isAutoIndentType(config, model, selections)) {
            final indentationForSelections:Array<IndentationForSelection> = [];
            for (selection in selections) {
                final indentation = _findActualIndentationForSelection(config, model, selection, ch);
                if (indentation == null) {
                    // Auto indentation failed
                    return null;
                }
                indentationForSelections.push({selection: selection, indentation: indentation});
            }
            final autoClosingPairClose = AutoClosingOpenCharTypeOperation.getAutoClosingPairClose(config, model, selections, ch, false);
            return _getIndentationAndAutoClosingPairEdits(config, model, indentationForSelections, ch, autoClosingPairClose);
        }
        return null;
    }

    static function _isAutoIndentType(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>):Bool {
        if ((config.autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return false;
        }
        for (i in 0...selections.length) {
            if (!model.tokenization.isCheapToTokenize(selections[i].getEndPosition().lineNumber)) {
                return false;
            }
        }
        return true;
    }

    static function _findActualIndentationForSelection(config:CursorConfiguration, model:ITextModel, selection:Selection, ch:String):Null<String> {
        final actualIndentation = AutoIndent.getIndentActionForType(config, model, selection, ch, {
            shiftIndent: (indentation) -> {
                return CursorTypeEditOperations.shiftIndent(config, indentation);
            },
            unshiftIndent: (indentation) -> {
                return CursorTypeEditOperations.unshiftIndent(config, indentation);
            },
        }, config.languageConfigurationService);

        if (actualIndentation == null) {
            return null;
        }

        final currentIndentation = LanguageConfigurationRegistry.getIndentationAtPosition(model, selection.startLineNumber, selection.startColumn);
        if (actualIndentation == config.normalizeIndentation(currentIndentation)) {
            return null;
        }
        return actualIndentation;
    }

    static function _getIndentationAndAutoClosingPairEdits(config:CursorConfiguration, model:ITextModel, indentationForSelections:Array<IndentationForSelection>, ch:String, autoClosingPairClose:Null<String>):EditOperationResult {
        final commands:Array<Null<ICommand>> = [for (item in indentationForSelections) {
            final selection = item.selection;
            final indentation = item.indentation;
            if (autoClosingPairClose != null) {
                // Apply both auto closing pair edits and auto indentation edits
                final indentationEdit = _getEditFromIndentationAndSelection(config, model, indentation, selection, ch, false);
                (new TypeWithIndentationAndAutoClosingCommand(indentationEdit, selection, ch, autoClosingPairClose) : ICommand);
            }
            else {
                // Apply only auto indentation edits
                final indentationEdit = _getEditFromIndentationAndSelection(config, model, indentation, selection, ch, true);
                CursorTypeEditOperations.typeCommand(indentationEdit.range, indentationEdit.text, false);
            }
        }];
        final editOptions = {shouldPushStackElementBefore: true, shouldPushStackElementAfter: false};
        return new EditOperationResult(EditOperationType.TypingOther, commands, editOptions);
    }

    static function _getEditFromIndentationAndSelection(config:CursorConfiguration, model:ITextModel, indentation:String, selection:Selection, ch:String, includeChInEdit:Bool = true):RangeAndText {
        final startLineNumber = selection.startLineNumber;
        final firstNonWhitespaceColumn = model.getLineFirstNonWhitespaceColumn(startLineNumber);
        var text:String = config.normalizeIndentation(indentation);
        if (firstNonWhitespaceColumn != 0) {
            final startLine = model.getLineContent(startLineNumber);
            text += startLine.substring(firstNonWhitespaceColumn - 1, selection.startColumn - 1);
        }
        text += includeChInEdit ? ch : '';
        final range = new Range(startLineNumber, 1, selection.endLineNumber, selection.endColumn);
        return {range: range, text: text};
    }

}

class AutoClosingOvertypeOperation {

    public static function getEdits(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, autoClosedCharacters:Array<Range>, ch:String):Null<EditOperationResult> {
        if (CursorTypeEditOperations.isAutoClosingOvertype(config, model, selections, autoClosedCharacters, ch)) {
            return _runAutoClosingOvertype(prevEditOperationType, selections, ch);
        }
        return null;
    }

    static function _runAutoClosingOvertype(prevEditOperationType:EditOperationType, selections:Array<Selection>, ch:String):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            final selection = selections[i];
            final position = selection.getPosition();
            final typeSelection = new Range(position.lineNumber, position.column, position.lineNumber, position.column + 1);
            commands[i] = new ReplaceCommand(typeSelection, ch);
        }
        return new EditOperationResult(EditOperationType.TypingOther, commands, {
            shouldPushStackElementBefore: CursorTypeEditOperations.shouldPushStackElementBetween(prevEditOperationType, EditOperationType.TypingOther),
            shouldPushStackElementAfter: false
        });
    }

}

class AutoClosingOvertypeWithInterceptorsOperation {

    public static function getEdits(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, autoClosedCharacters:Array<Range>, ch:String):Null<EditOperationResult> {
        if (CursorTypeEditOperations.isAutoClosingOvertype(config, model, selections, autoClosedCharacters, ch)) {
            // Unfortunately, the close character is at this point "doubled", so we need to delete it...
            final commands:Array<Null<ICommand>> = [for (s in selections) new ReplaceCommand(new Range(s.positionLineNumber, s.positionColumn, s.positionLineNumber, s.positionColumn + 1), '', false)];
            return new EditOperationResult(EditOperationType.TypingOther, commands, {
                shouldPushStackElementBefore: true,
                shouldPushStackElementAfter: false
            });
        }
        return null;
    }

}

private typedef BeforeAfterPosition = {
    var lineNumber:Int;
    var beforeColumn:Int;
    var afterColumn:Int;
}

class AutoClosingOpenCharTypeOperation {

    public static function getEdits(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, chIsAlreadyTyped:Bool, isDoingComposition:Bool):Null<EditOperationResult> {
        if (!isDoingComposition) {
            final autoClosingPairClose = getAutoClosingPairClose(config, model, selections, ch, chIsAlreadyTyped);
            if (autoClosingPairClose != null) {
                return _runAutoClosingOpenCharType(selections, ch, chIsAlreadyTyped, autoClosingPairClose);
            }
        }
        return null;
    }

    static function _runAutoClosingOpenCharType(selections:Array<Selection>, ch:String, chIsAlreadyTyped:Bool, autoClosingPairClose:String):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            final selection = selections[i];
            commands[i] = new TypeWithAutoClosingCommand(selection, ch, !chIsAlreadyTyped, autoClosingPairClose);
        }
        return new EditOperationResult(EditOperationType.TypingOther, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: false
        });
    }

    public static function getAutoClosingPairClose(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, chIsAlreadyTyped:Bool):Null<String> {
        for (selection in selections) {
            if (!selection.isEmpty()) {
                return null;
            }
        }
        // This method is called both when typing (regularly) and when composition ends
        // This means that we need to work with a text buffer where sometimes `ch` is not
        // there (it is being typed right now) or with a text buffer where `ch` has already been typed
        //
        // In order to avoid adding checks for `chIsAlreadyTyped` in all places, we will work
        // with two conceptual positions, the position before `ch` and the position after `ch`
        //
        final positions:Array<BeforeAfterPosition> = [for (s in selections) {
            final position = s.getPosition();
            if (chIsAlreadyTyped) {
                {lineNumber: position.lineNumber, beforeColumn: position.column - ch.length, afterColumn: position.column};
            }
            else {
                {lineNumber: position.lineNumber, beforeColumn: position.column, afterColumn: position.column};
            }
        }];
        // Find the longest auto-closing open pair in case of multiple ending in `ch`
        // e.g. when having [f","] and [","], it picks [f","] if the character before is f
        final pair = _findAutoClosingPairOpen(config, model, [for (p in positions) new Position(p.lineNumber, p.beforeColumn)], ch);
        if (pair == null) {
            return null;
        }
        var autoCloseConfig:EditorAutoClosingStrategy;
        var shouldAutoCloseBefore:(ch:String) -> Bool;

        final chIsQuote = CursorCommon.isQuote(ch);
        if (chIsQuote) {
            autoCloseConfig = config.autoClosingQuotes;
            shouldAutoCloseBefore = config.shouldAutoCloseBefore.quote;
        }
        else {
            final pairIsForComments = (config.blockCommentStartToken != null && config.blockCommentStartToken.length > 0) ? pair.open.indexOf(config.blockCommentStartToken) != -1 : false;
            if (pairIsForComments) {
                autoCloseConfig = config.autoClosingComments;
                shouldAutoCloseBefore = config.shouldAutoCloseBefore.comment;
            }
            else {
                autoCloseConfig = config.autoClosingBrackets;
                shouldAutoCloseBefore = config.shouldAutoCloseBefore.bracket;
            }
        }
        if (autoCloseConfig == 'never') {
            return null;
        }
        // Sometimes, it is possible to have two auto-closing pairs that have a containment relationship
        // e.g. when having [(,)] and [(*,*)]
        // - when typing (, the resulting state is (|)
        // - when typing *, the desired resulting state is (*|*), not (*|*))
        final containedPair = _findContainedAutoClosingPair(config, pair);
        final containedPairClose = containedPair != null ? containedPair.close : '';
        var isContainedPairPresent = true;

        for (position in positions) {
            final lineNumber = position.lineNumber;
            final beforeColumn = position.beforeColumn;
            final afterColumn = position.afterColumn;
            final lineText = model.getLineContent(lineNumber);
            final lineBefore = lineText.substring(0, beforeColumn - 1);
            final lineAfter = lineText.substring(afterColumn - 1);

            if (!StringTools.startsWith(lineAfter, containedPairClose)) {
                isContainedPairPresent = false;
            }
            // Only consider auto closing the pair if an allowed character follows or if another autoclosed pair closing brace follows
            if (lineAfter.length > 0) {
                final characterAfter = lineAfter.charAt(0);
                final isBeforeCloseBrace = _isBeforeClosingBrace(config, lineAfter);
                if (!isBeforeCloseBrace && !shouldAutoCloseBefore(characterAfter)) {
                    return null;
                }
            }
            // Do not auto-close ' or " after a word character
            if (pair.open.length == 1 && (ch == '\'' || ch == '"') && autoCloseConfig != 'always') {
                final wordSeparators = WordCharacterClassifier.getMapForWordSeparators(config.wordSeparators, []);
                if (lineBefore.length > 0) {
                    final characterBefore = StringTools.fastCodeAt(lineBefore, lineBefore.length - 1);
                    if (wordSeparators.get(characterBefore) == WordCharacterClass.Regular) {
                        return null;
                    }
                }
            }
            if (!model.tokenization.isCheapToTokenize(lineNumber)) {
                // Do not force tokenization
                return null;
            }
            model.tokenization.forceTokenization(lineNumber);
            final lineTokens = model.tokenization.getLineTokens(lineNumber);
            final scopedLineTokens = Supports.createScopedLineTokens(lineTokens, beforeColumn - 1);
            if (!pair.shouldAutoClose(scopedLineTokens, beforeColumn - scopedLineTokens.firstCharOffset)) {
                return null;
            }
            // Typing for example a quote could either start a new string, in which case auto-closing is desirable
            // or it could end a previously started string, in which case auto-closing is not desirable
            //
            // In certain cases, it is really not possible to look at the previous token to determine
            // what would happen. That's why we do something really unusual, we pretend to type a different
            // character and ask the tokenizer what the outcome of doing that is: after typing a neutral
            // character, are we in a string (i.e. the quote would most likely end a string) or not?
            //
            final neutralCharacter = pair.findNeutralCharacter();
            if (neutralCharacter != null && neutralCharacter.length > 0) {
                final tokenType = model.tokenization.getTokenTypeIfInsertingCharacter(lineNumber, beforeColumn, neutralCharacter);
                if (!pair.isOK(tokenType)) {
                    return null;
                }
            }
        }
        if (isContainedPairPresent) {
            return pair.close.substring(0, pair.close.length - containedPairClose.length);
        }
        else {
            return pair.close;
        }
    }

    /**
     * Find another auto-closing pair that is contained by the one passed in.
     *
     * e.g. when having [(,)] and [(*,*)] as auto-closing pairs
     * this method will find [(,)] as a containment pair for [(*,*)]
     */
    static function _findContainedAutoClosingPair(config:CursorConfiguration, pair:StandardAutoClosingPairConditional):Null<StandardAutoClosingPairConditional> {
        if (pair.open.length <= 1) {
            return null;
        }
        final lastChar = pair.close.charAt(pair.close.length - 1);
        // get candidates with the same last character as close
        var candidates = config.autoClosingPairs.autoClosingPairsCloseByEnd.get(lastChar);
        if (candidates == null) {
            candidates = [];
        }
        var result:Null<StandardAutoClosingPairConditional> = null;
        for (candidate in candidates) {
            if (candidate.open != pair.open && pair.open.indexOf(candidate.open) != -1 && StringTools.endsWith(pair.close, candidate.close)) {
                if (result == null || candidate.open.length > result.open.length) {
                    result = candidate;
                }
            }
        }
        return result;
    }

    /**
     * Determine if typing `ch` at all `positions` in the `model` results in an
     * auto closing open sequence being typed.
     *
     * Auto closing open sequences can consist of multiple characters, which
     * can lead to ambiguities. In such a case, the longest auto-closing open
     * sequence is returned.
     */
    static function _findAutoClosingPairOpen(config:CursorConfiguration, model:ITextModel, positions:Array<Position>, ch:String):Null<StandardAutoClosingPairConditional> {
        final candidates = config.autoClosingPairs.autoClosingPairsOpenByEnd.get(ch);
        if (candidates == null) {
            return null;
        }
        // Determine which auto-closing pair it is
        var result:Null<StandardAutoClosingPairConditional> = null;
        for (candidate in candidates) {
            if (result == null || candidate.open.length > result.open.length) {
                var candidateIsMatch = true;
                for (position in positions) {
                    final relevantText = model.getValueInRange(new Range(position.lineNumber, position.column - candidate.open.length + 1, position.lineNumber, position.column));
                    if (relevantText + ch != candidate.open) {
                        candidateIsMatch = false;
                        break;
                    }
                }
                if (candidateIsMatch) {
                    result = candidate;
                }
            }
        }
        return result;
    }

    static function _isBeforeClosingBrace(config:CursorConfiguration, lineAfter:String):Bool {
        // If the start of lineAfter can be interpretted as both a starting or ending brace, default to returning false
        final nextChar = lineAfter.charAt(0);
        var potentialStartingBraces = config.autoClosingPairs.autoClosingPairsOpenByStart.get(nextChar);
        if (potentialStartingBraces == null) {
            potentialStartingBraces = [];
        }
        var potentialClosingBraces = config.autoClosingPairs.autoClosingPairsCloseByStart.get(nextChar);
        if (potentialClosingBraces == null) {
            potentialClosingBraces = [];
        }

        var isBeforeStartingBrace = false;
        for (x in potentialStartingBraces) {
            if (StringTools.startsWith(lineAfter, x.open)) {
                isBeforeStartingBrace = true;
                break;
            }
        }
        var isBeforeClosingBrace = false;
        for (x in potentialClosingBraces) {
            if (StringTools.startsWith(lineAfter, x.close)) {
                isBeforeClosingBrace = true;
                break;
            }
        }

        return !isBeforeStartingBrace && isBeforeClosingBrace;
    }

}

class SurroundSelectionOperation {

    public static function getEdits(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, isDoingComposition:Bool):Null<EditOperationResult> {
        if (!isDoingComposition && _isSurroundSelectionType(config, model, selections, ch)) {
            return _runSurroundSelectionType(config, selections, ch);
        }
        return null;
    }

    static function _runSurroundSelectionType(config:CursorConfiguration, selections:Array<Selection>, ch:String):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            final selection = selections[i];
            final closeCharacter = config.surroundingPairs.get(ch);
            commands[i] = new SurroundSelectionCommand(selection, ch, closeCharacter);
        }
        return new EditOperationResult(EditOperationType.Other, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    }

    static function _isSurroundSelectionType(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String):Bool {
        if (!CursorTypeEditOperations.shouldSurroundChar(config, ch) || !config.surroundingPairs.exists(ch)) {
            return false;
        }
        final isTypingAQuoteCharacter = CursorCommon.isQuote(ch);
        for (selection in selections) {
            if (selection.isEmpty()) {
                return false;
            }
            var selectionContainsOnlyWhitespace = true;
            for (lineNumber in selection.startLineNumber...selection.endLineNumber + 1) {
                final lineText = model.getLineContent(lineNumber);
                final startIndex = (lineNumber == selection.startLineNumber ? selection.startColumn - 1 : 0);
                final endIndex = (lineNumber == selection.endLineNumber ? selection.endColumn - 1 : lineText.length);
                final selectedText = lineText.substring(startIndex, endIndex);
                if (CursorTypeEditOperations.containsNonSpaceOrTab(selectedText)) {
                    // this selected text contains something other than whitespace
                    selectionContainsOnlyWhitespace = false;
                    break;
                }
            }
            if (selectionContainsOnlyWhitespace) {
                return false;
            }
            if (isTypingAQuoteCharacter && selection.startLineNumber == selection.endLineNumber && selection.startColumn + 1 == selection.endColumn) {
                final selectionText = model.getValueInRange(selection);
                if (CursorCommon.isQuote(selectionText)) {
                    // Typing a quote character on top of another quote character
                    // => disable surround selection type
                    return false;
                }
            }
        }
        return true;
    }

}

class InterceptorElectricCharOperation {

    public static function getEdits(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, isDoingComposition:Bool):Null<EditOperationResult> {
        // Electric characters make sense only when dealing with a single cursor,
        // as multiple cursors typing brackets for example would interfer with bracket matching
        if (!isDoingComposition && _isTypeInterceptorElectricChar(config, model, selections)) {
            final r = _typeInterceptorElectricChar(prevEditOperationType, config, model, selections[0], ch);
            if (r != null) {
                return r;
            }
        }
        return null;
    }

    static function _isTypeInterceptorElectricChar(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>):Bool {
        if (selections.length == 1 && model.tokenization.isCheapToTokenize(selections[0].getEndPosition().lineNumber)) {
            return true;
        }
        return false;
    }

    static function _typeInterceptorElectricChar(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selection:Selection, ch:String):Null<EditOperationResult> {
        if (!config.electricChars.exists(ch) || !selection.isEmpty()) {
            return null;
        }
        final position = selection.getPosition();
        model.tokenization.forceTokenization(position.lineNumber);
        final lineTokens = model.tokenization.getLineTokens(position.lineNumber);
        var electricAction:Null<IElectricAction>;
        try {
            electricAction = config.onElectricCharacter(ch, lineTokens, position.column);
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
            return null;
        }
        if (electricAction == null) {
            return null;
        }
        if (electricAction.matchOpenBracket != null && electricAction.matchOpenBracket.length > 0) {
            final endColumn = (lineTokens.getLineContent() + ch).lastIndexOf(electricAction.matchOpenBracket) + 1;
            final match = model.bracketPairs.findMatchingBracketUp(electricAction.matchOpenBracket, {
                lineNumber: position.lineNumber,
                column: endColumn
            }, 500 /* give at most 500ms to compute */);
            if (match != null) {
                if (match.startLineNumber == position.lineNumber) {
                    // matched something on the same line => no change in indentation
                    return null;
                }
                final matchLine = model.getLineContent(match.startLineNumber);
                final matchLineIndentation = Strings.getLeadingWhitespace(matchLine);
                final newIndentation = config.normalizeIndentation(matchLineIndentation);
                final lineText = model.getLineContent(position.lineNumber);
                var lineFirstNonBlankColumn = model.getLineFirstNonWhitespaceColumn(position.lineNumber);
                if (lineFirstNonBlankColumn == 0) {
                    lineFirstNonBlankColumn = position.column;
                }
                final prefix = lineText.substring(lineFirstNonBlankColumn - 1, position.column - 1);
                final typeText = newIndentation + prefix + ch;
                final typeSelection = new Range(position.lineNumber, 1, position.lineNumber, position.column);
                final command = new ReplaceCommand(typeSelection, typeText);
                return new EditOperationResult(CursorTypeEditOperations.getTypingOperation(typeText, prevEditOperationType), [command], {
                    shouldPushStackElementBefore: false,
                    shouldPushStackElementAfter: true
                });
            }
        }
        return null;
    }

}

class SimpleCharacterTypeOperation {

    public static function getEdits(prevEditOperationType:EditOperationType, selections:Array<Selection>, ch:String):EditOperationResult {
        // A simple character type
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            commands[i] = new ReplaceCommand(selections[i], ch);
        }

        final opType = CursorTypeEditOperations.getTypingOperation(ch, prevEditOperationType);
        return new EditOperationResult(opType, commands, {
            shouldPushStackElementBefore: CursorTypeEditOperations.shouldPushStackElementBetween(prevEditOperationType, opType),
            shouldPushStackElementAfter: false
        });
    }

}

class EnterOperation {

    public static function getEdits(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, ch:String, isDoingComposition:Bool):Null<EditOperationResult> {
        if (!isDoingComposition && ch == '\n') {
            final commands:Array<Null<ICommand>> = [];
            for (i in 0...selections.length) {
                commands[i] = _enter(config, model, false, selections[i]);
            }
            return new EditOperationResult(EditOperationType.TypingOther, commands, {
                shouldPushStackElementBefore: true,
                shouldPushStackElementAfter: false,
            });
        }
        return null;
    }

    static function _enter(config:CursorConfiguration, model:ITextModel, keepPosition:Bool, range:Range):ICommand {
        if (config.autoIndent == EditorAutoIndentStrategy.None) {
            return CursorTypeEditOperations.typeCommand(range, '\n', keepPosition);
        }
        if (!model.tokenization.isCheapToTokenize(range.getStartPosition().lineNumber) || config.autoIndent == EditorAutoIndentStrategy.Keep) {
            final lineText = model.getLineContent(range.startLineNumber);
            final indentation = Strings.getLeadingWhitespace(lineText).substring(0, range.startColumn - 1);
            return CursorTypeEditOperations.typeCommand(range, '\n' + config.normalizeIndentation(indentation), keepPosition);
        }
        final r = EnterActionUtils.getEnterAction(config.autoIndent, model, range, config.languageConfigurationService);
        if (r != null) {
            if (r.indentAction == IndentAction.None) {
                // Nothing special
                return CursorTypeEditOperations.typeCommand(range, '\n' + config.normalizeIndentation(r.indentation + r.appendText), keepPosition);

            }
            else if (r.indentAction == IndentAction.Indent) {
                // Indent once
                return CursorTypeEditOperations.typeCommand(range, '\n' + config.normalizeIndentation(r.indentation + r.appendText), keepPosition);

            }
            else if (r.indentAction == IndentAction.IndentOutdent) {
                // Ultra special
                final normalIndent = config.normalizeIndentation(r.indentation);
                final increasedIndent = config.normalizeIndentation(r.indentation + r.appendText);
                final typeText = '\n' + increasedIndent + '\n' + normalIndent;
                if (keepPosition) {
                    return new ReplaceCommandWithoutChangingPosition(range, typeText, true);
                }
                else {
                    return new ReplaceCommandWithOffsetCursorState(range, typeText, -1, increasedIndent.length - normalIndent.length, true);
                }
            }
            else if (r.indentAction == IndentAction.Outdent) {
                final actualIndentation = CursorTypeEditOperations.unshiftIndent(config, r.indentation);
                return CursorTypeEditOperations.typeCommand(range, '\n' + config.normalizeIndentation(actualIndentation + r.appendText), keepPosition);
            }
        }

        final lineText = model.getLineContent(range.startLineNumber);
        final indentation = Strings.getLeadingWhitespace(lineText).substring(0, range.startColumn - 1);

        if ((config.autoIndent : Int) >= (EditorAutoIndentStrategy.Full : Int)) {
            final ir = AutoIndent.getIndentForEnter(config.autoIndent, model, range, {
                unshiftIndent: (indent) -> {
                    return CursorTypeEditOperations.unshiftIndent(config, indent);
                },
                shiftIndent: (indent) -> {
                    return CursorTypeEditOperations.shiftIndent(config, indent);
                },
                normalizeIndentation: (indent) -> {
                    return config.normalizeIndentation(indent);
                }
            }, config.languageConfigurationService);

            if (ir != null) {
                var oldEndViewColumn = config.visibleColumnFromColumn(model, range.getEndPosition());
                final oldEndColumn = range.endColumn;
                final newLineContent = model.getLineContent(range.endLineNumber);
                final firstNonWhitespace = Strings.firstNonWhitespaceIndex(newLineContent);
                if (firstNonWhitespace >= 0) {
                    range = range.setEndPosition(range.endLineNumber, Std.int(Math.max(range.endColumn, firstNonWhitespace + 1)));
                }
                else {
                    range = range.setEndPosition(range.endLineNumber, model.getLineMaxColumn(range.endLineNumber));
                }
                if (keepPosition) {
                    return new ReplaceCommandWithoutChangingPosition(range, '\n' + config.normalizeIndentation(ir.afterEnter), true);
                }
                else {
                    var offset = 0;
                    if (oldEndColumn <= firstNonWhitespace + 1) {
                        if (!config.insertSpaces) {
                            oldEndViewColumn = Math.ceil(oldEndViewColumn / config.indentSize);
                        }
                        offset = Std.int(Math.min(oldEndViewColumn + 1 - config.normalizeIndentation(ir.afterEnter).length - 1, 0));
                    }
                    return new ReplaceCommandWithOffsetCursorState(range, '\n' + config.normalizeIndentation(ir.afterEnter), 0, offset, true);
                }
            }
        }
        return CursorTypeEditOperations.typeCommand(range, '\n' + config.normalizeIndentation(indentation), keepPosition);
    }

    public static function lineInsertBefore(config:CursorConfiguration, model:Null<ITextModel>, selections:Null<Array<Selection>>):Array<ICommand> {
        if (model == null || selections == null) {
            return [];
        }
        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            var lineNumber = selections[i].positionLineNumber;
            if (lineNumber == 1) {
                commands[i] = new ReplaceCommandWithoutChangingPosition(new Range(1, 1, 1, 1), '\n');
            }
            else {
                lineNumber--;
                final column = model.getLineMaxColumn(lineNumber);

                commands[i] = _enter(config, model, false, new Range(lineNumber, column, lineNumber, column));
            }
        }
        return commands;
    }

    public static function lineInsertAfter(config:CursorConfiguration, model:Null<ITextModel>, selections:Null<Array<Selection>>):Array<ICommand> {
        if (model == null || selections == null) {
            return [];
        }
        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            final lineNumber = selections[i].positionLineNumber;
            final column = model.getLineMaxColumn(lineNumber);
            commands[i] = _enter(config, model, false, new Range(lineNumber, column, lineNumber, column));
        }
        return commands;
    }

    public static function lineBreakInsert(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>):Array<ICommand> {
        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            commands[i] = _enter(config, model, true, selections[i]);
        }
        return commands;
    }

}

class PasteOperation {

    public static function getEdits(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>, text:String, pasteOnNewLine:Bool, multicursorText:Array<String>):EditOperationResult {
        final distributedPaste = _distributePasteToCursors(config, selections, text, pasteOnNewLine, multicursorText);
        if (distributedPaste != null) {
            haxe.ds.ArraySort.sort(selections, Range.compareRangesUsingStarts);
            return _distributedPaste(config, model, selections, distributedPaste);
        }
        else {
            return _simplePaste(config, model, selections, text, pasteOnNewLine);
        }
    }

    static function _distributePasteToCursors(config:CursorConfiguration, selections:Array<Selection>, text:String, pasteOnNewLine:Bool, multicursorText:Array<String>):Null<Array<String>> {
        if (pasteOnNewLine) {
            return null;
        }
        if (selections.length == 1) {
            return null;
        }
        if (multicursorText != null && multicursorText.length == selections.length) {
            return multicursorText;
        }
        if (config.multiCursorPaste == 'spread') {
            // Try to spread the pasted text in case the line count matches the cursor count
            // Remove trailing \n if present
            if (text.length > 0 && StringTools.fastCodeAt(text, text.length - 1) == CharCode.LineFeed) {
                text = text.substring(0, text.length - 1);
            }
            // Remove trailing \r if present
            if (text.length > 0 && StringTools.fastCodeAt(text, text.length - 1) == CharCode.CarriageReturn) {
                text = text.substring(0, text.length - 1);
            }
            final lines = Strings.splitLines(text);
            if (lines.length == selections.length) {
                return lines;
            }
        }
        return null;
    }

    static function _distributedPaste(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>, text:Array<String>):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            commands[i] = new ReplaceCommand(selections[i], text[i]);
        }
        return new EditOperationResult(EditOperationType.Other, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    }

    static function _simplePaste(config:CursorConfiguration, model:ICursorSimpleModel, selections:Array<Selection>, text:String, pasteOnNewLine:Bool):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            final selection = selections[i];
            final position = selection.getPosition();
            if (pasteOnNewLine && !selection.isEmpty()) {
                pasteOnNewLine = false;
            }
            if (pasteOnNewLine && text.indexOf('\n') != text.length - 1) {
                pasteOnNewLine = false;
            }
            if (pasteOnNewLine) {
                // Paste entire line at the beginning of line
                final typeSelection = new Range(position.lineNumber, 1, position.lineNumber, 1);
                commands[i] = new ReplaceCommandThatPreservesSelection(typeSelection, text, selection, true);
            }
            else {
                commands[i] = new ReplaceCommand(selection, text);
            }
        }
        return new EditOperationResult(EditOperationType.Other, commands, {
            shouldPushStackElementBefore: true,
            shouldPushStackElementAfter: true
        });
    }

}

class CompositionOperation {

    public static function getEdits(prevEditOperationType:EditOperationType, config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int):EditOperationResult {
        final commands = [for (selection in selections) _compositionType(model, selection, text, replacePrevCharCnt, replaceNextCharCnt, positionDelta)];
        return new EditOperationResult(EditOperationType.TypingOther, commands, {
            shouldPushStackElementBefore: CursorTypeEditOperations.shouldPushStackElementBetween(prevEditOperationType, EditOperationType.TypingOther),
            shouldPushStackElementAfter: false
        });
    }

    static function _compositionType(model:ITextModel, selection:Selection, text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int):Null<ICommand> {
        if (!selection.isEmpty()) {
            // looks like https://github.com/microsoft/vscode/issues/2773
            // where a cursor operation occurred before a canceled composition
            // => ignore composition
            return null;
        }
        final pos = selection.getPosition();
        final startColumn = Std.int(Math.max(1, pos.column - replacePrevCharCnt));
        final endColumn = Std.int(Math.min(model.getLineMaxColumn(pos.lineNumber), pos.column + replaceNextCharCnt));
        final range = new Range(pos.lineNumber, startColumn, pos.lineNumber, endColumn);
        final oldText = model.getValueInRange(range);
        if (oldText == text && positionDelta == 0) {
            // => ignore composition that doesn't do anything
            return null;
        }
        return new ReplaceCommandWithOffsetCursorState(range, text, 0, positionDelta);
    }

}

class TypeWithoutInterceptorsOperation {

    public static function getEdits(prevEditOperationType:EditOperationType, selections:Array<Selection>, str:String):EditOperationResult {
        final commands:Array<Null<ICommand>> = [];
        for (i in 0...selections.length) {
            commands[i] = new ReplaceCommand(selections[i], str);
        }
        final opType = CursorTypeEditOperations.getTypingOperation(str, prevEditOperationType);
        return new EditOperationResult(opType, commands, {
            shouldPushStackElementBefore: CursorTypeEditOperations.shouldPushStackElementBetween(prevEditOperationType, opType),
            shouldPushStackElementAfter: false
        });
    }

}

class TabOperation {

    public static function getCommands(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>):Array<ICommand> {
        final commands:Array<ICommand> = [];
        for (i in 0...selections.length) {
            final selection = selections[i];
            if (selection.isEmpty()) {
                final lineText = model.getLineContent(selection.startLineNumber);
                if (AutoIndent.isEmptyOrWhitespace(lineText) && model.tokenization.isCheapToTokenize(selection.startLineNumber)) {
                    var goodIndent = _goodIndentForLine(config, model, selection.startLineNumber);
                    if (goodIndent == null || goodIndent.length == 0) {
                        goodIndent = '\t';
                    }
                    final possibleTypeText = config.normalizeIndentation(goodIndent);
                    if (!StringTools.startsWith(lineText, possibleTypeText)) {
                        commands[i] = new ReplaceCommand(new Range(selection.startLineNumber, 1, selection.startLineNumber, lineText.length + 1), possibleTypeText, true);
                        continue;
                    }
                }
                commands[i] = _replaceJumpToNextIndent(config, model, selection, true);
            }
            else {
                if (selection.startLineNumber == selection.endLineNumber) {
                    final lineMaxColumn = model.getLineMaxColumn(selection.startLineNumber);
                    if (selection.startColumn != 1 || selection.endColumn != lineMaxColumn) {
                        // This is a single line selection that is not the entire line
                        commands[i] = _replaceJumpToNextIndent(config, model, selection, false);
                        continue;
                    }
                }
                commands[i] = new ShiftCommand(selection, {
                    isUnshift: false,
                    tabSize: config.tabSize,
                    indentSize: config.indentSize,
                    insertSpaces: config.insertSpaces,
                    useTabStops: config.useTabStops,
                    autoIndent: config.autoIndent
                }, config.languageConfigurationService);
            }
        }
        return commands;
    }

    static function _goodIndentForLine(config:CursorConfiguration, model:ITextModel, lineNumber:Int):Null<String> {
        // Monaco's `action: IndentAction | EnterAction | null`: only an IndentAction is ever stored
        var action:Null<IndentAction> = null;
        var indentation:String = '';
        final expectedIndentAction = AutoIndent.getInheritIndentForLine(config.autoIndent, new TextModelVirtualModel(model), lineNumber, false, config.languageConfigurationService);
        if (expectedIndentAction != null) {
            action = expectedIndentAction.action;
            indentation = expectedIndentAction.indentation;
        }
        else if (lineNumber > 1) {
            var lastLineNumber = lineNumber - 1;
            while (lastLineNumber >= 1) {
                final lineText = model.getLineContent(lastLineNumber);
                final nonWhitespaceIdx = Strings.lastNonWhitespaceIndex(lineText);
                if (nonWhitespaceIdx >= 0) {
                    break;
                }
                lastLineNumber--;
            }
            if (lastLineNumber < 1) {
                // No previous line with content found
                return null;
            }
            final maxColumn = model.getLineMaxColumn(lastLineNumber);
            final expectedEnterAction = EnterActionUtils.getEnterAction(config.autoIndent, model, new Range(lastLineNumber, maxColumn, lastLineNumber, maxColumn), config.languageConfigurationService);
            if (expectedEnterAction != null) {
                indentation = expectedEnterAction.indentation + expectedEnterAction.appendText;
            }
        }
        // `if (action)`: IndentAction.None is 0, falsy
        if (action != null && action != IndentAction.None) {
            if (action == IndentAction.Indent) {
                indentation = CursorTypeEditOperations.shiftIndent(config, indentation);
            }
            if (action == IndentAction.Outdent) {
                indentation = CursorTypeEditOperations.unshiftIndent(config, indentation);
            }
            indentation = config.normalizeIndentation(indentation);
        }
        if (indentation.length == 0) {
            return null;
        }
        return indentation;
    }

    static function _replaceJumpToNextIndent(config:CursorConfiguration, model:ICursorSimpleModel, selection:Selection, insertsAutoWhitespace:Bool):ReplaceCommand {
        var typeText = '';
        final position = selection.getStartPosition();
        if (config.insertSpaces) {
            final visibleColumnFromColumn = config.visibleColumnFromColumn(model, position);
            final indentSize = config.indentSize;
            final spacesCnt = indentSize - (visibleColumnFromColumn % indentSize);
            for (i in 0...spacesCnt) {
                typeText += ' ';
            }
        }
        else {
            typeText = '\t';
        }
        return new ReplaceCommand(selection, typeText, insertsAutoWhitespace);
    }

}

class BaseTypeWithAutoClosingCommand extends ReplaceCommandWithOffsetCursorState {

    final _openCharacter:String;
    final _closeCharacter:String;
    public var closeCharacterRange:Null<Range>;
    public var enclosingRange:Null<Range>;

    public function new(selection:Selection, text:String, lineNumberDeltaOffset:Int, columnDeltaOffset:Int, openCharacter:String, closeCharacter:String) {
        super(selection, text, lineNumberDeltaOffset, columnDeltaOffset);
        this._openCharacter = openCharacter;
        this._closeCharacter = closeCharacter;
        this.closeCharacterRange = null;
        this.enclosingRange = null;
    }

    function _computeCursorStateWithRange(model:ITextModel, range:Range, helper:ICursorStateComputerData):Selection {
        this.closeCharacterRange = new Range(range.startLineNumber, range.endColumn - this._closeCharacter.length, range.endLineNumber, range.endColumn);
        this.enclosingRange = new Range(range.startLineNumber, range.endColumn - this._openCharacter.length - this._closeCharacter.length, range.endLineNumber, range.endColumn);
        return super.computeCursorState(model, helper);
    }

}

class TypeWithAutoClosingCommand extends BaseTypeWithAutoClosingCommand {

    public function new(selection:Selection, openCharacter:String, insertOpenCharacter:Bool, closeCharacter:String) {
        final text = (insertOpenCharacter ? openCharacter : '') + closeCharacter;
        final lineNumberDeltaOffset = 0;
        final columnDeltaOffset = -closeCharacter.length;
        super(selection, text, lineNumberDeltaOffset, columnDeltaOffset, openCharacter, closeCharacter);
    }

    override public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        final range = inverseEditOperations[0].range;
        return this._computeCursorStateWithRange(model, range, helper);
    }

}

class TypeWithIndentationAndAutoClosingCommand extends BaseTypeWithAutoClosingCommand {

    final _autoIndentationEdit:RangeAndText;
    final _autoClosingEdit:RangeAndText;

    public function new(autoIndentationEdit:RangeAndText, selection:Selection, openCharacter:String, closeCharacter:String) {
        final text = openCharacter + closeCharacter;
        final lineNumberDeltaOffset = 0;
        final columnDeltaOffset = openCharacter.length;
        super(selection, text, lineNumberDeltaOffset, columnDeltaOffset, openCharacter, closeCharacter);
        this._autoIndentationEdit = autoIndentationEdit;
        this._autoClosingEdit = {range: selection, text: text};
    }

    override public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        builder.addTrackedEditOperation(this._autoIndentationEdit.range, this._autoIndentationEdit.text);
        builder.addTrackedEditOperation(this._autoClosingEdit.range, this._autoClosingEdit.text);
    }

    override public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        if (inverseEditOperations.length != 2) {
            throw new haxe.Exception('There should be two inverse edit operations!');
        }
        final range1 = inverseEditOperations[0].range;
        final range2 = inverseEditOperations[1].range;
        final range = range1.plusRange(range2);
        return this._computeCursorStateWithRange(model, range, helper);
    }

}

/**
 * Module functions of cursorTypeEditOperations.ts.
 */
class CursorTypeEditOperations {

    /**
     * `/[^ \\t]/.test(text)`.
     */
    public static function containsNonSpaceOrTab(text:String):Bool {
        for (i in 0...text.length) {
            final c = StringTools.fastCodeAt(text, i);
            if (c != CharCode.Space && c != CharCode.Tab) {
                return true;
            }
        }
        return false;
    }

    public static function getTypingOperation(typedText:String, previousTypingOperation:EditOperationType):EditOperationType {
        if (typedText == ' ') {
            return previousTypingOperation == EditOperationType.TypingFirstSpace
                || previousTypingOperation == EditOperationType.TypingConsecutiveSpace
                ? EditOperationType.TypingConsecutiveSpace
                : EditOperationType.TypingFirstSpace;
        }

        return EditOperationType.TypingOther;
    }

    public static function shouldPushStackElementBetween(previousTypingOperation:EditOperationType, typingOperation:EditOperationType):Bool {
        if (isTypingOperation(previousTypingOperation) && !isTypingOperation(typingOperation)) {
            // Always set an undo stop before non-type operations
            return true;
        }
        if (previousTypingOperation == EditOperationType.TypingFirstSpace) {
            // `abc |d`: No undo stop
            // `abc  |d`: Undo stop
            return false;
        }
        // Insert undo stop between different operation types
        return normalizeOperationType(previousTypingOperation) != normalizeOperationType(typingOperation);
    }

    /**
     * Monaco returns `'space'` for the space operations: -1 here.
     */
    static function normalizeOperationType(type:EditOperationType):Int {
        return (type == EditOperationType.TypingConsecutiveSpace || type == EditOperationType.TypingFirstSpace)
            ? -1
            : type;
    }

    static function isTypingOperation(type:EditOperationType):Bool {
        return type == EditOperationType.TypingOther
            || type == EditOperationType.TypingFirstSpace
            || type == EditOperationType.TypingConsecutiveSpace;
    }

    public static function isAutoClosingOvertype(config:CursorConfiguration, model:ITextModel, selections:Array<Selection>, autoClosedCharacters:Array<Range>, ch:String):Bool {
        if (config.autoClosingOvertype == 'never') {
            return false;
        }
        if (!config.autoClosingPairs.autoClosingPairsCloseSingleChar.exists(ch)) {
            return false;
        }
        for (i in 0...selections.length) {
            final selection = selections[i];
            if (!selection.isEmpty()) {
                return false;
            }
            final position = selection.getPosition();
            final lineText = model.getLineContent(position.lineNumber);
            final afterCharacter = lineText.charAt(position.column - 1);
            if (afterCharacter != ch) {
                return false;
            }
            // Do not over-type quotes after a backslash
            final chIsQuote = CursorCommon.isQuote(ch);
            final beforeCharacter = position.column > 2 ? StringTools.fastCodeAt(lineText, position.column - 2) : CharCode.Null;
            if (beforeCharacter == CharCode.Backslash && chIsQuote) {
                return false;
            }
            // Must over-type a closing character typed by the editor
            if (config.autoClosingOvertype == 'auto') {
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

    public static function typeCommand(range:Range, text:String, keepPosition:Bool):ICommand {
        if (keepPosition) {
            return new ReplaceCommandWithoutChangingPosition(range, text, true);
        }
        else {
            return new ReplaceCommand(range, text, true);
        }
    }

    public static function shiftIndent(config:CursorConfiguration, indentation:String, ?count:Int):String {
        if (count == null || count == 0) {
            count = 1;
        }
        return ShiftCommand.shiftIndent(indentation, indentation.length + count, config.tabSize, config.indentSize, config.insertSpaces);
    }

    public static function unshiftIndent(config:CursorConfiguration, indentation:String, ?count:Int):String {
        if (count == null || count == 0) {
            count = 1;
        }
        return ShiftCommand.unshiftIndent(indentation, indentation.length + count, config.tabSize, config.indentSize, config.insertSpaces);
    }

    public static function shouldSurroundChar(config:CursorConfiguration, ch:String):Bool {
        if (CursorCommon.isQuote(ch)) {
            return (config.autoSurround == 'quotes' || config.autoSurround == 'languageDefined');
        }
        else {
            // Character is a bracket
            return (config.autoSurround == 'brackets' || config.autoSurround == 'languageDefined');
        }
    }

}
