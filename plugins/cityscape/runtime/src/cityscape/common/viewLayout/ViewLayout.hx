// Ported from vscode src/vs/editor/common/viewLayout/viewLayout.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

import cityscape.base.common.Event;
import cityscape.base.common.Scrollable;
import cityscape.common.EditorCommon.INewScrollPosition;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.ViewModel;
import cityscape.common.ViewModelEventDispatcher.ContentSizeChangedEvent;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorOptions;

private class EditorScrollDimensions {

    public final width:Float;
    public final contentWidth:Float;
    public final scrollWidth:Float;

    public final height:Float;
    public final contentHeight:Float;
    public final scrollHeight:Float;

    public function new(width:Float, contentWidth:Float, height:Float, contentHeight:Float) {
        width = LinesLayout.toInt32(width);
        contentWidth = LinesLayout.toInt32(contentWidth);
        height = LinesLayout.toInt32(height);
        contentHeight = LinesLayout.toInt32(contentHeight);

        if (width < 0) {
            width = 0;
        }
        if (contentWidth < 0) {
            contentWidth = 0;
        }

        if (height < 0) {
            height = 0;
        }
        if (contentHeight < 0) {
            contentHeight = 0;
        }

        this.width = width;
        this.contentWidth = contentWidth;
        this.scrollWidth = Math.max(width, contentWidth);

        this.height = height;
        this.contentHeight = contentHeight;
        this.scrollHeight = Math.max(height, contentHeight);
    }

    public function equals(other:EditorScrollDimensions):Bool {
        return (
            this.width == other.width
            && this.contentWidth == other.contentWidth
            && this.height == other.height
            && this.contentHeight == other.contentHeight
        );
    }

}

private class EditorScrollable {

    final _scrollable:Scrollable;
    var _dimensions:EditorScrollDimensions;

    public final onDidScroll:Event<ScrollEvent>;

    final _onDidContentSizeChange = new Emitter<ContentSizeChangedEvent>();
    public final onDidContentSizeChange:Event<ContentSizeChangedEvent>;

    public function new(smoothScrollDuration:Float) {
        this._dimensions = new EditorScrollDimensions(0, 0, 0, 0);
        this._scrollable = new Scrollable({
            forceIntegerValues: true,
            smoothScrollDuration: smoothScrollDuration
        });
        this.onDidScroll = this._scrollable.onScroll;
        this.onDidContentSizeChange = this._onDidContentSizeChange.event;
    }

    public function dispose():Void {
        _scrollable.dispose();
        _onDidContentSizeChange.dispose();
    }

    public function getScrollable():Scrollable {
        return this._scrollable;
    }

    public function setSmoothScrollDuration(smoothScrollDuration:Float):Void {
        this._scrollable.setSmoothScrollDuration(smoothScrollDuration);
    }

    public function validateScrollPosition(scrollPosition:INewScrollPosition):IScrollPosition {
        return this._scrollable.validateScrollPosition(scrollPosition);
    }

    public function getScrollDimensions():EditorScrollDimensions {
        return this._dimensions;
    }

    public function setScrollDimensions(dimensions:EditorScrollDimensions):Void {
        if (this._dimensions.equals(dimensions)) {
            return;
        }

        final oldDimensions = this._dimensions;
        this._dimensions = dimensions;

        this._scrollable.setScrollDimensions({
            width: dimensions.width,
            scrollWidth: dimensions.scrollWidth,
            height: dimensions.height,
            scrollHeight: dimensions.scrollHeight
        }, true);

        final contentWidthChanged = (oldDimensions.contentWidth != dimensions.contentWidth);
        final contentHeightChanged = (oldDimensions.contentHeight != dimensions.contentHeight);
        if (contentWidthChanged || contentHeightChanged) {
            this._onDidContentSizeChange.fire(new ContentSizeChangedEvent(
                oldDimensions.contentWidth, oldDimensions.contentHeight,
                dimensions.contentWidth, dimensions.contentHeight
            ));
        }
    }

    public function getFutureScrollPosition():ScrollState {
        return this._scrollable.getFutureScrollPosition();
    }

    public function getCurrentScrollPosition():ScrollState {
        return this._scrollable.getCurrentScrollPosition();
    }

    public function setScrollPositionNow(update:INewScrollPosition):Void {
        this._scrollable.setScrollPositionNow(update);
    }

