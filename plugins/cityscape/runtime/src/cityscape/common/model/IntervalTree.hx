// Ported from vscode src/vs/editor/common/model/intervalTree.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.common.Model.TrackedRangeStickiness;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;

//
// The red-black tree is based on the "Introduction to Algorithms" by Cormen, Leiserson and Rivest.
//

enum abstract ClassName(String) from String to String {
    var EditorHintDecoration = 'squiggly-hint';
    var EditorInfoDecoration = 'squiggly-info';
    var EditorWarningDecoration = 'squiggly-warning';
    var EditorErrorDecoration = 'squiggly-error';
    var EditorUnnecessaryDecoration = 'squiggly-unnecessary';
    var EditorUnnecessaryInlineDecoration = 'squiggly-inline-unnecessary';
    var EditorDeprecatedInlineDecoration = 'squiggly-inline-deprecated';
}

enum abstract NodeColor(Int) from Int to Int {
    var Black = 0;
    var Red = 1;
}

private enum abstract Constants(Int) from Int to Int {
    var ColorMask = 0x01;
    var ColorMaskInverse = 0xFE;
    var ColorOffset = 0;

    var IsVisitedMask = 0x02;
    var IsVisitedMaskInverse = 0xFD;
    var IsVisitedOffset = 1;

    var IsForValidationMask = 0x04;
    var IsForValidationMaskInverse = 0xFB;
    var IsForValidationOffset = 2;

    var StickinessMask = 0x18;
    var StickinessMaskInverse = 0xE7;
    var StickinessOffset = 3;

    var CollapseOnReplaceEditMask = 0x20;
    var CollapseOnReplaceEditMaskInverse = 0xDF;
    var CollapseOnReplaceEditOffset = 5;

    var IsMarginMask = 0x40;
    var IsMarginMaskInverse = 0xBF;
    var IsMarginOffset = 6;

    /**
     * Due to how deletion works (in order to avoid always walking the right subtree of the deleted node),
     * the deltas for nodes can grow and shrink dramatically. It has been observed, in practice, that unless
     * the deltas are corrected, integer overflow will occur.
     *
     * The integer overflow occurs when 53 bits are used in the numbers, but we will try to avoid it as
     * a node's delta gets below a negative 30 bits number.
     *
     * MIN SMI (SMall Integer) as defined in v8.
     * one bit is lost for boxing/unboxing flag.
     * one bit is lost for sign flag.
     * See https://thibaultlaurens.github.io/javascript/2013/04/29/how-the-v8-engine-works/#tagged-values
     */
    var MIN_SAFE_DELTA = -(1 << 30);

    /**
     * MAX SMI (SMall Integer) as defined in v8.
     * one bit is lost for boxing/unboxing flag.
     * one bit is lost for sign flag.
     * See https://thibaultlaurens.github.io/javascript/2013/04/29/how-the-v8-engine-works/#tagged-values
     */
    var MAX_SAFE_DELTA = 1 << 30;
}

class IntervalNode {

    /**
     * contains binary encoded information for color, visited, isForValidation and stickiness.
     */
    public var metadata:Int;

    public var parent:IntervalNode;

    public var left:IntervalNode;

    public var right:IntervalNode;

    public var start:Int;

    public var end:Int;

    public var delta:Int;

    public var maxEnd:Int;

    public var id:String;

    public var ownerId:Int;

    public var options:ModelDecorationOptions;

    public var cachedVersionId:Int;

    public var cachedAbsoluteStart:Int;

    public var cachedAbsoluteEnd:Int;

    public var range:Null<Range>;

    public function new(id:String, start:Int, end:Int) {
        this.metadata = 0;

        this.parent = this;
        this.left = this;
        this.right = this;
        IntervalTree.setNodeColor(this, NodeColor.Red);

        this.start = start;
        this.end = end;
        // FORCE_OVERFLOWING_TEST: this.delta = start;
        this.delta = 0;
        this.maxEnd = end;

        this.id = id;
        this.ownerId = 0;
        this.options = null;
        IntervalTree.setNodeIsForValidation(this, false);
        IntervalTree.setNodeIsInGlyphMargin(this, false);
        IntervalTree._setNodeStickiness(this, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges);
        IntervalTree.setCollapseOnReplaceEdit(this, false);

        this.cachedVersionId = 0;
        this.cachedAbsoluteStart = start;
        this.cachedAbsoluteEnd = end;
        this.range = null;

        IntervalTree.setNodeIsVisited(this, false);
    }

    public function reset(versionId:Int, start:Int, end:Int, range:Range):Void {
        this.start = start;
        this.end = end;
        this.maxEnd = end;
        this.cachedVersionId = versionId;
        this.cachedAbsoluteStart = start;
        this.cachedAbsoluteEnd = end;
        this.range = range;
    }

