// Ported from vscode src/vs/editor/common/textModelBracketPairs.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Arrays.CallbackIterable;
import cityscape.base.common.Event;
import cityscape.common.core.Position.IPosition;
import cityscape.common.core.Range;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast.PairAstNode;

/**
 * The bracket pairs part of a text model (bracket matching, colorization,
 * guides).
 *
 * The ranges taken by the `get*InRange` methods are `Range` instances
 * (Monaco's interface says `IRange`, its implementation uses `Range`
 * methods). Monaco's `[Range, Range]` results are arrays of two ranges.
 */
interface IBracketPairsTextModelPart {

    /**
     * Is fired when bracket pairs change, either due to a text or a settings change.
     */
    var onDidChange(default, null):VoidEvent;

    /**
     * Gets all bracket pairs that intersect the given position.
     * The result is sorted by the start position.
     */
    function getBracketPairsInRange(range:Range):CallbackIterable<BracketPairInfo>;

    /**
     * Gets all bracket pairs that intersect the given position.
     * The result is sorted by the start position.
     */
    function getBracketPairsInRangeWithMinIndentation(range:Range):CallbackIterable<BracketPairWithMinIndentationInfo>;

    function getBracketsInRange(range:Range, ?onlyColorizedBrackets:Bool):CallbackIterable<BracketInfo>;

    /**
     * Find the matching bracket of `request` up, counting brackets.
     * @param request The bracket we're searching for
     * @param position The position at which to start the search.
     * @param maxDuration In milliseconds.
     * @return The range of the matching bracket, or null if the bracket match was not found.
     */
    function findMatchingBracketUp(bracket:String, position:IPosition, ?maxDuration:Float):Null<Range>;

    /**
     * Find the first bracket in the model before `position`.
     * @param position The position at which to start the search.
     * @return The info for the first bracket before `position`, or null if there are no more brackets before `positions`.
     */
    function findPrevBracket(position:IPosition):Null<IFoundBracket>;

    /**
     * Find the first bracket in the model after `position`.
     * @param position The position at which to start the search.
     * @return The info for the first bracket after `position`, or null if there are no more brackets after `positions`.
     */
    function findNextBracket(position:IPosition):Null<IFoundBracket>;

    /**
     * Find the enclosing brackets that contain `position`.
     * @param position The position at which to start the search.
     * @return The opening and closing bracket ranges.
     */
    function findEnclosingBrackets(position:IPosition, ?maxDuration:Float):Null<Array<Range>>;

    /**
     * Given a `position`, if the position is on top or near a bracket,
     * find the matching bracket of that bracket and return the ranges of both brackets.
     * @param position The position at which to look for a bracket.
     * @return The ranges of the two brackets.
     */
    function matchBracket(position:IPosition, ?maxDuration:Float):Null<Array<Range>>;

}

typedef IFoundBracket = {
    var range:Range;
    /**
     * An `OpeningBracketKind` or a `ClosingBracketKind`.
     */
    var bracketInfo:BracketKind;
}

class BracketInfo {

    public final range:Range;
    /** 0-based level */
    public final nestingLevel:Int;
    public final nestingLevelOfEqualBracketType:Int;
    public final isInvalid:Bool;

    public function new(range:Range, nestingLevel:Int, nestingLevelOfEqualBracketType:Int, isInvalid:Bool) {
        this.range = range;
        this.nestingLevel = nestingLevel;
        this.nestingLevelOfEqualBracketType = nestingLevelOfEqualBracketType;
        this.isInvalid = isInvalid;
    }

}

class BracketPairInfo {

    public final range:Range;
    public final openingBracketRange:Range;
    public final closingBracketRange:Null<Range>;
    /** 0-based */
    public final nestingLevel:Int;
    public final nestingLevelOfEqualBracketType:Int;
    final bracketPairNode:PairAstNode;

    public function new(
        range:Range,
        openingBracketRange:Range,
        closingBracketRange:Null<Range>,
        nestingLevel:Int,
        nestingLevelOfEqualBracketType:Int,
        bracketPairNode:PairAstNode
    ) {
        this.range = range;
        this.openingBracketRange = openingBracketRange;
        this.closingBracketRange = closingBracketRange;
        this.nestingLevel = nestingLevel;
        this.nestingLevelOfEqualBracketType = nestingLevelOfEqualBracketType;
        this.bracketPairNode = bracketPairNode;
    }

    public var openingBracketInfo(get, never):OpeningBracketKind;
    function get_openingBracketInfo():OpeningBracketKind {
        return cast bracketPairNode.openingBracket.bracketInfo;
    }

    public var closingBracketInfo(get, never):Null<ClosingBracketKind>;
    function get_closingBracketInfo():Null<ClosingBracketKind> {
        final closingBracket = bracketPairNode.closingBracket;
        return closingBracket != null ? cast closingBracket.bracketInfo : null;
    }

}

class BracketPairWithMinIndentationInfo extends BracketPairInfo {

    /**
     * -1 if not requested, otherwise the size of the minimum indentation in the bracket pair in terms of visible columns.
     */
    public final minVisibleColumnIndentation:Int;

    public function new(
        range:Range,
        openingBracketRange:Range,
        closingBracketRange:Null<Range>,
        /**
         * 0-based
         */
        nestingLevel:Int,
        nestingLevelOfEqualBracketType:Int,
        bracketPairNode:PairAstNode,
        minVisibleColumnIndentation:Int
    ) {
        super(range, openingBracketRange, closingBracketRange, nestingLevel, nestingLevelOfEqualBracketType, bracketPairNode);
        this.minVisibleColumnIndentation = minVisibleColumnIndentation;
    }

}
