// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/ast.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.Errors.BugIndicatingError;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.CursorColumns;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer.OpeningBracketId;

enum abstract AstNodeKind(Int) from Int to Int {
    var Text = 0;
    var Bracket = 1;
    var Pair = 2;
    var UnexpectedClosingBracket = 3;
    var List = 4;
}

/**
 * `PairAstNode | ListAstNode | BracketAstNode | InvalidBracketAstNode | TextAstNode`:
 * test `kind` and cast to the node class.
 */
typedef AstNode = BaseAstNode;

/**
 * Monaco's `Number.MAX_SAFE_INTEGER`, the minimum indentation of a node
 * without text. Visible columns are `Int`s in Cityscape: the largest `Int`
 * is used instead.
 */
private inline final MAX_INDENTATION:Int = 0x7FFFFFFF;

/**
 * The base implementation for all AST nodes.
 *
 * `kind` and `listHeight` are fields set by the constructors (Monaco's
 * getters return constants), `missingOpeningBracketIds` too (lists update
 * theirs).
 */
class BaseAstNode {

    public final kind:AstNodeKind;

    /**
     * In case of a list, determines the height of the (2,3) tree.
     */
    public final listHeight:Int;

    /**
     * Represents the set of all (potentially) missing opening bracket ids in this node.
     * E.g. in `{ ] ) }` that set is {`[`, `(` }.
     */
    public var missingOpeningBracketIds(get, never):SmallImmutableSet<OpeningBracketId>;
    inline function get_missingOpeningBracketIds():SmallImmutableSet<OpeningBracketId> {
        return _missingOpeningBracketIds;
    }

    var _missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>;

    var _length:Length;

    /**
     * The length of the entire node, which should equal the sum of lengths of all children.
     */
    public var length(get, never):Length;
    inline function get_length():Length {
        return _length;
    }

    function new(kind:AstNodeKind, listHeight:Int, length:Length, missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>) {
        this.kind = kind;
        this.listHeight = listHeight;
        _length = length;
        _missingOpeningBracketIds = missingOpeningBracketIds;
    }

    public var childrenLength(get, never):Int;
    function get_childrenLength():Int {
        return 0;
    }

    /**
     * Might return null even if {@link idx} is smaller than {@link BaseAstNode.childrenLength}.
     */
    public function getChild(idx:Int):Null<AstNode> {
        return null;
    }

    /**
     * Try to avoid using this property, as implementations might need to allocate the resulting array.
     */
    public var children(get, never):Array<AstNode>;
    function get_children():Array<AstNode> {
        return [];
    }

    /**
     * @param openBracketIds The set of all opening brackets that have not yet been closed.
     */
    public function canBeReused(openBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        throw 'abstract';
    }

    /**
     * Flattens all lists in this AST. Only for debugging.
     */
    public function flattenLists():AstNode {
        throw 'abstract';
    }

    /**
     * Creates a deep clone.
     */
    public function deepClone():AstNode {
        throw 'abstract';
    }

    public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        throw 'abstract';
    }

}

/**
 * Represents a bracket pair including its child (e.g. `{ ... }`).
 * Might be unclosed.
 * Immutable, if all children are immutable.
 */
class PairAstNode extends BaseAstNode {

    public static function create(
        openingBracket:BracketAstNode,
        child:Null<AstNode>,
        closingBracket:Null<BracketAstNode>
    ):PairAstNode {
        var length = openingBracket.length;
        if (child != null) {
            length = Length.lengthAdd(length, child.length);
        }
        if (closingBracket != null) {
            length = Length.lengthAdd(length, closingBracket.length);
        }
        return new PairAstNode(length, openingBracket, child, closingBracket, child != null ? child.missingOpeningBracketIds : SmallImmutableSet.getEmpty());
    }

    public final openingBracket:BracketAstNode;
    public final child:Null<AstNode>;
    public final closingBracket:Null<BracketAstNode>;

    function new(
        length:Length,
        openingBracket:BracketAstNode,
        child:Null<AstNode>,
        closingBracket:Null<BracketAstNode>,
        missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>
    ) {
        super(AstNodeKind.Pair, 0, length, missingOpeningBracketIds);
        this.openingBracket = openingBracket;
        this.child = child;
        this.closingBracket = closingBracket;
    }

    override function get_childrenLength():Int {
        return 3;
    }

