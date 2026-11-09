// Ported from vscode src/vs/editor/common/core/positionToOffset.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

class PositionOffsetTransformer {

    final lineStartOffsetByLineIdx:Array<Int>;

    public final text:String;

    public function new(text:String) {
        this.text = text;
        this.lineStartOffsetByLineIdx = [];
        this.lineStartOffsetByLineIdx.push(0);
        for (i in 0...text.length) {
            if (StringTools.fastCodeAt(text, i) == '\n'.code) {
                this.lineStartOffsetByLineIdx.push(i + 1);
            }
        }
    }

    public function getOffset(position:Position):Int {
        return this.lineStartOffsetByLineIdx[position.lineNumber - 1] + position.column - 1;
    }

    public function getOffsetRange(range:Range):OffsetRange {
        return new OffsetRange(
            this.getOffset(range.getStartPosition()),
            this.getOffset(range.getEndPosition())
        );
    }

    public function getPosition(offset:Int):Position {
        // findLastIdxMonotonous(lineStartOffsetByLineIdx, i => i <= offset)
        var idx = -1;
        for (i in 0...this.lineStartOffsetByLineIdx.length) {
            if (this.lineStartOffsetByLineIdx[i] <= offset) {
                idx = i;
            }
            else {
                break;
            }
        }
        final lineNumber = idx + 1;
        final column = offset - this.lineStartOffsetByLineIdx[idx] + 1;
        return new Position(lineNumber, column);
    }

    public function getRange(offsetRange:OffsetRange):Range {
        return Range.fromPositions(
            this.getPosition(offsetRange.start),
            this.getPosition(offsetRange.endExclusive)
        );
    }

    public function getTextLength(offsetRange:OffsetRange):TextLength {
        return TextLength.ofRange(this.getRange(offsetRange));
    }

    public var textLength(get, never):TextLength;
    function get_textLength():TextLength {
        final lineIdx = this.lineStartOffsetByLineIdx.length - 1;
        return new TextLength(lineIdx, this.text.length - this.lineStartOffsetByLineIdx[lineIdx]);
    }

}
