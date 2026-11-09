// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/bracketPairsTree.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.Arrays.CallbackIterable;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelBracketPairs;
import cityscape.common.TextModelEvents;
import cityscape.common.TokenizationTextModelPart.BackgroundTokenizationState;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfigurationRegistry.ResolvedLanguageConfiguration;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.BeforeEditPositionMapper;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Brackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.CombineTextEditInfos;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Parser;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;

class BracketPairsTree extends Disposable {

    final didChangeEmitter = new VoidEmitter();

    /*
        There are two trees:
        * The initial tree that has no token information and is used for performant initial bracket colorization.
        * The tree that used token information to detect bracket pairs.

        To prevent flickering, we only switch from the initial tree to tree with token information
        when tokenization completes.
        Since the text can be edited while background tokenization is in progress, we need to update both trees.
    */
    var initialAstWithoutTokens:Null<AstNode>;
    var astWithTokens:Null<AstNode>;

    final denseKeyProvider = new DenseKeyProvider<String>();
    final brackets:LanguageAgnosticBracketTokens;

    public function didLanguageChange(languageId:String):Bool {
        return brackets.didLanguageChange(languageId);
    }

    public final onDidChange:VoidEvent;
    var queuedTextEditsForInitialAstWithoutTokens:Array<TextEditInfo> = [];
    var queuedTextEdits:Array<TextEditInfo> = [];

    final textModel:ITextModel;
    final getLanguageConfiguration:(languageId:String) -> ResolvedLanguageConfiguration;

    public function new(
        textModel:ITextModel,
        getLanguageConfiguration:(languageId:String) -> ResolvedLanguageConfiguration
    ) {
        super();
        this.textModel = textModel;
        this.getLanguageConfiguration = getLanguageConfiguration;
        brackets = new LanguageAgnosticBracketTokens(denseKeyProvider, getLanguageConfiguration);
        onDidChange = didChangeEmitter.event;

        if (!textModel.tokenization.hasTokens) {
            final brackets = this.brackets.getSingleLanguageBracketTokens(textModel.getLanguageId());
            final tokenizer = new FastTokenizer(textModel.getValue(), brackets);
            initialAstWithoutTokens = Parser.parseDocument(tokenizer, [], null, true);
            astWithTokens = initialAstWithoutTokens;
        }
        else if (textModel.tokenization.backgroundTokenizationState == BackgroundTokenizationState.Completed) {
            // Skip the initial ast, as there is no flickering.
            // Directly create the tree with token information.
            initialAstWithoutTokens = null;
            astWithTokens = parseDocumentFromTextBuffer([], null, false);
        }
        else {
            // We missed some token changes already, so we cannot use the fast tokenizer + delta increments
            initialAstWithoutTokens = parseDocumentFromTextBuffer([], null, true);
            astWithTokens = initialAstWithoutTokens;
        }
    }

    //#region TextModel events

    public function handleDidChangeBackgroundTokenizationState():Void {
        if (textModel.tokenization.backgroundTokenizationState == BackgroundTokenizationState.Completed) {
            final wasUndefined = initialAstWithoutTokens == null;
            // Clear the initial tree as we can use the tree with token information now.
            initialAstWithoutTokens = null;
            if (!wasUndefined) {
                didChangeEmitter.fire();
            }
        }
    }

    public function handleDidChangeTokens(e:IModelTokensChangedEvent):Void {
        final edits = [for (r in e.ranges)
            new TextEditInfo(
                Length.toLength(r.fromLineNumber - 1, 0),
                Length.toLength(r.toLineNumber, 0),
                Length.toLength(r.toLineNumber - r.fromLineNumber + 1, 0)
            )
        ];

        handleEdits(edits, true);

        if (initialAstWithoutTokens == null) {
            didChangeEmitter.fire();
        }
    }

    public function handleContentChanged(change:IModelContentChangedEvent):Void {
        final edits = TextEditInfo.fromModelContentChanges(change.changes);
        handleEdits(edits, false);
    }

    function handleEdits(edits:Array<TextEditInfo>, tokenChange:Bool):Void {
        // Lazily queue the edits and only apply them when the tree is accessed.
        final result = CombineTextEditInfos.combineTextEditInfos(queuedTextEdits, edits);

        queuedTextEdits = result;
        if (initialAstWithoutTokens != null && !tokenChange) {
            queuedTextEditsForInitialAstWithoutTokens = CombineTextEditInfos.combineTextEditInfos(queuedTextEditsForInitialAstWithoutTokens, edits);
        }
    }

    //#endregion