    override public function getChild(idx:Int):Null<AstNode> {
        switch (idx) {
            case 0: return openingBracket;
            case 1: return child;
            case 2: return closingBracket;
            case _:
        }
        throw 'Invalid child index';
    }

    /**
     * Avoid using this property, it allocates an array!
     */
    override function get_children():Array<AstNode> {
        final result:Array<AstNode> = [];
        result.push(openingBracket);
        if (child != null) {
            result.push(child);
        }
        if (closingBracket != null) {
            result.push(closingBracket);
        }
        return result;
    }

    override public function canBeReused(openBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        if (closingBracket == null) {
            // Unclosed pair ast nodes only
            // end at the end of the document
            // or when a parent node is closed.

            // This could be improved:
            // Only return false if some next token is neither "undefined" nor a bracket that closes a parent.

            return false;
        }

        if (openBracketIds.intersects(missingOpeningBracketIds)) {
            return false;
        }

        return true;
    }

    override public function flattenLists():AstNode {
        return PairAstNode.create(
            cast openingBracket.flattenLists(),
            child != null ? child.flattenLists() : null,
            closingBracket != null ? cast closingBracket.flattenLists() : null
        );
    }

    override public function deepClone():AstNode {
        return new PairAstNode(
            length,
            cast openingBracket.deepClone(),
            child != null ? child.deepClone() : null,
            closingBracket != null ? cast closingBracket.deepClone() : null,
            missingOpeningBracketIds
        );
    }

    override public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        return child != null ? child.computeMinIndentation(Length.lengthAdd(offset, openingBracket.length), textModel) : MAX_INDENTATION;
    }

}

class ListAstNode extends BaseAstNode {

    /**
     * This method uses more memory-efficient list nodes that can only store 2 or 3 children.
     */
    public static function create23(item1:AstNode, item2:AstNode, item3:Null<AstNode>, immutable:Bool = false):ListAstNode {
        var length = item1.length;
        var missingBracketIds = item1.missingOpeningBracketIds;

        if (item1.listHeight != item2.listHeight) {
            throw 'Invalid list heights';
        }

        length = Length.lengthAdd(length, item2.length);
        missingBracketIds = missingBracketIds.merge(item2.missingOpeningBracketIds);

        if (item3 != null) {
            if (item1.listHeight != item3.listHeight) {
                throw 'Invalid list heights';
            }
            length = Length.lengthAdd(length, item3.length);
            missingBracketIds = missingBracketIds.merge(item3.missingOpeningBracketIds);
        }
        return immutable
            ? new Immutable23ListAstNode(length, item1.listHeight + 1, item1, item2, item3, missingBracketIds)
            : new TwoThreeListAstNode(length, item1.listHeight + 1, item1, item2, item3, missingBracketIds);
    }

    public static function create(items:Array<AstNode>, immutable:Bool = false):ListAstNode {
        if (items.length == 0) {
            return getEmpty();
        }
        else {
            var length = items[0].length;
            var unopenedBrackets = items[0].missingOpeningBracketIds;
            for (i in 1...items.length) {
                length = Length.lengthAdd(length, items[i].length);
                unopenedBrackets = unopenedBrackets.merge(items[i].missingOpeningBracketIds);
            }
            return immutable
                ? new ImmutableArrayListAstNode(length, items[0].listHeight + 1, items, unopenedBrackets)
                : new ArrayListAstNode(length, items[0].listHeight + 1, items, unopenedBrackets);
        }
    }

    public static function getEmpty():ListAstNode {
        return new ImmutableArrayListAstNode(Length.lengthZero, 0, [], SmallImmutableSet.getEmpty());
    }

    var cachedMinIndentation:Int = -1;

    /**
     * Use ListAstNode.create.
     */
    function new(length:Length, listHeight:Int, missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>) {
        super(AstNodeKind.List, listHeight, length, missingOpeningBracketIds);
    }

    function throwIfImmutable():Void {
        // NOOP
    }

    function setChild(idx:Int, child:AstNode):Void {
        throw 'abstract';
    }

    public function makeLastElementMutable():Null<AstNode> {
        throwIfImmutable();
        final childCount = childrenLength;
        if (childCount == 0) {
            return null;
        }
        final lastChild = getChild(childCount - 1);
        final mutable:AstNode = lastChild.kind == AstNodeKind.List ? (cast lastChild : ListAstNode).toMutable() : lastChild;
        if (lastChild != mutable) {
            setChild(childCount - 1, mutable);
        }
        return mutable;
    }

