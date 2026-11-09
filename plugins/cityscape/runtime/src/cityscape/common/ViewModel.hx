// Ported from vscode src/vs/editor/common/viewModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Scrollable;
import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.INewScrollPosition;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model.EndOfLinePreference;
import cityscape.common.Model.IGlyphMarginLanesModel;
import cityscape.common.Model.IModelDecorationOptions;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.ModelLineProjectionData.ILineBreaksComputer;
import cityscape.common.ModelLineProjectionData.InjectedText;
import cityscape.common.TextModelGuides;
import cityscape.common.ViewEvents.VerticalRevealType;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.tokens.LineTokens.IViewLineTokens;
import haxe.extern.EitherType;

/**
 * The view model of an editor.
 *
 * Cityscape has no minimap: `getMinimapDecorationsInRange` and
 * `getMinimapLinesRenderingData` are not part of the interface.
 * `getPlainTextToCopy` returns a string or an array of strings, like Monaco.
 */
interface IViewModel extends ICursorSimpleModel {

    final model:ITextModel;

    final coordinatesConverter:ICoordinatesConverter;

    final viewLayout:IViewLayout;

    final cursorConfig:CursorConfiguration;

    final glyphLanes:IGlyphMarginLanesModel;

    function addViewEventHandler(eventHandler:ViewEventHandler):Void;
    function removeViewEventHandler(eventHandler:ViewEventHandler):Void;

    /**
     * Gives a hint that a lot of requests are about to come in for these line numbers.
     */
    function setViewport(startLineNumber:Int, endLineNumber:Int, centeredLineNumber:Int):Void;
    function visibleLinesStabilized():Void;
    function setHasFocus(hasFocus:Bool):Void;
    function onCompositionStart():Void;
    function onCompositionEnd():Void;

    function getDecorationsInViewport(visibleRange:Range):Array<ViewModelDecoration>;
    function getViewportViewLineRenderingData(visibleRange:Range, lineNumber:Int):ViewLineRenderingData;
    function getViewLineRenderingData(lineNumber:Int):ViewLineRenderingData;
    function getViewLineData(lineNumber:Int):ViewLineData;
    function getCompletelyVisibleViewRange():Range;
    function getCompletelyVisibleViewRangeAtScrollTop(scrollTop:Float):Range;

    function getHiddenAreas():Array<Range>;

