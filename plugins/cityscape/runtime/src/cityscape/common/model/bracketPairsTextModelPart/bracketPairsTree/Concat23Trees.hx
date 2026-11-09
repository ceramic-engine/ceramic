// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/concat23Trees.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;

/**
 * Module functions of concat23Trees.ts.
 */
class Concat23Trees {

    /**
     * Concatenates a list of (2,3) AstNode's into a single (2,3) AstNode.
     * This mutates the items of the input array!
     * If all items have the same height, this method has runtime O(items.length).
     * Otherwise, it has runtime O(items.length * max(log(items.length), items.max(i => i.height))).
     */
    public static function concat23Trees(items:Array<AstNode>):Null<AstNode> {
        if (items.length == 0) {
            return null;
        }
        if (items.length == 1) {
            return items[0];
        }

        var i = 0;
        /**
         * Reads nodes of same height and concatenates them to a single node.
         */
        function readNode():Null<AstNode> {
            if (i >= items.length) {
                return null;
            }
            final start = i;
            final height = items[start].listHeight;

            i++;
            while (i < items.length && items[i].listHeight == height) {
                i++;
            }

            if (i - start >= 2) {
                return concat23TreesOfSameHeight(start == 0 && i == items.length ? items : items.slice(start, i), false);
            }
            else {
                return items[start];
            }
        }

        // The items might not have the same height.
        // We merge all items by using a binary concat operator.
        var first:AstNode = readNode(); // There must be a first item
        var second:Null<AstNode> = readNode();
        if (second == null) {
            return first;
        }

        var item = readNode();
        while (item != null) {
            // Prefer concatenating smaller trees, as the runtime of concat depends on the tree height.
            if (heightDiff(first, second) <= heightDiff(second, item)) {
                first = concat(first, second);
                second = item;
            }
            else {
                second = concat(second, item);
            }
            item = readNode();
        }

        final result = concat(first, second);
        return result;
    }

    public static function concat23TreesOfSameHeight(items:Array<AstNode>, createImmutableLists:Bool = false):Null<AstNode> {
        if (items.length == 0) {
            return null;
        }
        if (items.length == 1) {
            return items[0];
        }

        var length = items.length;
        // All trees have same height, just create parent nodes.
        while (length > 3) {
            final newLength = length >> 1;
            for (i in 0...newLength) {
                final j = i << 1;
                items[i] = ListAstNode.create23(items[j], items[j + 1], j + 3 == length ? items[j + 2] : null, createImmutableLists);
            }
            length = newLength;
        }
        return ListAstNode.create23(items[0], items[1], length >= 3 ? items[2] : null, createImmutableLists);
    }

    static inline function heightDiff(node1:AstNode, node2:AstNode):Int {
        final d = node1.listHeight - node2.listHeight;
        return d < 0 ? -d : d;
    }

    static function concat(node1:AstNode, node2:AstNode):AstNode {
        if (node1.listHeight == node2.listHeight) {
            return ListAstNode.create23(node1, node2, null, false);
        }
        else if (node1.listHeight > node2.listHeight) {
            // node1 is the tree we want to insert into
            return append(cast node1, node2);
        }
        else {
            return prepend(cast node2, node1);
        }
    }

    /**
     * Appends the given node to the end of this (2,3) tree.
     * Returns the new root.
     */
    static function append(list:ListAstNode, nodeToAppend:AstNode):AstNode {
        list = list.toMutable();
        var curNode:AstNode = list;
        final parents:Array<ListAstNode> = [];
        var nodeToAppendOfCorrectHeight:Null<AstNode> = null;
        while (true) {
            // assert nodeToInsert.listHeight <= curNode.listHeight
            if (nodeToAppend.listHeight == curNode.listHeight) {
                nodeToAppendOfCorrectHeight = nodeToAppend;
                break;
            }
            // assert 0 <= nodeToInsert.listHeight < curNode.listHeight
            if (curNode.kind != AstNodeKind.List) {
                throw 'unexpected';
            }
            final curList:ListAstNode = cast curNode;
            parents.push(curList);
            // assert 2 <= curNode.childrenLength <= 3
            curNode = curList.makeLastElementMutable();
        }
        // assert nodeToAppendOfCorrectHeight!.listHeight === curNode.listHeight
        var i = parents.length - 1;
        while (i >= 0) {
            final parent = parents[i];
            if (nodeToAppendOfCorrectHeight != null) {
                // Can we take the element?
                if (parent.childrenLength >= 3) {
                    // assert parent.childrenLength === 3 && parent.listHeight === nodeToAppendOfCorrectHeight.listHeight + 1

                    // we need to split to maintain (2,3)-tree property.
                    // Send the third element + the new element to the parent.
                    nodeToAppendOfCorrectHeight = ListAstNode.create23(parent.unappendChild(), nodeToAppendOfCorrectHeight, null, false);
                }
                else {
                    parent.appendChildOfSameHeight(nodeToAppendOfCorrectHeight);
                    nodeToAppendOfCorrectHeight = null;
                }
            }
            else {
                parent.handleChildrenChanged();
            }
            i--;
        }
        if (nodeToAppendOfCorrectHeight != null) {
            return ListAstNode.create23(list, nodeToAppendOfCorrectHeight, null, false);
        }
        else {
            return list;
        }
    }

    /**
     * Prepends the given node to the end of this (2,3) tree.
     * Returns the new root.
     */
    static function prepend(list:ListAstNode, nodeToAppend:AstNode):AstNode {
        list = list.toMutable();
        var curNode:AstNode = list;
        final parents:Array<ListAstNode> = [];
        // assert nodeToInsert.listHeight <= curNode.listHeight
        while (nodeToAppend.listHeight != curNode.listHeight) {
            // assert 0 <= nodeToInsert.listHeight < curNode.listHeight
            if (curNode.kind != AstNodeKind.List) {
                throw 'unexpected';
            }
            final curList:ListAstNode = cast curNode;
            parents.push(curList);
            // assert 2 <= curNode.childrenFast.length <= 3
            curNode = curList.makeFirstElementMutable();
        }
        var nodeToPrependOfCorrectHeight:Null<AstNode> = nodeToAppend;
        // assert nodeToAppendOfCorrectHeight!.listHeight === curNode.listHeight
        var i = parents.length - 1;
        while (i >= 0) {
            final parent = parents[i];
            if (nodeToPrependOfCorrectHeight != null) {
                // Can we take the element?
                if (parent.childrenLength >= 3) {
                    // assert parent.childrenLength === 3 && parent.listHeight === nodeToAppendOfCorrectHeight.listHeight + 1

                    // we need to split to maintain (2,3)-tree property.
                    // Send the third element + the new element to the parent.
                    nodeToPrependOfCorrectHeight = ListAstNode.create23(nodeToPrependOfCorrectHeight, parent.unprependChild(), null, false);
                }
                else {
                    parent.prependChildOfSameHeight(nodeToPrependOfCorrectHeight);
                    nodeToPrependOfCorrectHeight = null;
                }
            }
            else {
                parent.handleChildrenChanged();
            }
            i--;
        }
        if (nodeToPrependOfCorrectHeight != null) {
            return ListAstNode.create23(nodeToPrependOfCorrectHeight, list, null, false);
        }
        else {
            return list;
        }
    }

}
