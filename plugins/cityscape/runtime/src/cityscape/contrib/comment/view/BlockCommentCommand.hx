// Ported from vscode src/vs/editor/contrib/comment/browser/blockCommentCommand.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.comment.view;

import cityscape.base.common.CharCode;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorStateComputerData;
import cityscape.common.EditorCommon.IEditOperationBuilder;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;

class BlockCommentCommand implements ICommand {

    final _selection:Selection;
    final _insertSpace:Bool;
    var _usedEndToken:Null<String>;
    public final insertsAutoWhitespace:Bool = false;
    final languageConfigurationService:ILanguageConfigurationService;

    public function new(selection:Selection, insertSpace:Bool, languageConfigurationService:ILanguageConfigurationService) {
        this._selection = selection;
        this._insertSpace = insertSpace;
        this._usedEndToken = null;
        this.languageConfigurationService = languageConfigurationService;
    }

    /**
     * JavaScript's `str.indexOf(search, fromIndex)` (a negative start is 0).
     */
    @:noCompletion public static inline function _jsIndexOf(str:String, search:String, fromIndex:Int):Int {
        return str.indexOf(search, fromIndex < 0 ? 0 : fromIndex);
    }

    /**
     * JavaScript's `str.lastIndexOf(search, fromIndex)` (a negative start is 0).
     */
    @:noCompletion public static inline function _jsLastIndexOf(str:String, search:String, fromIndex:Int):Int {
        return str.lastIndexOf(search, fromIndex < 0 ? 0 : fromIndex);
    }

    /**
     * JavaScript's `str.charCodeAt(index)`, -1 (NaN) out of the string.
     */
    @:noCompletion public static inline function _jsCharCodeAt(str:String, index:Int):Int {
        return (index < 0 || index >= str.length) ? -1 : StringTools.fastCodeAt(str, index);
    }

    public static function _haystackHasNeedleAtOffset(haystack:String, needle:String, offset:Int):Bool {
        if (offset < 0) {
            return false;
        }
        final needleLength = needle.length;
        final haystackLength = haystack.length;
        if (offset + needleLength > haystackLength) {
            return false;
        }

        for (i in 0...needleLength) {
            final codeA = StringTools.fastCodeAt(haystack, offset + i);
            final codeB = StringTools.fastCodeAt(needle, i);

            if (codeA == codeB) {
                continue;
            }
            if (codeA >= (CharCode.A : Int) && codeA <= (CharCode.Z : Int) && codeA + 32 == codeB) {
                // codeA is upper-case variant of codeB
                continue;
            }
            if (codeB >= (CharCode.A : Int) && codeB <= (CharCode.Z : Int) && codeB + 32 == codeA) {
                // codeB is upper-case variant of codeA
                continue;
            }

            return false;
        }
        return true;
    }

    function _createOperationsForBlockComment(selection:Range, startToken:String, endToken:String, insertSpace:Bool, model:ITextModel, builder:IEditOperationBuilder):Void {
        final startLineNumber = selection.startLineNumber;
        final startColumn = selection.startColumn;
        final endLineNumber = selection.endLineNumber;
        final endColumn = selection.endColumn;

        final startLineText = model.getLineContent(startLineNumber);
        final endLineText = model.getLineContent(endLineNumber);

        var startTokenIndex = _jsLastIndexOf(startLineText, startToken, startColumn - 1 + startToken.length);
        var endTokenIndex = _jsIndexOf(endLineText, endToken, endColumn - 1 - endToken.length);

        if (startTokenIndex != -1 && endTokenIndex != -1) {

            if (startLineNumber == endLineNumber) {
                final lineBetweenTokens = startLineText.substring(startTokenIndex + startToken.length, endTokenIndex);

                if (lineBetweenTokens.indexOf(endToken) >= 0) {
                    // force to add a block comment
                    startTokenIndex = -1;
                    endTokenIndex = -1;
                }
            }
            else {
                final startLineAfterStartToken = startLineText.substring(startTokenIndex + startToken.length);
                final endLineBeforeEndToken = endLineText.substring(0, endTokenIndex);

                if (startLineAfterStartToken.indexOf(endToken) >= 0 || endLineBeforeEndToken.indexOf(endToken) >= 0) {
                    // force to add a block comment
                    startTokenIndex = -1;
                    endTokenIndex = -1;
                }
            }
        }

        var ops:Array<ISingleEditOperation>;

        if (startTokenIndex != -1 && endTokenIndex != -1) {
            // Consider spaces as part of the comment tokens
            if (insertSpace && startTokenIndex + startToken.length < startLineText.length && StringTools.fastCodeAt(startLineText, startTokenIndex + startToken.length) == CharCode.Space) {
                // Pretend the start token contains a trailing space
                startToken = startToken + ' ';
            }

            if (insertSpace && endTokenIndex > 0 && StringTools.fastCodeAt(endLineText, endTokenIndex - 1) == CharCode.Space) {
                // Pretend the end token contains a leading space
                endToken = ' ' + endToken;
                endTokenIndex -= 1;
            }
            ops = BlockCommentCommand._createRemoveBlockCommentOperations(
                new Range(startLineNumber, startTokenIndex + startToken.length + 1, endLineNumber, endTokenIndex + 1), startToken, endToken
            );
        }
        else {
            ops = BlockCommentCommand._createAddBlockCommentOperations(selection, startToken, endToken, this._insertSpace);
            this._usedEndToken = ops.length == 1 ? endToken : null;
        }

        for (op in ops) {
            builder.addTrackedEditOperation(op.range, op.text);
        }
    }