    function flushQueue():Void {
        if (queuedTextEdits.length > 0) {
            astWithTokens = parseDocumentFromTextBuffer(queuedTextEdits, astWithTokens, false);
            queuedTextEdits = [];
        }
        if (queuedTextEditsForInitialAstWithoutTokens.length > 0) {
            if (initialAstWithoutTokens != null) {
                initialAstWithoutTokens = parseDocumentFromTextBuffer(queuedTextEditsForInitialAstWithoutTokens, initialAstWithoutTokens, false);
            }
            queuedTextEditsForInitialAstWithoutTokens = [];
        }
    }

    /**
     * @pure (only if isPure = true)
     */
    function parseDocumentFromTextBuffer(edits:Array<TextEditInfo>, previousAst:Null<AstNode>, immutable:Bool):AstNode {
        // Is much faster if `isPure = false`.
        final isPure = false;
        final previousAstClone = isPure ? (previousAst != null ? previousAst.deepClone() : null) : previousAst;
        final tokenizer = new TextBufferTokenizer(new TextModelTokenizerSource(textModel), brackets);
        final result = Parser.parseDocument(tokenizer, edits, previousAstClone, immutable);
        return result;
    }

    inline function currentAst():AstNode {
        return initialAstWithoutTokens != null ? initialAstWithoutTokens : astWithTokens;
    }

    public function getBracketsInRange(range:Range, onlyColorizedBrackets:Bool):CallbackIterable<BracketInfo> {
        flushQueue();

        final startOffset = Length.toLength(range.startLineNumber - 1, range.startColumn - 1);
        final endOffset = Length.toLength(range.endLineNumber - 1, range.endColumn - 1);
        return new CallbackIterable<BracketInfo>(cb -> {
            final node = currentAst();
            collectBrackets(node, Length.lengthZero, node.length, startOffset, endOffset, cb, 0, 0, new Map(), onlyColorizedBrackets);
        });
    }

    public function getBracketPairsInRange(range:Range, includeMinIndentation:Bool):CallbackIterable<BracketPairWithMinIndentationInfo> {
        flushQueue();

        final startLength = Length.positionToLength(range.getStartPosition());
        final endLength = Length.positionToLength(range.getEndPosition());

        return new CallbackIterable<BracketPairWithMinIndentationInfo>(cb -> {
            final node = currentAst();
            final context = new CollectBracketPairsContext(cb, includeMinIndentation, textModel);
            collectBracketPairs(node, Length.lengthZero, node.length, startLength, endLength, context, 0, new Map());
        });
    }

    public function getFirstBracketAfter(position:Position):Null<IFoundBracket> {
        flushQueue();

        final node = currentAst();
        return _getFirstBracketAfter(node, Length.lengthZero, node.length, Length.positionToLength(position));
    }

    public function getFirstBracketBefore(position:Position):Null<IFoundBracket> {
        flushQueue();

        final node = currentAst();
        return _getFirstBracketBefore(node, Length.lengthZero, node.length, Length.positionToLength(position));
    }

    static function _getFirstBracketBefore(node:AstNode, nodeOffsetStart:Length, nodeOffsetEnd:Length, position:Length):Null<IFoundBracket> {
        if (node.kind == AstNodeKind.List || node.kind == AstNodeKind.Pair) {
            final lengths:Array<{nodeOffsetStart:Length, nodeOffsetEnd:Length}> = [];
            final children = node.children;
            for (child in children) {
                nodeOffsetEnd = Length.lengthAdd(nodeOffsetStart, child.length);
                lengths.push({nodeOffsetStart: nodeOffsetStart, nodeOffsetEnd: nodeOffsetEnd});
                nodeOffsetStart = nodeOffsetEnd;
            }
            var i = lengths.length - 1;
            while (i >= 0) {
                final entry = lengths[i];
                if (Length.lengthLessThan(entry.nodeOffsetStart, position)) {
                    final result = _getFirstBracketBefore(children[i], entry.nodeOffsetStart, entry.nodeOffsetEnd, position);
                    if (result != null) {
                        return result;
                    }
                }
                i--;
            }
            return null;
        }
        else if (node.kind == AstNodeKind.UnexpectedClosingBracket) {
            return null;
        }
        else if (node.kind == AstNodeKind.Bracket) {
            final range = Length.lengthsToRange(nodeOffsetStart, nodeOffsetEnd);
            return {
                bracketInfo: (cast node : BracketAstNode).bracketInfo,
                range: range
            };
        }
        return null;
    }

