// Ported from vscode src/vs/editor/contrib/comment/browser/lineCommentCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.comment.view;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;

typedef IInsertionPoint = {
    var ignore:Bool;
    var commentStrOffset:Int;
}

typedef ILinePreflightData = {
    var ignore:Bool;
    var commentStr:String;
    var commentStrOffset:Int;
    var commentStrLength:Int;
}

/**
 * Monaco's `IPreflightData` (`IPreflightDataSupported | IPreflightDataUnsupported`):
 * `shouldRemoveComments` and `lines` are set when `supported` is true.
 */
typedef IPreflightData = {
    var supported:Bool;
    @:optional var shouldRemoveComments:Bool;
    @:optional var lines:Array<ILinePreflightData>;
}

typedef ISimpleModel = {
    function getLineContent(lineNumber:Int):String;
}

enum abstract Type(Int) from Int to Int {
    var Toggle = 0;
    var ForceAdd = 1;
    var ForceRemove = 2;
}

class LineCommentCommand implements ICommand {

    static inline final MAX_SAFE_SMALL_INTEGER:Int = 1 << 30;

    final _selection:Selection;
    final _indentSize:Int;
    final _type:Type;
    final _insertSpace:Bool;
    final _ignoreEmptyLines:Bool;
    var _selectionId:Null<String>;
    var _deltaColumn:Int;
    var _moveEndPositionDown:Bool;
    var _ignoreFirstLine:Bool;
    public final insertsAutoWhitespace:Bool = false;
    final languageConfigurationService:ILanguageConfigurationService;

    public function new(
        languageConfigurationService:ILanguageConfigurationService,
        selection:Selection,
        indentSize:Int,
        type:Type,
        insertSpace:Bool,
        ignoreEmptyLines:Bool,
        ?ignoreFirstLine:Bool
    ) {
        this.languageConfigurationService = languageConfigurationService;
        this._selection = selection;
        this._indentSize = indentSize;
        this._type = type;
        this._insertSpace = insertSpace;
        this._selectionId = null;
        this._deltaColumn = 0;
        this._moveEndPositionDown = false;
        this._ignoreEmptyLines = ignoreEmptyLines;
        this._ignoreFirstLine = ignoreFirstLine == true;
    }

    /**
     * Do an initial pass over the lines and gather info about the line comment string.
     * Returns null if any of the lines doesn't support a line comment string.
     */
    static function _gatherPreflightCommentStrings(model:ITextModel, startLineNumber:Int, endLineNumber:Int, languageConfigurationService:ILanguageConfigurationService):Null<Array<ILinePreflightData>> {

        model.tokenization.tokenizeIfCheap(startLineNumber);
        final languageId = model.getLanguageIdAtPosition(startLineNumber, 1);

        final config = languageConfigurationService.getLanguageConfiguration(languageId).comments;
        final commentStr = (config != null ? config.lineCommentToken : null);
        if (commentStr == null || commentStr.length == 0) {
            // Mode does not support line comments
            return null;
        }

        final lines:Array<ILinePreflightData> = [];
        for (i in 0...endLineNumber - startLineNumber + 1) {
            lines[i] = {
                ignore: false,
                commentStr: commentStr,
                commentStrOffset: 0,
                commentStrLength: commentStr.length
            };
        }

        return lines;
    }

