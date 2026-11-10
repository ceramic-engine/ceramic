// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollWidget.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.base.common.Lifecycle;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions.EditorLayoutInfo;
import cityscape.common.core.Position;
import cityscape.contrib.folding.view.FoldingModel;
import cityscape.view.CityscapeView;
import cityscape.view.Codicons;
import cityscape.view.EditorBrowser;
import glaze.App;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.CursorStyle;
import glaze.Element;
import glaze.GlobalElementId;
import glaze.HitboxBehavior;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.LayoutId;
import glaze.Length;
import glaze.LinePaint;
import glaze.MouseButton;
import glaze.Point;
import glaze.Size;
import glaze.Style;
import glaze.TextAlign;
import glaze.Window;

import glaze.Prelude.*;

using glaze.LengthTools;

/*
 * Monaco's widget is a DOM overlay: a node per sticky line (its rendered
 * HTML, the line number, the folding codicon), positioned and stacked with
 * CSS. Cityscape keeps the same state (`setState`, the rendered lines, the
 * line to rebuild from) and paints the lines with Glaze
 * (`StickyScrollPaintElement`): the line's tokens and inline decorations as
 * the view renders them, the line number, the folding control, the
 * background, the bottom border and the shadow of stickyScroll.css. The
 * mouse targets of the DOM attributes (`data-sticky-line-index`...) are
 * computed from the position in the widget.
 */

class StickyScrollWidgetState {

    public final startLineNumbers:Array<Int>;
    public final endLineNumbers:Array<Int>;
    public final lastLineRelativePosition:Float;
    public final showEndForLine:Null<Int>;

    public function new(startLineNumbers:Array<Int>, endLineNumbers:Array<Int>, lastLineRelativePosition:Float, ?showEndForLine:Null<Int>) {
        this.startLineNumbers = startLineNumbers;
        this.endLineNumbers = endLineNumbers;
        this.lastLineRelativePosition = lastLineRelativePosition;
        this.showEndForLine = showEndForLine;
    }

    static function arrayEquals(a:Array<Int>, b:Array<Int>):Bool {
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    public function equals(other:Null<StickyScrollWidgetState>):Bool {
        return other != null
            && this.lastLineRelativePosition == other.lastLineRelativePosition
            && this.showEndForLine == other.showEndForLine
            && arrayEquals(this.startLineNumbers, other.startLineNumbers)
            && arrayEquals(this.endLineNumbers, other.endLineNumbers);
    }

    public static var Empty(get, never):StickyScrollWidgetState;
    static function get_Empty():StickyScrollWidgetState {
        return new StickyScrollWidgetState([], [], 0);
    }

}

class RenderedStickyLine {

    public final index:Int;
    public final lineNumber:Int;
    public final foldingIcon:Null<StickyFoldingIcon>;

    public function new(index:Int, lineNumber:Int, foldingIcon:Null<StickyFoldingIcon>) {
        this.index = index;
        this.lineNumber = lineNumber;
        this.foldingIcon = foldingIcon;
    }

}

class StickyFoldingIcon {

    public var isCollapsed:Bool;
    public var foldingStartLine:Int;
    public var foldingEndLine:Int;
    public var dimension:Float;
    public var visible:Bool = true;

    public function new(isCollapsed:Bool, foldingStartLine:Int, foldingEndLine:Int, dimension:Float) {
        this.isCollapsed = isCollapsed;
        this.foldingStartLine = foldingStartLine;
        this.foldingEndLine = foldingEndLine;
        this.dimension = dimension;
    }

    public function setVisible(visible:Bool):Void {
        this.visible = visible;
    }

}

/**
 * What the widget's DOM node under the mouse is (Monaco reads it from the
 * attributes of the node): the line index, whether it is the line content
 * or the folding icon, and the editor position in the content.
 */
class StickyScrollHit {

    public final lineIndex:Int;
    public final isInStickyLine:Bool;
    public final isInFoldingIcon:Bool;
    public final position:Null<Position>;