    public function setOptions(options:ModelDecorationOptions):Void {
        this.options = options;
        final className = this.options.className;
        IntervalTree.setNodeIsForValidation(this, (
            className == ClassName.EditorErrorDecoration
            || className == ClassName.EditorWarningDecoration
            || className == ClassName.EditorInfoDecoration
        ));
        IntervalTree.setNodeIsInGlyphMargin(this, this.options.glyphMarginClassName != null);
        IntervalTree._setNodeStickiness(this, this.options.stickiness);
        IntervalTree.setCollapseOnReplaceEdit(this, this.options.collapseOnReplaceEdit);
    }

    public function setCachedOffsets(absoluteStart:Int, absoluteEnd:Int, cachedVersionId:Int):Void {
        if (this.cachedVersionId != cachedVersionId) {
            this.range = null;
        }
        this.cachedVersionId = cachedVersionId;
        this.cachedAbsoluteStart = absoluteStart;
        this.cachedAbsoluteEnd = absoluteEnd;
    }

    public function detach():Void {
        this.parent = null;
        this.left = null;
        this.right = null;
    }

}

/**
 * An interval tree (decorations of a model).
 *
 * Monaco shares one `SENTINEL` node between all the trees and writes to it
 * (visited flags, deltas, parent) during the operations. Cityscape gives
 * each tree its own sentinel (`IntervalTree.SENTINEL`, an instance field)
 * so that no state is shared between models.
 */
class IntervalTree {

    /**
     * `Constants.MIN_SAFE_DELTA`: see the comment in `Constants`.
     */
    static inline final MIN_SAFE_DELTA:Int = -(1 << 30);

    /**
     * `Constants.MAX_SAFE_DELTA`: see the comment in `Constants`.
     */
    static inline final MAX_SAFE_DELTA:Int = 1 << 30;

    /**
     * The sentinel of this tree.
     */
    public final SENTINEL:IntervalNode;

    public var root:IntervalNode;

    public var requestNormalizeDelta:Bool;

    public function new() {
        final sentinel = new IntervalNode(null, 0, 0);
        sentinel.parent = sentinel;
        sentinel.left = sentinel;
        sentinel.right = sentinel;
        setNodeColor(sentinel, NodeColor.Black);
        this.SENTINEL = sentinel;
        this.root = sentinel;
        this.requestNormalizeDelta = false;
    }

    // #region node metadata

    public static inline function getNodeColor(node:IntervalNode):NodeColor {
        return ((node.metadata & Constants.ColorMask) >>> Constants.ColorOffset);
    }

    public static inline function setNodeColor(node:IntervalNode, color:NodeColor):Void {
        node.metadata = (
            (node.metadata & Constants.ColorMaskInverse) | (color << Constants.ColorOffset)
        );
    }

    public static inline function getNodeIsVisited(node:IntervalNode):Bool {
        return ((node.metadata & Constants.IsVisitedMask) >>> Constants.IsVisitedOffset) == 1;
    }

    public static inline function setNodeIsVisited(node:IntervalNode, value:Bool):Void {
        node.metadata = (
            (node.metadata & Constants.IsVisitedMaskInverse) | ((value ? 1 : 0) << Constants.IsVisitedOffset)
        );
    }

    public static inline function getNodeIsForValidation(node:IntervalNode):Bool {
        return ((node.metadata & Constants.IsForValidationMask) >>> Constants.IsForValidationOffset) == 1;
    }

    public static inline function setNodeIsForValidation(node:IntervalNode, value:Bool):Void {
        node.metadata = (
            (node.metadata & Constants.IsForValidationMaskInverse) | ((value ? 1 : 0) << Constants.IsForValidationOffset)
        );
    }

    public static inline function getNodeIsInGlyphMargin(node:IntervalNode):Bool {
        return ((node.metadata & Constants.IsMarginMask) >>> Constants.IsMarginOffset) == 1;
    }

    public static inline function setNodeIsInGlyphMargin(node:IntervalNode, value:Bool):Void {
        node.metadata = (
            (node.metadata & Constants.IsMarginMaskInverse) | ((value ? 1 : 0) << Constants.IsMarginOffset)
        );
    }

    public static inline function getNodeStickiness(node:IntervalNode):TrackedRangeStickiness {
        return ((node.metadata & Constants.StickinessMask) >>> Constants.StickinessOffset);
    }

    public static inline function _setNodeStickiness(node:IntervalNode, stickiness:TrackedRangeStickiness):Void {
        node.metadata = (
            (node.metadata & Constants.StickinessMaskInverse) | (stickiness << Constants.StickinessOffset)
        );
    }

    public static inline function getCollapseOnReplaceEdit(node:IntervalNode):Bool {
        return ((node.metadata & Constants.CollapseOnReplaceEditMask) >>> Constants.CollapseOnReplaceEditOffset) == 1;
    }

    public static inline function setCollapseOnReplaceEdit(node:IntervalNode, value:Bool):Void {
        node.metadata = (
            (node.metadata & Constants.CollapseOnReplaceEditMaskInverse) | ((value ? 1 : 0) << Constants.CollapseOnReplaceEditOffset)
        );
    }

    public static function setNodeStickiness(node:IntervalNode, stickiness:TrackedRangeStickiness):Void {
        _setNodeStickiness(node, stickiness);
    }