    /**
     * Analyze lines and decide which lines are relevant and what the toggle should do.
     * Also, build up several offsets and lengths useful in the generation of editor operations.
     */
    public static function _analyzeLines(type:Type, insertSpace:Bool, model:ISimpleModel, lines:Array<ILinePreflightData>, startLineNumber:Int, ignoreEmptyLines:Bool, ignoreFirstLine:Bool, languageConfigurationService:ILanguageConfigurationService):IPreflightData {
        var onlyWhitespaceLines = true;

        var shouldRemoveComments:Bool;
        if (type == Type.Toggle) {
            shouldRemoveComments = true;
        }
        else if (type == Type.ForceAdd) {
            shouldRemoveComments = false;
        }
        else {
            shouldRemoveComments = true;
        }

        for (i in 0...lines.length) {
            final lineData = lines[i];
            final lineNumber = startLineNumber + i;

            if (lineNumber == startLineNumber && ignoreFirstLine) {
                // first line ignored
                lineData.ignore = true;
                continue;
            }

            final lineContent = model.getLineContent(lineNumber);
            final lineContentStartOffset = Strings.firstNonWhitespaceIndex(lineContent);

            if (lineContentStartOffset == -1) {
                // Empty or whitespace only line
                lineData.ignore = ignoreEmptyLines;
                lineData.commentStrOffset = lineContent.length;
                continue;
            }

            onlyWhitespaceLines = false;
            lineData.ignore = false;
            lineData.commentStrOffset = lineContentStartOffset;

            if (shouldRemoveComments && !BlockCommentCommand._haystackHasNeedleAtOffset(lineContent, lineData.commentStr, lineContentStartOffset)) {
                if (type == Type.Toggle) {
                    // Every line so far has been a line comment, but this one is not
                    shouldRemoveComments = false;
                }
                else if (type == Type.ForceAdd) {
                    // Will not happen
                }
                else {
                    lineData.ignore = true;
                }
            }

            if (shouldRemoveComments && insertSpace) {
                // Remove a following space if present
                final commentStrEndOffset = lineContentStartOffset + lineData.commentStrLength;
                if (commentStrEndOffset < lineContent.length && StringTools.fastCodeAt(lineContent, commentStrEndOffset) == CharCode.Space) {
                    lineData.commentStrLength += 1;
                }
            }
        }

        if (type == Type.Toggle && onlyWhitespaceLines) {
            // For only whitespace lines, we insert comments
            shouldRemoveComments = false;

            // Also, no longer ignore them
            for (i in 0...lines.length) {
                lines[i].ignore = false;
            }
        }

        return {
            supported: true,
            shouldRemoveComments: shouldRemoveComments,
            lines: lines
        };
    }

    /**
     * Analyze all lines and decide exactly what to do => not supported | insert line comments | remove line comments
     */
    public static function _gatherPreflightData(type:Type, insertSpace:Bool, model:ITextModel, startLineNumber:Int, endLineNumber:Int, ignoreEmptyLines:Bool, ignoreFirstLine:Bool, languageConfigurationService:ILanguageConfigurationService):IPreflightData {
        final lines = LineCommentCommand._gatherPreflightCommentStrings(model, startLineNumber, endLineNumber, languageConfigurationService);
        if (lines == null) {
            return {
                supported: false
            };
        }

        return LineCommentCommand._analyzeLines(type, insertSpace, model, lines, startLineNumber, ignoreEmptyLines, ignoreFirstLine, languageConfigurationService);
    }

    /**
     * Given a successful analysis, execute either insert line comments, either remove line comments
     */
    function _executeLineComments(model:ISimpleModel, builder:IEditOperationBuilder, data:IPreflightData, s:Selection):Void {

        var ops:Array<ISingleEditOperation>;

        if (data.shouldRemoveComments) {
            ops = LineCommentCommand._createRemoveLineCommentsOperations(data.lines, s.startLineNumber);
        }
        else {
            LineCommentCommand._normalizeInsertionPoint(model, cast data.lines, s.startLineNumber, this._indentSize);
            ops = this._createAddLineCommentsOperations(data.lines, s.startLineNumber);
        }

        final cursorPosition = new Position(s.positionLineNumber, s.positionColumn);

        for (i in 0...ops.length) {
            builder.addEditOperation(ops[i].range, ops[i].text);
            if (Range.isEmptyStatic(ops[i].range) && Range.getStartPositionStatic(ops[i].range).equals(cursorPosition)) {
                final lineContent = model.getLineContent(cursorPosition.lineNumber);
                if (lineContent.length + 1 == cursorPosition.column) {
                    this._deltaColumn = (ops[i].text != null ? ops[i].text : '').length;
                }
            }
        }

        this._selectionId = builder.trackSelection(s);
    }

