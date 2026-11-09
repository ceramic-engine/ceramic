// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/nodeReader.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;

/**
 * Allows to efficiently find a longest child at a given offset in a fixed node.
 * The requested offsets must increase monotonously.
 */
class NodeReader {

    final nextNodes:Array<AstNode>;
    final offsets:Array<Length>;
    final idxs:Array<Int>;
    var lastOffset:Length = Length.lengthZero;

    public function new(node:AstNode) {
        nextNodes = [node];
        offsets = [Length.lengthZero];
        idxs = [];
    }

    /**
     * Returns the longest node at `offset` that satisfies the predicate.
     * @param offset must be greater than or equal to the last offset this method has been called with!
     */
    public function readLongestNodeAt(offset:Length, predicate:(node:AstNode) -> Bool):Null<AstNode> {
        if (Length.lengthLessThan(offset, lastOffset)) {
            throw 'Invalid offset';
        }
        lastOffset = offset;

        // Find the longest node of all those that are closest to the current offset.
        while (true) {
            if (nextNodes.length == 0) {
                return null;
            }
            final curNode = nextNodes[nextNodes.length - 1];
            final curNodeOffset = offsets[offsets.length - 1];

            if (Length.lengthLessThan(offset, curNodeOffset)) {
                // The next best node is not here yet.
                // The reader must advance before a cached node is hit.
                return null;
            }

            if (Length.lengthLessThan(curNodeOffset, offset)) {
                // The reader is ahead of the current node.
                if (Length.lengthLessThanEqual(Length.lengthAdd(curNodeOffset, curNode.length), offset)) {
                    // The reader is after the end of the current node.
                    nextNodeAfterCurrent();
                }
                else {
                    // The reader is somewhere in the current node.
                    final nextChildIdx = getNextChildIdx(curNode);
                    if (nextChildIdx != -1) {
                        // Go to the first child and repeat.
                        nextNodes.push(curNode.getChild(nextChildIdx));
                        offsets.push(curNodeOffset);
                        idxs.push(nextChildIdx);
                    }
                    else {
                        // We don't have children
                        nextNodeAfterCurrent();
                    }
                }
            }
            else {
                // readerOffsetBeforeChange === curNodeOffset
                if (predicate(curNode)) {
                    nextNodeAfterCurrent();
                    return curNode;
                }
                else {
                    final nextChildIdx = getNextChildIdx(curNode);
                    // look for shorter node
                    if (nextChildIdx == -1) {
                        // There is no shorter node.
                        nextNodeAfterCurrent();
                        return null;
                    }
                    else {
                        // Descend into first child & repeat.
                        nextNodes.push(curNode.getChild(nextChildIdx));
                        offsets.push(curNodeOffset);
                        idxs.push(nextChildIdx);
                    }
                }
            }
        }
    }

    // Navigates to the longest node that continues after the current node.
    function nextNodeAfterCurrent():Void {
        while (true) {
            final currentOffset = offsets.length > 0 ? offsets[offsets.length - 1] : Length.lengthZero;
            final currentNode = nextNodes.length > 0 ? nextNodes[nextNodes.length - 1] : null;
            nextNodes.pop();
            offsets.pop();

            if (idxs.length == 0) {
                // We just popped the root node, there is no next node.
                break;
            }

            // Parent is not undefined, because idxs is not empty
            final parent = nextNodes[nextNodes.length - 1];
            final nextChildIdx = getNextChildIdx(parent, idxs[idxs.length - 1]);

            if (nextChildIdx != -1) {
                nextNodes.push(parent.getChild(nextChildIdx));
                offsets.push(Length.lengthAdd(currentOffset, currentNode.length));
                idxs[idxs.length - 1] = nextChildIdx;
                break;
            }
            else {
                idxs.pop();
            }
            // We fully consumed the parent.
            // Current node is now parent, so call nextNodeAfterCurrent again
        }
    }

    static function getNextChildIdx(node:AstNode, curIdx:Int = -1):Int {
        while (true) {
            curIdx++;
            if (curIdx >= node.childrenLength) {
                return -1;
            }
            if (node.getChild(curIdx) != null) {
                return curIdx;
            }
        }
    }

}
