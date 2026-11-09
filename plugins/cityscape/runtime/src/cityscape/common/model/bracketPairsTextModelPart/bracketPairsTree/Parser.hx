// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/parser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BeforeEditPositionMapper;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Concat23Trees;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.NodeReader;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;

/**
 * Non incrementally built ASTs are immutable.
 */
class Parser {

    /**
     * `parseDocument` of parser.ts.
     * Non incrementally built ASTs are immutable.
     */
    public static function parseDocument(tokenizer:Tokenizer, edits:Array<TextEditInfo>, oldNode:Null<AstNode>, createImmutableLists:Bool):AstNode {
        final parser = new Parser(tokenizer, edits, oldNode, createImmutableLists);
        return parser.doParseDocument();
    }

    final oldNodeReader:Null<NodeReader>;
    final positionMapper:BeforeEditPositionMapper;
    var _itemsConstructed:Int = 0;
    var _itemsFromCache:Int = 0;

    /**
     * Reports how many nodes were constructed in the last parse operation.
     */
    public var nodesConstructed(get, never):Int;
    inline function get_nodesConstructed():Int {
        return _itemsConstructed;
    }

    /**
     * Reports how many nodes were reused in the last parse operation.
     */
    public var nodesReused(get, never):Int;
    inline function get_nodesReused():Int {
        return _itemsFromCache;
    }

    final tokenizer:Tokenizer;
    final createImmutableLists:Bool;

    public function new(
        tokenizer:Tokenizer,
        edits:Array<TextEditInfo>,
        oldNode:Null<AstNode>,
        createImmutableLists:Bool
    ) {
        this.tokenizer = tokenizer;
        this.createImmutableLists = createImmutableLists;
        if (oldNode != null && createImmutableLists) {
            throw 'Not supported';
        }

        oldNodeReader = oldNode != null ? new NodeReader(oldNode) : null;
        positionMapper = new BeforeEditPositionMapper(edits);
    }

    /**
     * Monaco's `parseDocument` method (renamed: Haxe forbids a static and an
     * instance field with the same name).
     */
    public function doParseDocument():AstNode {
        _itemsConstructed = 0;
        _itemsFromCache = 0;

        var result = parseList(SmallImmutableSet.getEmpty(), 0);
        if (result == null) {
            result = ListAstNode.getEmpty();
        }

        return result;
    }

    function parseList(
        openedBracketIds:SmallImmutableSet<OpeningBracketId>,
        level:Int
    ):Null<AstNode> {
        final items:Array<AstNode> = [];

        while (true) {
            var child = tryReadChildFromCache(openedBracketIds);

            if (child == null) {
                final token = tokenizer.peek();
                if (
                    token == null ||
                    (token.kind == TokenKind.ClosingBracket &&
                        token.bracketIds.intersects(openedBracketIds))
                ) {
                    break;
                }

                child = parseChild(openedBracketIds, level + 1);
            }

            if (child.kind == AstNodeKind.List && child.childrenLength == 0) {
                continue;
            }

            items.push(child);
        }

        // When there is no oldNodeReader, all items are created from scratch and must have the same height.
        final result = oldNodeReader != null ? Concat23Trees.concat23Trees(items) : Concat23Trees.concat23TreesOfSameHeight(items, createImmutableLists);
        return result;
    }

    function tryReadChildFromCache(openedBracketIds:SmallImmutableSet<OpeningBracketId>):Null<AstNode> {
        if (oldNodeReader != null) {
            final maxCacheableLength = positionMapper.getDistanceToNextChange(tokenizer.offset);
            if (maxCacheableLength == null || !Length.lengthIsZero(maxCacheableLength)) {
                final cachedNode = oldNodeReader.readLongestNodeAt(positionMapper.getOffsetBeforeChange(tokenizer.offset), curNode -> {
                    // The edit could extend the ending token, thus we cannot re-use nodes that touch the edit.
                    // If there is no edit anymore, we can re-use the node in any case.
                    if (maxCacheableLength != null && !Length.lengthLessThan(curNode.length, maxCacheableLength)) {
                        // Either the node contains edited text or touches edited text.
                        // In the latter case, brackets might have been extended (`end` -> `ending`), so even touching nodes cannot be reused.
                        return false;
                    }
                    final canBeReused = curNode.canBeReused(openedBracketIds);
                    return canBeReused;
                });

                if (cachedNode != null) {
                    _itemsFromCache++;
                    tokenizer.skip(cachedNode.length);
                    return cachedNode;
                }
            }
        }
        return null;
    }

    function parseChild(
        openedBracketIds:SmallImmutableSet<OpeningBracketId>,
        level:Int
    ):AstNode {
        _itemsConstructed++;

        final token = tokenizer.read();

        switch (token.kind) {
            case TokenKind.ClosingBracket:
                return new InvalidBracketAstNode(token.bracketIds, token.length);

            case TokenKind.Text:
                return token.astNode;

            case TokenKind.OpeningBracket:
                if (level > 300) {
                    // To prevent stack overflows
                    return new TextAstNode(token.length);
                }

                final set = openedBracketIds.merge(token.bracketIds);
                final child = parseList(set, level + 1);

                final nextToken = tokenizer.peek();
                if (
                    nextToken != null &&
                    nextToken.kind == TokenKind.ClosingBracket &&
                    (nextToken.bracketId == token.bracketId || nextToken.bracketIds.intersects(token.bracketIds))
                ) {
                    tokenizer.read();
                    return PairAstNode.create(
                        cast token.astNode,
                        child,
                        cast nextToken.astNode
                    );
                }
                else {
                    return PairAstNode.create(
                        cast token.astNode,
                        child,
                        null
                    );
                }

            default:
                throw 'unexpected';
        }
    }

}