    function _attemptRemoveBlockComment(model:ITextModel, s:Selection, startToken:String, endToken:String):Null<Array<ISingleEditOperation>> {
        var startLineNumber = s.startLineNumber;
        var endLineNumber = s.endLineNumber;

        final startTokenAllowedBeforeColumn = endToken.length + Std.int(Math.max(
            model.getLineFirstNonWhitespaceColumn(s.startLineNumber),
            s.startColumn
        ));

        var startTokenIndex = BlockCommentCommand._jsLastIndexOf(model.getLineContent(startLineNumber), startToken, startTokenAllowedBeforeColumn - 1);
        var endTokenIndex = BlockCommentCommand._jsIndexOf(model.getLineContent(endLineNumber), endToken, s.endColumn - 1 - startToken.length);

        if (startTokenIndex != -1 && endTokenIndex == -1) {
            endTokenIndex = BlockCommentCommand._jsIndexOf(model.getLineContent(startLineNumber), endToken, startTokenIndex + startToken.length);
            endLineNumber = startLineNumber;
        }

        if (startTokenIndex == -1 && endTokenIndex != -1) {
            startTokenIndex = BlockCommentCommand._jsLastIndexOf(model.getLineContent(endLineNumber), startToken, endTokenIndex);
            startLineNumber = endLineNumber;
        }

        if (s.isEmpty() && (startTokenIndex == -1 || endTokenIndex == -1)) {
            startTokenIndex = model.getLineContent(startLineNumber).indexOf(startToken);
            if (startTokenIndex != -1) {
                endTokenIndex = BlockCommentCommand._jsIndexOf(model.getLineContent(startLineNumber), endToken, startTokenIndex + startToken.length);
            }
        }

        // We have to adjust to possible inner white space.
        // For Space after startToken, add Space to startToken - range math will work out.
        if (startTokenIndex != -1 && BlockCommentCommand._jsCharCodeAt(model.getLineContent(startLineNumber), startTokenIndex + startToken.length) == CharCode.Space) {
            startToken += ' ';
        }

        // For Space before endToken, add Space before endToken and shift index one left.
        if (endTokenIndex != -1 && BlockCommentCommand._jsCharCodeAt(model.getLineContent(endLineNumber), endTokenIndex - 1) == CharCode.Space) {
            endToken = ' ' + endToken;
            endTokenIndex -= 1;
        }

        if (startTokenIndex != -1 && endTokenIndex != -1) {
            return BlockCommentCommand._createRemoveBlockCommentOperations(
                new Range(startLineNumber, startTokenIndex + startToken.length + 1, endLineNumber, endTokenIndex + 1), startToken, endToken
            );
        }

        return null;
    }

