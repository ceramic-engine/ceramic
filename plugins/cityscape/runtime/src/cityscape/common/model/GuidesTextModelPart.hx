// Ported from vscode src/vs/editor/common/model/guidesTextModelPart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Errors.BugIndicatingError;
import cityscape.common.TextModelGuides;
import cityscape.common.core.Position.IPosition;

/**
 * The indent guides of a text model.
 *
 * Monaco reads `foldingRules.offSide` from the language configuration
 * service; until the language configuration is ported, it comes from
 * `isOffSide` (false by default). TODO(step 1, cs1-tokens): wire `isOffSide`
 * to the language configuration (`foldingRules.offSide` of the model's
 * language) and port `getLinesBracketGuides` with the bracket pairs part.
 */
class GuidesTextModelPart extends TextModelPart implements IGuidesTextModelPart {

    final textModel:TextModel;

    /**
     * Whether the language uses the off side rule (`foldingRules.offSide`).
     */
    public var isOffSide:(languageId:String) -> Bool = (languageId:String) -> false;

    public function new(textModel:TextModel) {
        super();
        this.textModel = textModel;
    }

    function _computeIndentLevel(lineIndex:Int):Int {
        return Utils.computeIndentLevel(
            this.textModel.getLineContent(lineIndex + 1),
            this.textModel.getOptions().tabSize
        );
    }

    static inline function ceilDiv(a:Int, b:Int):Int {
        return Math.ceil(a / b);
    }

    static inline function floorDiv(a:Int, b:Int):Int {
        return Math.floor(a / b);
    }