    static function _getFirstBracketAfter(node:AstNode, nodeOffsetStart:Length, nodeOffsetEnd:Length, position:Length):Null<IFoundBracket> {
        if (node.kind == AstNodeKind.List || node.kind == AstNodeKind.Pair) {
            for (child in node.children) {
                nodeOffsetEnd = Length.lengthAdd(nodeOffsetStart, child.length);
                if (Length.lengthLessThan(position, nodeOffsetEnd)) {
                    final result = _getFirstBracketAfter(child, nodeOffsetStart, nodeOffsetEnd, position);
                    if (result != null) {
                        return result;
                    }
                }
                nodeOffsetStart = nodeOffsetEnd;
            }
            return null;
        }
        else if (node.kind == AstNodeKind.UnexpectedClosingBracket) {
            return null;
        }
        else if (node.kind == AstNodeKind.Bracket) {
            final range = Length.lengthsToRange(nodeOffsetStart, nodeOffsetEnd);
            return {
                bracketInfo: (cast node : BracketAstNode).bracketInfo,
                range: range
            };
        }
        return null;
    }

    static function collectBrackets(
        node:AstNode,
        nodeOffsetStart:Length,
        nodeOffsetEnd:Length,
        startOffset:Length,
        endOffset:Length,
        push:(item:BracketInfo) -> Bool,
        level:Int,
        nestingLevelOfEqualBracketType:Int,
        levelPerBracketType:Null<Map<String, Int>>,
        onlyColorizedBrackets:Bool,
        parentPairIsIncomplete:Bool = false
    ):Bool {
        if (level > 200) {
            return true;
        }

        // whileLoop
        while (true) {
            switch (node.kind) {
                case AstNodeKind.List:
                    final childCount = node.childrenLength;
                    var restart = false;
                    for (i in 0...childCount) {
                        final child = node.getChild(i);
                        if (child == null) {
                            continue;
                        }
                        nodeOffsetEnd = Length.lengthAdd(nodeOffsetStart, child.length);
                        if (
                            Length.lengthLessThanEqual(nodeOffsetStart, endOffset) &&
                            Length.lengthGreaterThanEqual(nodeOffsetEnd, startOffset)
                        ) {
                            final childEndsAfterEnd = Length.lengthGreaterThanEqual(nodeOffsetEnd, endOffset);
                            if (childEndsAfterEnd) {
                                // No child after this child in the requested window, don't recurse
                                node = child;
                                restart = true;
                                break;
                            }

                            final shouldContinue = collectBrackets(child, nodeOffsetStart, nodeOffsetEnd, startOffset, endOffset, push, level, 0, levelPerBracketType, onlyColorizedBrackets);
                            if (!shouldContinue) {
                                return false;
                            }
                        }
                        nodeOffsetStart = nodeOffsetEnd;
                    }
                    if (restart) {
                        continue; // whileLoop
                    }
                    return true;

                case AstNodeKind.Pair:
                    final pair:PairAstNode = cast node;
                    final colorize = !onlyColorizedBrackets || pair.closingBracket == null || (cast pair.closingBracket.bracketInfo : ClosingBracketKind).closesColorized(cast pair.openingBracket.bracketInfo);

                    var levelPerBracket = 0;
                    if (levelPerBracketType != null) {
                        var existing = levelPerBracketType.get(pair.openingBracket.text);
                        if (existing == null) {
                            existing = 0;
                        }
                        levelPerBracket = existing;
                        if (colorize) {
                            existing++;
                            levelPerBracketType.set(pair.openingBracket.text, existing);
                        }
                    }

                    final childCount = pair.childrenLength;
                    var restart = false;
                    for (i in 0...childCount) {
                        final child = pair.getChild(i);
                        if (child == null) {
                            continue;
                        }
                        nodeOffsetEnd = Length.lengthAdd(nodeOffsetStart, child.length);
                        if (
                            Length.lengthLessThanEqual(nodeOffsetStart, endOffset) &&
                            Length.lengthGreaterThanEqual(nodeOffsetEnd, startOffset)
                        ) {
                            final childEndsAfterEnd = Length.lengthGreaterThanEqual(nodeOffsetEnd, endOffset);
                            if (childEndsAfterEnd && child.kind != AstNodeKind.Bracket) {
                                // No child after this child in the requested window, don't recurse
                                // Don't do this for brackets because of unclosed/unopened brackets
                                node = child;
                                if (colorize) {
                                    level++;
                                    nestingLevelOfEqualBracketType = levelPerBracket + 1;
                                }
                                else {
                                    nestingLevelOfEqualBracketType = levelPerBracket;
                                }
                                restart = true;
                                break;
                            }

                            if (colorize || child.kind != AstNodeKind.Bracket || pair.closingBracket == null) {
                                final shouldContinue = collectBrackets(
                                    child,
                                    nodeOffsetStart,
                                    nodeOffsetEnd,
                                    startOffset,
                                    endOffset,
                                    push,
                                    colorize ? level + 1 : level,
                                    colorize ? levelPerBracket + 1 : levelPerBracket,
                                    levelPerBracketType,
                                    onlyColorizedBrackets,
                                    pair.closingBracket == null
                                );
                                if (!shouldContinue) {
                                    return false;
                                }
                            }
                        }
                        nodeOffsetStart = nodeOffsetEnd;
                    }
                    if (restart) {
                        continue; // whileLoop
                    }

                    if (levelPerBracketType != null) {
                        levelPerBracketType.set(pair.openingBracket.text, levelPerBracket);
                    }

                    return true;

                case AstNodeKind.UnexpectedClosingBracket:
                    final range = Length.lengthsToRange(nodeOffsetStart, nodeOffsetEnd);
                    return push(new BracketInfo(range, level - 1, 0, true));

                case AstNodeKind.Bracket:
                    final range = Length.lengthsToRange(nodeOffsetStart, nodeOffsetEnd);
                    return push(new BracketInfo(range, level - 1, nestingLevelOfEqualBracketType - 1, parentPairIsIncomplete));

                case AstNodeKind.Text:
                    return true;

                case _:
                    return true;
            }
        }
    }