    public function makeFirstElementMutable():Null<AstNode> {
        throwIfImmutable();
        final childCount = childrenLength;
        if (childCount == 0) {
            return null;
        }
        final firstChild = getChild(0);
        final mutable:AstNode = firstChild.kind == AstNodeKind.List ? (cast firstChild : ListAstNode).toMutable() : firstChild;
        if (firstChild != mutable) {
            setChild(0, mutable);
        }
        return mutable;
    }

    override public function canBeReused(openBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        if (openBracketIds.intersects(missingOpeningBracketIds)) {
            return false;
        }

        if (childrenLength == 0) {
            // Don't reuse empty lists.
            return false;
        }

        var lastChild:AstNode = this;
        while (lastChild.kind == AstNodeKind.List) {
            final lastLength = lastChild.childrenLength;
            if (lastLength == 0) {
                // Empty lists should never be contained in other lists.
                throw new BugIndicatingError();
            }
            lastChild = lastChild.getChild(lastLength - 1);
        }

        return lastChild.canBeReused(openBracketIds);
    }

    public function handleChildrenChanged():Void {
        throwIfImmutable();

        final count = childrenLength;

        var length = getChild(0).length;
        var unopenedBrackets = getChild(0).missingOpeningBracketIds;

        for (i in 1...count) {
            final child = getChild(i);
            length = Length.lengthAdd(length, child.length);
            unopenedBrackets = unopenedBrackets.merge(child.missingOpeningBracketIds);
        }

        _length = length;
        _missingOpeningBracketIds = unopenedBrackets;
        cachedMinIndentation = -1;
    }

    override public function flattenLists():AstNode {
        final items:Array<AstNode> = [];
        for (c in children) {
            final normalized = c.flattenLists();
            if (normalized.kind == AstNodeKind.List) {
                for (n in normalized.children) {
                    items.push(n);
                }
            }
            else {
                items.push(normalized);
            }
        }
        return ListAstNode.create(items);
    }

    override public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        if (cachedMinIndentation != -1) {
            return cachedMinIndentation;
        }

        var minIndentation = MAX_INDENTATION;
        var childOffset = offset;
        for (i in 0...childrenLength) {
            final child = getChild(i);
            if (child != null) {
                final childIndentation = child.computeMinIndentation(childOffset, textModel);
                if (childIndentation < minIndentation) {
                    minIndentation = childIndentation;
                }
                childOffset = Length.lengthAdd(childOffset, child.length);
            }
        }

        cachedMinIndentation = minIndentation;
        return minIndentation;
    }

    /**
     * Creates a shallow clone that is mutable, or itself if it is already mutable.
     */
    public function toMutable():ListAstNode {
        throw 'abstract';
    }

    public function appendChildOfSameHeight(node:AstNode):Void {
        throw 'abstract';
    }

    public function unappendChild():Null<AstNode> {
        throw 'abstract';
    }

    public function prependChildOfSameHeight(node:AstNode):Void {
        throw 'abstract';
    }

    public function unprependChild():Null<AstNode> {
        throw 'abstract';
    }

}

class TwoThreeListAstNode extends ListAstNode {

    var _item1:AstNode;
    var _item2:AstNode;
    var _item3:Null<AstNode>;

    override function get_childrenLength():Int {
        return _item3 != null ? 3 : 2;
    }

    override public function getChild(idx:Int):Null<AstNode> {
        switch (idx) {
            case 0: return _item1;
            case 1: return _item2;
            case 2: return _item3;
            case _:
        }
        throw 'Invalid child index';
    }

    override function setChild(idx:Int, node:AstNode):Void {
        switch (idx) {
            case 0: _item1 = node; return;
            case 1: _item2 = node; return;
            case 2: _item3 = node; return;
            case _:
        }
        throw 'Invalid child index';
    }

    override function get_children():Array<AstNode> {
        return _item3 != null ? [_item1, _item2, _item3] : [_item1, _item2];
    }

    public var item1(get, never):AstNode;
    inline function get_item1():AstNode {
        return _item1;
    }

    public var item2(get, never):AstNode;
    inline function get_item2():AstNode {
        return _item2;
    }

