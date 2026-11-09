// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/lineSequence.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.CharCode;
import cityscape.common.core.OffsetRange;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm.ISequence;

class LineSequence implements ISequence {

    final trimmedHash:Array<Int>;
    final lines:Array<String>;

    public function new(trimmedHash:Array<Int>, lines:Array<String>) {
        this.trimmedHash = trimmedHash;
        this.lines = lines;
    }

    public function getElement(offset:Int):Int {
        return this.trimmedHash[offset];
    }

    public var length(get, never):Int;
    function get_length():Int {
        return this.trimmedHash.length;
    }

    public function getBoundaryScore(length:Int):Int {
        final indentationBefore = length == 0 ? 0 : getIndentation(this.lines[length - 1]);
        final indentationAfter = length == this.lines.length ? 0 : getIndentation(this.lines[length]);
        return 1000 - (indentationBefore + indentationAfter);
    }

    public function getText(range:OffsetRange):String {
        return this.lines.slice(range.start, range.endExclusive).join('\n');
    }

    public function isStronglyEqual(offset1:Int, offset2:Int):Bool {
        return this.lines[offset1] == this.lines[offset2];
    }

    static function getIndentation(str:String):Int {
        var i = 0;
        while (i < str.length && (StringTools.fastCodeAt(str, i) == CharCode.Space || StringTools.fastCodeAt(str, i) == CharCode.Tab)) {
            i++;
        }
        return i;
    }

}