    public static function _createRemoveBlockCommentOperations(r:Range, startToken:String, endToken:String):Array<ISingleEditOperation> {
        final res:Array<ISingleEditOperation> = [];

        if (!r.isEmpty()) {
            // Remove block comment start
            res.push(EditOperation.delete(new Range(
                r.startLineNumber, r.startColumn - startToken.length,
                r.startLineNumber, r.startColumn
            )));

            // Remove block comment end
            res.push(EditOperation.delete(new Range(
                r.endLineNumber, r.endColumn,
                r.endLineNumber, r.endColumn + endToken.length
            )));
        }
        else {
            // Remove both continuously
            res.push(EditOperation.delete(new Range(
                r.startLineNumber, r.startColumn - startToken.length,
                r.endLineNumber, r.endColumn + endToken.length
            )));
        }

        return res;
    }

    public static function _createAddBlockCommentOperations(r:Range, startToken:String, endToken:String, insertSpace:Bool):Array<ISingleEditOperation> {
        final res:Array<ISingleEditOperation> = [];

        if (!r.isEmpty()) {
            // Insert block comment start
            res.push(EditOperation.insert(new Position(r.startLineNumber, r.startColumn), startToken + (insertSpace ? ' ' : '')));

            // Insert block comment end
            res.push(EditOperation.insert(new Position(r.endLineNumber, r.endColumn), (insertSpace ? ' ' : '') + endToken));
        }
        else {
            // Insert both continuously
            res.push(EditOperation.replace(new Range(
                r.startLineNumber, r.startColumn,
                r.endLineNumber, r.endColumn
            ), startToken + '  ' + endToken));
        }

        return res;
    }

    public function getEditOperations(model:ITextModel, builder:IEditOperationBuilder):Void {
        final startLineNumber = this._selection.startLineNumber;
        final startColumn = this._selection.startColumn;

        model.tokenization.tokenizeIfCheap(startLineNumber);
        final languageId = model.getLanguageIdAtPosition(startLineNumber, startColumn);
        final config = this.languageConfigurationService.getLanguageConfiguration(languageId).comments;
        if (config == null || !truthy(config.blockCommentStartToken) || !truthy(config.blockCommentEndToken)) {
            // Mode does not support block comments
            return;
        }

        this._createOperationsForBlockComment(this._selection, config.blockCommentStartToken, config.blockCommentEndToken, this._insertSpace, model, builder);
    }

    public function computeCursorState(model:ITextModel, helper:ICursorStateComputerData):Selection {
        final inverseEditOperations = helper.getInverseEditOperations();
        if (inverseEditOperations.length == 2) {
            final startTokenEditOperation = inverseEditOperations[0];
            final endTokenEditOperation = inverseEditOperations[1];

            return new Selection(
                startTokenEditOperation.range.endLineNumber,
                startTokenEditOperation.range.endColumn,
                endTokenEditOperation.range.startLineNumber,
                endTokenEditOperation.range.startColumn
            );
        }
        else {
            final srcRange = inverseEditOperations[0].range;
            final deltaColumn = truthy(this._usedEndToken) ? -this._usedEndToken.length - 1 : 0; // minus 1 space before endToken
            return new Selection(
                srcRange.endLineNumber,
                srcRange.endColumn + deltaColumn,
                srcRange.endLineNumber,
                srcRange.endColumn + deltaColumn
            );
        }
    }

    /**
     * JavaScript truthiness of an optional string.
     */
    @:noCompletion public static inline function truthy(s:Null<String>):Bool {
        return s != null && s.length > 0;
    }

}