    public function new(lineIndex:Int, isInStickyLine:Bool, isInFoldingIcon:Bool, position:Null<Position>) {
        this.lineIndex = lineIndex;
        this.isInStickyLine = isInStickyLine;
        this.isInFoldingIcon = isInFoldingIcon;
        this.position = position;
    }

}

class StickyScrollWidget extends Disposable implements IOverlayWidget {

    public static inline final ID = 'editor.contrib.stickyScrollWidget';

    final _editor:ICodeEditor;
    final _foldingIconStore = new DisposableStore();

    var _previousState:Null<StickyScrollWidgetState> = null;
    var _lineHeight:Float;
    var _renderedStickyLines:Array<RenderedStickyLine> = [];
    var _lineNumbers:Array<Int> = [];
    var _lastLineRelativePosition:Float = 0;
    var _minContentWidthInPx:Float = 0;
    var _isOnGlyphMargin:Bool = false;

    /**
     * Monaco's `display: none` of the root node.
     */
    var _visible:Bool = false;

    /**
     * The height of the widget (the root node's style).
     */
    public var height(default, null):Float = 0;

    /**
     * The index of the line with the keyboard focus (-1: none).
     */
    public var focusedLineIndex(default, null):Int = -1;

    /**
     * The index of the line under the mouse (-1: none), for
     * `editorStickyScrollHover.background`.
     */
    public var hoveredLineIndex(default, null):Int = -1;

    /**
     * The lines rendered by the widget (its own cache, apart from the
     * visible lines of the view).
     */
    @:allow(cityscape.contrib.stickyScroll.view)
    final _renderCache:Map<Int, RenderedViewLine> = new Map();

    /**
     * Where the widget was last painted (window coordinates).
     */
    public var bounds(default, null):Null<Bounds> = null;

    /**
     * Mouse handlers of the controller (Monaco's DOM listeners of the
     * controller on the widget's node).
     */
    public var onMouseDownHandler:Null<(hit:Null<StickyScrollHit>, button:MouseButton, modifiers:glaze.Modifiers) -> Void> = null;
    public var onMouseMoveHandler:Null<(hit:Null<StickyScrollHit>, modifiers:glaze.Modifiers) -> Void> = null;
    public var onMouseLeaveHandler:Null<() -> Void> = null;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._lineHeight = editor.getOption(EditorOption.lineHeight);

        this._register(this._editor.onDidChangeConfiguration((e) -> {
            if (e.hasChanged(EditorOption.lineHeight)) {
                this._lineHeight = this._editor.getOption(EditorOption.lineHeight);
            }
        }));
        this._register(this._foldingIconStore);
    }

    public var lineNumbers(get, never):Array<Int>;
    function get_lineNumbers():Array<Int> {
        return this._lineNumbers;
    }

    public var lineNumberCount(get, never):Int;
    function get_lineNumberCount():Int {
        return this._lineNumbers.length;
    }

    public function getRenderedStickyLine(lineNumber:Int):Null<RenderedStickyLine> {
        for (stickyLine in this._renderedStickyLines) {
            if (stickyLine.lineNumber == lineNumber) {
                return stickyLine;
            }
        }
        return null;
    }

    public function getRenderedStickyLines():Array<RenderedStickyLine> {
        return this._renderedStickyLines;
    }

    public function getCurrentLines():Array<Int> {
        return this._lineNumbers;
    }

    public var lastLineRelativePosition(get, never):Float;
    inline function get_lastLineRelativePosition():Float {
        return this._lastLineRelativePosition;
    }

    public function isVisible():Bool {
        return this._visible && this._renderedStickyLines.length > 0;
    }

    public function setState(_state:Null<StickyScrollWidgetState>, foldingModel:Null<FoldingModel>, ?_rebuildFromLine:Int):Void {
        if (_rebuildFromLine == null
            && ((this._previousState == null && _state == null) || (this._previousState != null && this._previousState.equals(_state)))
        ) {
            return;
        }
        final isWidgetHeightZero = this._isWidgetHeightZero(_state);
        final state = isWidgetHeightZero ? null : _state;
        final rebuildFromLine = isWidgetHeightZero ? 0 : this._findLineToRebuildWidgetFrom(_state, _rebuildFromLine);
        this._renderRootNode(state, foldingModel, rebuildFromLine);
        this._previousState = _state;
    }