    public var item3(get, never):Null<AstNode>;
    inline function get_item3():Null<AstNode> {
        return _item3;
    }

    public function new(
        length:Length,
        listHeight:Int,
        item1:AstNode,
        item2:AstNode,
        item3:Null<AstNode>,
        missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>
    ) {
        super(length, listHeight, missingOpeningBracketIds);
        _item1 = item1;
        _item2 = item2;
        _item3 = item3;
    }

    override public function deepClone():AstNode {
        return new TwoThreeListAstNode(
            length,
            listHeight,
            _item1.deepClone(),
            _item2.deepClone(),
            _item3 != null ? _item3.deepClone() : null,
            missingOpeningBracketIds
        );
    }

    override public function appendChildOfSameHeight(node:AstNode):Void {
        if (_item3 != null) {
            throw 'Cannot append to a full (2,3) tree node';
        }
        throwIfImmutable();
        _item3 = node;
        handleChildrenChanged();
    }

    override public function unappendChild():Null<AstNode> {
        if (_item3 == null) {
            throw 'Cannot remove from a non-full (2,3) tree node';
        }
        throwIfImmutable();
        final result = _item3;
        _item3 = null;
        handleChildrenChanged();
        return result;
    }

    override public function prependChildOfSameHeight(node:AstNode):Void {
        if (_item3 != null) {
            throw 'Cannot prepend to a full (2,3) tree node';
        }
        throwIfImmutable();
        _item3 = _item2;
        _item2 = _item1;
        _item1 = node;
        handleChildrenChanged();
    }

    override public function unprependChild():Null<AstNode> {
        if (_item3 == null) {
            throw 'Cannot remove from a non-full (2,3) tree node';
        }
        throwIfImmutable();
        final result = _item1;
        _item1 = _item2;
        _item2 = _item3;
        _item3 = null;

        handleChildrenChanged();
        return result;
    }

    override public function toMutable():ListAstNode {
        return this;
    }

}

/**
 * Immutable, if all children are immutable.
 */
class Immutable23ListAstNode extends TwoThreeListAstNode {

    override public function toMutable():ListAstNode {
        return new TwoThreeListAstNode(length, listHeight, item1, item2, item3, missingOpeningBracketIds);
    }

    override function throwIfImmutable():Void {
        throw 'this instance is immutable';
    }

}

/**
 * For debugging.
 */
class ArrayListAstNode extends ListAstNode {

    final _children:Array<AstNode>;

    override function get_childrenLength():Int {
        return _children.length;
    }

    override public function getChild(idx:Int):Null<AstNode> {
        return idx >= 0 && idx < _children.length ? _children[idx] : null;
    }

    override function setChild(idx:Int, child:AstNode):Void {
        _children[idx] = child;
    }

    override function get_children():Array<AstNode> {
        return _children;
    }

    public function new(
        length:Length,
        listHeight:Int,
        children:Array<AstNode>,
        missingOpeningBracketIds:SmallImmutableSet<OpeningBracketId>
    ) {
        super(length, listHeight, missingOpeningBracketIds);
        _children = children;
    }

    override public function deepClone():AstNode {
        final children = new Array<AstNode>();
        for (i in 0..._children.length) {
            children[i] = _children[i].deepClone();
        }
        return new ArrayListAstNode(length, listHeight, children, missingOpeningBracketIds);
    }

    override public function appendChildOfSameHeight(node:AstNode):Void {
        throwIfImmutable();
        _children.push(node);
        handleChildrenChanged();
    }

    override public function unappendChild():Null<AstNode> {
        throwIfImmutable();
        final item = _children.pop();
        handleChildrenChanged();
        return item;
    }

    override public function prependChildOfSameHeight(node:AstNode):Void {
        throwIfImmutable();
        _children.unshift(node);
        handleChildrenChanged();
    }

    override public function unprependChild():Null<AstNode> {
        throwIfImmutable();
        final item = _children.shift();
        handleChildrenChanged();
        return item;
    }

    override public function toMutable():ListAstNode {
        return this;
    }

}

/**
 * Immutable, if all children are immutable.
 */
class ImmutableArrayListAstNode extends ArrayListAstNode {

    override public function toMutable():ListAstNode {
        return new ArrayListAstNode(length, listHeight, children.copy(), missingOpeningBracketIds);
    }

    override function throwIfImmutable():Void {
        throw 'this instance is immutable';
    }

}