    /**
     * Given an unsuccessful analysis, delegate to the block comment command
     */
    function _executeBlockComment(model:ITextModel, builder:IEditOperationBuilder, s:Selection):Void {
        model.tokenization.tokenizeIfCheap(s.startLineNumber);
        final languageId = model.getLanguageIdAtPosition(s.startLineNumber, 1);
        final config = this.languageConfigurationService.getLanguageConfiguration(languageId).comments;
        if (config == null || !BlockCommentCommand.truthy(config.blockCommentStartToken) || !BlockCommentCommand.truthy(config.blockCommentEndToken)) {
            // Mode does not support block comments
            return;
        }

        final startToken = config.blockCommentStartToken;
        final endToken = config.blockCommentEndToken;

        var ops = this._attemptRemoveBlockComment(model, s, startToken, endToken);
        if (ops == null) {
            if (s.isEmpty()) {
                final lineContent = model.getLineContent(s.startLineNumber);
                var firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(lineContent);
                if (firstNonWhitespaceIndex == -1) {
                    // Line is empty or contains only whitespace
                    firstNonWhitespaceIndex = lineContent.length;
                }
                ops = BlockCommentCommand._createAddBlockCommentOperations(
                    new Range(s.startLineNumber, firstNonWhitespaceIndex + 1, s.startLineNumber, lineContent.length + 1),
                    startToken,
                    endToken,
                    this._insertSpace
                );
            }
            else {
                ops = BlockCommentCommand._createAddBlockCommentOperations(
                    new Range(s.startLineNumber, model.getLineFirstNonWhitespaceColumn(s.startLineNumber), s.endLineNumber, model.getLineMaxColumn(s.endLineNumber)),
                    startToken,
                    endToken,
                    this._insertSpace
                );
            }

            if (ops.length == 1) {
                // Leave cursor after token and Space
                this._deltaColumn = startToken.length + 1;
            }
        }
        this._selectionId = builder.trackSelection(s);
        for (op in ops) {
            builder.addEditOperation(op.range, op.text);
        }
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {

        var s = this._selection;
        this._moveEndPositionDown = false;

        if (s.startLineNumber == s.endLineNumber && this._ignoreFirstLine) {
            builder.addEditOperation(new Range(s.startLineNumber, model.getLineMaxColumn(s.startLineNumber), s.startLineNumber + 1, 1), s.startLineNumber == model.getLineCount() ? '' : '\n');
            this._selectionId = builder.trackSelection(s);
            return;
        }

        if (s.startLineNumber < s.endLineNumber && s.endColumn == 1) {
            this._moveEndPositionDown = true;
            s = s.setEndPosition(s.endLineNumber - 1, model.getLineMaxColumn(s.endLineNumber - 1));
        }

        final data = LineCommentCommand._gatherPreflightData(
            this._type,
            this._insertSpace,
            model,
            s.startLineNumber,
            s.endLineNumber,
            this._ignoreEmptyLines,
            this._ignoreFirstLine,
            this.languageConfigurationService
        );

        if (data.supported) {
            this._executeLineComments(model, builder, data, s);
            return;
        }

        this._executeBlockComment(model, builder, s);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        var result = helper.getTrackedSelection(this._selectionId);

        if (this._moveEndPositionDown) {
            result = result.setEndPosition(result.endLineNumber + 1, 1);
        }

        return new Selection(
            result.selectionStartLineNumber,
            result.selectionStartColumn + this._deltaColumn,
            result.positionLineNumber,
            result.positionColumn + this._deltaColumn
        );
    }

    /**
     * Generate edit operations in the remove line comment case
     */
    public static function _createRemoveLineCommentsOperations(lines:Array<ILinePreflightData>, startLineNumber:Int):Array<ISingleEditOperation> {
        final res:Array<ISingleEditOperation> = [];

        for (i in 0...lines.length) {
            final lineData = lines[i];

            if (lineData.ignore) {
                continue;
            }

            res.push(EditOperation.delete(new Range(
                startLineNumber + i, lineData.commentStrOffset + 1,
                startLineNumber + i, lineData.commentStrOffset + lineData.commentStrLength + 1
            )));
        }

        return res;
    }

    /**
     * Generate edit operations in the add line comment case
     */
    function _createAddLineCommentsOperations(lines:Array<ILinePreflightData>, startLineNumber:Int):Array<ISingleEditOperation> {
        final res:Array<ISingleEditOperation> = [];
        final afterCommentStr = this._insertSpace ? ' ' : '';

        for (i in 0...lines.length) {
            final lineData = lines[i];

            if (lineData.ignore) {
                continue;
            }

            res.push(EditOperation.insert(new Position(startLineNumber + i, lineData.commentStrOffset + 1), lineData.commentStr + afterCommentStr));
        }

        return res;
    }

    static function nextVisibleColumn(currentVisibleColumn:Int, indentSize:Int, isTab:Bool, columnSize:Int):Int {
        if (isTab) {
            return currentVisibleColumn + (indentSize - (currentVisibleColumn % indentSize));
        }
        return currentVisibleColumn + columnSize;
    }

    /**
     * Adjust insertion points to have them vertically aligned in the add line comment case
     */
    public static function _normalizeInsertionPoint(model:ISimpleModel, lines:Array<IInsertionPoint>, startLineNumber:Int, indentSize:Int):Void {
        var minVisibleColumn = MAX_SAFE_SMALL_INTEGER;
        var j:Int;
        var lenJ:Int;

        for (i in 0...lines.length) {
            if (lines[i].ignore) {
                continue;
            }

            final lineContent = model.getLineContent(startLineNumber + i);

            var currentVisibleColumn = 0;
            var j = 0;
            final lenJ = lines[i].commentStrOffset;
            while (currentVisibleColumn < minVisibleColumn && j < lenJ) {
                currentVisibleColumn = LineCommentCommand.nextVisibleColumn(currentVisibleColumn, indentSize, StringTools.fastCodeAt(lineContent, j) == CharCode.Tab, 1);
                j++;
            }

            if (currentVisibleColumn < minVisibleColumn) {
                minVisibleColumn = currentVisibleColumn;
            }
        }

        minVisibleColumn = Std.int(Math.floor(minVisibleColumn / indentSize)) * indentSize;

        for (i in 0...lines.length) {
            if (lines[i].ignore) {
                continue;
            }

            final lineContent = model.getLineContent(startLineNumber + i);

            var currentVisibleColumn = 0;
            j = 0;
            lenJ = lines[i].commentStrOffset;
            while (currentVisibleColumn < minVisibleColumn && j < lenJ) {
                currentVisibleColumn = LineCommentCommand.nextVisibleColumn(currentVisibleColumn, indentSize, StringTools.fastCodeAt(lineContent, j) == CharCode.Tab, 1);
                j++;
            }

            if (currentVisibleColumn > minVisibleColumn) {
                lines[i].commentStrOffset = j - 1;
            }
            else {
                lines[i].commentStrOffset = j;
            }
        }
    }

}