    function _isWidgetHeightZero(state:Null<StickyScrollWidgetState>):Bool {
        if (state == null) {
            return true;
        }
        final futureWidgetHeight = state.startLineNumbers.length * this._lineHeight + state.lastLineRelativePosition;
        if (futureWidgetHeight > 0) {
            this._lastLineRelativePosition = state.lastLineRelativePosition;
            final lineNumbers = state.startLineNumbers.copy();
            if (state.showEndForLine != null) {
                lineNumbers[state.showEndForLine] = state.endLineNumbers[state.showEndForLine];
            }
            this._lineNumbers = lineNumbers;
        }
        else {
            this._lastLineRelativePosition = 0;
            this._lineNumbers = [];
        }
        return futureWidgetHeight == 0;
    }

    function _findLineToRebuildWidgetFrom(state:Null<StickyScrollWidgetState>, ?_rebuildFromLine:Int):Int {
        if (state == null || this._previousState == null) {
            return 0;
        }
        if (_rebuildFromLine != null) {
            return _rebuildFromLine;
        }
        final previousState = this._previousState;
        var indexOfLinesAlreadyRendered = -1;
        for (i in 0...state.startLineNumbers.length) {
            if (previousState.startLineNumbers.indexOf(state.startLineNumbers[i]) == -1) {
                indexOfLinesAlreadyRendered = i;
                break;
            }
        }
        return (indexOfLinesAlreadyRendered == -1) ? 0 : indexOfLinesAlreadyRendered;
    }

    function _clearStickyLinesFromLine(clearFromLine:Int):Void {
        this._foldingIconStore.clear();
        // Keep the lines that need to be updated
        this._renderedStickyLines = this._renderedStickyLines.slice(0, clearFromLine);
        this._visible = false;
    }

    function _setFoldingIconsVisibility(allVisible:Bool):Void {
        for (line in this._renderedStickyLines) {
            final foldingIcon = line.foldingIcon;
            if (foldingIcon == null) {
                continue;
            }
            foldingIcon.setVisible(allVisible ? true : foldingIcon.isCollapsed);
        }
    }

    function _renderRootNode(state:Null<StickyScrollWidgetState>, foldingModel:Null<FoldingModel>, rebuildFromLine:Int):Void {
        this._clearStickyLinesFromLine(rebuildFromLine);
        if (state == null) {
            this.height = 0;
            this._changed();
            return;
        }
        // For new sticky lines
        final linesToRender = this._lineNumbers.slice(rebuildFromLine);
        for (i in 0...linesToRender.length) {
            final stickyLine = this._renderChildNode(i + rebuildFromLine, linesToRender[i], foldingModel);
            if (stickyLine == null) {
                continue;
            }
            this._renderedStickyLines.push(stickyLine);
        }

        final widgetHeight = this._lineNumbers.length * this._lineHeight + this._lastLineRelativePosition;
        this._visible = true;
        this.height = widgetHeight;
        this._changed();
    }

    /**
     * Monaco's `_setFoldingHoverListeners` (`showFoldingControls:
     * 'mouseover'`): the folding icons show while the mouse is over the line
     * numbers of the widget.
     */
    public function setMouseOverLineNumbers(isOnGlyphMargin:Bool):Void {
        final showFoldingControls:String = this._editor.getOption(EditorOption.showFoldingControls);
        if (showFoldingControls != 'mouseover' || isOnGlyphMargin == this._isOnGlyphMargin) {
            return;
        }
        this._isOnGlyphMargin = isOnGlyphMargin;
        this._setFoldingIconsVisibility(isOnGlyphMargin);
        this._changed();
    }

    function _renderChildNode(index:Int, line:Int, foldingModel:Null<FoldingModel>):Null<RenderedStickyLine> {
        final viewModel = this._editor._getViewModel();
        if (viewModel == null) {
            return null;
        }
        final foldingIcon = this._renderFoldingIconForLine(foldingModel, line);
        return new RenderedStickyLine(index, line, foldingIcon);
    }