    public function getActiveIndentGuide(lineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo {
        this.assertNotDisposed();
        final lineCount = this.textModel.getLineCount();

        if (lineNumber < 1 || lineNumber > lineCount) {
            throw new BugIndicatingError('Illegal value for lineNumber');
        }

        final offSide = isOffSide(this.textModel.getLanguageId());

        var up_aboveContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var up_aboveContentLineIndent = -1;
        var up_belowContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var up_belowContentLineIndent = -1;
        final up_resolveIndents = (lineNumber:Int) -> {
            if (
                up_aboveContentLineIndex != -1
                && (up_aboveContentLineIndex == -2 || up_aboveContentLineIndex > lineNumber - 1)
            ) {
                up_aboveContentLineIndex = -1;
                up_aboveContentLineIndent = -1;

                // must find previous line with content
                var lineIndex = lineNumber - 2;
                while (lineIndex >= 0) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        up_aboveContentLineIndex = lineIndex;
                        up_aboveContentLineIndent = indent;
                        break;
                    }
                    lineIndex--;
                }
            }

            if (up_belowContentLineIndex == -2) {
                up_belowContentLineIndex = -1;
                up_belowContentLineIndent = -1;

                // must find next line with content
                for (lineIndex in lineNumber...lineCount) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        up_belowContentLineIndex = lineIndex;
                        up_belowContentLineIndent = indent;
                        break;
                    }
                }
            }
        };

        var down_aboveContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var down_aboveContentLineIndent = -1;
        var down_belowContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var down_belowContentLineIndent = -1;
        final down_resolveIndents = (lineNumber:Int) -> {
            if (down_aboveContentLineIndex == -2) {
                down_aboveContentLineIndex = -1;
                down_aboveContentLineIndent = -1;

                // must find previous line with content
                var lineIndex = lineNumber - 2;
                while (lineIndex >= 0) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        down_aboveContentLineIndex = lineIndex;
                        down_aboveContentLineIndent = indent;
                        break;
                    }
                    lineIndex--;
                }
            }

            if (
                down_belowContentLineIndex != -1
                && (down_belowContentLineIndex == -2 || down_belowContentLineIndex < lineNumber - 1)
            ) {
                down_belowContentLineIndex = -1;
                down_belowContentLineIndent = -1;

                // must find next line with content
                for (lineIndex in lineNumber...lineCount) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        down_belowContentLineIndex = lineIndex;
                        down_belowContentLineIndent = indent;
                        break;
                    }
                }
            }
        };

        var startLineNumber = 0;
        var goUp = true;
        var endLineNumber = 0;
        var goDown = true;
        var indent = 0;

        var initialIndent = 0;

        var distance = 0;
        while (goUp || goDown) {
            final upLineNumber = lineNumber - distance;
            final downLineNumber = lineNumber + distance;

            if (distance > 1 && (upLineNumber < 1 || upLineNumber < minLineNumber)) {
                goUp = false;
            }
            if (distance > 1 && (downLineNumber > lineCount || downLineNumber > maxLineNumber)) {
                goDown = false;
            }
            if (distance > 50000) {
                // stop processing
                goUp = false;
                goDown = false;
            }

            var upLineIndentLevel:Int = -1;
            if (goUp && upLineNumber >= 1) {
                // compute indent level going up
                final currentIndent = this._computeIndentLevel(upLineNumber - 1);
                if (currentIndent >= 0) {
                    // This line has content (besides whitespace)
                    // Use the line's indent
                    up_belowContentLineIndex = upLineNumber - 1;
                    up_belowContentLineIndent = currentIndent;
                    upLineIndentLevel = ceilDiv(currentIndent, this.textModel.getOptions().indentSize);
                }
                else {
                    up_resolveIndents(upLineNumber);
                    upLineIndentLevel = this._getIndentLevelForWhitespaceLine(offSide, up_aboveContentLineIndent, up_belowContentLineIndent);
                }
            }

            var downLineIndentLevel = -1;
            if (goDown && downLineNumber <= lineCount) {
                // compute indent level going down
                final currentIndent = this._computeIndentLevel(downLineNumber - 1);
                if (currentIndent >= 0) {
                    // This line has content (besides whitespace)
                    // Use the line's indent
                    down_aboveContentLineIndex = downLineNumber - 1;
                    down_aboveContentLineIndent = currentIndent;
                    downLineIndentLevel = ceilDiv(currentIndent, this.textModel.getOptions().indentSize);
                }
                else {
                    down_resolveIndents(downLineNumber);
                    downLineIndentLevel = this._getIndentLevelForWhitespaceLine(offSide, down_aboveContentLineIndent, down_belowContentLineIndent);
                }
            }

            if (distance == 0) {
                initialIndent = upLineIndentLevel;
                distance++;
                continue;
            }

            if (distance == 1) {
                if (downLineNumber <= lineCount && downLineIndentLevel >= 0 && initialIndent + 1 == downLineIndentLevel) {
                    // This is the beginning of a scope, we have special handling here, since we want the
                    // child scope indent to be active, not the parent scope
                    goUp = false;
                    startLineNumber = downLineNumber;
                    endLineNumber = downLineNumber;
                    indent = downLineIndentLevel;
                    distance++;
                    continue;
                }

                if (upLineNumber >= 1 && upLineIndentLevel >= 0 && upLineIndentLevel - 1 == initialIndent) {
                    // This is the end of a scope, just like above
                    goDown = false;
                    startLineNumber = upLineNumber;
                    endLineNumber = upLineNumber;
                    indent = upLineIndentLevel;
                    distance++;
                    continue;
                }

                startLineNumber = lineNumber;
                endLineNumber = lineNumber;
                indent = initialIndent;
                if (indent == 0) {
                    // No need to continue
                    return {startLineNumber: startLineNumber, endLineNumber: endLineNumber, indent: indent};
                }
            }

            if (goUp) {
                if (upLineIndentLevel >= indent) {
                    startLineNumber = upLineNumber;
                }
                else {
                    goUp = false;
                }
            }
            if (goDown) {
                if (downLineIndentLevel >= indent) {
                    endLineNumber = downLineNumber;
                }
                else {
                    goDown = false;
                }
            }
            distance++;
        }

        return {startLineNumber: startLineNumber, endLineNumber: endLineNumber, indent: indent};
    }

    /**
     * TODO(step 1, cs1-tokens): bracket guides need the bracket pairs part
     * (`getBracketPairsInRangeWithMinIndentation`); until then every line
     * has no bracket guide.
     */
    public function getLinesBracketGuides(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>> {
        final result:Array<Array<IndentGuide>> = [];
        for (lineNumber in startLineNumber...endLineNumber + 1) {
            result.push([]);
        }
        return result;
    }

    public function getLinesIndentGuides(startLineNumber:Int, endLineNumber:Int):Array<Int> {
        this.assertNotDisposed();
        final lineCount = this.textModel.getLineCount();

        if (startLineNumber < 1 || startLineNumber > lineCount) {
            throw 'Illegal value for startLineNumber';
        }
        if (endLineNumber < 1 || endLineNumber > lineCount) {
            throw 'Illegal value for endLineNumber';
        }

        final options = this.textModel.getOptions();
        final offSide = isOffSide(this.textModel.getLanguageId());

        final result:Array<Int> = [];
        result.resize(endLineNumber - startLineNumber + 1);

        var aboveContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var aboveContentLineIndent = -1;

        var belowContentLineIndex = -2; /* -2 is a marker for not having computed it */
        var belowContentLineIndent = -1;

        for (lineNumber in startLineNumber...endLineNumber + 1) {
            final resultIndex = lineNumber - startLineNumber;

            final currentIndent = this._computeIndentLevel(lineNumber - 1);
            if (currentIndent >= 0) {
                // This line has content (besides whitespace)
                // Use the line's indent
                aboveContentLineIndex = lineNumber - 1;
                aboveContentLineIndent = currentIndent;
                result[resultIndex] = ceilDiv(currentIndent, options.indentSize);
                continue;
            }

            if (aboveContentLineIndex == -2) {
                aboveContentLineIndex = -1;
                aboveContentLineIndent = -1;

                // must find previous line with content
                var lineIndex = lineNumber - 2;
                while (lineIndex >= 0) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        aboveContentLineIndex = lineIndex;
                        aboveContentLineIndent = indent;
                        break;
                    }
                    lineIndex--;
                }
            }

            if (belowContentLineIndex != -1 && (belowContentLineIndex == -2 || belowContentLineIndex < lineNumber - 1)) {
                belowContentLineIndex = -1;
                belowContentLineIndent = -1;

                // must find next line with content
                for (lineIndex in lineNumber...lineCount) {
                    final indent = this._computeIndentLevel(lineIndex);
                    if (indent >= 0) {
                        belowContentLineIndex = lineIndex;
                        belowContentLineIndent = indent;
                        break;
                    }
                }
            }

            result[resultIndex] = this._getIndentLevelForWhitespaceLine(offSide, aboveContentLineIndent, belowContentLineIndent);
        }
        return result;
    }

    function _getIndentLevelForWhitespaceLine(offSide:Bool, aboveContentLineIndent:Int, belowContentLineIndent:Int):Int {
        final options = this.textModel.getOptions();

        if (aboveContentLineIndent == -1 || belowContentLineIndent == -1) {
            // At the top or bottom of the file
            return 0;
        }
        else if (aboveContentLineIndent < belowContentLineIndent) {
            // we are inside the region above
            return 1 + floorDiv(aboveContentLineIndent, options.indentSize);
        }
        else if (aboveContentLineIndent == belowContentLineIndent) {
            // we are in between two regions
            return ceilDiv(belowContentLineIndent, options.indentSize);
        }
        else {
            if (offSide) {
                // same level as region below
                return ceilDiv(belowContentLineIndent, options.indentSize);
            }
            else {
                // we are inside the region that ends below
                return 1 + floorDiv(belowContentLineIndent, options.indentSize);
            }
        }
    }

}

class BracketPairGuidesClassNames {

    public final activeClassName = 'indent-active';

    public function new() {}

    public function getInlineClassName(nestingLevel:Int, nestingLevelOfEqualBracketType:Int, independentColorPoolPerBracketType:Bool):String {
        return this.getInlineClassNameOfLevel(independentColorPoolPerBracketType ? nestingLevelOfEqualBracketType : nestingLevel);
    }

    public function getInlineClassNameOfLevel(level:Int):String {
        // To support a dynamic amount of colors up to 6 colors,
        // we use a number that is a lcm of all numbers from 1 to 6.
        return 'bracket-indent-guide lvl-${level % 30}';
    }

}
