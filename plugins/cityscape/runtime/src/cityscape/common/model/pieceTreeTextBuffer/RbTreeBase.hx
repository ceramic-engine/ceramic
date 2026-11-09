// Ported from vscode src/vs/editor/common/model/pieceTreeTextBuffer/rbTreeBase.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.pieceTreeTextBuffer;

import cityscape.common.model.pieceTreeTextBuffer.PieceTreeBase.Piece;

/**
 * A node of the red-black tree of a piece tree.
 *
 * Monaco shares one `SENTINEL` node between all the trees and writes to it
 * during deletions (its parent is reset afterwards). Cityscape gives each
 * tree its own sentinel (`PieceTreeBase.SENTINEL`) so that no state is
 * shared between models (several editors, threads); `next` and `prev` take
 * the sentinel of the tree.
 */
class TreeNode {

    public var parent:TreeNode;

    public var left:TreeNode;

    public var right:TreeNode;

    public var color:NodeColor;

    // Piece
    public var piece:Piece;

    /**
     * size of the left subtree (not inorder)
     */
    public var size_left:Int;

    /**
     * line feeds cnt in the left subtree (not in order)
     */
    public var lf_left:Int;

    public function new(piece:Piece, color:NodeColor) {
        this.piece = piece;
        this.color = color;
        this.size_left = 0;
        this.lf_left = 0;
        this.parent = this;
        this.left = this;
        this.right = this;
    }

    public function next(SENTINEL:TreeNode):TreeNode {
        if (this.right != SENTINEL) {
            return RbTreeBase.leftest(this.right, SENTINEL);
        }

        var node:TreeNode = this;

        while (node.parent != SENTINEL) {
            if (node.parent.left == node) {
                break;
            }

            node = node.parent;
        }

        if (node.parent == SENTINEL) {
            return SENTINEL;
        }
        else {
            return node.parent;
        }
    }

    public function prev(SENTINEL:TreeNode):TreeNode {
        if (this.left != SENTINEL) {
            return RbTreeBase.righttest(this.left, SENTINEL);
        }

        var node:TreeNode = this;

        while (node.parent != SENTINEL) {
            if (node.parent.right == node) {
                break;
            }

            node = node.parent;
        }

        if (node.parent == SENTINEL) {
            return SENTINEL;
        }
        else {
            return node.parent;
        }
    }

    public function detach():Void {
        this.parent = null;
        this.left = null;
        this.right = null;
    }

}

enum abstract NodeColor(Int) from Int to Int {
    var Black = 0;
    var Red = 1;
}

/**
 * Module functions of rbTreeBase.ts.
 */
class RbTreeBase {

    /**
     * A new sentinel node (black, its own parent and children).
     */
    public static function createSentinel():TreeNode {
        final sentinel = new TreeNode(null, NodeColor.Black);
        sentinel.parent = sentinel;
        sentinel.left = sentinel;
        sentinel.right = sentinel;
        sentinel.color = NodeColor.Black;
        return sentinel;
    }

    public static function leftest(node:TreeNode, SENTINEL:TreeNode):TreeNode {
        while (node.left != SENTINEL) {
            node = node.left;
        }
        return node;
    }

    public static function righttest(node:TreeNode, SENTINEL:TreeNode):TreeNode {
        while (node.right != SENTINEL) {
            node = node.right;
        }
        return node;
    }

    static function calculateSize(node:TreeNode, SENTINEL:TreeNode):Int {
        var result = 0;
        // Iterative version of `node.size_left + node.piece.length + calculateSize(node.right)`
        while (node != SENTINEL) {
            result += node.size_left + node.piece.length;
            node = node.right;
        }
        return result;
    }

    static function calculateLF(node:TreeNode, SENTINEL:TreeNode):Int {
        var result = 0;
        // Iterative version of `node.lf_left + node.piece.lineFeedCnt + calculateLF(node.right)`
        while (node != SENTINEL) {
            result += node.lf_left + node.piece.lineFeedCnt;
            node = node.right;
        }
        return result;
    }

    static inline function resetSentinel(SENTINEL:TreeNode):Void {
        SENTINEL.parent = SENTINEL;
    }

