// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/combineTextEditInfos.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.Arrays.ArrayQueue;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BeforeEditPositionMapper.TextEditInfo;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;

/**
 * Module functions of combineTextEditInfos.ts.
 */
class CombineTextEditInfos {

    public static function combineTextEditInfos(textEditInfoFirst:Array<TextEditInfo>, textEditInfoSecond:Array<TextEditInfo>):Array<TextEditInfo> {
        if (textEditInfoFirst.length == 0) {
            return textEditInfoSecond;
        }
        if (textEditInfoSecond.length == 0) {
            return textEditInfoFirst;
        }

        // s0: State before any edits
        final s0ToS1Map = new ArrayQueue(toLengthMapping(textEditInfoFirst));
        // s1: State after first edit, but before second edit
        final s1ToS2Map:Array<Null<LengthMapping>> = cast toLengthMapping(textEditInfoSecond);
        s1ToS2Map.push(null); // Copy everything from old to new (Monaco's `{ modified: false, lengthBefore: undefined, lengthAfter: undefined }`)
        // s2: State after both edits

        var curItem:Null<LengthMapping> = s0ToS1Map.dequeue();

        /**
         * @param s1Length Use null for length "infinity"
         */
        function nextS0ToS1MapWithS1LengthOf(s1Length:Null<Length>):Array<LengthMapping> {
            if (s1Length == null) {
                final taken = s0ToS1Map.takeWhile(v -> true);
                final arr = taken != null ? taken : [];
                if (curItem != null) {
                    arr.unshift(curItem);
                }
                return arr;
            }

            var length:Length = s1Length;
            final result:Array<LengthMapping> = [];
            while (curItem != null && !Length.lengthIsZero(length)) {
                final split = curItem.splitAt(length);
                final item = split.item;
                result.push(item);
                length = Length.lengthDiffNonNegative(item.lengthAfter, length);
                curItem = split.remainingItem != null ? split.remainingItem : s0ToS1Map.dequeue();
            }
            if (!Length.lengthIsZero(length)) {
                result.push(new LengthMapping(false, length, length));
            }
            return result;
        }

        final result:Array<TextEditInfo> = [];

        function pushEdit(startOffset:Length, endOffset:Length, newLength:Length):Void {
            if (result.length > 0 && Length.lengthEquals(result[result.length - 1].endOffset, startOffset)) {
                final lastResult = result[result.length - 1];
                result[result.length - 1] = new TextEditInfo(lastResult.startOffset, endOffset, Length.lengthAdd(lastResult.newLength, newLength));
            }
            else {
                result.push(new TextEditInfo(startOffset, endOffset, newLength));
            }
        }

        var s0offset = Length.lengthZero;
        for (s1ToS2 in s1ToS2Map) {
            final s0ToS1Map = nextS0ToS1MapWithS1LengthOf(s1ToS2 != null ? s1ToS2.lengthBefore : null);
            if (s1ToS2 != null && s1ToS2.modified) {
                final s0Length = Length.sumLengths(s0ToS1Map, s -> s.lengthBefore);
                final s0EndOffset = Length.lengthAdd(s0offset, s0Length);
                pushEdit(s0offset, s0EndOffset, s1ToS2.lengthAfter);
                s0offset = s0EndOffset;
            }
            else {
                for (s1 in s0ToS1Map) {
                    final s0startOffset = s0offset;
                    s0offset = Length.lengthAdd(s0offset, s1.lengthBefore);
                    if (s1.modified) {
                        pushEdit(s0startOffset, s0offset, s1.lengthAfter);
                    }
                }
            }
        }

        return result;
    }

    static function toLengthMapping(textEditInfos:Array<TextEditInfo>):Array<LengthMapping> {
        final result:Array<LengthMapping> = [];
        var lastOffset = Length.lengthZero;
        for (textEditInfo in textEditInfos) {
            final spaceLength = Length.lengthDiffNonNegative(lastOffset, textEditInfo.startOffset);
            if (!Length.lengthIsZero(spaceLength)) {
                result.push(new LengthMapping(false, spaceLength, spaceLength));
            }

            final lengthBefore = Length.lengthDiffNonNegative(textEditInfo.startOffset, textEditInfo.endOffset);
            result.push(new LengthMapping(true, lengthBefore, textEditInfo.newLength));
            lastOffset = textEditInfo.endOffset;
        }
        return result;
    }

}

private class LengthMapping {

    /**
     * If false, length before and length after equal.
     */
    public final modified:Bool;
    public final lengthBefore:Length;
    public final lengthAfter:Length;

    public function new(modified:Bool, lengthBefore:Length, lengthAfter:Length) {
        this.modified = modified;
        this.lengthBefore = lengthBefore;
        this.lengthAfter = lengthAfter;
    }

    public function splitAt(lengthAfter:Length):{item:LengthMapping, remainingItem:Null<LengthMapping>} {
        final remainingLengthAfter = Length.lengthDiffNonNegative(lengthAfter, this.lengthAfter);
        if (Length.lengthEquals(remainingLengthAfter, Length.lengthZero)) {
            return {item: this, remainingItem: null};
        }
        else if (modified) {
            return {
                item: new LengthMapping(modified, lengthBefore, lengthAfter),
                remainingItem: new LengthMapping(modified, Length.lengthZero, remainingLengthAfter)
            };
        }
        else {
            return {
                item: new LengthMapping(modified, lengthAfter, lengthAfter),
                remainingItem: new LengthMapping(modified, remainingLengthAfter, remainingLengthAfter)
            };
        }
    }

    public function toString():String {
        return (modified ? 'M' : 'U') + ':' + Length.lengthToObj(lengthBefore) + ' -> ' + Length.lengthToObj(lengthAfter);
    }

}