    function _renderFoldingIconForLine(foldingModel:Null<FoldingModel>, line:Int):Null<StickyFoldingIcon> {
        final showFoldingControls:String = this._editor.getOption(EditorOption.showFoldingControls);
        if (foldingModel == null || showFoldingControls == 'never') {
            return null;
        }
        final foldingRegions = foldingModel.regions;
        final indexOfFoldingRegion = foldingRegions.findRange(line);
        if (indexOfFoldingRegion < 0) {
            return null;
        }
        final startLineNumber = foldingRegions.getStartLineNumber(indexOfFoldingRegion);
        final isFoldingScope = line == startLineNumber;
        if (!isFoldingScope) {
            return null;
        }
        final isCollapsed = foldingRegions.isCollapsed(indexOfFoldingRegion);
        final foldingIcon = new StickyFoldingIcon(isCollapsed, startLineNumber, foldingRegions.getEndLineNumber(indexOfFoldingRegion), this._lineHeight);
        foldingIcon.setVisible(this._isOnGlyphMargin ? true : (isCollapsed || showFoldingControls == 'always'));
        return foldingIcon;
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        // Monaco: TOP_CENTER with a stack ordinal; the widget places itself
        // over the whole width here
        return null;
    }

    public function getMinContentWidthInPx():Float {
        return this._minContentWidthInPx;
    }

    public function focusLineWithIndex(index:Int):Void {
        if (0 <= index && index < this._renderedStickyLines.length) {
            this.focusedLineIndex = index;
            this._changed();
        }
    }

    public function clearFocusedLine():Void {
        if (this.focusedLineIndex != -1) {
            this.focusedLineIndex = -1;
            this._changed();
        }
    }

    /**
     * The top of a rendered sticky line in the widget (Monaco's
     * `_updateTopAndZIndexOfStickyLine`).
     */
    public function topOfStickyLine(stickyLine:RenderedStickyLine):Float {
        final isLastLine = stickyLine.index == this._lineNumbers.length - 1;
        if (isLastLine) {
            return stickyLine.index * this._lineHeight + this._lastLineRelativePosition + (stickyLine.foldingIcon != null && stickyLine.foldingIcon.isCollapsed ? 1 : 0);
        }
        return stickyLine.index * this._lineHeight;
    }

    /**
     * The sticky line under a point of the widget (`localY` from its top):
     * the intermediate lines are over the last one (Monaco's z-index).
     */
    public function hitTest(localX:Float, localY:Float):Null<StickyScrollHit> {
        if (!isVisible() || localY < 0 || localY >= this.height) {
            return null;
        }
        var found:Null<RenderedStickyLine> = null;
        for (stickyLine in this._renderedStickyLines) {
            final top = topOfStickyLine(stickyLine);
            if (localY >= top && localY < top + this._lineHeight) {
                final isLastLine = stickyLine.index == this._lineNumbers.length - 1;
                if (found == null || !isLastLine) {
                    found = stickyLine;
                }
            }
        }
        if (found == null) {
            return null;
        }
        final layoutInfo:EditorLayoutInfo = this._editor.getLayoutInfo();
        final contentLeft = layoutInfo.contentLeft;
        if (localX < contentLeft) {
            // the line number node, with the folding icon floated right
            final icon = found.foldingIcon;
            final isInIcon = icon != null && localX >= contentLeft - icon.dimension;
            return new StickyScrollHit(found.index, false, isInIcon, null);
        }
        return new StickyScrollHit(found.index, true, false, this.editorPositionAt(found, localX - contentLeft));
    }