    function getLineCount():Int;
    function getLineContent(lineNumber:Int):String;
    function getLineLength(lineNumber:Int):Int;
    function getActiveIndentGuide(lineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo;
    function getLinesIndentGuides(startLineNumber:Int, endLineNumber:Int):Array<Int>;
    function getBracketGuidesInRangeByLine(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>>;
    function getLineMinColumn(lineNumber:Int):Int;
    function getLineMaxColumn(lineNumber:Int):Int;
    function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int;
    function getLineLastNonWhitespaceColumn(lineNumber:Int):Int;
    function getAllOverviewRulerDecorations(theme:EditorTheme):Array<OverviewRulerDecorationsGroup>;
    function getValueInRange(range:Range, eol:EndOfLinePreference):String;
    function getValueLengthInRange(range:Range, eol:EndOfLinePreference):Int;
    function modifyPosition(position:Position, offset:Int):Position;

    function getInjectedTextAt(viewPosition:Position):Null<InjectedText>;

    function deduceModelPositionRelativeToViewPosition(viewAnchorPosition:Position, deltaOffset:Int, lineFeedCnt:Int):Position;
    function getPlainTextToCopy(modelRanges:Array<Range>, emptySelectionClipboard:Bool, forceCRLF:Bool):EitherType<String, Array<String>>;
    function getRichTextToCopy(modelRanges:Array<Range>, emptySelectionClipboard:Bool):Null<{html:String, mode:String}>;

    function createLineBreaksComputer():ILineBreaksComputer;

    //#region cursor
    function getPrimaryCursorState():CursorState;
    function getLastAddedCursorIndex():Int;
    function getCursorStates():Array<CursorState>;
    function setCursorStates(source:Null<String>, reason:CursorChangeReason, states:Null<Array<PartialCursorState>>):Bool;
    function getCursorColumnSelectData():IColumnSelectData;
    function getCursorAutoClosedCharacters():Array<Range>;
    function setCursorColumnSelectData(columnSelectData:IColumnSelectData):Void;
    function getPrevEditOperationType():EditOperationType;
    function setPrevEditOperationType(type:EditOperationType):Void;
    function revealAllCursors(source:Null<String>, revealHorizontal:Bool, ?minimalReveal:Bool):Void;
    function revealPrimaryCursor(source:Null<String>, revealHorizontal:Bool, ?minimalReveal:Bool):Void;
    function revealTopMostCursor(source:Null<String>):Void;
    function revealBottomMostCursor(source:Null<String>):Void;
    function revealRange(source:Null<String>, revealHorizontal:Bool, viewRange:Range, verticalType:VerticalRevealType, scrollType:ScrollType):Void;
    //#endregion

    function changeWhitespace(callback:(accessor:IWhitespaceChangeAccessor) -> Void):Void;
    function batchEvents(callback:() -> Void):Void;
}

interface IViewLayout {

    function getScrollable():Scrollable;

    function getScrollWidth():Float;
    function getScrollHeight():Float;

    function getCurrentScrollLeft():Float;
    function getCurrentScrollTop():Float;
    function getCurrentViewport():Viewport;
    function getFutureViewport():Viewport;

    function setScrollPosition(position:INewScrollPosition, type:ScrollType):Void;
    function deltaScrollNow(deltaScrollLeft:Float, deltaScrollTop:Float):Void;

    function validateScrollPosition(scrollPosition:INewScrollPosition):IScrollPosition;

    function setMaxLineWidth(maxLineWidth:Float):Void;

    function setOverlayWidgetsMinWidth(overlayWidgetsMinWidth:Float):Void;

    function getLinesViewportData():IPartialViewLinesViewportData;
    function getLinesViewportDataAtScrollTop(scrollTop:Float):IPartialViewLinesViewportData;
    function getWhitespaces():Array<IEditorWhitespace>;

    function isAfterLines(verticalOffset:Float):Bool;
    function isInTopPadding(verticalOffset:Float):Bool;
    function isInBottomPadding(verticalOffset:Float):Bool;
    function getLineNumberAtVerticalOffset(verticalOffset:Float):Int;
    function getVerticalOffsetForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float;
    function getVerticalOffsetAfterLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float;
    function getWhitespaceAtVerticalOffset(verticalOffset:Float):Null<IViewWhitespaceViewportData>;

    /**
     * Get the layout information for whitespaces currently in the viewport
     */
    function getWhitespaceViewportData():Array<IViewWhitespaceViewportData>;
}

typedef IEditorWhitespace = {
    final id:String;
    final afterLineNumber:Int;
    final height:Float;
}

/**
 * An accessor that allows for whitespace to be added, removed or changed in bulk.
 */
interface IWhitespaceChangeAccessor {
    function insertWhitespace(afterLineNumber:Int, ordinal:Int, heightInPx:Float, minWidth:Float):String;
    function changeOneWhitespace(id:String, newAfterLineNumber:Int, newHeight:Float):Void;
    function removeWhitespace(id:String):Void;
}

typedef IPartialViewLinesViewportData = {
    /**
     * Value to be substracted from `scrollTop` (in order to vertical offset numbers < 1MM)
     */
    final bigNumbersDelta:Float;
    /**
     * The first (partially) visible line number.
     */
    final startLineNumber:Int;
    /**
     * The last (partially) visible line number.
     */
    final endLineNumber:Int;
    /**
     * relativeVerticalOffset[i] is the `top` position for line at `i` + `startLineNumber`.
     */
    final relativeVerticalOffset:Array<Float>;
    /**
     * The centered line in the viewport.
     */
    final centeredLineNumber:Int;
    /**
     * The first completely visible line number.
     */
    final completelyVisibleStartLineNumber:Int;
    /**
     * The last completely visible line number.
     */
    final completelyVisibleEndLineNumber:Int;

    /**
     * The height of a line.
     */
    final lineHeight:Float;
}

typedef IViewWhitespaceViewportData = {
    final id:String;
    final afterLineNumber:Int;
    final verticalOffset:Float;
    final height:Float;
}

class Viewport {

    public final top:Int;

    public final left:Int;

    public final width:Int;

    public final height:Int;

    public function new(top:Float, left:Float, width:Float, height:Float) {
        // `x | 0` in Monaco: truncation to a 32 bit integer
        this.top = toInt32(top);
        this.left = toInt32(left);
        this.width = toInt32(width);
        this.height = toInt32(height);
    }

    static inline function toInt32(value:Float):Int {
        return Math.isNaN(value) || !Math.isFinite(value) ? 0 : Std.int(value);
    }

}

interface ICoordinatesConverter {
    // View -> Model conversion and related methods
    function convertViewPositionToModelPosition(viewPosition:Position):Position;
    function convertViewRangeToModelRange(viewRange:Range):Range;
    function validateViewPosition(viewPosition:Position, expectedModelPosition:Position):Position;
    function validateViewRange(viewRange:Range, expectedModelRange:Range):Range;

    // Model -> View conversion and related methods
    /**
     * @param allowZeroLineNumber Should it return 0 when there are hidden lines at the top and the position is in the hidden area?
     * @param belowHiddenRanges When the model position is in a hidden area, should it return the first view position after or before?
     */
    function convertModelPositionToViewPosition(modelPosition:Position, ?affinity:PositionAffinity, ?allowZeroLineNumber:Bool, ?belowHiddenRanges:Bool):Position;
    /**
     * @param affinity Only has an effect if the range is empty.
     */
    function convertModelRangeToViewRange(modelRange:Range, ?affinity:PositionAffinity):Range;
    function modelPositionIsVisible(modelPosition:Position):Bool;
    function getModelLineViewLineCount(modelLineNumber:Int):Int;
    function getViewLineNumberOfModelPosition(modelLineNumber:Int, modelColumn:Int):Int;
}

class ViewLineData {

    /**
     * The content at this view line.
     */
    public final content:String;

    /**
     * Does this line continue with a wrapped line?
     */
    public final continuesWithWrappedLine:Bool;

    /**
     * The minimum allowed column at this view line.
     */
    public final minColumn:Int;

    /**
     * The maximum allowed column at this view line.
     */
    public final maxColumn:Int;

    /**
     * The visible column at the start of the line (after the fauxIndent).
     */
    public final startVisibleColumn:Int;

    /**
     * The tokens at this view line.
     */
    public final tokens:IViewLineTokens;

    /**
     * Additional inline decorations for this line.
     */
    public final inlineDecorations:Null<Array<SingleLineInlineDecoration>>;

    public function new(content:String, continuesWithWrappedLine:Bool, minColumn:Int, maxColumn:Int, startVisibleColumn:Int, tokens:IViewLineTokens, inlineDecorations:Null<Array<SingleLineInlineDecoration>>) {
        this.content = content;
        this.continuesWithWrappedLine = continuesWithWrappedLine;
        this.minColumn = minColumn;
        this.maxColumn = maxColumn;
        this.startVisibleColumn = startVisibleColumn;
        this.tokens = tokens;
        this.inlineDecorations = inlineDecorations;
    }

}

class ViewLineRenderingData {

    /**
     * The minimum allowed column at this view line.
     */
    public final minColumn:Int;

    /**
     * The maximum allowed column at this view line.
     */
    public final maxColumn:Int;

    /**
     * The content at this view line.
     */
    public final content:String;

    /**
     * Does this line continue with a wrapped line?
     */
    public final continuesWithWrappedLine:Bool;

    /**
     * Describes if `content` contains RTL characters.
     */
    public final containsRTL:Bool;

    /**
     * Describes if `content` contains only basic ASCII characters.
     */
    public final isBasicASCII:Bool;

    /**
     * The tokens at this view line.
     */
    public final tokens:IViewLineTokens;

    /**
     * Inline decorations at this view line.
     */
    public final inlineDecorations:Array<InlineDecoration>;

    /**
     * The tab size for this view model.
     */
    public final tabSize:Int;

    /**
     * The visible column at the start of the line (after the fauxIndent)
     */
    public final startVisibleColumn:Int;

    public function new(minColumn:Int, maxColumn:Int, content:String, continuesWithWrappedLine:Bool, mightContainRTL:Bool, mightContainNonBasicASCII:Bool, tokens:IViewLineTokens, inlineDecorations:Array<InlineDecoration>, tabSize:Int, startVisibleColumn:Int) {
        this.minColumn = minColumn;
        this.maxColumn = maxColumn;
        this.content = content;
        this.continuesWithWrappedLine = continuesWithWrappedLine;

        this.isBasicASCII = ViewLineRenderingData.isBasicASCIIStatic(content, mightContainNonBasicASCII);
        this.containsRTL = ViewLineRenderingData.containsRTLStatic(content, this.isBasicASCII, mightContainRTL);

        this.tokens = tokens;
        this.inlineDecorations = inlineDecorations;
        this.tabSize = tabSize;
        this.startVisibleColumn = startVisibleColumn;
    }

    /**
     * Monaco's static `ViewLineRenderingData.isBasicASCII` (the suffix
     * avoids the clash with the field of the same name).
     */
    public static function isBasicASCIIStatic(lineContent:String, mightContainNonBasicASCII:Bool):Bool {
        if (mightContainNonBasicASCII) {
            return Strings.isBasicASCII(lineContent);
        }
        return true;
    }

    /**
     * Monaco's static `ViewLineRenderingData.containsRTL` (the suffix
     * avoids the clash with the field of the same name).
     */
    public static function containsRTLStatic(lineContent:String, isBasicASCII:Bool, mightContainRTL:Bool):Bool {
        if (!isBasicASCII && mightContainRTL) {
            return Strings.containsRTL(lineContent);
        }
        return false;
    }

}

enum abstract InlineDecorationType(Int) from Int to Int {
    var Regular = 0;
    var Before = 1;
    var After = 2;
    var RegularAffectingLetterSpacing = 3;
}

class InlineDecoration {

    public final range:Range;

    public final inlineClassName:String;

    public final type:InlineDecorationType;

    /**
     * The typed style of the decoration (Cityscape): `inlineStyle` of the
     * decoration options, or of the injected text. Null for class names only.
     */
    public final style:Null<cityscape.common.DecorationStyle.IDecorationStyle>;

    public function new(range:Range, inlineClassName:String, type:InlineDecorationType, ?style:cityscape.common.DecorationStyle.IDecorationStyle) {
        this.range = range;
        this.inlineClassName = inlineClassName;
        this.type = type;
        this.style = style;
    }

}

class SingleLineInlineDecoration {

    public final startOffset:Int;

    public final endOffset:Int;

    public final inlineClassName:String;

    public final inlineClassNameAffectsLetterSpacing:Bool;

    /**
     * The typed style of the injected text (Cityscape), or null.
     */
    public final style:Null<cityscape.common.DecorationStyle.IDecorationStyle>;

    public function new(startOffset:Int, endOffset:Int, inlineClassName:String, inlineClassNameAffectsLetterSpacing:Bool, ?style:cityscape.common.DecorationStyle.IDecorationStyle) {
        this.startOffset = startOffset;
        this.endOffset = endOffset;
        this.inlineClassName = inlineClassName;
        this.inlineClassNameAffectsLetterSpacing = inlineClassNameAffectsLetterSpacing;
        this.style = style;
    }

    public function toInlineDecoration(lineNumber:Int):InlineDecoration {
        return new InlineDecoration(
            new Range(lineNumber, this.startOffset + 1, lineNumber, this.endOffset + 1),
            this.inlineClassName,
            this.inlineClassNameAffectsLetterSpacing ? InlineDecorationType.RegularAffectingLetterSpacing : InlineDecorationType.Regular,
            this.style
        );
    }

}

class ViewModelDecoration {

    public final range:Range;

    public final options:IModelDecorationOptions;

    public function new(range:Range, options:IModelDecorationOptions) {
        this.range = range;
        this.options = options;
    }

}

class OverviewRulerDecorationsGroup {

    public final color:String;

    public final zIndex:Float;

    public final data:Array<Float>;

    public function new(color:String, zIndex:Float, data:Array<Float>) {
        this.color = color;
        this.zIndex = zIndex;
        this.data = data;
    }

    public static function compareByRenderingProps(a:OverviewRulerDecorationsGroup, b:OverviewRulerDecorationsGroup):Int {
        if (a.zIndex == b.zIndex) {
            if (a.color < b.color) {
                return -1;
            }
            if (a.color > b.color) {
                return 1;
            }
            return 0;
        }
        final d = a.zIndex - b.zIndex;
        return d < 0 ? -1 : (d > 0 ? 1 : 0);
    }

    public static function equals(a:OverviewRulerDecorationsGroup, b:OverviewRulerDecorationsGroup):Bool {
        if (a.color != b.color || a.zIndex != b.zIndex || a.data.length != b.data.length) {
            return false;
        }
        for (i in 0...a.data.length) {
            if (a.data[i] != b.data[i]) {
                return false;
            }
        }
        return true;
    }

    public static function equalsArr(a:Array<OverviewRulerDecorationsGroup>, b:Array<OverviewRulerDecorationsGroup>):Bool {
        if (a == b) {
            return true;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!equals(a[i], b[i])) {
                return false;
            }
        }
        return true;
    }

}