    static function collectBracketPairs(
        node:AstNode,
        nodeOffsetStart:Length,
        nodeOffsetEnd:Length,
        startOffset:Length,
        endOffset:Length,
        context:CollectBracketPairsContext,
        level:Int,
        levelPerBracketType:Null<Map<String, Int>>
    ):Bool {
        if (level > 200) {
            return true;
        }

        var shouldContinue = true;

        if (node.kind == AstNodeKind.Pair) {
            final pair:PairAstNode = cast node;
            var levelPerBracket = 0;
            if (levelPerBracketType != null) {
                var existing = levelPerBracketType.get(pair.openingBracket.text);
                if (existing == null) {
                    existing = 0;
                }
                levelPerBracket = existing;
                existing++;
                levelPerBracketType.set(pair.openingBracket.text, existing);
            }

            final openingBracketEnd = Length.lengthAdd(nodeOffsetStart, pair.openingBracket.length);
            var minIndentation = -1;
            if (context.includeMinIndentation) {
                minIndentation = pair.computeMinIndentation(
                    nodeOffsetStart,
                    context.textModel
                );
            }

            shouldContinue = context.push(
                new BracketPairWithMinIndentationInfo(
                    Length.lengthsToRange(nodeOffsetStart, nodeOffsetEnd),
                    Length.lengthsToRange(nodeOffsetStart, openingBracketEnd),
                    pair.closingBracket != null
                        ? Length.lengthsToRange(
                            Length.lengthAdd(openingBracketEnd, pair.child != null ? pair.child.length : Length.lengthZero),
                            nodeOffsetEnd
                        )
                        : null,
                    level,
                    levelPerBracket,
                    pair,
                    minIndentation
                )
            );

            nodeOffsetStart = openingBracketEnd;
            if (shouldContinue && pair.child != null) {
                final child = pair.child;
                nodeOffsetEnd = Length.lengthAdd(nodeOffsetStart, child.length);
                if (
                    Length.lengthLessThanEqual(nodeOffsetStart, endOffset) &&
                    Length.lengthGreaterThanEqual(nodeOffsetEnd, startOffset)
                ) {
                    shouldContinue = collectBracketPairs(
                        child,
                        nodeOffsetStart,
                        nodeOffsetEnd,
                        startOffset,
                        endOffset,
                        context,
                        level + 1,
                        levelPerBracketType
                    );
                    if (!shouldContinue) {
                        return false;
                    }
                }
            }

            if (levelPerBracketType != null) {
                levelPerBracketType.set(pair.openingBracket.text, levelPerBracket);
            }
        }
        else {
            var curOffset = nodeOffsetStart;
            for (child in node.children) {
                final childOffset = curOffset;
                curOffset = Length.lengthAdd(curOffset, child.length);

                if (
                    Length.lengthLessThanEqual(childOffset, endOffset) &&
                    Length.lengthLessThanEqual(startOffset, curOffset)
                ) {
                    shouldContinue = collectBracketPairs(
                        child,
                        childOffset,
                        curOffset,
                        startOffset,
                        endOffset,
                        context,
                        level,
                        levelPerBracketType
                    );
                    if (!shouldContinue) {
                        return false;
                    }
                }
            }
        }
        return shouldContinue;
    }

}

private class CollectBracketPairsContext {

    public final push:(item:BracketPairWithMinIndentationInfo) -> Bool;
    public final includeMinIndentation:Bool;
    public final textModel:ITextModel;

    public function new(push:(item:BracketPairWithMinIndentationInfo) -> Bool, includeMinIndentation:Bool, textModel:ITextModel) {
        this.push = push;
        this.includeMinIndentation = includeMinIndentation;
        this.textModel = textModel;
    }

}