    public function setScrollPositionSmooth(update:INewScrollPosition):Void {
        this._scrollable.setScrollPositionSmooth(update);
    }

    public function hasPendingScrollAnimation():Bool {
        return this._scrollable.hasPendingScrollAnimation();
    }

}

class ViewLayout implements IViewLayout {

    static inline final SMOOTH_SCROLLING_TIME = 125;

    final _configuration:IEditorConfiguration;
    final _linesLayout:LinesLayout;
    var _maxLineWidth:Float;
    var _overlayWidgetsMinWidth:Float;

    final _scrollable:EditorScrollable;
    public final onDidScroll:Event<ScrollEvent>;
    public final onDidContentSizeChange:Event<ContentSizeChangedEvent>;

    public function new(configuration:IEditorConfiguration, lineCount:Int) {
        this._configuration = configuration;
        final options = this._configuration.options;
        final layoutInfo = options.get(EditorOption.layoutInfo);
        final padding = options.get(EditorOption.padding);

        this._linesLayout = new LinesLayout(lineCount, options.get(EditorOption.lineHeight), padding.top, padding.bottom);
        this._maxLineWidth = 0;
        this._overlayWidgetsMinWidth = 0;

        this._scrollable = new EditorScrollable(0);
        this._configureSmoothScrollDuration();

        this._scrollable.setScrollDimensions(new EditorScrollDimensions(
            layoutInfo.contentWidth,
            0,
            layoutInfo.height,
            0
        ));
        this.onDidScroll = this._scrollable.onDidScroll;
        this.onDidContentSizeChange = this._scrollable.onDidContentSizeChange;

        this._updateHeight();
    }

    public function dispose():Void {
        this._scrollable.dispose();
    }

    public function getScrollable():Scrollable {
        return this._scrollable.getScrollable();
    }

    public function onHeightMaybeChanged():Void {
        this._updateHeight();
    }

    function _configureSmoothScrollDuration():Void {
        this._scrollable.setSmoothScrollDuration(this._configuration.options.get(EditorOption.smoothScrolling) ? SMOOTH_SCROLLING_TIME : 0);
    }

    // ---- begin view event handlers

    public function onConfigurationChanged(e:ConfigurationChangedEvent):Void {
        final options = this._configuration.options;
        if (e.hasChanged(EditorOption.lineHeight)) {
            this._linesLayout.setLineHeight(options.get(EditorOption.lineHeight));
        }
        if (e.hasChanged(EditorOption.padding)) {
            final padding = options.get(EditorOption.padding);
            this._linesLayout.setPadding(padding.top, padding.bottom);
        }
        if (e.hasChanged(EditorOption.layoutInfo)) {
            final layoutInfo = options.get(EditorOption.layoutInfo);
            final width = layoutInfo.contentWidth;
            final height = layoutInfo.height;
            final scrollDimensions = this._scrollable.getScrollDimensions();
            final contentWidth = scrollDimensions.contentWidth;
            this._scrollable.setScrollDimensions(new EditorScrollDimensions(
                width,
                scrollDimensions.contentWidth,
                height,
                this._getContentHeight(width, height, contentWidth)
            ));
        } else {
            this._updateHeight();
        }
        if (e.hasChanged(EditorOption.smoothScrolling)) {
            this._configureSmoothScrollDuration();
        }
    }

    public function onFlushed(lineCount:Int):Void {
        this._linesLayout.onFlushed(lineCount);
    }

    public function onLinesDeleted(fromLineNumber:Int, toLineNumber:Int):Void {
        this._linesLayout.onLinesDeleted(fromLineNumber, toLineNumber);
    }

    public function onLinesInserted(fromLineNumber:Int, toLineNumber:Int):Void {
        this._linesLayout.onLinesInserted(fromLineNumber, toLineNumber);
    }

    // ---- end view event handlers

    function _getHorizontalScrollbarHeight(width:Float, scrollWidth:Float):Float {
        final options = this._configuration.options;
        final scrollbar = options.get(EditorOption.scrollbar);
        if (scrollbar.horizontal == ScrollbarVisibility.Hidden) {
            // horizontal scrollbar not visible
            return 0;
        }
        if (width >= scrollWidth) {
            // horizontal scrollbar not visible
            return 0;
        }
        return scrollbar.horizontalScrollbarSize;
    }