    // #endregion

    public function intervalSearch(start:Int, end:Int, filterOwnerId:Int, filterOutValidation:Bool, cachedVersionId:Int, onlyMarginDecorations:Bool):Array<IntervalNode> {
        if (this.root == SENTINEL) {
            return [];
        }
        return _intervalSearch(this, start, end, filterOwnerId, filterOutValidation, cachedVersionId, onlyMarginDecorations);
    }

    public function search(filterOwnerId:Int, filterOutValidation:Bool, cachedVersionId:Int, onlyMarginDecorations:Bool):Array<IntervalNode> {
        if (this.root == SENTINEL) {
            return [];
        }
        return _search(this, filterOwnerId, filterOutValidation, cachedVersionId, onlyMarginDecorations);
    }

    /**
     * Will not set `cachedAbsoluteStart` nor `cachedAbsoluteEnd` on the returned nodes!
     */
    public function collectNodesFromOwner(ownerId:Int):Array<IntervalNode> {
        return _collectNodesFromOwner(this, ownerId);
    }

    /**
     * Will not set `cachedAbsoluteStart` nor `cachedAbsoluteEnd` on the returned nodes!
     */
    public function collectNodesPostOrder():Array<IntervalNode> {
        return _collectNodesPostOrder(this);
    }

    public function insert(node:IntervalNode):Void {
        rbTreeInsert(this, node);
        this._normalizeDeltaIfNecessary();
    }

    public function delete(node:IntervalNode):Void {
        rbTreeDelete(this, node);
        this._normalizeDeltaIfNecessary();
    }

    public function resolveNode(node:IntervalNode, cachedVersionId:Int):Void {
        final initialNode = node;
        var delta = 0;
        while (node != this.root) {
            if (node == node.parent.right) {
                delta += node.parent.delta;
            }
            node = node.parent;
        }

        final nodeStart = initialNode.start + delta;
        final nodeEnd = initialNode.end + delta;
        initialNode.setCachedOffsets(nodeStart, nodeEnd, cachedVersionId);
    }

    public function acceptReplace(offset:Int, length:Int, textLength:Int, forceMoveMarkers:Bool):Void {
        if (this.root == SENTINEL) {
            // Cityscape: nothing to update in an empty tree (no allocation)
            return;
        }

        // Our strategy is to remove all directly impacted nodes, and then add them back to the tree.

        // (1) collect all nodes that are intersecting this edit as nodes of interest
        final nodesOfInterest = searchForEditing(this, offset, offset + length);

        // (2) remove all nodes that are intersecting this edit
        for (i in 0...nodesOfInterest.length) {
            final node = nodesOfInterest[i];
            rbTreeDelete(this, node);
        }
        this._normalizeDeltaIfNecessary();

        // (3) edit all tree nodes except the nodes of interest
        noOverlapReplace(this, offset, offset + length, textLength);
        this._normalizeDeltaIfNecessary();

        // (4) edit the nodes of interest and insert them back in the tree
        for (i in 0...nodesOfInterest.length) {
            final node = nodesOfInterest[i];
            node.start = node.cachedAbsoluteStart;
            node.end = node.cachedAbsoluteEnd;
            nodeAcceptEdit(node, offset, (offset + length), textLength, forceMoveMarkers);
            node.maxEnd = node.end;
            rbTreeInsert(this, node);
        }
        this._normalizeDeltaIfNecessary();
    }

    public function getAllInOrder():Array<IntervalNode> {
        return _search(this, 0, false, 0, false);
    }

    function _normalizeDeltaIfNecessary():Void {
        if (!this.requestNormalizeDelta) {
            return;
        }
        this.requestNormalizeDelta = false;
        normalizeDelta(this);
    }

    //#region Delta Normalization

    static function normalizeDelta(T:IntervalTree):Void {
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        var delta = 0;
        while (node != SENTINEL) {

            if (node.left != SENTINEL && !getNodeIsVisited(node.left)) {
                // go left
                node = node.left;
                continue;
            }

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                delta += node.delta;
                node = node.right;
                continue;
            }

            // handle current node
            node.start = delta + node.start;
            node.end = delta + node.end;
            node.delta = 0;
            recomputeMaxEnd(T, node);

            setNodeIsVisited(node, true);

            // going up from this node
            setNodeIsVisited(node.left, false);
            setNodeIsVisited(node.right, false);
            if (node == node.parent.right) {
                delta -= node.parent.delta;
            }
            node = node.parent;
        }