    public static function leftRotate(tree:PieceTreeBase, x:TreeNode):Void {
        final SENTINEL = tree.SENTINEL;
        final y = x.right;

        // fix size_left
        y.size_left += x.size_left + (x.piece != null ? x.piece.length : 0);
        y.lf_left += x.lf_left + (x.piece != null ? x.piece.lineFeedCnt : 0);
        x.right = y.left;

        if (y.left != SENTINEL) {
            y.left.parent = x;
        }
        y.parent = x.parent;
        if (x.parent == SENTINEL) {
            tree.root = y;
        }
        else if (x.parent.left == x) {
            x.parent.left = y;
        }
        else {
            x.parent.right = y;
        }
        y.left = x;
        x.parent = y;
    }

    public static function rightRotate(tree:PieceTreeBase, y:TreeNode):Void {
        final SENTINEL = tree.SENTINEL;
        final x = y.left;
        y.left = x.right;
        if (x.right != SENTINEL) {
            x.right.parent = y;
        }
        x.parent = y.parent;

        // fix size_left
        y.size_left -= x.size_left + (x.piece != null ? x.piece.length : 0);
        y.lf_left -= x.lf_left + (x.piece != null ? x.piece.lineFeedCnt : 0);

        if (y.parent == SENTINEL) {
            tree.root = x;
        }
        else if (y == y.parent.right) {
            y.parent.right = x;
        }
        else {
            y.parent.left = x;
        }

        x.right = y;
        y.parent = x;
    }

    public static function rbDelete(tree:PieceTreeBase, z:TreeNode):Void {
        final SENTINEL = tree.SENTINEL;
        var x:TreeNode;
        var y:TreeNode;

        if (z.left == SENTINEL) {
            y = z;
            x = y.right;
        }
        else if (z.right == SENTINEL) {
            y = z;
            x = y.left;
        }
        else {
            y = leftest(z.right, SENTINEL);
            x = y.right;
        }

        if (y == tree.root) {
            tree.root = x;

            // if x is null, we are removing the only node
            x.color = NodeColor.Black;
            z.detach();
            resetSentinel(SENTINEL);
            tree.root.parent = SENTINEL;

            return;
        }

        final yWasRed = (y.color == NodeColor.Red);

        if (y == y.parent.left) {
            y.parent.left = x;
        }
        else {
            y.parent.right = x;
        }

        if (y == z) {
            x.parent = y.parent;
            recomputeTreeMetadata(tree, x);
        }
        else {
            if (y.parent == z) {
                x.parent = y;
            }
            else {
                x.parent = y.parent;
            }

            // as we make changes to x's hierarchy, update size_left of subtree first
            recomputeTreeMetadata(tree, x);

            y.left = z.left;
            y.right = z.right;
            y.parent = z.parent;
            y.color = z.color;

            if (z == tree.root) {
                tree.root = y;
            }
            else {
                if (z == z.parent.left) {
                    z.parent.left = y;
                }
                else {
                    z.parent.right = y;
                }
            }

            if (y.left != SENTINEL) {
                y.left.parent = y;
            }
            if (y.right != SENTINEL) {
                y.right.parent = y;
            }
            // update metadata
            // we replace z with y, so in this sub tree, the length change is z.item.length
            y.size_left = z.size_left;
            y.lf_left = z.lf_left;
            recomputeTreeMetadata(tree, y);
        }

        z.detach();

        if (x.parent.left == x) {
            final newSizeLeft = calculateSize(x, SENTINEL);
            final newLFLeft = calculateLF(x, SENTINEL);
            if (newSizeLeft != x.parent.size_left || newLFLeft != x.parent.lf_left) {
                final delta = newSizeLeft - x.parent.size_left;
                final lf_delta = newLFLeft - x.parent.lf_left;
                x.parent.size_left = newSizeLeft;
                x.parent.lf_left = newLFLeft;
                updateTreeMetadata(tree, x.parent, delta, lf_delta);
            }
        }

        recomputeTreeMetadata(tree, x.parent);

        if (yWasRed) {
            resetSentinel(SENTINEL);
            return;
        }

        // RB-DELETE-FIXUP
        var w:TreeNode;
        while (x != tree.root && x.color == NodeColor.Black) {
            if (x == x.parent.left) {
                w = x.parent.right;

                if (w.color == NodeColor.Red) {
                    w.color = NodeColor.Black;
                    x.parent.color = NodeColor.Red;
                    leftRotate(tree, x.parent);
                    w = x.parent.right;
                }

                if (w.left.color == NodeColor.Black && w.right.color == NodeColor.Black) {
                    w.color = NodeColor.Red;
                    x = x.parent;
                }
                else {
                    if (w.right.color == NodeColor.Black) {
                        w.left.color = NodeColor.Black;
                        w.color = NodeColor.Red;
                        rightRotate(tree, w);
                        w = x.parent.right;
                    }

                    w.color = x.parent.color;
                    x.parent.color = NodeColor.Black;
                    w.right.color = NodeColor.Black;
                    leftRotate(tree, x.parent);
                    x = tree.root;
                }
            }
            else {
                w = x.parent.left;

                if (w.color == NodeColor.Red) {
                    w.color = NodeColor.Black;
                    x.parent.color = NodeColor.Red;
                    rightRotate(tree, x.parent);
                    w = x.parent.left;
                }

                if (w.left.color == NodeColor.Black && w.right.color == NodeColor.Black) {
                    w.color = NodeColor.Red;
                    x = x.parent;
                }
                else {
                    if (w.left.color == NodeColor.Black) {
                        w.right.color = NodeColor.Black;
                        w.color = NodeColor.Red;
                        leftRotate(tree, w);
                        w = x.parent.left;
                    }

                    w.color = x.parent.color;
                    x.parent.color = NodeColor.Black;
                    w.left.color = NodeColor.Black;
                    rightRotate(tree, x.parent);
                    x = tree.root;
                }
            }
        }
        x.color = NodeColor.Black;
        resetSentinel(SENTINEL);
    }