    function _getContentHeight(width:Float, height:Float, contentWidth:Float):Float {
        final options = this._configuration.options;

        var result = this._linesLayout.getLinesTotalHeight();
        if (options.get(EditorOption.scrollBeyondLastLine)) {
            result += Math.max(0, height - options.get(EditorOption.lineHeight) - options.get(EditorOption.padding).bottom);
        } else if (!options.get(EditorOption.scrollbar).ignoreHorizontalScrollbarInContentHeight) {
            result += this._getHorizontalScrollbarHeight(width, contentWidth);
        }

        return result;
    }

    function _updateHeight():Void {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        final width = scrollDimensions.width;
        final height = scrollDimensions.height;
        final contentWidth = scrollDimensions.contentWidth;
        this._scrollable.setScrollDimensions(new EditorScrollDimensions(
            width,
            scrollDimensions.contentWidth,
            height,
            this._getContentHeight(width, height, contentWidth)
        ));
    }

    // ---- Layouting logic

    public function getCurrentViewport():Viewport {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        final currentScrollPosition = this._scrollable.getCurrentScrollPosition();
        return new Viewport(
            currentScrollPosition.scrollTop,
            currentScrollPosition.scrollLeft,
            scrollDimensions.width,
            scrollDimensions.height
        );
    }

    public function getFutureViewport():Viewport {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        final currentScrollPosition = this._scrollable.getFutureScrollPosition();
        return new Viewport(
            currentScrollPosition.scrollTop,
            currentScrollPosition.scrollLeft,
            scrollDimensions.width,
            scrollDimensions.height
        );
    }

    function _computeContentWidth():Float {
        final options = this._configuration.options;
        final maxLineWidth = this._maxLineWidth;
        final wrappingInfo = options.get(EditorOption.wrappingInfo);
        final fontInfo = options.get(EditorOption.fontInfo);
        final layoutInfo = options.get(EditorOption.layoutInfo);
        if (wrappingInfo.isViewportWrapping) {
            // Cityscape has no minimap: Monaco's minimap case does not apply
            return maxLineWidth;
        } else {
            final extraHorizontalSpace = options.get(EditorOption.scrollBeyondLastColumn) * fontInfo.typicalHalfwidthCharacterWidth;
            final whitespaceMinWidth = this._linesLayout.getWhitespaceMinWidth();
            return Math.max(Math.max(maxLineWidth + extraHorizontalSpace + layoutInfo.verticalScrollbarWidth, whitespaceMinWidth), this._overlayWidgetsMinWidth);
        }
    }

    public function setMaxLineWidth(maxLineWidth:Float):Void {
        this._maxLineWidth = maxLineWidth;
        this._updateContentWidth();
    }

    public function setOverlayWidgetsMinWidth(maxMinWidth:Float):Void {
        this._overlayWidgetsMinWidth = maxMinWidth;
        this._updateContentWidth();
    }

    function _updateContentWidth():Void {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        this._scrollable.setScrollDimensions(new EditorScrollDimensions(
            scrollDimensions.width,
            this._computeContentWidth(),
            scrollDimensions.height,
            scrollDimensions.contentHeight
        ));

        // The height might depend on the fact that there is a horizontal scrollbar or not
        this._updateHeight();
    }

    // ---- view state

    public function saveState():{scrollTop:Float, scrollTopWithoutViewZones:Float, scrollLeft:Float} {
        final currentScrollPosition = this._scrollable.getFutureScrollPosition();
        final scrollTop = currentScrollPosition.scrollTop;
        final firstLineNumberInViewport = this._linesLayout.getLineNumberAtOrAfterVerticalOffset(scrollTop);
        final whitespaceAboveFirstLine = this._linesLayout.getWhitespaceAccumulatedHeightBeforeLineNumber(firstLineNumberInViewport);
        return {
            scrollTop: scrollTop,
            scrollTopWithoutViewZones: scrollTop - whitespaceAboveFirstLine,
            scrollLeft: currentScrollPosition.scrollLeft
        };
    }

    // ----

    public function changeWhitespace(callback:(accessor:IWhitespaceChangeAccessor) -> Void):Bool {
        final hadAChange = this._linesLayout.changeWhitespace(callback);
        if (hadAChange) {
            this.onHeightMaybeChanged();
        }
        return hadAChange;
    }

    public function getVerticalOffsetForLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float {
        return this._linesLayout.getVerticalOffsetForLineNumber(lineNumber, includeViewZones == true);
    }