    /**
     * The editor position of a point of a sticky line's content (`x` from
     * the left of the content), like `getEditorPositionFromNode`.
     */
    function editorPositionAt(stickyLine:RenderedStickyLine, x:Float):Null<Position> {
        final rendered = this._renderedLineOf(stickyLine.lineNumber);
        if (rendered == null) {
            return null;
        }
        final scrollLeft = this._editor.getOption(EditorOption.stickyScroll).scrollWithEditor ? this._editor.getScrollLeft() : 0;
        final viewColumn = rendered.xToColumn(x + scrollLeft);
        final viewModel = this._editor._getViewModel();
        final viewLineNumber = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(stickyLine.lineNumber, 1)).lineNumber;
        final modelPosition = viewModel.coordinatesConverter.convertViewPositionToModelPosition(new Position(viewLineNumber, viewColumn));
        return new Position(stickyLine.lineNumber, modelPosition.column);
    }

    function cityscapeView():Null<CityscapeView> {
        final widget = Std.downcast(this._editor, cityscape.view.widget.codeEditor.CodeEditorWidget);
        if (widget == null) {
            return null;
        }
        return Std.downcast(widget.getView(), CityscapeView);
    }

    function _renderedLineOf(lineNumber:Int):Null<RenderedViewLine> {
        final view = cityscapeView();
        final viewModel = this._editor._getViewModel();
        if (view == null || viewModel == null) {
            return null;
        }
        final viewLineNumber = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(lineNumber, 1)).lineNumber;
        return view.renderViewLine(viewLineNumber, null, this._renderCache);
    }

    public function setHoveredLineIndex(index:Int):Void {
        if (index != this.hoveredLineIndex) {
            this.hoveredLineIndex = index;
            this._changed();
        }
    }

    /**
     * The Glaze view of the widget, created at the first render of the
     * editor and kept in its tree: a change of the widget renders it again
     * (`_changed`), not the editor.
     */
    var _viewEntity:Null<glaze.Entity<StickyScrollView>> = null;
    var _app:Null<App> = null;

    function _changed():Void {
        this._editor.layoutOverlayWidget(this);
        final v = this._viewEntity;
        if (v != null && this._app != null) {
            this._app.notify(v.entityId());
        }
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = this._viewEntity;
        if (v == null) {
            final view = cityscapeView();
            if (view == null) {
                return null;
            }
            this._app = cx;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:glaze.Context<StickyScrollView>) -> new StickyScrollView(this, view)), cx);
            this._viewEntity = v;
        }
        return v;
    }

    @:allow(cityscape.contrib.stickyScroll.view)
    function _renderView(view:CityscapeView):IntoElement {
        if (!isVisible() || this.height <= 0) {
            return div();
        }
        final layoutInfo:EditorLayoutInfo = this._editor.getLayoutInfo();
        final width = layoutInfo.width - layoutInfo.verticalScrollbarWidth;
        return div().absolute().top0().left0().w(px(width)).h(px(Math.max(0, this.height)))
            .onMouseDown(MouseButton.Left, (event, window, cx) -> this._dispatchMouseDown(event.position, MouseButton.Left, event.modifiers, cx))
            .onMouseDown(MouseButton.Right, (event, window, cx) -> this._dispatchMouseDown(event.position, MouseButton.Right, event.modifiers, cx))
            .onMouseMove((event, window, cx) -> this._dispatchMouseMove(event.position, event.modifiers))
            .onHover((hovered:Bool) -> {
                if (!hovered) {
                    this.setHoveredLineIndex(-1);
                    this.setMouseOverLineNumbers(false);
                    if (this.onMouseLeaveHandler != null) {
                        this.onMouseLeaveHandler();
                    }
                }
            })
            .child(new StickyScrollPaintElement(this, view));
    }

    override public function dispose():Void {
        cityscape.view.ViewEntities.release(this._viewEntity);
        this._viewEntity = null;
        this._app = null;
        super.dispose();
    }

    function _localPoint(position:Point):Null<Point> {
        final b = this.bounds;
        if (b == null) {
            return null;
        }
        return new Point(position.x - b.origin.x, position.y - b.origin.y);
    }

    function _dispatchMouseDown(position:Point, button:MouseButton, modifiers:glaze.Modifiers, cx:App):Void {
        final local = _localPoint(position);
        if (local == null) {
            return;
        }
        final hit = hitTest(local.x, local.y);
        // the editor under the widget does not get the click
        cx.stopPropagation();
        if (this.onMouseDownHandler != null) {
            this.onMouseDownHandler(hit, button, modifiers);
        }
    }

    function _dispatchMouseMove(position:Point, modifiers:glaze.Modifiers):Void {
        final local = _localPoint(position);
        if (local == null) {
            return;
        }
        final hit = hitTest(local.x, local.y);
        this.setHoveredLineIndex(hit != null && hit.isInStickyLine ? hit.lineIndex : -1);
        final layoutInfo:EditorLayoutInfo = this._editor.getLayoutInfo();
        this.setMouseOverLineNumbers(local.x < layoutInfo.contentLeft);
        if (this.onMouseMoveHandler != null) {
            this.onMouseMoveHandler(hit, modifiers);
        }
    }

    final _boxShadow:Array<glaze.BoxShadow> = [new glaze.BoxShadow(0, 4, new Hsla(0, 0, 0, 1)).withBlurRadius(2).withSpreadRadius(-2)];

    var _shadowBounds:Null<Bounds> = null;

    static final _noCorners = glaze.Corners.all(0);

    @:allow(cityscape.contrib.stickyScroll.view)
    function _paint(bounds:Bounds, view:CityscapeView, window:Window, cx:App):Void {
        this.bounds = bounds;
        final theme = view.theme;
        final options = this._editor.getOptions();
        final layoutInfo:EditorLayoutInfo = options.get(EditorOption.layoutInfo);
        final fontInfo = options.get(EditorOption.fontInfo);
        final lineHeight = this._lineHeight;
        final x0 = bounds.origin.x;
        final y0 = bounds.origin.y;
        final width = bounds.size.width;
        final height = this.height;
        final contentLeft = layoutInfo.contentLeft;

        var background = theme.getColor('editorStickyScroll.background');
        if (background == null) {
            background = theme.getColor('editor.background');
        }
        final hoverBackground = theme.getColor('editorStickyScrollHover.background');
        final lineNumberColor = theme.getColor('editorLineNumber.foreground');
        final border = theme.getColor('editorStickyScroll.border');
        final shadow = theme.getColor('editorStickyScroll.shadow');

        // box-shadow: editorStickyScroll.shadow 0 4px 2px -2px (under the
        // widget: the widget's background covers the rest)
        if (shadow != null && shadow.a > 0 && height > 0) {
            final boxShadow = _boxShadow[0];
            boxShadow.color = shadow;
            final previous = _shadowBounds;
            if (previous == null || previous.origin.x != x0 || previous.origin.y != y0 || previous.size.width != width || previous.size.height != height) {
                _shadowBounds = new Bounds(new Point(x0, y0), new Size(width, height));
            }
            window.paintDropShadows(_shadowBounds, _noCorners, _boxShadow);
        }

        window.pushContentMask(new ContentMask(new Bounds(new Point(x0, y0), new Size(width, Math.max(0, height)))));

        if (background != null) {
            fill2(window, x0, y0, width, height, background);
        }

        final scrollLeft = options.get(EditorOption.stickyScroll).scrollWithEditor ? this._editor.getScrollLeft() : 0;
        final textSystem = window.textSystem();
        final numberFont = view.measurements.resolveEditorFont(fontInfo.fontFamily, cityscape.view.EditorFontMeasurements.parseFontWeight(fontInfo.fontWeight), false, cityscape.view.EditorFontMeasurements.parseFontFeatureSettings(fontInfo.fontFeatureSettings));
        final lineNumbers = options.get(EditorOption.lineNumbers);
        var foldingColor = theme.getColor('editorGutter.foldingControlForeground');
        if (foldingColor == null) {
            foldingColor = new Hsla(0, 0, 0.77, 1);
        }

        // The last line first: the intermediate lines are painted over it (z-index 1)
        final order:Array<RenderedStickyLine> = [];
        final count = this._renderedStickyLines.length;
        if (count > 0) {
            final last = this._renderedStickyLines[count - 1];
            if (last.index == this._lineNumbers.length - 1) {
                order.push(last);
                for (i in 0...count - 1) {
                    order.push(this._renderedStickyLines[i]);
                }
            }
            else {
                for (l in this._renderedStickyLines) {
                    order.push(l);
                }
            }
        }

        for (stickyLine in order) {
            final top = y0 + topOfStickyLine(stickyLine);
            final highlighted = stickyLine.index == this.hoveredLineIndex || stickyLine.index == this.focusedLineIndex;
            // the line's own background (`background-color: inherit`)
            if (background != null) {
                fill2(window, x0, top, width, lineHeight, background);
            }
            if (highlighted && hoverBackground != null) {
                fill2(window, x0 + contentLeft, top, width - contentLeft, lineHeight, hoverBackground);
            }

            // content (`.sticky-line-content`), scrolled with the editor
            final rendered = this._renderedLineOf(stickyLine.lineNumber);
            if (rendered != null && rendered.layout.len > 0) {
                window.pushContentMask(new ContentMask(new Bounds(new Point(x0 + contentLeft, top), new Size(Math.max(0, width - contentLeft), lineHeight))));
                LinePaint.paintLineAligned(new Point(x0 + contentLeft - scrollLeft, top), rendered.layout, lineHeight, TextAlign.Left, rendered.layout.width, rendered.decorationRuns, null, window.textPainter(), null);
                window.popContentMask();
            }

            // line number (`.sticky-line-number-inner`, right aligned)
            var label:Null<String> = null;
            if (lineNumbers.renderType == RenderLineNumbersType.On || (lineNumbers.renderType == RenderLineNumbersType.Interval && stickyLine.lineNumber % 10 == 0)) {
                label = '' + stickyLine.lineNumber;
            }
            else if (lineNumbers.renderType == RenderLineNumbersType.Relative) {
                final position = this._editor.getPosition();
                label = '' + Std.int(Math.abs(stickyLine.lineNumber - (position != null ? position.lineNumber : 0)));
            }
            if (label != null && layoutInfo.lineNumbersWidth > 0 && lineNumberColor != null) {
                final shaped = textSystem.shapeLine(label, fontInfo.fontSize, [new glaze.TextRun(glaze.util.Utf8.byteLength(label), numberFont, lineNumberColor)]);
                final labelWidth:Float = shaped.width();
                shaped.paint(new Point(x0 + layoutInfo.lineNumbersLeft + layoutInfo.lineNumbersWidth - labelWidth, top), lineHeight, TextAlign.Left, null, window.textPainter());
            }

            // folding icon (a codicon of 16 px, floated right in a box of
            // the line height, at the top of the box: `font: 16px/1 codicon`)
            final icon = stickyLine.foldingIcon;
            if (icon != null && icon.visible) {
                final size = 16.0;
                final boxLeft = x0 + contentLeft - icon.dimension;
                Codicons.paintFoldingIcon(window, cx, boxLeft + (icon.dimension - size) / 2, top + size * Codicons.ASCENT, size, icon.isCollapsed, foldingColor);
            }
        }

        window.popContentMask();

        // border-bottom: 1px solid editorStickyScroll.border
        if (border != null && border.a > 0) {
            fill2(window, x0, y0 + height - 1, width, 1, border);
        }
    }

    static inline function fill2(window:Window, x:Float, y:Float, w:Float, h:Float, color:Hsla):Void {
        if (w > 0 && h > 0) {
            window.paintQuad(fill(new Bounds(new Point(x, y), new Size(w, h)), color));
        }
    }

}

/**
 * The Glaze view of the sticky scroll widget (an entity, rendered again when
 * the widget changes).
 */
class StickyScrollView extends glaze.Model implements glaze.Render {

    final widget:StickyScrollWidget;
    final view:CityscapeView;

    public function new(widget:StickyScrollWidget, view:CityscapeView) {
        super();
        this.widget = widget;
        this.view = view;
    }

    public function render(window:Window, cx:glaze.Context<Dynamic>):IntoElement {
        return @:privateAccess widget._renderView(view);
    }

}

/**
 * The Glaze element of the sticky scroll widget: fills its box and paints
 * the widget there.
 */
class StickyScrollPaintElement extends Element {

    final widget:StickyScrollWidget;
    final view:CityscapeView;

    public function new(widget:StickyScrollWidget, view:CityscapeView) {
        this.widget = widget;
        this.view = view;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        window.setCursorStyle(CursorStyle.Arrow, hitbox);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        @:privateAccess widget._paint(bounds, view, window, cx);
    }

}