    public static function fixInsert(tree:PieceTreeBase, x:TreeNode):Void {
        recomputeTreeMetadata(tree, x);

        while (x != tree.root && x.parent.color == NodeColor.Red) {
            if (x.parent == x.parent.parent.left) {
                final y = x.parent.parent.right;

                if (y.color == NodeColor.Red) {
                    x.parent.color = NodeColor.Black;
                    y.color = NodeColor.Black;
                    x.parent.parent.color = NodeColor.Red;
                    x = x.parent.parent;
                }
                else {
                    if (x == x.parent.right) {
                        x = x.parent;
                        leftRotate(tree, x);
                    }

                    x.parent.color = NodeColor.Black;
                    x.parent.parent.color = NodeColor.Red;
                    rightRotate(tree, x.parent.parent);
                }
            }
            else {
                final y = x.parent.parent.left;

                if (y.color == NodeColor.Red) {
                    x.parent.color = NodeColor.Black;
                    y.color = NodeColor.Black;
                    x.parent.parent.color = NodeColor.Red;
                    x = x.parent.parent;
                }
                else {
                    if (x == x.parent.left) {
                        x = x.parent;
                        rightRotate(tree, x);
                    }
                    x.parent.color = NodeColor.Black;
                    x.parent.parent.color = NodeColor.Red;
                    leftRotate(tree, x.parent.parent);
                }
            }
        }

        tree.root.color = NodeColor.Black;
    }

    public static function updateTreeMetadata(tree:PieceTreeBase, x:TreeNode, delta:Int, lineFeedCntDelta:Int):Void {
        final SENTINEL = tree.SENTINEL;
        // node length change or line feed count change
        while (x != tree.root && x != SENTINEL) {
            if (x.parent.left == x) {
                x.parent.size_left += delta;
                x.parent.lf_left += lineFeedCntDelta;
            }

            x = x.parent;
        }
    }

    public static function recomputeTreeMetadata(tree:PieceTreeBase, x:TreeNode):Void {
        final SENTINEL = tree.SENTINEL;
        var delta = 0;
        var lf_delta = 0;
        if (x == tree.root) {
            return;
        }

        // go upwards till the node whose left subtree is changed.
        while (x != tree.root && x == x.parent.right) {
            x = x.parent;
        }

        if (x == tree.root) {
            // well, it means we add a node to the end (inorder)
            return;
        }

        // x is the node whose right subtree is changed.
        x = x.parent;

        delta = calculateSize(x.left, SENTINEL) - x.size_left;
        lf_delta = calculateLF(x.left, SENTINEL) - x.lf_left;
        x.size_left += delta;
        x.lf_left += lf_delta;

        // go upwards till root. O(logN)
        while (x != tree.root && (delta != 0 || lf_delta != 0)) {
            if (x.parent.left == x) {
                x.parent.size_left += delta;
                x.parent.lf_left += lf_delta;
            }

            x = x.parent;
        }
    }

}