        setNodeIsVisited(T.root, false);
    }

    //#endregion

    //#region Editing

    static function adjustMarkerBeforeColumn(markerOffset:Int, markerStickToPreviousCharacter:Bool, checkOffset:Int, moveSemantics:MarkerMoveSemantics):Bool {
        if (markerOffset < checkOffset) {
            return true;
        }
        if (markerOffset > checkOffset) {
            return false;
        }
        if (moveSemantics == MarkerMoveSemantics.ForceMove) {
            return false;
        }
        if (moveSemantics == MarkerMoveSemantics.ForceStay) {
            return true;
        }
        return markerStickToPreviousCharacter;
    }

    /**
     * This is a lot more complicated than strictly necessary to maintain the same behaviour
     * as when decorations were implemented using two markers.
     */
    public static function nodeAcceptEdit(node:IntervalNode, start:Int, end:Int, textLength:Int, forceMoveMarkers:Bool):Void {
        final nodeStickiness = getNodeStickiness(node);
        final startStickToPreviousCharacter = (
            nodeStickiness == TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges
            || nodeStickiness == TrackedRangeStickiness.GrowsOnlyWhenTypingBefore
        );
        final endStickToPreviousCharacter = (
            nodeStickiness == TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
            || nodeStickiness == TrackedRangeStickiness.GrowsOnlyWhenTypingBefore
        );

        final deletingCnt = (end - start);
        final insertingCnt = textLength;
        final commonLength = (deletingCnt < insertingCnt ? deletingCnt : insertingCnt);

        final nodeStart = node.start;
        var startDone = false;

        final nodeEnd = node.end;
        var endDone = false;

        if (start <= nodeStart && nodeEnd <= end && getCollapseOnReplaceEdit(node)) {
            // This edit encompasses the entire decoration range
            // and the decoration has asked to become collapsed
            node.start = start;
            startDone = true;
            node.end = start;
            endDone = true;
        }

        {
            final moveSemantics = forceMoveMarkers ? MarkerMoveSemantics.ForceMove : (deletingCnt > 0 ? MarkerMoveSemantics.ForceStay : MarkerMoveSemantics.MarkerDefined);
            if (!startDone && adjustMarkerBeforeColumn(nodeStart, startStickToPreviousCharacter, start, moveSemantics)) {
                startDone = true;
            }
            if (!endDone && adjustMarkerBeforeColumn(nodeEnd, endStickToPreviousCharacter, start, moveSemantics)) {
                endDone = true;
            }
        }

        if (commonLength > 0 && !forceMoveMarkers) {
            final moveSemantics = (deletingCnt > insertingCnt ? MarkerMoveSemantics.ForceStay : MarkerMoveSemantics.MarkerDefined);
            if (!startDone && adjustMarkerBeforeColumn(nodeStart, startStickToPreviousCharacter, start + commonLength, moveSemantics)) {
                startDone = true;
            }
            if (!endDone && adjustMarkerBeforeColumn(nodeEnd, endStickToPreviousCharacter, start + commonLength, moveSemantics)) {
                endDone = true;
            }
        }

        {
            final moveSemantics = forceMoveMarkers ? MarkerMoveSemantics.ForceMove : MarkerMoveSemantics.MarkerDefined;
            if (!startDone && adjustMarkerBeforeColumn(nodeStart, startStickToPreviousCharacter, end, moveSemantics)) {
                node.start = start + insertingCnt;
                startDone = true;
            }
            if (!endDone && adjustMarkerBeforeColumn(nodeEnd, endStickToPreviousCharacter, end, moveSemantics)) {
                node.end = start + insertingCnt;
                endDone = true;
            }
        }

        // Finish
        final deltaColumn = (insertingCnt - deletingCnt);
        if (!startDone) {
            node.start = (nodeStart + deltaColumn > 0 ? nodeStart + deltaColumn : 0);
        }
        if (!endDone) {
            node.end = (nodeEnd + deltaColumn > 0 ? nodeEnd + deltaColumn : 0);
        }

        if (node.start > node.end) {
            node.end = node.start;
        }
    }

    static function searchForEditing(T:IntervalTree, start:Int, end:Int):Array<IntervalNode> {
        // https://en.wikipedia.org/wiki/Interval_tree#Augmented_tree
        // Now, it is known that two intervals A and B overlap only when both
        // A.low <= B.high and A.high >= B.low. When searching the trees for
        // nodes overlapping with a given interval, you can immediately skip:
        //  a) all nodes to the right of nodes whose low value is past the end of the given interval.
        //  b) all nodes that have their maximum 'high' value below the start of the given interval.
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        var delta = 0;
        var nodeMaxEnd = 0;
        var nodeStart = 0;
        var nodeEnd = 0;
        final result:Array<IntervalNode> = [];
        var resultLen = 0;
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                if (node == node.parent.right) {
                    delta -= node.parent.delta;
                }
                node = node.parent;
                continue;
            }

            if (!getNodeIsVisited(node.left)) {
                // first time seeing this node
                nodeMaxEnd = delta + node.maxEnd;
                if (nodeMaxEnd < start) {
                    // cover case b) from above
                    // there is no need to search this node or its children
                    setNodeIsVisited(node, true);
                    continue;
                }

                if (node.left != SENTINEL) {
                    // go left
                    node = node.left;
                    continue;
                }
            }

            // handle current node
            nodeStart = delta + node.start;
            if (nodeStart > end) {
                // cover case a) from above
                // there is no need to search this node or its right subtree
                setNodeIsVisited(node, true);
                continue;
            }

            nodeEnd = delta + node.end;
            if (nodeEnd >= start) {
                node.setCachedOffsets(nodeStart, nodeEnd, 0);
                result[resultLen++] = node;
            }
            setNodeIsVisited(node, true);

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                delta += node.delta;
                node = node.right;
                continue;
            }
        }

        setNodeIsVisited(T.root, false);

        return result;
    }

    static function noOverlapReplace(T:IntervalTree, start:Int, end:Int, textLength:Int):Void {
        // https://en.wikipedia.org/wiki/Interval_tree#Augmented_tree
        // Now, it is known that two intervals A and B overlap only when both
        // A.low <= B.high and A.high >= B.low. When searching the trees for
        // nodes overlapping with a given interval, you can immediately skip:
        //  a) all nodes to the right of nodes whose low value is past the end of the given interval.
        //  b) all nodes that have their maximum 'high' value below the start of the given interval.
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        var delta = 0;
        var nodeMaxEnd = 0;
        var nodeStart = 0;
        final editDelta = (textLength - (end - start));
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                if (node == node.parent.right) {
                    delta -= node.parent.delta;
                }
                recomputeMaxEnd(T, node);
                node = node.parent;
                continue;
            }

            if (!getNodeIsVisited(node.left)) {
                // first time seeing this node
                nodeMaxEnd = delta + node.maxEnd;
                if (nodeMaxEnd < start) {
                    // cover case b) from above
                    // there is no need to search this node or its children
                    setNodeIsVisited(node, true);
                    continue;
                }

                if (node.left != SENTINEL) {
                    // go left
                    node = node.left;
                    continue;
                }
            }

            // handle current node
            nodeStart = delta + node.start;
            if (nodeStart > end) {
                node.start += editDelta;
                node.end += editDelta;
                node.delta += editDelta;
                if (node.delta < MIN_SAFE_DELTA || node.delta > MAX_SAFE_DELTA) {
                    T.requestNormalizeDelta = true;
                }
                // cover case a) from above
                // there is no need to search this node or its right subtree
                setNodeIsVisited(node, true);
                continue;
            }

            setNodeIsVisited(node, true);

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                delta += node.delta;
                node = node.right;
                continue;
            }
        }

        setNodeIsVisited(T.root, false);
    }

    //#endregion

    //#region Searching

    static function _collectNodesFromOwner(T:IntervalTree, ownerId:Int):Array<IntervalNode> {
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        final result:Array<IntervalNode> = [];
        var resultLen = 0;
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                node = node.parent;
                continue;
            }

            if (node.left != SENTINEL && !getNodeIsVisited(node.left)) {
                // go left
                node = node.left;
                continue;
            }

            // handle current node
            if (node.ownerId == ownerId) {
                result[resultLen++] = node;
            }

            setNodeIsVisited(node, true);

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                node = node.right;
                continue;
            }
        }

        setNodeIsVisited(T.root, false);

        return result;
    }

    static function _collectNodesPostOrder(T:IntervalTree):Array<IntervalNode> {
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        final result:Array<IntervalNode> = [];
        var resultLen = 0;
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                node = node.parent;
                continue;
            }

            if (node.left != SENTINEL && !getNodeIsVisited(node.left)) {
                // go left
                node = node.left;
                continue;
            }

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                node = node.right;
                continue;
            }

            // handle current node
            result[resultLen++] = node;
            setNodeIsVisited(node, true);
        }

        setNodeIsVisited(T.root, false);

        return result;
    }

    static function _search(T:IntervalTree, filterOwnerId:Int, filterOutValidation:Bool, cachedVersionId:Int, onlyMarginDecorations:Bool):Array<IntervalNode> {
        final SENTINEL = T.SENTINEL;
        var node = T.root;
        var delta = 0;
        var nodeStart = 0;
        var nodeEnd = 0;
        final result:Array<IntervalNode> = [];
        var resultLen = 0;
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                if (node == node.parent.right) {
                    delta -= node.parent.delta;
                }
                node = node.parent;
                continue;
            }

            if (node.left != SENTINEL && !getNodeIsVisited(node.left)) {
                // go left
                node = node.left;
                continue;
            }

            // handle current node
            nodeStart = delta + node.start;
            nodeEnd = delta + node.end;

            node.setCachedOffsets(nodeStart, nodeEnd, cachedVersionId);

            var include = true;
            if (filterOwnerId != 0 && node.ownerId != 0 && node.ownerId != filterOwnerId) {
                include = false;
            }
            if (filterOutValidation && getNodeIsForValidation(node)) {
                include = false;
            }
            if (onlyMarginDecorations && !getNodeIsInGlyphMargin(node)) {
                include = false;
            }

            if (include) {
                result[resultLen++] = node;
            }

            setNodeIsVisited(node, true);

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                delta += node.delta;
                node = node.right;
                continue;
            }
        }

        setNodeIsVisited(T.root, false);

        return result;
    }

    static function _intervalSearch(T:IntervalTree, intervalStart:Int, intervalEnd:Int, filterOwnerId:Int, filterOutValidation:Bool, cachedVersionId:Int, onlyMarginDecorations:Bool):Array<IntervalNode> {
        // https://en.wikipedia.org/wiki/Interval_tree#Augmented_tree
        // Now, it is known that two intervals A and B overlap only when both
        // A.low <= B.high and A.high >= B.low. When searching the trees for
        // nodes overlapping with a given interval, you can immediately skip:
        //  a) all nodes to the right of nodes whose low value is past the end of the given interval.
        //  b) all nodes that have their maximum 'high' value below the start of the given interval.

        final SENTINEL = T.SENTINEL;
        var node = T.root;
        var delta = 0;
        var nodeMaxEnd = 0;
        var nodeStart = 0;
        var nodeEnd = 0;
        final result:Array<IntervalNode> = [];
        var resultLen = 0;
        while (node != SENTINEL) {
            if (getNodeIsVisited(node)) {
                // going up from this node
                setNodeIsVisited(node.left, false);
                setNodeIsVisited(node.right, false);
                if (node == node.parent.right) {
                    delta -= node.parent.delta;
                }
                node = node.parent;
                continue;
            }

            if (!getNodeIsVisited(node.left)) {
                // first time seeing this node
                nodeMaxEnd = delta + node.maxEnd;
                if (nodeMaxEnd < intervalStart) {
                    // cover case b) from above
                    // there is no need to search this node or its children
                    setNodeIsVisited(node, true);
                    continue;
                }

                if (node.left != SENTINEL) {
                    // go left
                    node = node.left;
                    continue;
                }
            }

            // handle current node
            nodeStart = delta + node.start;
            if (nodeStart > intervalEnd) {
                // cover case a) from above
                // there is no need to search this node or its right subtree
                setNodeIsVisited(node, true);
                continue;
            }

            nodeEnd = delta + node.end;

            if (nodeEnd >= intervalStart) {
                // There is overlap
                node.setCachedOffsets(nodeStart, nodeEnd, cachedVersionId);

                var include = true;
                if (filterOwnerId != 0 && node.ownerId != 0 && node.ownerId != filterOwnerId) {
                    include = false;
                }
                if (filterOutValidation && getNodeIsForValidation(node)) {
                    include = false;
                }
                if (onlyMarginDecorations && !getNodeIsInGlyphMargin(node)) {
                    include = false;
                }

                if (include) {
                    result[resultLen++] = node;
                }
            }

            setNodeIsVisited(node, true);

            if (node.right != SENTINEL && !getNodeIsVisited(node.right)) {
                // go right
                delta += node.delta;
                node = node.right;
                continue;
            }
        }

        setNodeIsVisited(T.root, false);

        return result;
    }

    //#endregion

    //#region Insertion

    static function rbTreeInsert(T:IntervalTree, newNode:IntervalNode):IntervalNode {
        final SENTINEL = T.SENTINEL;
        if (T.root == SENTINEL) {
            newNode.parent = SENTINEL;
            newNode.left = SENTINEL;
            newNode.right = SENTINEL;
            setNodeColor(newNode, NodeColor.Black);
            T.root = newNode;
            return T.root;
        }

        treeInsert(T, newNode);

        recomputeMaxEndWalkToRoot(T, newNode.parent);

        // repair tree
        var x = newNode;
        while (x != T.root && getNodeColor(x.parent) == NodeColor.Red) {
            if (x.parent == x.parent.parent.left) {
                final y = x.parent.parent.right;

                if (getNodeColor(y) == NodeColor.Red) {
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(y, NodeColor.Black);
                    setNodeColor(x.parent.parent, NodeColor.Red);
                    x = x.parent.parent;
                }
                else {
                    if (x == x.parent.right) {
                        x = x.parent;
                        leftRotate(T, x);
                    }
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(x.parent.parent, NodeColor.Red);
                    rightRotate(T, x.parent.parent);
                }
            }
            else {
                final y = x.parent.parent.left;

                if (getNodeColor(y) == NodeColor.Red) {
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(y, NodeColor.Black);
                    setNodeColor(x.parent.parent, NodeColor.Red);
                    x = x.parent.parent;
                }
                else {
                    if (x == x.parent.left) {
                        x = x.parent;
                        rightRotate(T, x);
                    }
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(x.parent.parent, NodeColor.Red);
                    leftRotate(T, x.parent.parent);
                }
            }
        }

        setNodeColor(T.root, NodeColor.Black);

        return newNode;
    }

    static function treeInsert(T:IntervalTree, z:IntervalNode):Void {
        final SENTINEL = T.SENTINEL;
        var delta:Int = 0;
        var x = T.root;
        final zAbsoluteStart = z.start;
        final zAbsoluteEnd = z.end;
        while (true) {
            final cmp = intervalCompare(zAbsoluteStart, zAbsoluteEnd, x.start + delta, x.end + delta);
            if (cmp < 0) {
                // this node should be inserted to the left
                // => it is not affected by the node's delta
                if (x.left == SENTINEL) {
                    z.start -= delta;
                    z.end -= delta;
                    z.maxEnd -= delta;
                    x.left = z;
                    break;
                }
                else {
                    x = x.left;
                }
            }
            else {
                // this node should be inserted to the right
                // => it is not affected by the node's delta
                if (x.right == SENTINEL) {
                    z.start -= (delta + x.delta);
                    z.end -= (delta + x.delta);
                    z.maxEnd -= (delta + x.delta);
                    x.right = z;
                    break;
                }
                else {
                    delta += x.delta;
                    x = x.right;
                }
            }
        }

        z.parent = x;
        z.left = SENTINEL;
        z.right = SENTINEL;
        setNodeColor(z, NodeColor.Red);
    }

    //#endregion

    //#region Deletion

    static function rbTreeDelete(T:IntervalTree, z:IntervalNode):Void {
        final SENTINEL = T.SENTINEL;

        var x:IntervalNode;
        var y:IntervalNode;

        // RB-DELETE except we don't swap z and y in case c)
        // i.e. we always delete what's pointed at by z.

        if (z.left == SENTINEL) {
            x = z.right;
            y = z;

            // x's delta is no longer influenced by z's delta
            x.delta += z.delta;
            if (x.delta < MIN_SAFE_DELTA || x.delta > MAX_SAFE_DELTA) {
                T.requestNormalizeDelta = true;
            }
            x.start += z.delta;
            x.end += z.delta;
        }
        else if (z.right == SENTINEL) {
            x = z.left;
            y = z;
        }
        else {
            y = leftest(T, z.right);
            x = y.right;

            // y's delta is no longer influenced by z's delta,
            // but we don't want to walk the entire right-hand-side subtree of x.
            // we therefore maintain z's delta in y, and adjust only x
            x.start += y.delta;
            x.end += y.delta;
            x.delta += y.delta;
            if (x.delta < MIN_SAFE_DELTA || x.delta > MAX_SAFE_DELTA) {
                T.requestNormalizeDelta = true;
            }

            y.start += z.delta;
            y.end += z.delta;
            y.delta = z.delta;
            if (y.delta < MIN_SAFE_DELTA || y.delta > MAX_SAFE_DELTA) {
                T.requestNormalizeDelta = true;
            }
        }

        if (y == T.root) {
            T.root = x;
            setNodeColor(x, NodeColor.Black);

            z.detach();
            resetSentinel(T);
            recomputeMaxEnd(T, x);
            T.root.parent = SENTINEL;
            return;
        }

        final yWasRed = (getNodeColor(y) == NodeColor.Red);

        if (y == y.parent.left) {
            y.parent.left = x;
        }
        else {
            y.parent.right = x;
        }

        if (y == z) {
            x.parent = y.parent;
        }
        else {

            if (y.parent == z) {
                x.parent = y;
            }
            else {
                x.parent = y.parent;
            }

            y.left = z.left;
            y.right = z.right;
            y.parent = z.parent;
            setNodeColor(y, getNodeColor(z));

            if (z == T.root) {
                T.root = y;
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
        }

        z.detach();

        if (yWasRed) {
            recomputeMaxEndWalkToRoot(T, x.parent);
            if (y != z) {
                recomputeMaxEndWalkToRoot(T, y);
                recomputeMaxEndWalkToRoot(T, y.parent);
            }
            resetSentinel(T);
            return;
        }

        recomputeMaxEndWalkToRoot(T, x);
        recomputeMaxEndWalkToRoot(T, x.parent);
        if (y != z) {
            recomputeMaxEndWalkToRoot(T, y);
            recomputeMaxEndWalkToRoot(T, y.parent);
        }

        // RB-DELETE-FIXUP
        var w:IntervalNode;
        while (x != T.root && getNodeColor(x) == NodeColor.Black) {

            if (x == x.parent.left) {
                w = x.parent.right;

                if (getNodeColor(w) == NodeColor.Red) {
                    setNodeColor(w, NodeColor.Black);
                    setNodeColor(x.parent, NodeColor.Red);
                    leftRotate(T, x.parent);
                    w = x.parent.right;
                }

                if (getNodeColor(w.left) == NodeColor.Black && getNodeColor(w.right) == NodeColor.Black) {
                    setNodeColor(w, NodeColor.Red);
                    x = x.parent;
                }
                else {
                    if (getNodeColor(w.right) == NodeColor.Black) {
                        setNodeColor(w.left, NodeColor.Black);
                        setNodeColor(w, NodeColor.Red);
                        rightRotate(T, w);
                        w = x.parent.right;
                    }

                    setNodeColor(w, getNodeColor(x.parent));
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(w.right, NodeColor.Black);
                    leftRotate(T, x.parent);
                    x = T.root;
                }
            }
            else {
                w = x.parent.left;

                if (getNodeColor(w) == NodeColor.Red) {
                    setNodeColor(w, NodeColor.Black);
                    setNodeColor(x.parent, NodeColor.Red);
                    rightRotate(T, x.parent);
                    w = x.parent.left;
                }

                if (getNodeColor(w.left) == NodeColor.Black && getNodeColor(w.right) == NodeColor.Black) {
                    setNodeColor(w, NodeColor.Red);
                    x = x.parent;
                }
                else {
                    if (getNodeColor(w.left) == NodeColor.Black) {
                        setNodeColor(w.right, NodeColor.Black);
                        setNodeColor(w, NodeColor.Red);
                        leftRotate(T, w);
                        w = x.parent.left;
                    }

                    setNodeColor(w, getNodeColor(x.parent));
                    setNodeColor(x.parent, NodeColor.Black);
                    setNodeColor(w.left, NodeColor.Black);
                    rightRotate(T, x.parent);
                    x = T.root;
                }
            }
        }

        setNodeColor(x, NodeColor.Black);
        resetSentinel(T);
    }

    static function leftest(T:IntervalTree, node:IntervalNode):IntervalNode {
        final SENTINEL = T.SENTINEL;
        while (node.left != SENTINEL) {
            node = node.left;
        }
        return node;
    }

    static function resetSentinel(T:IntervalTree):Void {
        final SENTINEL = T.SENTINEL;
        SENTINEL.parent = SENTINEL;
        SENTINEL.delta = 0; // optional
        SENTINEL.start = 0; // optional
        SENTINEL.end = 0; // optional
    }

    //#endregion

    //#region Rotations

    static function leftRotate(T:IntervalTree, x:IntervalNode):Void {
        final SENTINEL = T.SENTINEL;
        final y = x.right; // set y.

        y.delta += x.delta; // y's delta is no longer influenced by x's delta
        if (y.delta < MIN_SAFE_DELTA || y.delta > MAX_SAFE_DELTA) {
            T.requestNormalizeDelta = true;
        }
        y.start += x.delta;
        y.end += x.delta;

        x.right = y.left; // turn y's left subtree into x's right subtree.
        if (y.left != SENTINEL) {
            y.left.parent = x;
        }
        y.parent = x.parent; // link x's parent to y.
        if (x.parent == SENTINEL) {
            T.root = y;
        }
        else if (x == x.parent.left) {
            x.parent.left = y;
        }
        else {
            x.parent.right = y;
        }

        y.left = x; // put x on y's left.
        x.parent = y;

        recomputeMaxEnd(T, x);
        recomputeMaxEnd(T, y);
    }

    static function rightRotate(T:IntervalTree, y:IntervalNode):Void {
        final SENTINEL = T.SENTINEL;
        final x = y.left;

        y.delta -= x.delta;
        if (y.delta < MIN_SAFE_DELTA || y.delta > MAX_SAFE_DELTA) {
            T.requestNormalizeDelta = true;
        }
        y.start -= x.delta;
        y.end -= x.delta;

        y.left = x.right;
        if (x.right != SENTINEL) {
            x.right.parent = y;
        }
        x.parent = y.parent;
        if (y.parent == SENTINEL) {
            T.root = x;
        }
        else if (y == y.parent.right) {
            y.parent.right = x;
        }
        else {
            y.parent.left = x;
        }

        x.right = y;
        y.parent = x;

        recomputeMaxEnd(T, y);
        recomputeMaxEnd(T, x);
    }

    //#endregion

    //#region max end computation

    static inline function computeMaxEnd(SENTINEL:IntervalNode, node:IntervalNode):Int {
        var maxEnd = node.end;
        if (node.left != SENTINEL) {
            final leftMaxEnd = node.left.maxEnd;
            if (leftMaxEnd > maxEnd) {
                maxEnd = leftMaxEnd;
            }
        }
        if (node.right != SENTINEL) {
            final rightMaxEnd = node.right.maxEnd + node.delta;
            if (rightMaxEnd > maxEnd) {
                maxEnd = rightMaxEnd;
            }
        }
        return maxEnd;
    }

    /**
     * Monaco's `recomputeMaxEnd(node)` (the tree gives the sentinel).
     */
    public static function recomputeMaxEnd(T:IntervalTree, node:IntervalNode):Void {
        node.maxEnd = computeMaxEnd(T.SENTINEL, node);
    }

    static function recomputeMaxEndWalkToRoot(T:IntervalTree, node:IntervalNode):Void {
        final SENTINEL = T.SENTINEL;
        while (node != SENTINEL) {

            final maxEnd = computeMaxEnd(SENTINEL, node);

            if (node.maxEnd == maxEnd) {
                // no need to go further
                return;
            }

            node.maxEnd = maxEnd;
            node = node.parent;
        }
    }

    //#endregion

    //#region utils

    public static function intervalCompare(aStart:Int, aEnd:Int, bStart:Int, bEnd:Int):Int {
        if (aStart == bStart) {
            return aEnd - bEnd;
        }
        return aStart - bStart;
    }

    //#endregion

}

private enum abstract MarkerMoveSemantics(Int) from Int to Int {
    var MarkerDefined = 0;
    var ForceMove = 1;
    var ForceStay = 2;
}
