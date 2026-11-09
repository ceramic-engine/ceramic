// Ported from vscode src/vs/editor/contrib/linesOperations/browser/moveLinesCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.linesOperations.view;

import cityscape.base.common.Strings;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.commands.ShiftCommand;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.AutoIndent;
import cityscape.common.languages.EnterAction.EnterActionUtils;
import cityscape.common.languages.LanguageConfiguration.CompleteEnterAction;
import cityscape.common.languages.LanguageConfiguration.IndentAction;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.languages.supports.IndentRules.IndentConsts;
import cityscape.common.tokens.LineTokens.IViewLineTokens;
import cityscape.contrib.indentation.common.IndentUtils;

/**
 * Monaco's `IVirtualModel` object literals of moveLinesCommand.ts: the
 * content and tokens of each line come from functions; the language comes
 * from the model.
 */
private class MoveLinesVirtualModel implements IVirtualModel implements IVirtualModelTokenization {

    final model:ITextModel;
    final _getLineTokens:(lineNumber:Int) -> IViewLineTokens;
    final _getLineContent:(lineNumber:Int) -> String;

    public function new(model:ITextModel, getLineTokens:(lineNumber:Int) -> IViewLineTokens, getLineContent:(lineNumber:Int) -> String) {
        this.model = model;
        this._getLineTokens = getLineTokens;
        this._getLineContent = getLineContent;
    }

    public var tokenization(get, never):IVirtualModelTokenization;
    inline function get_tokenization():IVirtualModelTokenization {
        return this;
    }

    public function getLineContent(lineNumber:Int):String {
        return _getLineContent(lineNumber);
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        return _getLineTokens(lineNumber);
    }

    public function getLanguageId():String {
        return model.getLanguageId();
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return model.getLanguageIdAtPosition(lineNumber, column);
    }

    public function forceTokenization(lineNumber:Int):Void {
        // Monaco's literals have no `forceTokenization`
    }

}

class MoveLinesCommand implements ICommand {

    final _selection:Selection;
    final _isMovingDown:Bool;
    final _autoIndent:EditorAutoIndentStrategy;

    var _selectionId:Null<String>;
    var _moveEndPositionDown:Bool = false;
    var _moveEndLineSelectionShrink:Bool;

    final _languageConfigurationService:ILanguageConfigurationService;

    public final insertsAutoWhitespace:Bool = false;

