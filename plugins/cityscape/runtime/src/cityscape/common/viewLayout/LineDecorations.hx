// Ported from vscode src/vs/editor/common/viewLayout/lineDecorations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

import cityscape.base.common.Strings;
import cityscape.common.DecorationStyle.IDecorationStyle;
import cityscape.common.ViewModel.InlineDecoration;
import cityscape.common.ViewModel.InlineDecorationType;
import cityscape.common.viewLayout.LinePart.LinePartMetadata;

class LineDecoration {

    public final startColumn:Int;
    public final endColumn:Int;
    public final className:String;
    public final type:InlineDecorationType;

    /**
     * The typed style of the decoration (Cityscape), or null.
     */
    public final style:Null<IDecorationStyle>;

    public function new(startColumn:Int, endColumn:Int, className:String, type:InlineDecorationType, ?style:IDecorationStyle) {
        this.startColumn = startColumn;
        this.endColumn = endColumn;
        this.className = className;
        this.type = type;
        this.style = style;
    }

    static function _equals(a:LineDecoration, b:LineDecoration):Bool {
        return (
            a.startColumn == b.startColumn
            && a.endColumn == b.endColumn
            && a.className == b.className
            && a.type == b.type
            && a.style == b.style
        );
    }

    public static function equalsArr(a:Array<LineDecoration>, b:Array<LineDecoration>):Bool {
        final aLen = a.length;
        final bLen = b.length;
        if (aLen != bLen) {
            return false;
        }
        for (i in 0...aLen) {
            if (!LineDecoration._equals(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

    public static function extractWrapped(arr:Array<LineDecoration>, startOffset:Int, endOffset:Int):Array<LineDecoration> {
        if (arr.length == 0) {
            return arr;
        }
        final startColumn = startOffset + 1;
        final endColumn = endOffset + 1;
        final lineLength = endOffset - startOffset;
        final r = [];
        for (dec in arr) {
            if (dec.endColumn <= startColumn || dec.startColumn >= endColumn) {
                continue;
            }
            final s = dec.startColumn - startColumn + 1;
            final e = dec.endColumn - startColumn + 1;
            r.push(new LineDecoration(s > 1 ? s : 1, e < lineLength + 1 ? e : lineLength + 1, dec.className, dec.type, dec.style));
        }
        return r;
    }

    public static function filter(lineDecorations:Array<InlineDecoration>, lineNumber:Int, minLineColumn:Int, maxLineColumn:Int):Array<LineDecoration> {
        if (lineDecorations.length == 0) {
            return [];
        }

        final result:Array<LineDecoration> = [];

        for (i in 0...lineDecorations.length) {
            final d = lineDecorations[i];
            final range = d.range;

            if (range.endLineNumber < lineNumber || range.startLineNumber > lineNumber) {
                // Ignore decorations that sit outside this line
                continue;
            }

            if (range.isEmpty() && (d.type == InlineDecorationType.Regular || d.type == InlineDecorationType.RegularAffectingLetterSpacing)) {
                // Ignore empty range decorations
                continue;
            }

            final startColumn = (range.startLineNumber == lineNumber ? range.startColumn : minLineColumn);
            final endColumn = (range.endLineNumber == lineNumber ? range.endColumn : maxLineColumn);

            result.push(new LineDecoration(startColumn, endColumn, d.inlineClassName, d.type, d.style));
        }

        return result;
    }

    static function _typeCompare(a:InlineDecorationType, b:InlineDecorationType):Int {
        final ORDER = [2, 0, 1, 3];
        return ORDER[a] - ORDER[b];
    }

    public static function compare(a:LineDecoration, b:LineDecoration):Int {
        if (a.startColumn != b.startColumn) {
            return a.startColumn - b.startColumn;
        }

        if (a.endColumn != b.endColumn) {
            return a.endColumn - b.endColumn;
        }

        final typeCmp = LineDecoration._typeCompare(a.type, b.type);
        if (typeCmp != 0) {
            return typeCmp;
        }

        if (a.className != b.className) {
            return a.className < b.className ? -1 : 1;
        }

        return 0;
    }

}

class DecorationSegment {

    public var startOffset:Int;
    public var endOffset:Int;
    public var className:String;
    public var metadata:Int;

    public function new(startOffset:Int, endOffset:Int, className:String, metadata:Int) {
        this.startOffset = startOffset;
        this.endOffset = endOffset;
        this.className = className;
        this.metadata = metadata;
    }

}

private class Stack {

    public var count:Int;
    final stopOffsets:Array<Int>;
    final classNames:Array<String>;
    final metadata:Array<Int>;

    public function new() {
        this.stopOffsets = [];
        this.classNames = [];
        this.metadata = [];
        this.count = 0;
    }

    static function _metadata(metadata:Array<Int>):Int {
        var result = 0;
        for (i in 0...metadata.length) {
            result |= metadata[i];
        }
        return result;
    }

    public function consumeLowerThan(maxStopOffset:Int, nextStartOffset:Int, result:Array<DecorationSegment>):Int {

        while (this.count > 0 && this.stopOffsets[0] < maxStopOffset) {
            var i = 0;

            // Take all equal stopping offsets
            while (i + 1 < this.count && this.stopOffsets[i] == this.stopOffsets[i + 1]) {
                i++;
            }

            // Basically we are consuming the first i + 1 elements of the stack
            result.push(new DecorationSegment(nextStartOffset, this.stopOffsets[i], this.classNames.join(' '), Stack._metadata(this.metadata)));
            nextStartOffset = this.stopOffsets[i] + 1;

            // Consume them
            this.stopOffsets.splice(0, i + 1);
            this.classNames.splice(0, i + 1);
            this.metadata.splice(0, i + 1);
            this.count -= (i + 1);
        }

        if (this.count > 0 && nextStartOffset < maxStopOffset) {
            result.push(new DecorationSegment(nextStartOffset, maxStopOffset - 1, this.classNames.join(' '), Stack._metadata(this.metadata)));
            nextStartOffset = maxStopOffset;
        }

        return nextStartOffset;
    }

    public function insert(stopOffset:Int, className:String, metadata:Int):Void {
        if (this.count == 0 || this.stopOffsets[this.count - 1] <= stopOffset) {
            // Insert at the end
            this.stopOffsets.push(stopOffset);
            this.classNames.push(className);
            this.metadata.push(metadata);
        } else {
            // Find the insertion position for `stopOffset`
            for (i in 0...this.count) {
                if (this.stopOffsets[i] >= stopOffset) {
                    this.stopOffsets.insert(i, stopOffset);
                    this.classNames.insert(i, className);
                    this.metadata.insert(i, metadata);
                    break;
                }
            }
        }
        this.count++;
        return;
    }

}

class LineDecorationsNormalizer {

    /**
     * `Constants.MAX_SAFE_SMALL_INTEGER` (vs/base/common/uint.ts).
     */
    static inline final MAX_SAFE_SMALL_INTEGER:Int = 1 << 30;

    /**
     * Normalize line decorations. Overlapping decorations will generate multiple segments
     */
    public static function normalize(lineContent:String, lineDecorations:Array<LineDecoration>):Array<DecorationSegment> {
        if (lineDecorations.length == 0) {
            return [];
        }

        final result:Array<DecorationSegment> = [];

        final stack = new Stack();
        var nextStartOffset = 0;

        for (i in 0...lineDecorations.length) {
            final d = lineDecorations[i];
            var startColumn = d.startColumn;
            var endColumn = d.endColumn;
            final className = d.className;
            final metadata = (
                d.type == InlineDecorationType.Before
                    ? LinePartMetadata.PSEUDO_BEFORE
                    : d.type == InlineDecorationType.After
                        ? LinePartMetadata.PSEUDO_AFTER
                        : 0
            );

            // If the position would end up in the middle of a high-low surrogate pair, we move it to before the pair
            if (startColumn > 1 && startColumn - 2 < lineContent.length) {
                final charCodeBefore = StringTools.fastCodeAt(lineContent, startColumn - 2);
                if (Strings.isHighSurrogate(charCodeBefore)) {
                    startColumn--;
                }
            }

            if (endColumn > 1 && endColumn - 2 < lineContent.length) {
                final charCodeBefore = StringTools.fastCodeAt(lineContent, endColumn - 2);
                if (Strings.isHighSurrogate(charCodeBefore)) {
                    endColumn--;
                }
            }

            final currentStartOffset = startColumn - 1;
            final currentEndOffset = endColumn - 2;

            nextStartOffset = stack.consumeLowerThan(currentStartOffset, nextStartOffset, result);

            if (stack.count == 0) {
                nextStartOffset = currentStartOffset;
            }
            stack.insert(currentEndOffset, className, metadata);
        }

        stack.consumeLowerThan(MAX_SAFE_SMALL_INTEGER, nextStartOffset, result);

        return result;
    }

}