class ImmutableLeafAstNode extends BaseAstNode {

    override public function flattenLists():AstNode {
        return this;
    }

    override public function deepClone():AstNode {
        return this;
    }

}

class TextAstNode extends ImmutableLeafAstNode {

    public function new(length:Length) {
        super(AstNodeKind.Text, 0, length, SmallImmutableSet.getEmpty());
    }

    override public function canBeReused(_openedBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        return true;
    }

    override public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        final start = Length.lengthToObj(offset);
        // Text ast nodes don't have partial indentation (ensured by the tokenizer).
        // Thus, if this text node does not start at column 0, the first line cannot have any indentation at all.
        final startLineNumber = (start.columnCount == 0 ? start.lineCount : start.lineCount + 1) + 1;
        final endLineNumber = Length.lengthGetLineCount(Length.lengthAdd(offset, length)) + 1;

        var result = MAX_INDENTATION;

        for (lineNumber in startLineNumber...endLineNumber + 1) {
            final firstNonWsColumn = textModel.getLineFirstNonWhitespaceColumn(lineNumber);
            final lineContent = textModel.getLineContent(lineNumber);
            if (firstNonWsColumn == 0) {
                continue;
            }

            final visibleColumn = visibleColumnOfIndentation(lineContent, firstNonWsColumn, textModel.getOptions().tabSize);
            if (visibleColumn < result) {
                result = visibleColumn;
            }
        }

        return result;
    }

    /**
     * `CursorColumns.visibleColumnFromColumn(lineContent, column, tabSize)`
     * for a column at or before the first non whitespace character: the text
     * before it only has spaces and tabs (`getLineFirstNonWhitespaceColumn`
     * only skips those), which are single code units of one grapheme each.
     *
     * TODO(step 2): use `CursorColumns.visibleColumnFromColumn` once it is
     * ported (it needs the grapheme iterator of strings.ts).
     */
    static function visibleColumnOfIndentation(lineContent:String, column:Int, tabSize:Int):Int {
        final textLen = (column - 1) < lineContent.length ? (column - 1) : lineContent.length;
        var result = 0;
        for (i in 0...textLen) {
            if (StringTools.fastCodeAt(lineContent, i) == '\t'.code) {
                result = CursorColumns.nextRenderTabStop(result, tabSize);
            }
            else {
                result = result + 1;
            }
        }
        return result;
    }

}

class BracketAstNode extends ImmutableLeafAstNode {

    public static function create(
        length:Length,
        bracketInfo:BracketKind,
        bracketIds:SmallImmutableSet<OpeningBracketId>
    ):BracketAstNode {
        final node = new BracketAstNode(length, bracketInfo, bracketIds);
        return node;
    }

    public final bracketInfo:BracketKind;

    /**
     * In case of a opening bracket, this is the id of the opening bracket.
     * In case of a closing bracket, this contains the ids of all opening brackets it can close.
     */
    public final bracketIds:SmallImmutableSet<OpeningBracketId>;

    function new(
        length:Length,
        bracketInfo:BracketKind,
        bracketIds:SmallImmutableSet<OpeningBracketId>
    ) {
        super(AstNodeKind.Bracket, 0, length, SmallImmutableSet.getEmpty());
        this.bracketInfo = bracketInfo;
        this.bracketIds = bracketIds;
    }

    public var text(get, never):String;
    inline function get_text():String {
        return bracketInfo.bracketText;
    }

    public var languageId(get, never):String;
    inline function get_languageId():String {
        return bracketInfo.languageId;
    }

    override public function canBeReused(_openedBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        // These nodes could be reused,
        // but not in a general way.
        // Their parent may be reused.
        return false;
    }

    override public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        return MAX_INDENTATION;
    }

}

class InvalidBracketAstNode extends ImmutableLeafAstNode {

    public function new(closingBrackets:SmallImmutableSet<OpeningBracketId>, length:Length) {
        super(AstNodeKind.UnexpectedClosingBracket, 0, length, closingBrackets);
    }

    override public function canBeReused(openedBracketIds:SmallImmutableSet<OpeningBracketId>):Bool {
        return !openedBracketIds.intersects(missingOpeningBracketIds);
    }

    override public function computeMinIndentation(offset:Length, textModel:ITextModel):Int {
        return MAX_INDENTATION;
    }

}
