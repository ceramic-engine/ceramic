// Ported from vscode src/vs/editor/common/model/guidesTextModelPart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.CharCode;
import cityscape.base.common.Errors.BugIndicatingError;
import cityscape.base.common.Strings;
import cityscape.common.TextModelGuides;
import cityscape.common.core.CursorColumns;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * The indent guides and bracket pair guides of a text model.
 *
 * `foldingRules.offSide` comes from the language configuration service of
 * the model's context (`isOffSide`, which can be replaced in tests).
 */
class GuidesTextModelPart extends TextModelPart implements IGuidesTextModelPart {

    final textModel:TextModel;

    /**
     * Whether the language uses the off side rule (`foldingRules.offSide`).
     */
    public var isOffSide:(languageId:String) -> Bool;

    public function new(textModel:TextModel) {
        super();
        this.textModel = textModel;
        this.isOffSide = (languageId:String) -> {
            final foldingRules = textModel.context.languageConfigurationService.getLanguageConfiguration(languageId).foldingRules;
            return foldingRules != null && foldingRules.offSide == true;
        };
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

    public function getLinesBracketGuides(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>> {
        final result:Array<Array<IndentGuide>> = [];
        for (lineNumber in startLineNumber...endLineNumber + 1) {
            result.push([]);
        }

        // If requested, this could be made configurable.
        final includeSingleLinePairs = true;

        final bracketPairs = this.textModel.bracketPairs.getBracketPairsInRangeWithMinIndentation(
            new Range(
                startLineNumber,
                1,
                endLineNumber,
                this.textModel.getLineMaxColumn(endLineNumber)
            )
        ).toArray();

        var activeBracketPairRange:Null<Range> = null;
        if (activePosition != null && bracketPairs.length > 0) {
            final bracketsContainingActivePosition = (
                startLineNumber <= activePosition.lineNumber && activePosition.lineNumber <= endLineNumber
                    // We don't need to query the brackets again if the cursor is in the viewport
                    ? [for (bp in bracketPairs) (bp : cityscape.common.TextModelBracketPairs.BracketPairInfo)]
                    : this.textModel.bracketPairs.getBracketPairsInRange(Range.fromPositions(activePosition)).toArray()
            ).filter(bp -> Range.strictContainsPosition(bp.range, activePosition));

            var i = bracketsContainingActivePosition.length - 1;
            while (i >= 0) {
                final bp = bracketsContainingActivePosition[i];
                if (includeSingleLinePairs || bp.range.startLineNumber != bp.range.endLineNumber) {
                    activeBracketPairRange = bp.range;
                    break;
                }
                i--;
            }
        }

        final independentColorPoolPerBracketType = this.textModel.getOptions().bracketPairColorizationOptions.independentColorPoolPerBracketType;
        final colorProvider = new BracketPairGuidesClassNames();

        for (pair in bracketPairs) {
            if (pair.closingBracketRange == null) {
                continue;
            }

            final isActive = activeBracketPairRange != null && pair.range.equalsRange(activeBracketPairRange);

            if (!isActive && !options.includeInactive) {
                continue;
            }

            final className =
                colorProvider.getInlineClassName(pair.nestingLevel, pair.nestingLevelOfEqualBracketType, independentColorPoolPerBracketType) +
                (options.highlightActive && isActive
                    ? ' ' + colorProvider.activeClassName
                    : '');

            final start = pair.openingBracketRange.getStartPosition();
            final end = pair.closingBracketRange.getStartPosition();

            final horizontalGuides = options.horizontalGuides == HorizontalGuidesState.Enabled || (options.horizontalGuides == HorizontalGuidesState.EnabledForActive && isActive);

            if (pair.range.startLineNumber == pair.range.endLineNumber) {
                if (includeSingleLinePairs && horizontalGuides) {
                    result[pair.range.startLineNumber - startLineNumber].push(
                        new IndentGuide(
                            -1,
                            pair.openingBracketRange.getEndPosition().column,
                            className,
                            new IndentGuideHorizontalLine(false, end.column),
                            -1,
                            -1
                        )
                    );
                }
                continue;
            }

            final endVisibleColumn = this.getVisibleColumnFromPosition(end);
            final startVisibleColumn = this.getVisibleColumnFromPosition(pair.openingBracketRange.getStartPosition());
            final guideVisibleColumn = Std.int(Math.min(Math.min(startVisibleColumn, endVisibleColumn), pair.minVisibleColumnIndentation + 1));

            var renderHorizontalEndLineAtTheBottom = false;

            final firstNonWsIndex = Strings.firstNonWhitespaceIndex(this.textModel.getLineContent(pair.closingBracketRange.startLineNumber));
            final hasTextBeforeClosingBracket = firstNonWsIndex < pair.closingBracketRange.startColumn - 1;
            if (hasTextBeforeClosingBracket) {
                renderHorizontalEndLineAtTheBottom = true;
            }

            final visibleGuideStartLineNumber = Std.int(Math.max(start.lineNumber, startLineNumber));
            final visibleGuideEndLineNumber = Std.int(Math.min(end.lineNumber, endLineNumber));

            final offset = renderHorizontalEndLineAtTheBottom ? 1 : 0;

            for (l in visibleGuideStartLineNumber...(visibleGuideEndLineNumber + offset)) {
                result[l - startLineNumber].push(
                    new IndentGuide(
                        guideVisibleColumn,
                        -1,
                        className,
                        null,
                        l == start.lineNumber ? start.column : -1,
                        l == end.lineNumber ? end.column : -1
                    )
                );
            }

            if (horizontalGuides) {
                if (start.lineNumber >= startLineNumber && startVisibleColumn > guideVisibleColumn) {
                    result[start.lineNumber - startLineNumber].push(
                        new IndentGuide(
                            guideVisibleColumn,
                            -1,
                            className,
                            new IndentGuideHorizontalLine(false, start.column),
                            -1,
                            -1
                        )
                    );
                }

                if (end.lineNumber <= endLineNumber && endVisibleColumn > guideVisibleColumn) {
                    result[end.lineNumber - startLineNumber].push(
                        new IndentGuide(
                            guideVisibleColumn,
                            -1,
                            className,
                            new IndentGuideHorizontalLine(!renderHorizontalEndLineAtTheBottom, end.column),
                            -1,
                            -1
                        )
                    );
                }
            }
        }

        for (guides in result) {
            haxe.ds.ArraySort.sort(guides, (a, b) -> a.visibleColumn - b.visibleColumn);
        }

        return result;
    }

    function getVisibleColumnFromPosition(position:Position):Int {
        return CursorColumns.visibleColumnFromColumn(
            this.textModel.getLineContent(position.lineNumber),
            position.column,
            this.textModel.getOptions().tabSize
        ) + 1;
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
