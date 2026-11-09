// Ported from vscode src/vs/editor/common/commands/shiftCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.commands;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.EditorCommon;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.EnterAction.EnterActionUtils;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;

typedef IShiftCommandOpts = {
    var isUnshift:Bool;
    var tabSize:Int;
    var indentSize:Int;
    var insertSpaces:Bool;
    var useTabStops:Bool;
    var autoIndent:EditorAutoIndentStrategy;
}

class ShiftCommand implements ICommand {

    /**
     * Monaco's `cachedStringRepeat`: Cityscape keeps no cache in statics
     * (the strings are short).
     */
    static function cachedStringRepeat(str:String, count:Int):String {
        if (count <= 0) {
            return '';
        }
        final buf = new StringBuf();
        for (i in 0...count) {
            buf.add(str);
        }
        return buf.toString();
    }

    public static function unshiftIndent(line:String, column:Int, tabSize:Int, indentSize:Int, insertSpaces:Bool):String {
        // Determine the visible column where the content starts
        final contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(line, column, tabSize);

        if (insertSpaces) {
            final indent = cachedStringRepeat(' ', indentSize);
            final desiredTabStop = CursorColumns.prevIndentTabStop(contentStartVisibleColumn, indentSize);
            final indentCount = Std.int(desiredTabStop / indentSize); // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
        else {
            final indent = '\t';
            final desiredTabStop = CursorColumns.prevRenderTabStop(contentStartVisibleColumn, tabSize);
            final indentCount = Std.int(desiredTabStop / tabSize); // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
    }

    public static function shiftIndent(line:String, column:Int, tabSize:Int, indentSize:Int, insertSpaces:Bool):String {
        // Determine the visible column where the content starts
        final contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(line, column, tabSize);

        if (insertSpaces) {
            final indent = cachedStringRepeat(' ', indentSize);
            final desiredTabStop = CursorColumns.nextIndentTabStop(contentStartVisibleColumn, indentSize);
            final indentCount = Std.int(desiredTabStop / indentSize); // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
        else {
            final indent = '\t';
            final desiredTabStop = CursorColumns.nextRenderTabStop(contentStartVisibleColumn, tabSize);
            final indentCount = Std.int(desiredTabStop / tabSize); // will be an integer
            return cachedStringRepeat(indent, indentCount);
        }
    }

    final _opts:IShiftCommandOpts;
    final _selection:Selection;
    var _selectionId:Null<String>;
    var _useLastEditRangeForCursorEndPosition:Bool;
    var _selectionStartColumnStaysPut:Bool;
    final _languageConfigurationService:ILanguageConfigurationService;
    public final insertsAutoWhitespace:Bool = false;

    public function new(range:Selection, opts:IShiftCommandOpts, languageConfigurationService:ILanguageConfigurationService) {
        this._opts = opts;
        this._selection = range;
        this._selectionId = null;
        this._useLastEditRangeForCursorEndPosition = false;
        this._selectionStartColumnStaysPut = false;
        this._languageConfigurationService = languageConfigurationService;
    }

    function _addEditOperation(builder:IEditOperationBuilder, range:Range, text:String):Void {
        if (this._useLastEditRangeForCursorEndPosition) {
            builder.addTrackedEditOperation(range, text);
        }
        else {
            builder.addEditOperation(range, text);
        }
    }

    /**
     * `/^\\s*$/.test(text)` (JavaScript's `\\s`).
     */
    static function isEmptyOrWhitespace(text:String):Bool {
        for (i in 0...text.length) {
            if (!Strings.isJsWhitespace(StringTools.fastCodeAt(text, i))) {
                return false;
            }
        }
        return true;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        final startLine = this._selection.startLineNumber;

        var endLine = this._selection.endLineNumber;
        if (this._selection.endColumn == 1 && startLine != endLine) {
            endLine = endLine - 1;
        }

        final tabSize = this._opts.tabSize;
        final indentSize = this._opts.indentSize;
        final insertSpaces = this._opts.insertSpaces;
        final shouldIndentEmptyLines = (startLine == endLine);

        if (this._opts.useTabStops) {
            // if indenting or outdenting on a whitespace only line
            if (this._selection.isEmpty()) {
                if (isEmptyOrWhitespace(model.getLineContent(startLine))) {
                    this._useLastEditRangeForCursorEndPosition = true;
                }
            }

            // keep track of previous line's "miss-alignment"
            var previousLineExtraSpaces = 0;
            var extraSpaces = 0;
            var lineNumber = startLine;
            while (lineNumber <= endLine) {
                extraSpaces = 0;
                final lineText = model.getLineContent(lineNumber);
                var indentationEndIndex = Strings.firstNonWhitespaceIndex(lineText);

                if (this._opts.isUnshift && (lineText.length == 0 || indentationEndIndex == 0)) {
                    // empty line or line with no leading whitespace => nothing to do
                    lineNumber++;
                    previousLineExtraSpaces = extraSpaces;
                    continue;
                }

                if (!shouldIndentEmptyLines && !this._opts.isUnshift && lineText.length == 0) {
                    // do not indent empty lines => nothing to do
                    lineNumber++;
                    previousLineExtraSpaces = extraSpaces;
                    continue;
                }

                if (indentationEndIndex == -1) {
                    // the entire line is whitespace
                    indentationEndIndex = lineText.length;
                }

                if (lineNumber > 1) {
                    final contentStartVisibleColumn = CursorColumns.visibleColumnFromColumn(lineText, indentationEndIndex + 1, tabSize);
                    if (contentStartVisibleColumn % indentSize != 0) {
                        // The current line is "miss-aligned", so let's see if this is expected...
                        // This can only happen when it has trailing commas in the indent
                        if (model.tokenization.isCheapToTokenize(lineNumber - 1)) {
                            final enterAction = EnterActionUtils.getEnterAction(this._opts.autoIndent, model, new Range(lineNumber - 1, model.getLineMaxColumn(lineNumber - 1), lineNumber - 1, model.getLineMaxColumn(lineNumber - 1)), this._languageConfigurationService);
                            if (enterAction != null) {
                                extraSpaces = previousLineExtraSpaces;
                                if (enterAction.appendText != null && enterAction.appendText.length > 0) {
                                    var j = 0;
                                    final lenJ = enterAction.appendText.length;
                                    while (j < lenJ && extraSpaces < indentSize) {
                                        if (StringTools.fastCodeAt(enterAction.appendText, j) == CharCode.Space) {
                                            extraSpaces++;
                                        }
                                        else {
                                            break;
                                        }
                                        j++;
                                    }
                                }
                                if (enterAction.removeText != 0) {
                                    extraSpaces = Std.int(Math.max(0, extraSpaces - enterAction.removeText));
                                }

                                // Act as if `prefixSpaces` is not part of the indentation
                                for (j in 0...extraSpaces) {
                                    if (indentationEndIndex == 0 || StringTools.fastCodeAt(lineText, indentationEndIndex - 1) != CharCode.Space) {
                                        break;
                                    }
                                    indentationEndIndex--;
                                }
                            }
                        }
                    }
                }

                if (this._opts.isUnshift && indentationEndIndex == 0) {
                    // line with no leading whitespace => nothing to do
                    lineNumber++;
                    previousLineExtraSpaces = extraSpaces;
                    continue;
                }

                var desiredIndent:String;
                if (this._opts.isUnshift) {
                    desiredIndent = ShiftCommand.unshiftIndent(lineText, indentationEndIndex + 1, tabSize, indentSize, insertSpaces);
                }
                else {
                    desiredIndent = ShiftCommand.shiftIndent(lineText, indentationEndIndex + 1, tabSize, indentSize, insertSpaces);
                }

                this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, indentationEndIndex + 1), desiredIndent);
                if (lineNumber == startLine && !this._selection.isEmpty()) {
                    // Force the startColumn to stay put because we're inserting after it
                    this._selectionStartColumnStaysPut = (this._selection.startColumn <= indentationEndIndex + 1);
                }

                lineNumber++;
                previousLineExtraSpaces = extraSpaces;
            }
        }
        else {

            // if indenting or outdenting on a whitespace only line
            if (!this._opts.isUnshift && this._selection.isEmpty() && model.getLineLength(startLine) == 0) {
                this._useLastEditRangeForCursorEndPosition = true;
            }

            final oneIndent = (insertSpaces ? cachedStringRepeat(' ', indentSize) : '\t');

            for (lineNumber in startLine...endLine + 1) {
                final lineText = model.getLineContent(lineNumber);
                var indentationEndIndex = Strings.firstNonWhitespaceIndex(lineText);

                if (this._opts.isUnshift && (lineText.length == 0 || indentationEndIndex == 0)) {
                    // empty line or line with no leading whitespace => nothing to do
                    continue;
                }

                if (!shouldIndentEmptyLines && !this._opts.isUnshift && lineText.length == 0) {
                    // do not indent empty lines => nothing to do
                    continue;
                }

                if (indentationEndIndex == -1) {
                    // the entire line is whitespace
                    indentationEndIndex = lineText.length;
                }

                if (this._opts.isUnshift && indentationEndIndex == 0) {
                    // line with no leading whitespace => nothing to do
                    continue;
                }

                if (this._opts.isUnshift) {

                    indentationEndIndex = Std.int(Math.min(indentationEndIndex, indentSize));
                    for (i in 0...indentationEndIndex) {
                        final chr = StringTools.fastCodeAt(lineText, i);
                        if (chr == CharCode.Tab) {
                            indentationEndIndex = i + 1;
                            break;
                        }
                    }

                    this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, indentationEndIndex + 1), '');
                }
                else {
                    this._addEditOperation(builder, new Range(lineNumber, 1, lineNumber, 1), oneIndent);
                    if (lineNumber == startLine && !this._selection.isEmpty()) {
                        // Force the startColumn to stay put because we're inserting after it
                        this._selectionStartColumnStaysPut = (this._selection.startColumn == 1);
                    }
                }
            }
        }

        this._selectionId = builder.trackSelection(this._selection);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        if (this._useLastEditRangeForCursorEndPosition) {
            final lastOp = helper.getInverseEditOperations()[0];
            return new Selection(lastOp.range.endLineNumber, lastOp.range.endColumn, lastOp.range.endLineNumber, lastOp.range.endColumn);
        }
        final result = helper.getTrackedSelection(this._selectionId);

        if (this._selectionStartColumnStaysPut) {
            // The selection start should not move
            final initialStartColumn = this._selection.startColumn;
            final resultStartColumn = result.startColumn;
            if (resultStartColumn <= initialStartColumn) {
                return result;
            }

            if (result.getDirection() == SelectionDirection.LTR) {
                return new Selection(result.startLineNumber, initialStartColumn, result.endLineNumber, result.endColumn);
            }
            return new Selection(result.endLineNumber, result.endColumn, result.startLineNumber, initialStartColumn);
        }

        return result;
    }

}