    public function getVerticalOffsetAfterLineNumber(lineNumber:Int, ?includeViewZones:Bool):Float {
        return this._linesLayout.getVerticalOffsetAfterLineNumber(lineNumber, includeViewZones == true);
    }

    public function isAfterLines(verticalOffset:Float):Bool {
        return this._linesLayout.isAfterLines(verticalOffset);
    }

    public function isInTopPadding(verticalOffset:Float):Bool {
        return this._linesLayout.isInTopPadding(verticalOffset);
    }

    public function isInBottomPadding(verticalOffset:Float):Bool {
        return this._linesLayout.isInBottomPadding(verticalOffset);
    }

    public function getLineNumberAtVerticalOffset(verticalOffset:Float):Int {
        return this._linesLayout.getLineNumberAtOrAfterVerticalOffset(verticalOffset);
    }

    public function getWhitespaceAtVerticalOffset(verticalOffset:Float):Null<IViewWhitespaceViewportData> {
        return this._linesLayout.getWhitespaceAtVerticalOffset(verticalOffset);
    }

    public function getLinesViewportData():IPartialViewLinesViewportData {
        final visibleBox = this.getCurrentViewport();
        return this._linesLayout.getLinesViewportData(visibleBox.top, visibleBox.top + visibleBox.height);
    }

    /**
     * Cityscape: the visible line numbers of `getLinesViewportData`, written
     * to `out` (no allocation).
     */
    public function getLinesViewportRange(out:LinesLayout.LinesViewportRange):Void {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        final currentScrollPosition = this._scrollable.getCurrentScrollPosition();
        final top = currentScrollPosition.scrollTop;
        this._linesLayout.getLinesViewportRange(top, top + scrollDimensions.height, out);
    }

    public function getLinesViewportDataAtScrollTop(scrollTop:Float):IPartialViewLinesViewportData {
        // do some minimal validations on scrollTop
        final scrollDimensions = this._scrollable.getScrollDimensions();
        if (scrollTop + scrollDimensions.height > scrollDimensions.scrollHeight) {
            scrollTop = scrollDimensions.scrollHeight - scrollDimensions.height;
        }
        if (scrollTop < 0) {
            scrollTop = 0;
        }
        return this._linesLayout.getLinesViewportData(scrollTop, scrollTop + scrollDimensions.height);
    }

    public function getWhitespaceViewportData():Array<IViewWhitespaceViewportData> {
        final visibleBox = this.getCurrentViewport();
        return this._linesLayout.getWhitespaceViewportData(visibleBox.top, visibleBox.top + visibleBox.height);
    }

    public function getWhitespaces():Array<IEditorWhitespace> {
        return this._linesLayout.getWhitespaces();
    }

    // ----

    public function getContentWidth():Float {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        return scrollDimensions.contentWidth;
    }

    public function getScrollWidth():Float {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        return scrollDimensions.scrollWidth;
    }

    public function getContentHeight():Float {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        return scrollDimensions.contentHeight;
    }

    public function getScrollHeight():Float {
        final scrollDimensions = this._scrollable.getScrollDimensions();
        return scrollDimensions.scrollHeight;
    }

    public function getCurrentScrollLeft():Float {
        final currentScrollPosition = this._scrollable.getCurrentScrollPosition();
        return currentScrollPosition.scrollLeft;
    }

    public function getCurrentScrollTop():Float {
        final currentScrollPosition = this._scrollable.getCurrentScrollPosition();
        return currentScrollPosition.scrollTop;
    }

    public function validateScrollPosition(scrollPosition:INewScrollPosition):IScrollPosition {
        return this._scrollable.validateScrollPosition(scrollPosition);
    }

    public function setScrollPosition(position:INewScrollPosition, type:ScrollType):Void {
        if (type == ScrollType.Immediate) {
            this._scrollable.setScrollPositionNow(position);
        } else {
            this._scrollable.setScrollPositionSmooth(position);
        }
    }

    public function hasPendingScrollAnimation():Bool {
        return this._scrollable.hasPendingScrollAnimation();
    }

    public function deltaScrollNow(deltaScrollLeft:Float, deltaScrollTop:Float):Void {
        final currentScrollPosition = this._scrollable.getCurrentScrollPosition();
        this._scrollable.setScrollPositionNow({
            scrollLeft: currentScrollPosition.scrollLeft + deltaScrollLeft,
            scrollTop: currentScrollPosition.scrollTop + deltaScrollTop
        });
    }

}
