// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/concat23Trees.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Concat23Trees;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import testing.TestCase;

/**
 * suite('Bracket Pair Colorizer - mergeItems')
 */
class Concat23TreesTest extends TestCase {

    function testClone() {
        final tree = ListAstNode.create([
            new TextAstNode(Length.toLength(1, 1)),
            new TextAstNode(Length.toLength(1, 1)),
        ]);

        assertTrue(equals(tree, tree.deepClone()));
    }

    static function equals(node1:AstNode, node2:AstNode):Bool {
        if (!Length.lengthEquals(node1.length, node2.length)) {
            return false;
        }

        if (node1.children.length != node2.children.length) {
            return false;
        }

        for (i in 0...node1.children.length) {
            if (!equals(node1.children[i], node2.children[i])) {
                return false;
            }
        }

        if (!node1.missingOpeningBracketIds.equals(node2.missingOpeningBracketIds)) {
            return false;
        }

        if (node1.kind == AstNodeKind.Pair && node2.kind == AstNodeKind.Pair) {
            return true;
        }
        else if (node1.kind == node2.kind) {
            return true;
        }

        return false;
    }

    function mergeAndCheck(lists:Array<AstNode>) {
        final merged = Concat23Trees.concat23Trees([for (l in lists) l.deepClone()]);
        final node = (merged != null ? merged : ListAstNode.create([])).flattenLists();
        // This trivial merge does not maintain the (2,3) tree invariant.
        final referenceNode = ListAstNode.create(lists).flattenLists();

        assertTrue(equals(node, referenceNode), 'merge23Trees failed');
    }

    function testEmptyList() {
        mergeAndCheck([]);
    }

    function testSameHeightLists() {
        final textNode = new TextAstNode(Length.toLength(1, 1));
        final tree = ListAstNode.create([textNode.deepClone(), textNode.deepClone()]);
        mergeAndCheck([tree.deepClone(), tree.deepClone(), tree.deepClone(), tree.deepClone(), tree.deepClone()]);
    }

    function testDifferentHeightLists1() {
        final textNode = new TextAstNode(Length.toLength(1, 1));
        final tree1 = ListAstNode.create([textNode.deepClone(), textNode.deepClone()]);
        final tree2 = ListAstNode.create([tree1.deepClone(), tree1.deepClone()]);

        mergeAndCheck([tree1, tree2]);
    }

    function testDifferentHeightLists2() {
        final textNode = new TextAstNode(Length.toLength(1, 1));
        final tree1 = ListAstNode.create([textNode.deepClone(), textNode.deepClone()]);
        final tree2 = ListAstNode.create([tree1.deepClone(), tree1.deepClone()]);

        mergeAndCheck([tree2, tree1]);
    }

    function testDifferentHeightLists3() {
        final textNode = new TextAstNode(Length.toLength(1, 1));
        final tree1 = ListAstNode.create([textNode.deepClone(), textNode.deepClone()]);
        final tree2 = ListAstNode.create([tree1.deepClone(), tree1.deepClone()]);

        mergeAndCheck([tree2, tree1, tree1, tree2, tree2]);
    }

}