    public function new(selection:Selection, isMovingDown:Bool, autoIndent:EditorAutoIndentStrategy, languageConfigurationService:ILanguageConfigurationService) {
        this._selection = selection;
        this._isMovingDown = isMovingDown;
        this._autoIndent = autoIndent;
        this._selectionId = null;
        this._moveEndLineSelectionShrink = false;
        this._languageConfigurationService = languageConfigurationService;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {

        final modelLineCount = model.getLineCount();

        if (this._isMovingDown && this._selection.endLineNumber == modelLineCount) {
            this._selectionId = builder.trackSelection(this._selection);
            return;
        }
        if (!this._isMovingDown && this._selection.startLineNumber == 1) {
            this._selectionId = builder.trackSelection(this._selection);
            return;
        }

        this._moveEndPositionDown = false;
        var s = this._selection;

        if (s.startLineNumber < s.endLineNumber && s.endColumn == 1) {
            this._moveEndPositionDown = true;
            s = s.setEndPosition(s.endLineNumber - 1, model.getLineMaxColumn(s.endLineNumber - 1));
        }

        final modelOptions = model.getOptions();
        final tabSize = modelOptions.tabSize;
        final indentSize = modelOptions.indentSize;
        final insertSpaces = modelOptions.insertSpaces;
        final indentConverter = this.buildIndentConverter(tabSize, indentSize, insertSpaces);

        if (s.startLineNumber == s.endLineNumber && model.getLineMaxColumn(s.startLineNumber) == 1) {
            // Current line is empty
            final lineNumber = s.startLineNumber;
            final otherLineNumber = (this._isMovingDown ? lineNumber + 1 : lineNumber - 1);

            if (model.getLineMaxColumn(otherLineNumber) == 1) {
                // Other line number is empty too, so no editing is needed
                // Add a no-op to force running by the model
                builder.addEditOperation(new Range(1, 1, 1, 1), null);
            }
            else {
                // Type content from other line number on line number
                builder.addEditOperation(new Range(lineNumber, 1, lineNumber, 1), model.getLineContent(otherLineNumber));

                // Remove content from other line number
                builder.addEditOperation(new Range(otherLineNumber, 1, otherLineNumber, model.getLineMaxColumn(otherLineNumber)), null);
            }
            // Track selection at the other line number
            s = new Selection(otherLineNumber, 1, otherLineNumber, 1);

        }
        else {

            var movingLineNumber:Int;
            var movingLineText:String;

            if (this._isMovingDown) {
                movingLineNumber = s.endLineNumber + 1;
                movingLineText = model.getLineContent(movingLineNumber);
                // Delete line that needs to be moved
                builder.addEditOperation(new Range(movingLineNumber - 1, model.getLineMaxColumn(movingLineNumber - 1), movingLineNumber, model.getLineMaxColumn(movingLineNumber)), null);

                var insertingText = movingLineText;

                if (this.shouldAutoIndent(model, s)) {
                    final movingLineMatchResult = this.matchEnterRule(model, indentConverter, tabSize, movingLineNumber, s.startLineNumber - 1);
                    // if s.startLineNumber - 1 matches onEnter rule, we still honor that.
                    if (movingLineMatchResult != null) {
                        final oldIndentation = Strings.getLeadingWhitespace(model.getLineContent(movingLineNumber));
                        final newSpaceCnt = movingLineMatchResult + IndentUtils.getSpaceCnt(oldIndentation, tabSize);
                        final newIndentation = IndentUtils.generateIndent(newSpaceCnt, tabSize, insertSpaces);
                        insertingText = newIndentation + this.trimStart(movingLineText);
                    }
                    else {
                        // no enter rule matches, let's check indentatin rules then.
                        final sLine = s.startLineNumber;
                        final virtualModel = new MoveLinesVirtualModel(
                            model,
                            (lineNumber:Int) -> {
                                if (lineNumber == sLine) {
                                    return model.tokenization.getLineTokens(movingLineNumber);
                                }
                                else {
                                    return model.tokenization.getLineTokens(lineNumber);
                                }
                            },
                            (lineNumber:Int) -> {
                                if (lineNumber == sLine) {
                                    return model.getLineContent(movingLineNumber);
                                }
                                else {
                                    return model.getLineContent(lineNumber);
                                }
                            }
                        );
                        final indentOfMovingLine = AutoIndent.getGoodIndentForLine(
                            this._autoIndent,
                            virtualModel,
                            model.getLanguageIdAtPosition(movingLineNumber, 1),
                            s.startLineNumber,
                            indentConverter,
                            this._languageConfigurationService
                        );
                        if (indentOfMovingLine != null) {
                            final oldIndentation = Strings.getLeadingWhitespace(model.getLineContent(movingLineNumber));
                            final newSpaceCnt = IndentUtils.getSpaceCnt(indentOfMovingLine, tabSize);
                            final oldSpaceCnt = IndentUtils.getSpaceCnt(oldIndentation, tabSize);
                            if (newSpaceCnt != oldSpaceCnt) {
                                final newIndentation = IndentUtils.generateIndent(newSpaceCnt, tabSize, insertSpaces);
                                insertingText = newIndentation + this.trimStart(movingLineText);
                            }
                        }
                    }

                    // add edit operations for moving line first to make sure it's executed after we make indentation change
                    // to s.startLineNumber
                    builder.addEditOperation(new Range(s.startLineNumber, 1, s.startLineNumber, 1), insertingText + '\n');

                    final ret = this.matchEnterRuleMovingDown(model, indentConverter, tabSize, s.startLineNumber, movingLineNumber, insertingText);

                    // check if the line being moved before matches onEnter rules, if so let's adjust the indentation by onEnter rules.
                    if (ret != null) {
                        if (ret != 0) {
                            this.getIndentEditsOfMovingBlock(model, builder, s, tabSize, insertSpaces, ret);
                        }
                    }
                    else {
                        // it doesn't match onEnter rules, let's check indentation rules then.
                        final sStart = s.startLineNumber;
                        final sEnd = s.endLineNumber;
                        final textToInsert = insertingText;
                        final virtualModel = new MoveLinesVirtualModel(
                            model,
                            (lineNumber:Int) -> {
                                if (lineNumber == sStart) {
                                    // TODO@aiday-mar: the tokens here don't correspond exactly to the corresponding content (after indentation adjustment), have to fix this.
                                    return model.tokenization.getLineTokens(movingLineNumber);
                                }
                                else if (lineNumber >= sStart + 1 && lineNumber <= sEnd + 1) {
                                    return model.tokenization.getLineTokens(lineNumber - 1);
                                }
                                else {
                                    return model.tokenization.getLineTokens(lineNumber);
                                }
                            },
                            (lineNumber:Int) -> {
                                if (lineNumber == sStart) {
                                    return textToInsert;
                                }
                                else if (lineNumber >= sStart + 1 && lineNumber <= sEnd + 1) {
                                    return model.getLineContent(lineNumber - 1);
                                }
                                else {
                                    return model.getLineContent(lineNumber);
                                }
                            }
                        );

                        final newIndentatOfMovingBlock = AutoIndent.getGoodIndentForLine(
                            this._autoIndent,
                            virtualModel,
                            model.getLanguageIdAtPosition(movingLineNumber, 1),
                            s.startLineNumber + 1,
                            indentConverter,
                            this._languageConfigurationService
                        );

                        if (newIndentatOfMovingBlock != null) {
                            final oldIndentation = Strings.getLeadingWhitespace(model.getLineContent(s.startLineNumber));
                            final newSpaceCnt = IndentUtils.getSpaceCnt(newIndentatOfMovingBlock, tabSize);
                            final oldSpaceCnt = IndentUtils.getSpaceCnt(oldIndentation, tabSize);
                            if (newSpaceCnt != oldSpaceCnt) {
                                final spaceCntOffset = newSpaceCnt - oldSpaceCnt;

                                this.getIndentEditsOfMovingBlock(model, builder, s, tabSize, insertSpaces, spaceCntOffset);
                            }
                        }
                    }
                }
                else {
                    // Insert line that needs to be moved before
                    builder.addEditOperation(new Range(s.startLineNumber, 1, s.startLineNumber, 1), insertingText + '\n');
                }
            }
            else {
                movingLineNumber = s.startLineNumber - 1;
                movingLineText = model.getLineContent(movingLineNumber);

                // Delete line that needs to be moved
                builder.addEditOperation(new Range(movingLineNumber, 1, movingLineNumber + 1, 1), null);

                // Insert line that needs to be moved after
                builder.addEditOperation(new Range(s.endLineNumber, model.getLineMaxColumn(s.endLineNumber), s.endLineNumber, model.getLineMaxColumn(s.endLineNumber)), '\n' + movingLineText);

                if (this.shouldAutoIndent(model, s)) {
                    final sStart = s.startLineNumber;
                    final virtualModel = new MoveLinesVirtualModel(
                        model,
                        (lineNumber:Int) -> {
                            if (lineNumber == movingLineNumber) {
                                return model.tokenization.getLineTokens(sStart);
                            }
                            else {
                                return model.tokenization.getLineTokens(lineNumber);
                            }
                        },
                        (lineNumber:Int) -> {
                            if (lineNumber == movingLineNumber) {
                                return model.getLineContent(sStart);
                            }
                            else {
                                return model.getLineContent(lineNumber);
                            }
                        }
                    );

                    final ret = this.matchEnterRule(model, indentConverter, tabSize, s.startLineNumber, s.startLineNumber - 2);
                    // check if s.startLineNumber - 2 matches onEnter rules, if so adjust the moving block by onEnter rules.
                    if (ret != null) {
                        if (ret != 0) {
                            this.getIndentEditsOfMovingBlock(model, builder, s, tabSize, insertSpaces, ret);
                        }
                    }
                    else {
                        // it doesn't match any onEnter rule, let's check indentation rules then.
                        final indentOfFirstLine = AutoIndent.getGoodIndentForLine(
                            this._autoIndent,
                            virtualModel,
                            model.getLanguageIdAtPosition(s.startLineNumber, 1),
                            movingLineNumber,
                            indentConverter,
                            this._languageConfigurationService
                        );
                        if (indentOfFirstLine != null) {
                            // adjust the indentation of the moving block
                            final oldIndent = Strings.getLeadingWhitespace(model.getLineContent(s.startLineNumber));
                            final newSpaceCnt = IndentUtils.getSpaceCnt(indentOfFirstLine, tabSize);
                            final oldSpaceCnt = IndentUtils.getSpaceCnt(oldIndent, tabSize);
                            if (newSpaceCnt != oldSpaceCnt) {
                                final spaceCntOffset = newSpaceCnt - oldSpaceCnt;

                                this.getIndentEditsOfMovingBlock(model, builder, s, tabSize, insertSpaces, spaceCntOffset);
                            }
                        }
                    }
                }
            }
        }

        this._selectionId = builder.trackSelection(s);
    }

    function buildIndentConverter(tabSize:Int, indentSize:Int, insertSpaces:Bool):IIndentConverter {
        return {
            shiftIndent: (indentation:String) -> {
                return ShiftCommand.shiftIndent(indentation, indentation.length + 1, tabSize, indentSize, insertSpaces);
            },
            unshiftIndent: (indentation:String) -> {
                return ShiftCommand.unshiftIndent(indentation, indentation.length + 1, tabSize, indentSize, insertSpaces);
            }
        };
    }

    function parseEnterResult(model:ITextModel, indentConverter:IIndentConverter, tabSize:Int, line:Int, enter:Null<CompleteEnterAction>):Null<Int> {
        if (enter != null) {
            var enterPrefix = enter.indentation;

            if (enter.indentAction == IndentAction.None) {
                enterPrefix = enter.indentation + enter.appendText;
            }
            else if (enter.indentAction == IndentAction.Indent) {
                enterPrefix = enter.indentation + enter.appendText;
            }
            else if (enter.indentAction == IndentAction.IndentOutdent) {
                enterPrefix = enter.indentation;
            }
            else if (enter.indentAction == IndentAction.Outdent) {
                enterPrefix = indentConverter.unshiftIndent(enter.indentation) + enter.appendText;
            }
            final movingLineText = model.getLineContent(line);
            if (this.trimStart(movingLineText).indexOf(this.trimStart(enterPrefix)) >= 0) {
                final oldIndentation = Strings.getLeadingWhitespace(model.getLineContent(line));
                var newIndentation = Strings.getLeadingWhitespace(enterPrefix);
                final indentMetadataOfMovelingLine = AutoIndent.getIndentMetadata(model, line, this._languageConfigurationService);
                if (indentMetadataOfMovelingLine != null && (indentMetadataOfMovelingLine & IndentConsts.DECREASE_MASK) != 0) {
                    newIndentation = indentConverter.unshiftIndent(newIndentation);
                }
                final newSpaceCnt = IndentUtils.getSpaceCnt(newIndentation, tabSize);
                final oldSpaceCnt = IndentUtils.getSpaceCnt(oldIndentation, tabSize);
                return newSpaceCnt - oldSpaceCnt;
            }
        }

        return null;
    }

    /**
     *
     * @param model
     * @param indentConverter
     * @param tabSize
     * @param line the line moving down
     * @param futureAboveLineNumber the line which will be at the `line` position
     * @param futureAboveLineText
     */
    function matchEnterRuleMovingDown(model:ITextModel, indentConverter:IIndentConverter, tabSize:Int, line:Int, futureAboveLineNumber:Int, futureAboveLineText:String):Null<Int> {
        if (Strings.lastNonWhitespaceIndex(futureAboveLineText) >= 0) {
            // break
            final maxColumn = model.getLineMaxColumn(futureAboveLineNumber);
            final enter = EnterActionUtils.getEnterAction(this._autoIndent, model, new Range(futureAboveLineNumber, maxColumn, futureAboveLineNumber, maxColumn), this._languageConfigurationService);
            return this.parseEnterResult(model, indentConverter, tabSize, line, enter);
        }
        else {
            // go upwards, starting from `line - 1`
            var validPrecedingLine = line - 1;
            while (validPrecedingLine >= 1) {
                final lineContent = model.getLineContent(validPrecedingLine);
                final nonWhitespaceIdx = Strings.lastNonWhitespaceIndex(lineContent);

                if (nonWhitespaceIdx >= 0) {
                    break;
                }

                validPrecedingLine--;
            }

            if (validPrecedingLine < 1 || line > model.getLineCount()) {
                return null;
            }

            final maxColumn = model.getLineMaxColumn(validPrecedingLine);
            final enter = EnterActionUtils.getEnterAction(this._autoIndent, model, new Range(validPrecedingLine, maxColumn, validPrecedingLine, maxColumn), this._languageConfigurationService);
            return this.parseEnterResult(model, indentConverter, tabSize, line, enter);
        }
    }

    function matchEnterRule(model:ITextModel, indentConverter:IIndentConverter, tabSize:Int, line:Int, oneLineAbove:Int, ?previousLineText:String):Null<Int> {
        var validPrecedingLine = oneLineAbove;
        while (validPrecedingLine >= 1) {
            // ship empty lines as empty lines just inherit indentation
            var lineContent;
            if (validPrecedingLine == oneLineAbove && previousLineText != null) {
                lineContent = previousLineText;
            }
            else {
                lineContent = model.getLineContent(validPrecedingLine);
            }

            final nonWhitespaceIdx = Strings.lastNonWhitespaceIndex(lineContent);
            if (nonWhitespaceIdx >= 0) {
                break;
            }
            validPrecedingLine--;
        }

        if (validPrecedingLine < 1 || line > model.getLineCount()) {
            return null;
        }

        final maxColumn = model.getLineMaxColumn(validPrecedingLine);
        final enter = EnterActionUtils.getEnterAction(this._autoIndent, model, new Range(validPrecedingLine, maxColumn, validPrecedingLine, maxColumn), this._languageConfigurationService);
        return this.parseEnterResult(model, indentConverter, tabSize, line, enter);
    }

    /**
     * Monaco's `str.replace(/^\s+/, '')` (JavaScript's `\s`).
     */
    function trimStart(str:String):String {
        var i = 0;
        final len = str.length;
        while (i < len && isJsWhitespace(StringTools.fastCodeAt(str, i))) {
            i++;
        }
        return i == 0 ? str : str.substring(i);
    }

    static function isJsWhitespace(c:Int):Bool {
        return (c >= 9 && c <= 13) || c == 32 || c == 0xA0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 || c == 0xFEFF;
    }

    function shouldAutoIndent(model:ITextModel, selection:Selection):Bool {
        if ((this._autoIndent : Int) < (EditorAutoIndentStrategy.Full : Int)) {
            return false;
        }
        // if it's not easy to tokenize, we stop auto indent.
        if (!model.tokenization.isCheapToTokenize(selection.startLineNumber)) {
            return false;
        }
        final languageAtSelectionStart = model.getLanguageIdAtPosition(selection.startLineNumber, 1);
        final languageAtSelectionEnd = model.getLanguageIdAtPosition(selection.endLineNumber, 1);

        if (languageAtSelectionStart != languageAtSelectionEnd) {
            return false;
        }

        if (this._languageConfigurationService.getLanguageConfiguration(languageAtSelectionStart).indentRulesSupport == null) {
            return false;
        }

        return true;
    }

    function getIndentEditsOfMovingBlock(model:ITextModel, builder:IEditOperationBuilder, s:Selection, tabSize:Int, insertSpaces:Bool, offset:Int):Void {
        for (i in s.startLineNumber...s.endLineNumber + 1) {
            final lineContent = model.getLineContent(i);
            final originalIndent = Strings.getLeadingWhitespace(lineContent);
            final originalSpacesCnt = IndentUtils.getSpaceCnt(originalIndent, tabSize);
            final newSpacesCnt = originalSpacesCnt + offset;
            final newIndent = IndentUtils.generateIndent(newSpacesCnt, tabSize, insertSpaces);

            if (newIndent != originalIndent) {
                builder.addEditOperation(new Range(i, 1, i, originalIndent.length + 1), newIndent);

                if (i == s.endLineNumber && s.endColumn <= originalIndent.length + 1 && newIndent == '') {
                    // as users select part of the original indent white spaces
                    // when we adjust the indentation of endLine, we should adjust the cursor position as well.
                    this._moveEndLineSelectionShrink = true;
                }
            }

        }
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        var result = helper.getTrackedSelection(this._selectionId);

        if (this._moveEndPositionDown) {
            result = result.setEndPosition(result.endLineNumber + 1, 1);
        }

        if (this._moveEndLineSelectionShrink && result.startLineNumber < result.endLineNumber) {
            result = result.setEndPosition(result.endLineNumber, 2);
        }

        return result;
    }

}
