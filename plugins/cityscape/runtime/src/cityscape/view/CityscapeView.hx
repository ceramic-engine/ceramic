// New code for Cityscape (not a port): the state of one editor view in Glaze,
// what Monaco splits between `View` (browser/view.ts), its view parts
// (viewLines, lineNumbers, selections, viewCursors, currentLineHighlight,
// decorations, indentGuides, rulers, overviewRuler) and the mouse handler.
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.CharCode;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Strings;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.DecorationStyle;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model;
import cityscape.common.ViewEventHandler;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.config.FontInfo;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.viewLayout.LineDecorations;
import cityscape.common.viewLayout.ViewLineRenderer;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.CoreCommands.CoreCommandArgs;
import cityscape.view.CoreCommands.CoreNavigationCommands;
import cityscape.view.CoreCommands.NavigationCommandRevealType;
import cityscape.common.EditorCommon.Handler;
import cityscape.common.ModelLineProjectionData.ILineBreaksComputerFactory;
import glaze.MouseButton;
import cityscape.view.EditorBrowser;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.view.DecorationStyleResolver;
import cityscape.view.MeasuredLineBreaksComputer;
import cityscape.view.config.EditorConfiguration;
import glaze.App;
import glaze.Bounds;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.Entity;
import glaze.DecorationRun;
import glaze.Font;
import glaze.FontId;
import glaze.FontRun;
import glaze.Hsla;
import glaze.KeyDownEvent;
import glaze.LineLayout;
import glaze.Model as GlazeModel;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.ScrollEvent;
import glaze.Size;
import glaze.StrikethroughStyle;
import glaze.UTF16Selection;
import glaze.UnderlineStyle;
import glaze.Window;
import glaze.kit.base.Scrollbar.ScrollbarHandleImpl;
import glaze.util.Ref;

using glaze.ScrollDelta.ScrollDeltaTools;

/**
 * A view line rendered for Glaze: Monaco's rendering of the line (parts,
 * character mapping), the text shaped with font-only runs, and the paint
 * runs of its parts (token colors and inline decoration styles, painted
 * over the shaped layout: recoloring never shapes again, AUDIT A.1.7).
 */
class RenderedViewLine {

    public final input:RenderLineInput;
    public final runs:ViewLineRuns;
    public final output:RenderLineOutput;
    public final layout:LineLayout;
    public final offsets:LineOffsetMap;
    public final partStyles:Array<ResolvedPartStyle>;
    public final decorationRuns:Array<DecorationRun>;
    public final minColumn:Int;
    public final maxColumn:Int;
    public final fontGeneration:Int;
    public final themeVersion:Int;

    /**
     * The `CityscapeView.renderGeneration` this line was last checked
     * against (-1: one of its view events invalidated it).
     */
    public var generation:Int = -1;

    /**
     * The model line of this view line and whether the view line is its
     * first one (for the line numbers), -1 until the paint asks (the line
     * mapping does not change while the line is cached: a mapping change
     * drops the cache).
     */
    public var modelLineNumber:Int = -1;
    public var isFirstViewLine:Bool = false;

    /**
     * The x bounds of the boxes of the parts (the backgrounds), when a part
     * has a horizontal padding or a fixed width; null otherwise (the boxes
     * are the x of the part's text). Inlay hints, step 7, cs7-rest-inlay.
     */
    public var partBoxStarts:Null<Array<Float>> = null;
    public var partBoxEnds:Null<Array<Float>> = null;

    public function new(input:RenderLineInput, runs:ViewLineRuns, output:RenderLineOutput, layout:LineLayout, offsets:LineOffsetMap, partStyles:Array<ResolvedPartStyle>, decorationRuns:Array<DecorationRun>, minColumn:Int, maxColumn:Int, fontGeneration:Int, themeVersion:Int) {
        this.input = input;
        this.runs = runs;
        this.output = output;
        this.layout = layout;
        this.offsets = offsets;
        this.partStyles = partStyles;
        this.decorationRuns = decorationRuns;
        this.minColumn = minColumn;
        this.maxColumn = maxColumn;
        this.fontGeneration = fontGeneration;
        this.themeVersion = themeVersion;
    }

    /**
     * The x of a view column, from the start of the text.
     */
    public function columnToX(column:Int):Float {
        if (output.characterMapping.length == 0) {
            return 0;
        }
        var c = column;
        if (c < 1) {
            c = 1;
        }
        if (c > output.characterMapping.length) {
            c = output.characterMapping.length;
        }
        final partData = output.characterMapping.getDomPartData(c);
        final rendered = runs.renderedOffsetOf(CharacterMapping.getPartIndex(partData), CharacterMapping.getCharIndex(partData));
        return xForRenderedOffset(rendered);
    }

    /**
     * The x of a UTF-16 offset of the rendered text, like the caret
     * positions of the browser (Blink's `ShapeResult`), which Monaco reads
     * from the DOM: the x of the glyph cluster starting at the offset; inside
     * a cluster (an emoji sequence, a keycap, a ligature), the cluster's x
     * plus its advance shared evenly between the graphemes it holds, the
     * offset taken back to the start of its grapheme. So the columns inside
     * one emoji are at its left edge, like in Monaco.
     */
    function xForRenderedOffset(offset:Int):Float {
        final byte = offsets.utf16ToByte(offset);
        if (byte >= offsets.byteLength) {
            return layout.width;
        }
        var clusterIndex = -1;
        var clusterX = 0.0;
        var nextIndex = -1;
        var nextX:Float = layout.width;
        for (run in layout.runs) {
            for (glyph in run.glyphs) {
                final index = glyph.index;
                if (index <= byte) {
                    if (index != clusterIndex) {
                        clusterIndex = index;
                        clusterX = glyph.position.x;
                    }
                } else {
                    nextIndex = index;
                    nextX = glyph.position.x;
                    break;
                }
            }
            if (nextIndex != -1) {
                break;
            }
        }
        if (clusterIndex == -1) {
            return layout.xForIndex(byte);
        }
        if (clusterIndex == byte) {
            return clusterX;
        }
        // Inside a cluster: its graphemes (Monaco's rules) share its advance
        final text = runs.text;
        final start = offsets.byteToUtf16(clusterIndex);
        final end = nextIndex == -1 ? text.length : offsets.byteToUtf16(nextIndex);
        var graphemes = 0;
        var containing = 0;
        var o = start;
        while (o < end) {
            if (o <= offset) {
                containing = graphemes;
            }
            graphemes++;
            o += Std.int(Math.max(1, Strings.nextCharLength(text, o)));
        }
        if (graphemes <= 1) {
            return clusterX;
        }
        return clusterX + (nextX - clusterX) * containing / graphemes;
    }

    /**
     * Applies the horizontal padding and the fixed widths of the parts
     * (`ResolvedPartStyle.paddingLeft`, `paddingRight`, `width`) to the
     * shaped layout of a line by moving its glyphs, like CSS inline padding
     * and inline-block widths (the inlay hints' padding and spacers), and
     * sets the box bounds of the parts. Nothing changes when no part has
     * spacing. Inlay hints, step 7, cs7-rest-inlay.
     */
    public function applyHorizontalSpacing():Void {
        final count = partStyles.length;
        var any = false;
        for (style in partStyles) {
            if (style.paddingLeft != 0 || style.paddingRight != 0 || style.width >= 0) {
                any = true;
                break;
            }
        }
        if (!any) {
            return;
        }
        final starts:Array<Float> = [];
        final ends:Array<Float> = [];
        final glyphShifts:Array<Float> = [];
        final startBytes:Array<Int> = [];
        final endBytes:Array<Int> = [];
        var total = 0.0;
        for (i in 0...count) {
            final style = partStyles[i];
            final startByte = offsets.utf16ToByte(runs.partStarts[i]);
            final endByte = offsets.utf16ToByte(runs.partEnds[i]);
            final x1:Float = layout.xForIndex(startByte);
            final x2:Float = layout.xForIndex(endByte);
            final extra = style.width >= 0 ? style.width - (x2 - x1) : 0.0;
            starts.push(x1 + total);
            glyphShifts.push(total + style.paddingLeft);
            total += style.paddingLeft + style.paddingRight + extra;
            ends.push(x2 + total);
            startBytes.push(startByte);
            endBytes.push(endByte);
        }
        var p = 0;
        for (run in layout.runs) {
            for (glyph in run.glyphs) {
                final index = glyph.index;
                if (p >= count || index < startBytes[p]) {
                    p = 0;
                }
                while (p < count && index >= endBytes[p]) {
                    p++;
                }
                if (p < count && index >= startBytes[p]) {
                    final shift = glyphShifts[p];
                    if (shift != 0) {
                        glyph.position = new glaze.Point(glyph.position.x + shift, glyph.position.y);
                    }
                }
            }
        }
        layout.width = layout.width + total;
        partBoxStarts = starts;
        partBoxEnds = ends;
    }

    /**
     * The view column closest to `x` (from the start of the text).
     */
    public function xToColumn(x:Float):Int {
        if (output.characterMapping.length == 0) {
            return 1;
        }
        if (x <= 0) {
            return minColumn;
        }
        if (x >= layout.width) {
            return maxColumn;
        }
        // The closest column by the shaped x of every column (lines are short)
        var best = minColumn;
        var bestDistance = Math.POSITIVE_INFINITY;
        var column = minColumn;
        while (column <= maxColumn) {
            final cx = columnToX(column);
            final d = Math.abs(cx - x);
            if (d < bestDistance) {
                bestDistance = d;
                best = column;
            }
            if (cx > x) {
                break;
            }
            column++;
        }
        return best;
    }

}

/**
 * The Glaze view of a Cityscape editor (Monaco's `View` and its view parts,
 * the mouse handler and the text area input): it renders the view model of
 * its `CodeEditorWidget`, which holds the model, the options and the
 * editor's state, and feeds it the input. Implements the text input of
 * Glaze (IME) and the scrollbar handle of the kit.
 *
 * Keys reach the editor through its keybindings (`CityscapeEditor` binds
 * one Glaze key binding per chord, handled by `onRunKeybinding`); a key
 * without keybinding is typed when it is Enter (Monaco's textarea input).
 */
class CityscapeView extends GlazeModel implements glaze.EntityInputHandler implements ICodeEditorView {

    public final widget:CodeEditorWidget;
    public final context:Cityscape;

    /**
     * The numeric id of the editor (the owner id of its decorations).
     */
    public var editorId(get, never):Int;
    inline function get_editorId():Int {
        return widget.getNumericId();
    }

    /**
     * Shows a model (`CodeEditorWidget.setModel`).
     */
    public function setModel(model:Null<ITextModel>):Void {
        widget.setModel(model);
    }

    public var model(get, never):Null<ITextModel>;
    inline function get_model():Null<ITextModel> {
        return widget.getModel();
    }

    public var viewModel(get, never):Null<ViewModel>;
    inline function get_viewModel():Null<ViewModel> {
        return widget.getViewModel();
    }

    public var configuration(get, never):EditorConfiguration;
    inline function get_configuration():EditorConfiguration {
        return widget.getConfiguration();
    }

    /**
     * The folding of this editor (its `editor.contrib.folding` contribution).
     */
    public var foldingController(get, never):Null<cityscape.contrib.folding.view.Folding.FoldingController>;
    function get_foldingController() {
        return cityscape.contrib.folding.view.Folding.FoldingController.get(widget);
    }

    public final measurements:EditorFontMeasurements;
    public final resolver:DecorationStyleResolver;

    /**
     * The colors of the indentation and bracket pair guides.
     */
    public final guideColors:cityscape.view.viewParts.indentGuides.IndentGuides.IndentGuideColors;
    public final theme:ViewTheme;
    public final scrollHandle:CityscapeScrollHandle;
    public final focusHandle:glaze.FocusHandle;

    final app:App;
    var eventHandler:Null<CityscapeViewEventHandler> = null;
    var window:Null<Window> = null;

    /**
     * Rendered view lines, by view line number (checked with
     * `RenderLineInput.equals`, like Monaco's `ViewLine`).
     */
    var renderCache:Map<Int, RenderedViewLine> = new Map();

    /**
     * The bounds of the editor element (window coordinates) from the last
     * prepaint.
     */
    public var elementBounds(default, null):Bounds = new Bounds(new Point(0, 0), new Size(0, 0));

    /**
     * The mouse cursor over the text instead of the I-beam (null: the
     * I-beam): what Monaco's CSS `cursor` of a decoration does (a link under
     * Cmd, a clickable inlay hint part, a color swatch). Set it with
     * `EditorWidgets.setMouseCursor`.
     */
    public var mouseCursor:Null<glaze.CursorStyle> = null;

    /**
     * The widest rendered line so far (Monaco's `setMaxLineWidth`).
     */
    var maxLineWidth:Float = 0;

    // Mouse
    var mouseDown:Bool = false;
    var mouseDownCount:Int = 0;
    var mouseDownAlt:Bool = false;
    var mouseDownShift:Bool = false;

    // Clipboard: the text of the last copy and whether it came from empty
    // selections (Monaco's clipboard metadata, for `pasteOnNewLine` and the
    // multi cursor paste)
    var lastCopiedText:Null<String> = null;
    var lastCopiedIsFromEmptySelection:Bool = false;
    var lastCopiedMulticursorText:Null<Array<String>> = null;

    // Cursor blink
    public var cursorVisible(default, null):Bool = true;
    var blinkStop:Null<() -> Void> = null;

    // IME composition (model offsets)
    var markedRange:Null<glaze.Range> = null;

    // Keys: the chord of a keybinding that did not handle its key, whose key
    // down event already reached the editor's listeners
    var keyDownFiredFor:Null<String> = null;

    var lastTextFocus:Bool = false;
    var lastWidgetFocus:Bool = false;

    public function new(cx:Context<CityscapeView>, widget:CodeEditorWidget, measurements:EditorFontMeasurements) {
        super();
        this.app = cx.app;
        this.widget = widget;
        this.context = widget.context;
        this.theme = new ViewTheme(context.themeService, context.tokenizationRegistry);
        this.measurements = measurements;
        this.resolver = new DecorationStyleResolver(theme, context.decorationStyles);
        this.guideColors = new cityscape.view.viewParts.indentGuides.IndentGuides.IndentGuideColors(theme);
        this.scrollHandle = new CityscapeScrollHandle(this);
        this.focusHandle = cx.app.focusHandle();
        widget.setView(this);
        #if cityscape_debug_counters
        cityscape.base.common.DebugCounters.views++;
        #end
    }

    function notifyChanged():Void {
        app.notify(entityId);
        final paint = paintView;
        if (paint != null) {
            app.notify(paint.entityId());
        }
        // The view rendering the `CityscapeEditor` component draws from this
        // view too (the scrollbar from its scroll state, the overlay
        // widgets): it renders with the paint view (Glaze renders a dirty
        // view alone, without its ancestors, when its bounds do not change)
        if (hostViewId != -1) {
            app.notify(hostViewId);
        }
    }

    /**
     * The Glaze view painting this editor view (its `CityscapeViewElement`):
     * `notifyChanged` marks it dirty, so a window caching its views paints
     * the editor again (a model only read by an element of a cached view
     * would not make that view render again).
     */
    public var paintView(default, null):Null<Entity<CityscapePaintView>> = null;

    /**
     * Creates `paintView` (once; `view` is this view's entity).
     */
    public function ensurePaintView(view:Entity<CityscapeView>, cx:App):Entity<CityscapePaintView> {
        var paint = paintView;
        if (paint == null) {
            paint = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((_:Context<CityscapePaintView>) -> new CityscapePaintView(view)), cx);
            paintView = paint;
        }
        return paint;
    }

    /**
     * Releases the timers and the theme listener (the component calls it
     * when it leaves the tree, before disposing the widget).
     */
    #if cityscape_debug_counters
    var viewDisposed = false;
    #end

    public function disposeView():Void {
        #if cityscape_debug_counters
        if (!viewDisposed) {
            viewDisposed = true;
            cityscape.base.common.DebugCounters.views--;
        }
        #end
        widget.setView(null);
        final viewModel = this.viewModel;
        if (viewModel != null && eventHandler != null) {
            viewModel.removeViewEventHandler(eventHandler);
        }
        eventHandler = null;
        theme.dispose();
        stopBlink();
        ViewEntities.release(paintView);
        paintView = null;
    }

    //#region ICodeEditorView

    public function createDomLineBreaksComputerFactory():Null<ILineBreaksComputerFactory> {
        return new MeasuredLineBreaksComputerFactory(new ViewLineMeasurer(this));
    }

    public function onDidAttachModel(viewModel:ViewModel):Void {
        final handler = new CityscapeViewEventHandler(this);
        this.eventHandler = handler;
        viewModel.addViewEventHandler(handler);
        resetRenderCache();
        maxLineWidth = 0;
        lastVisibleStart = -1;
        lastVisibleEnd = -1;
        viewModel.setHasFocus(lastTextFocus);
        notifyChanged();
    }

    public function onWillDetachModel(viewModel:ViewModel):Void {
        if (eventHandler != null) {
            viewModel.removeViewEventHandler(eventHandler);
        }
        eventHandler = null;
        resetRenderCache();
        notifyChanged();
    }

    public function focus():Void {
        final w = this.window;
        if (w != null) {
            focusHandle.focus(w, app);
            syncFocus(w, app);
        }
    }

    public function isFocused():Bool {
        final w = this.window;
        return w != null && focusHandle.isFocused(w);
    }

    public function hasWidgetFocus():Bool {
        final w = this.window;
        return w != null && focusHandle.containsFocused(w, app);
    }

    public function render(forceRedraw:Bool):Void {
        if (forceRedraw) {
            resetRenderCache();
        }
        notifyChanged();
    }

    public function clipboardAction(action:String):Void {
        switch (action) {
            case 'copy':
                copySelection(app);
            case 'cut':
                copySelection(app);
                if (viewModel != null) {
                    widget.trigger('keyboard', Handler.Cut, null);
                }
            case 'paste':
                final item = app.readFromClipboard();
                final text = item != null ? item.text() : null;
                if (text != null) {
                    pasteText(text);
                }
            case _:
        }
        restartBlink();
        notifyChanged();
    }

    /**
     * The view rendering the `CityscapeEditor` component of this view (-1
     * before its first render), notified when the overlay widgets change:
     * the component lists them in its render.
     */
    public var hostViewId:Int = -1;

    public function overlayWidgetsChanged():Void {
        // The host lists them (`notifyChanged` notifies it)
        notifyChanged();
    }

    public function getOffsetForColumn(modelLineNumber:Int, modelColumn:Int):Float {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return -1;
        }
        // Monaco's View.getOffsetForColumn: the position is validated first
        // (a column inside a surrogate pair goes to the start of the pair)
        final modelPosition = viewModel.model.validatePosition({lineNumber: modelLineNumber, column: modelColumn});
        final viewPosition = viewModel.coordinatesConverter.convertModelPositionToViewPosition(modelPosition);
        return renderViewLine(viewPosition.lineNumber).columnToX(viewPosition.column);
    }

    public function getScrolledVisiblePosition(modelPosition:Position):Null<{top:Float, left:Float, height:Float}> {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return null;
        }
        final viewPosition = viewModel.coordinatesConverter.convertModelPositionToViewPosition(modelPosition);
        final layout = viewModel.viewLayout;
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final x = renderViewLine(viewPosition.lineNumber).columnToX(viewPosition.column);
        return {
            top: layout.getVerticalOffsetForLineNumber(viewPosition.lineNumber) - layout.getCurrentScrollTop(),
            left: layoutInfo.contentLeft + x - layout.getCurrentScrollLeft(),
            height: configuration.options.get(EditorOption.lineHeight)
        };
    }

    /**
     * The mouse target under a window point (`mouseTargetAt`).
     */
    public function getTargetAtClientPoint(clientX:Float, clientY:Float):Null<MouseTarget> {
        if (viewModel == null) {
            return null;
        }
        return mouseTargetAt(new Point(clientX, clientY));
    }

    /**
     * Monaco's mouse target (`MouseTargetFactory`, in model coordinates like
     * the targets of the editor's mouse events): the margin parts, the text,
     * or the empty content after a line or after the lines.
     */
    /**
     * Monaco's `HitTestContext.getZoneAtCoord` and `_hitTestViewZone`: the
     * view zone at a vertical offset, with the positions before and after
     * it (in model coordinates), or null.
     */
    function hitTestViewZone(mouseVerticalOffset:Float, isInContentArea:Bool, mouseColumn:Int):Null<MouseTarget> {
        final viewModel = this.viewModel;
        final viewZoneWhitespace = viewModel.viewLayout.getWhitespaceAtVerticalOffset(mouseVerticalOffset);
        if (viewZoneWhitespace == null) {
            return null;
        }
        final converter = viewModel.coordinatesConverter;
        final viewZoneMiddle = viewZoneWhitespace.verticalOffset + viewZoneWhitespace.height / 2;
        final lineCount = viewModel.getLineCount();
        var positionBefore:Null<Position> = null;
        var position:Null<Position>;
        var positionAfter:Null<Position> = null;

        if (viewZoneWhitespace.afterLineNumber != lineCount) {
            // There are more lines after this view zone
            positionAfter = converter.convertViewPositionToModelPosition(new Position(viewZoneWhitespace.afterLineNumber + 1, 1));
        }
        if (viewZoneWhitespace.afterLineNumber > 0) {
            // There are more lines above this view zone
            positionBefore = converter.convertViewPositionToModelPosition(new Position(viewZoneWhitespace.afterLineNumber, viewModel.getLineMaxColumn(viewZoneWhitespace.afterLineNumber)));
        }

        if (positionAfter == null) {
            position = positionBefore;
        }
        else if (positionBefore == null) {
            position = positionAfter;
        }
        else if (mouseVerticalOffset < viewZoneMiddle) {
            position = positionBefore;
        }
        else {
            position = positionAfter;
        }
        final target = new MouseTarget(isInContentArea ? MouseTargetType.CONTENT_VIEW_ZONE : MouseTargetType.GUTTER_VIEW_ZONE, position, mouseColumn, position != null ? Range.fromPositions(position, position) : null);
        target.viewZoneOffsetY = mouseVerticalOffset - viewZoneWhitespace.verticalOffset;
        target.viewZoneData = {
            viewZoneId: viewZoneWhitespace.id,
            afterLineNumber: viewZoneWhitespace.afterLineNumber,
            positionBefore: positionBefore,
            positionAfter: positionAfter,
            position: position
        };
        return target;
    }

    public function mouseTargetAt(point:Point):MouseTarget {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return new MouseTarget(MouseTargetType.UNKNOWN, null, 0, null);
        }
        final converter = viewModel.coordinatesConverter;
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final layout = viewModel.viewLayout;
        final relativeX = point.x - elementBounds.origin.x;
        final relativeY = point.y - elementBounds.origin.y;
        final verticalOffset = relativeY + layout.getCurrentScrollTop();
        final mouseColumn = mouseColumnAt(point);
        if (relativeX < 0 || relativeY < 0 || relativeX > elementBounds.size.width || relativeY > elementBounds.size.height) {
            return new MouseTarget(MouseTargetType.OUTSIDE_EDITOR, null, mouseColumn, null);
        }
        // The overview ruler beside the scrollbar (Cityscape's
        // `overviewRulerPosition: 'beside'`): like Monaco's ruler, a child of
        // the scrollable element, `_hitTestScrollbar` (the kit scrollbar
        // takes its own column)
        final rulerRight = cityscape.common.config.EditorViewOptions.OverviewRulerPlacement.right(configuration.options);
        if (rulerRight > 0) {
            final rulerLeft = elementBounds.size.width - rulerRight - layoutInfo.overviewRuler.width;
            if (relativeX >= rulerLeft && relativeX < rulerLeft + layoutInfo.overviewRuler.width) {
                final possibleLineNumber = layout.getLineNumberAtVerticalOffset(verticalOffset);
                final position = converter.convertViewPositionToModelPosition(new Position(possibleLineNumber, viewModel.getLineMaxColumn(possibleLineNumber)));
                return new MouseTarget(MouseTargetType.SCROLLBAR, position, mouseColumn, Range.fromPositions(position, position));
            }
        }
        // _hitTestViewZone
        final zoneTarget = hitTestViewZone(verticalOffset, relativeX >= layoutInfo.contentLeft, mouseColumn);
        if (zoneTarget != null) {
            return zoneTarget;
        }
        if (relativeX < layoutInfo.contentLeft) {
            // _hitTestMargin: the full line range at the mouse
            var lineNumber:Int;
            var range:Range;
            var isAfterLines = false;
            if (layout.isAfterLines(verticalOffset)) {
                lineNumber = viewModel.getLineCount();
                final maxColumn = viewModel.getLineMaxColumn(lineNumber);
                range = new Range(lineNumber, maxColumn, lineNumber, maxColumn);
                isAfterLines = true;
            }
            else {
                lineNumber = layout.getLineNumberAtVerticalOffset(verticalOffset);
                range = new Range(lineNumber, 1, lineNumber, viewModel.getLineMaxColumn(lineNumber));
            }
            final modelRange = converter.convertViewRangeToModelRange(range);
            final position = modelRange.getStartPosition();
            var offset = Math.abs(relativeX);
            final offsetX = offset;
            offset -= layoutInfo.glyphMarginLeft;
            var type:MouseTargetType;
            var elementLeft:Float;
            if (offset <= layoutInfo.glyphMarginWidth) {
                type = MouseTargetType.GUTTER_GLYPH_MARGIN;
                elementLeft = layoutInfo.glyphMarginLeft;
            }
            else {
                offset -= layoutInfo.glyphMarginWidth;
                if (offset <= layoutInfo.lineNumbersWidth) {
                    type = MouseTargetType.GUTTER_LINE_NUMBERS;
                    elementLeft = layoutInfo.lineNumbersLeft;
                }
                else {
                    type = MouseTargetType.GUTTER_LINE_DECORATIONS;
                    elementLeft = layoutInfo.decorationsLeft;
                }
            }
            return new MouseTarget(type, position, mouseColumn, modelRange, elementLeft, offsetX, isAfterLines);
        }
        // _hitTestViewLines
        if (layout.isInTopPadding(verticalOffset)) {
            return new MouseTarget(MouseTargetType.CONTENT_EMPTY, new Position(1, 1), mouseColumn, new Range(1, 1, 1, 1), 0, 0, true);
        }
        if (layout.isAfterLines(verticalOffset) || layout.isInBottomPadding(verticalOffset)) {
            final lineCount = viewModel.getLineCount();
            final position = converter.convertViewPositionToModelPosition(new Position(lineCount, viewModel.getLineMaxColumn(lineCount)));
            return new MouseTarget(MouseTargetType.CONTENT_EMPTY, position, mouseColumn, Range.fromPositions(position, position), 0, 0, true);
        }
        final lineNumber = layout.getLineNumberAtVerticalOffset(verticalOffset);
        final line = renderViewLine(lineNumber);
        final contentX:Float = relativeX - layoutInfo.contentLeft + layout.getCurrentScrollLeft();
        // The `⋯` after a folded line is part of the line (a CSS `::after`
        // in Monaco)
        final lineWidth:Float = line.layout.width + foldedEllipsisWidth(line);
        if (viewModel.getLineLength(lineNumber) == 0 || contentX >= lineWidth) {
            final viewColumn = viewModel.getLineLength(lineNumber) == 0 ? 1 : viewModel.getLineMaxColumn(lineNumber);
            final position = converter.convertViewPositionToModelPosition(new Position(lineNumber, viewColumn));
            return new MouseTarget(MouseTargetType.CONTENT_EMPTY, position, mouseColumn, Range.fromPositions(position, position), 0, 0, false, contentX - lineWidth);
        }
        final viewPosition = new Position(lineNumber, contentX >= line.layout.width ? viewModel.getLineMaxColumn(lineNumber) : line.xToColumn(contentX));
        final position = converter.convertViewPositionToModelPosition(viewPosition);
        final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, position, mouseColumn, Range.fromPositions(position, position));
        // HitTestContext.doHitTest: the injected text at the hit position
        target.injectedText = viewModel.getInjectedTextAt(viewPosition);
        return target;
    }

    /**
     * The width of the `⋯` drawn after a folded line (0 when the line has
     * no `inline-folded` part).
     */
    public function foldedEllipsisWidth(line:RenderedViewLine):Float {
        if (!lineHasFoldedEllipsis(line)) {
            return 0;
        }
        // folding.css: `content: "\22EF"` with `margin: 0.1em 0.2em 0 0.2em`
        return fontInfo().fontSize * 0.4 + foldedEllipsisLayout().width;
    }

    static inline final FOLDED_ELLIPSIS = '\u22EF';

    var _ellipsisLayout:Null<LineLayout> = null;
    var _ellipsisKey:String = '';

    /**
     * The shaped `⋯` of folding.css's `.inline-folded:after`, in the editor
     * font (cached while the fonts stay the same).
     */
    public function foldedEllipsisLayout():LineLayout {
        final info = fontInfo();
        final textSystem = app.textSystem();
        final fontId = textSystem.resolveFont(baseFont(null, false, null));
        final key = textSystem.fontGeneration + '|' + info.fontSize + '|' + fontId;
        if (_ellipsisLayout == null || _ellipsisKey != key) {
            _ellipsisKey = key;
            _ellipsisLayout = textSystem.platformTextSystem.layoutLine(FOLDED_ELLIPSIS, info.fontSize, [new FontRun(glaze.util.Utf8.byteLength(FOLDED_ELLIPSIS), fontId)]);
        }
        return _ellipsisLayout;
    }

    public static function lineHasFoldedEllipsis(line:RenderedViewLine):Bool {
        final names = line.runs.partClassNames;
        for (i in 0...names.length) {
            if (names[i].indexOf('inline-folded') != -1) {
                return true;
            }
        }
        return false;
    }

    //#endregion

    /**
     * Reads the focus of the editor (its text, its widgets) and tells the
     * widget when it changed (Monaco's focus tracker and the textarea's
     * focus events).
     */
    public function syncFocus(window:Window, cx:App):Void {
        this.window = window;
        final textFocus = focusHandle.isFocused(window);
        final widgetFocus = textFocus || focusHandle.containsFocused(window, cx);
        if (widgetFocus != lastWidgetFocus) {
            lastWidgetFocus = widgetFocus;
            widget._setWidgetFocus(widgetFocus);
        }
        if (textFocus != lastTextFocus) {
            lastTextFocus = textFocus;
            final viewModel = this.viewModel;
            if (viewModel != null) {
                viewModel.setHasFocus(textFocus);
            }
            if (textFocus) {
                restartBlink();
            }
            else {
                stopBlink();
                cursorVisible = true;
            }
        }
    }

    var lastVisibleStart:Int = -1;
    var lastVisibleEnd:Int = -1;

    /**
     * Called by the element after it laid out the visible view lines: when
     * they changed, the model tokenizes them first (Monaco calls
     * `visibleLinesStabilized` once the view rendered).
     */
    public function visibleLinesRendered(startLineNumber:Int, endLineNumber:Int):Void {
        final viewModel = this.viewModel;
        if (viewModel == null || (startLineNumber == lastVisibleStart && endLineNumber == lastVisibleEnd)) {
            return;
        }
        lastVisibleStart = startLineNumber;
        lastVisibleEnd = endLineNumber;
        viewModel.visibleLinesStabilized();
    }

    public function updateOptions(options:IEditorOptions):Void {
        widget.updateOptions(options);
        resetRenderCache();
        notifyChanged();
    }

    public function setWrappingIndentColumns(value:Int):Void {
        if (widget.getWrappingIndentColumns() == value) {
            return;
        }
        widget.setWrappingIndentColumns(value);
        resetRenderCache();
        notifyChanged();
    }

    @:allow(cityscape.view.CityscapeViewEventHandler)
    function onViewEvents(flush:Bool, flushed:Bool = false):Void {
        if (flush) {
            resetRenderCache();
        }
        if (flushed) {
            // viewLines.ts `onFlushed`: the widest line is measured again
            // (the scroll width follows the new text)
            maxLineWidth = 0;
        }
        notifyChanged();
    }

    @:allow(cityscape.view.CityscapeViewEventHandler)
    function onRevealRange(e:ViewRevealRangeRequestEvent):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final range:Null<Range> = e.range != null ? e.range : (e.selections != null && e.selections.length > 0 ? e.selections[0] : null);
        if (range == null) {
            return;
        }
        final layout = viewModel.viewLayout;
        final lineHeight = configuration.options.get(EditorOption.lineHeight);
        final viewport = layout.getCurrentViewport();
        final top = layout.getVerticalOffsetForLineNumber(range.startLineNumber);
        final bottom = layout.getVerticalOffsetForLineNumber(range.endLineNumber) + lineHeight;
        var scrollTop = viewport.top;
        switch (e.verticalType) {
            case VerticalRevealType.Center | VerticalRevealType.CenterIfOutsideViewport:
                if (e.verticalType == VerticalRevealType.Center || top < viewport.top || bottom > viewport.top + viewport.height) {
                    scrollTop = Std.int((top + bottom) / 2 - viewport.height / 2);
                }
            case VerticalRevealType.Top:
                scrollTop = Std.int(top);
            case VerticalRevealType.Bottom:
                scrollTop = Std.int(bottom - viewport.height);
            case VerticalRevealType.NearTop | VerticalRevealType.NearTopIfOutsideViewport:
                if (e.verticalType == VerticalRevealType.NearTop || top < viewport.top || bottom > viewport.top + viewport.height) {
                    // Monaco: 5 lines of context above
                    scrollTop = Std.int(Math.max(0, top - 5 * lineHeight));
                }
            case _:
                if (top < viewport.top) {
                    scrollTop = Std.int(top);
                } else if (bottom > viewport.top + viewport.height) {
                    scrollTop = Std.int(bottom - viewport.height);
                }
        }
        var scrollLeft:Float = viewport.left;
        if (e.revealHorizontal && range.startLineNumber == range.endLineNumber) {
            final line = renderViewLine(range.startLineNumber);
            final x = line.columnToX(range.startColumn);
            final contentWidth = configuration.options.get(EditorOption.layoutInfo).contentWidth;
            final margin = 4 * configuration.options.get(EditorOption.fontInfo).typicalHalfwidthCharacterWidth;
            if (x < viewport.left) {
                scrollLeft = Math.max(0, x - margin);
            } else if (x > viewport.left + contentWidth - margin) {
                scrollLeft = x - contentWidth + margin;
            }
        }
        layout.setScrollPosition({scrollTop: scrollTop, scrollLeft: scrollLeft}, ScrollType.Immediate);
    }

    //#region layout and rendering

    /**
     * Called by the element at prepaint with its bounds (window coordinates).
     */
    public function layoutTo(bounds:Bounds, scaleFactor:Float, ?window:Window):Void {
        elementBounds = bounds;
        if (window != null) {
            this.window = window;
        }
        if (configuration.pixelRatio != scaleFactor) {
            configuration.pixelRatio = scaleFactor;
            configuration.recomputeOptions();
        }
        configuration.observeContainer({width: bounds.size.width, height: bounds.size.height});
    }

    public inline function fontInfo():FontInfo {
        return configuration.options.get(EditorOption.fontInfo);
    }

    // `baseFont` results, by font info, weight, style and features
    var baseFontInfo:Null<FontInfo> = null;
    var baseFontGeneration:Int = -1;
    var baseFontColorEmoji:Bool = true;
    final baseFontWeights:Array<Float> = [];
    final baseFontItalics:Array<Bool> = [];
    final baseFontFeatures:Array<Null<String>> = [];
    final baseFonts:Array<Font> = [];

    // public for the additional lines of the ghost text (inline completions, cs7-rest-inline)
    public function baseFont(weight:Null<Float>, italic:Bool, features:Null<String>):Font {
        final info = fontInfo();
        // the resolved fonts change with the fonts added (`resolveEditorFont`)
        final generation = app.textSystem().fontGeneration;
        final colorEmoji = preferColorEmoji();
        if (info != baseFontInfo || generation != baseFontGeneration || colorEmoji != baseFontColorEmoji || baseFonts.length >= 32) {
            baseFontInfo = info;
            baseFontGeneration = generation;
            baseFontColorEmoji = colorEmoji;
            baseFontWeights.resize(0);
            baseFontItalics.resize(0);
            baseFontFeatures.resize(0);
            baseFonts.resize(0);
        }
        // NaN for no weight (the font info's)
        final w:Float = weight != null ? weight : Math.NaN;
        for (i in 0...baseFonts.length) {
            final cachedWeight = baseFontWeights[i];
            if ((cachedWeight == w || (Math.isNaN(cachedWeight) && Math.isNaN(w))) && baseFontItalics[i] == italic && baseFontFeatures[i] == features) {
                return baseFonts[i];
            }
        }
        final font = resolveBaseFont(info, weight, italic, features);
        baseFontWeights.push(w);
        baseFontItalics.push(italic);
        baseFontFeatures.push(features);
        baseFonts.push(font);
        return font;
    }

    function resolveBaseFont(info:FontInfo, weight:Null<Float>, italic:Bool, features:Null<String>):Font {
        final w = weight != null ? weight : EditorFontMeasurements.parseFontWeight(info.fontWeight);
        final f = EditorFontMeasurements.parseFontFeatureSettings(features != null ? features : info.fontFeatureSettings);
        return measurements.resolveEditorFont(info.fontFamily, w, italic, f, preferColorEmoji());
    }

    /** The `preferColorEmoji` option (Cityscape addition) */
    public function preferColorEmoji():Bool {
        return configuration.options.get(EditorOption.preferColorEmoji);
    }

    /**
     * Monaco's `ViewLine` input: the rendering data of a view line, its
     * inline decorations (typed styles given synthetic class names) and the
     * whitespace options.
     */
    function createRenderLineInput(viewLineNumber:Int, visibleRange:Null<Range>):{input:RenderLineInput, minColumn:Int, maxColumn:Int} {
        final viewModel = this.viewModel;
        final options = configuration.options;
        final data = visibleRange != null ? viewModel.getViewportViewLineRenderingData(visibleRange, viewLineNumber) : viewModel.getViewLineRenderingData(viewLineNumber);
        final info = fontInfo();
        var lineDecorations = LineDecoration.filter(data.inlineDecorations, viewLineNumber, data.minColumn, data.maxColumn);
        lineDecorations = [for (d in lineDecorations) {
            if (d.style != null) {
                final synthetic = resolver.classNameOfStyle(d.style);
                new LineDecoration(d.startColumn, d.endColumn, d.className.length > 0 ? d.className + ' ' + synthetic : synthetic, d.type, null);
            } else {
                d;
            }
        }];
        var renderWhitespace = options.get(EditorOption.renderWhitespace);
        var selectionsOnLine:Null<Array<LineRange>> = null;
        if (renderWhitespace == 'selection') {
            selectionsOnLine = [];
            for (s in viewSelections()) {
                if (s.isEmpty() || s.endLineNumber < viewLineNumber || s.startLineNumber > viewLineNumber) {
                    continue;
                }
                final start = (s.startLineNumber == viewLineNumber ? s.startColumn : data.minColumn);
                final end = (s.endLineNumber == viewLineNumber ? s.endColumn : data.maxColumn);
                if (start < end) {
                    selectionsOnLine.push(new LineRange(start - 1, end - 1));
                }
            }
            if (selectionsOnLine.length == 0) {
                selectionsOnLine = null;
            }
            else {
                // its input changes when the selections change
                selectionInputLines.push(viewLineNumber);
            }
        }
        final input = new RenderLineInput(
            info.isMonospace && !options.get(EditorOption.disableMonospaceOptimizations),
            info.canUseHalfwidthRightwardsArrow,
            data.content,
            data.continuesWithWrappedLine,
            data.isBasicASCII,
            data.containsRTL,
            data.minColumn - 1,
            data.tokens,
            lineDecorations,
            data.tabSize,
            data.startVisibleColumn,
            info.spaceWidth,
            info.middotWidth,
            info.wsmiddotWidth,
            options.get(EditorOption.stopRenderingLineAfter),
            renderWhitespace,
            options.get(EditorOption.renderControlCharacters),
            info.fontFeatureSettings != '"liga" off, "calt" off',
            selectionsOnLine
        );
        return {input: input, minColumn: data.minColumn, maxColumn: data.maxColumn};
    }

    /**
     * The rendered view line `viewLineNumber` (cached while its rendering
     * input, the fonts and the theme stay the same). `cache` replaces the
     * cache of the visible lines (the sticky scroll keeps its own lines).
     */
    public function renderViewLine(viewLineNumber:Int, ?visibleRange:Range, ?cache:Map<Int, RenderedViewLine>):RenderedViewLine {
        final renderCache = cache != null ? cache : this.renderCache;
        if (cache != null && extraRenderCaches.indexOf(cache) == -1) {
            extraRenderCaches.push(cache);
        }
        final fontGeneration = app.textSystem().fontGeneration;
        final cached = renderCache.get(viewLineNumber);
        final current = cached != null && cached.fontGeneration == fontGeneration && cached.themeVersion == theme.version;
        // No view event touched the line since it was checked (Monaco's
        // `ViewLine` renders again only the lines its events invalidated):
        // its rendering input is the same, not built again
        if (current && cached.generation == renderGeneration && !checkRenderCache) {
            return cached;
        }
        final created = createRenderLineInput(viewLineNumber, visibleRange);
        final input = created.input;
        if (current && cached.input.equals(input)) {
            cached.generation = renderGeneration;
            return cached;
        }
        if (current && cached.generation == renderGeneration) {
            // `checkRenderCache`: the line was taken as unchanged, wrongly
            renderCacheErrors++;
        }

        final runs = new ViewLineRuns();
        final output = ViewLineRenderer.renderViewLineTo(input, runs);
        final text = runs.text;
        final offsets = new LineOffsetMap();
        offsets.reset(text);

        // Font-only runs: one per font (weight, style, features)
        final partStyles:Array<ResolvedPartStyle> = [];
        final fontRuns:Array<FontRun> = [];
        final decorationRuns:Array<DecorationRun> = [];
        final textSystem = app.textSystem();
        var lastFontId:Null<FontId> = null;
        var lastFontRunStart = 0;
        final info = fontInfo();
        for (i in 0...runs.partStarts.length) {
            final style = resolver.resolve(runs.partClassNames[i]);
            partStyles.push(style);
            final startByte = offsets.utf16ToByte(runs.partStarts[i]);
            final endByte = offsets.utf16ToByte(runs.partEnds[i]);
            final len = endByte - startByte;
            if (len <= 0) {
                continue;
            }
            final fontId = textSystem.resolveFont(baseFont(style.fontWeight, style.italic, style.fontFeatures));
            if (lastFontId == null || fontId != lastFontId) {
                if (lastFontId != null) {
                    fontRuns.push(new FontRun(startByte - lastFontRunStart, lastFontId));
                }
                lastFontId = fontId;
                lastFontRunStart = startByte;
            }
            var color = style.color;
            if (style.opacity < 1) {
                color = color.opacity(style.opacity);
            }
            final underline = style.underlineThickness > 0 ? new UnderlineStyle(style.underlineThickness, style.underlineColor != null ? style.underlineColor : color, style.underlineWavy) : null;
            final strikethrough = style.strikethroughThickness > 0 ? new StrikethroughStyle(style.strikethroughThickness, style.strikethroughColor != null ? style.strikethroughColor : color) : null;
            decorationRuns.push(new DecorationRun(len, color, null, underline, strikethrough));
        }
        if (lastFontId != null) {
            fontRuns.push(new FontRun(offsets.byteLength - lastFontRunStart, lastFontId));
        }

        final layout = (text.length == 0 || fontRuns.length == 0)
            ? new LineLayout(info.fontSize, 0, 0, 0, [], 0)
            : textSystem.platformTextSystem.layoutLine(text, info.fontSize, fontRuns);

        final rendered = new RenderedViewLine(input, runs, output, layout, offsets, partStyles, decorationRuns, created.minColumn, created.maxColumn, fontGeneration, theme.version);
        rendered.generation = renderGeneration;
        if (cache == null && cached == null) {
            renderCacheKeys.push(viewLineNumber);
        }
        // Inlay hints (step 7, cs7-rest-inlay): horizontal padding and spacers
        rendered.applyHorizontalSpacing();
        renderCache.set(viewLineNumber, rendered);
        if (layout.width > maxLineWidth) {
            maxLineWidth = layout.width;
            viewModel.viewLayout.setMaxLineWidth(maxLineWidth);
        }
        return rendered;
    }

    /**
     * Bumped by the view events that may change the rendering of any line
     * (decorations, view zones, the selections when whitespace is rendered
     * in them): the cached lines are checked again (`RenderLineInput.equals`).
     */
    var renderGeneration:Int = 0;

    /**
     * The other caches given to `renderViewLine` (the sticky scroll's), whose
     * lines the view events invalidate too.
     */
    final extraRenderCaches:Array<Map<Int, RenderedViewLine>> = [];

    /**
     * Diagnostic (tests, benchmarks): `renderViewLine` builds the rendering
     * input of every line and counts in `renderCacheErrors` the cached lines
     * taken as unchanged by the view events while their input changed.
     */
    public static var checkRenderCache:Bool = false;

    public static var renderCacheErrors:Int = 0;

    var selectionsGeneration:Int = -1;
    var selectionsValue:Null<Array<Selection>> = null;

    /**
     * `viewModel.getViewSelections()`, kept until the next view event (the
     * paint and the rendering inputs of the lines read it many times per
     * frame). Not to be modified.
     */
    public function viewSelections():Array<Selection> {
        var value = selectionsValue;
        if (value == null || selectionsGeneration != paintGeneration) {
            value = viewModel.getViewSelections();
            selectionsValue = value;
            selectionsGeneration = paintGeneration;
        }
        return value;
    }

    /**
     * The view lines whose rendering input holds selections
     * (`renderWhitespace: 'selection'`), since the last cursor change.
     */
    final selectionInputLines:Array<Int> = [];

    /**
     * A cursor change with `renderWhitespace: 'selection'`: the lines whose
     * input held selections and the lines of the new selections render again
     * (Monaco checks every line again; the others keep no selection).
     */
    @:allow(cityscape.view.CityscapeViewEventHandler)
    function invalidateSelectionLines(selections:Array<Selection>):Void {
        for (i in 0...selectionInputLines.length) {
            final ln = selectionInputLines[i];
            invalidateLines(ln, ln);
        }
        selectionInputLines.resize(0);
        for (i in 0...selections.length) {
            final s = selections[i];
            if (!s.isEmpty()) {
                invalidateLines(s.startLineNumber, s.endLineNumber);
            }
        }
    }

    @:allow(cityscape.view.CityscapeViewEventHandler)
    function invalidateAllLines():Void {
        renderGeneration++;
    }

    /**
     * Invalidates the cached view lines `[from, to]`.
     */
    @:allow(cityscape.view.CityscapeViewEventHandler)
    function invalidateLines(from:Int, to:Int):Void {
        invalidateLinesIn(renderCache, from, to);
        for (i in 0...extraRenderCaches.length) {
            invalidateLinesIn(extraRenderCaches[i], from, to);
        }
    }

    static function invalidateLinesIn(cache:Map<Int, RenderedViewLine>, from:Int, to:Int):Void {
        for (lineNumber in from...to + 1) {
            final line = cache.get(lineNumber);
            if (line != null) {
                line.generation = -1;
            }
        }
    }

    /**
     * Drops the cached lines outside `[start, end]` (called after a paint).
     */
    public function trimRenderCache(start:Int, end:Int):Void {
        final keys = renderCacheKeys;
        var i = 0;
        while (i < keys.length) {
            final k = keys[i];
            if (k < start - 20 || k > end + 20) {
                renderCache.remove(k);
                keys[i] = keys[keys.length - 1];
                keys.pop();
            }
            else {
                i++;
            }
        }
    }

    /**
     * The view line numbers of `renderCache` (trimmed without iterating the
     * map, which allocates its keys on hxcpp).
     */
    final renderCacheKeys:Array<Int> = [];

    /**
     * Drops the rendered lines and what the element keeps between frames.
     */
    function resetRenderCache():Void {
        renderCache = new Map();
        renderCacheKeys.resize(0);
        selectionInputLines.resize(0);
        // the lines of the other caches (sticky scroll) are checked again
        renderGeneration++;
        paintGeneration++;
    }

    /**
     * Bumped by the view events (scrolling excepted) and when the rendered
     * lines are dropped: what the paint keeps from one frame to the next
     * (selections, guides, overview ruler marks, line number labels) is
     * computed again.
     */
    public var paintGeneration(default, null):Int = 0;

    @:allow(cityscape.view.CityscapeViewEventHandler)
    function invalidatePaint():Void {
        paintGeneration++;
    }

    /**
     * The state the element keeps from one frame to the next.
     */
    @:allow(cityscape.view.CityscapeViewElement)
    @:allow(cityscape.CityscapeEditor)
    final paintState:CityscapeViewElement.PaintState = new CityscapeViewElement.PaintState();

    //#endregion

    //#region hit testing

    /**
     * The view position under a window point (Monaco's mouse target, for
     * the content area only).
     */
    public function viewPositionAt(point:Point):Position {
        final viewModel = this.viewModel;
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final layout = viewModel.viewLayout;
        final y = point.y - elementBounds.origin.y + layout.getCurrentScrollTop();
        final x = point.x - elementBounds.origin.x - layoutInfo.contentLeft + layout.getCurrentScrollLeft();
        if (y < 0 || layout.isInTopPadding(y)) {
            return new Position(1, 1);
        }
        if (layout.isAfterLines(y)) {
            final last = viewModel.getLineCount();
            return new Position(last, viewModel.getLineMaxColumn(last));
        }
        final lineNumber = layout.getLineNumberAtVerticalOffset(y);
        final line = renderViewLine(lineNumber);
        return new Position(lineNumber, line.xToColumn(x));
    }

    public function modelPositionAt(point:Point):Position {
        return viewModel.coordinatesConverter.convertViewPositionToModelPosition(viewPositionAt(point));
    }

    //#endregion


    //#region mouse

    /**
     * The mouse column of Monaco's mouse target (a visible column from the
     * x position, for the column selection).
     */
    function mouseColumnAt(point:Point):Int {
        final viewModel = this.viewModel;
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final fontInfo:FontInfo = configuration.options.get(EditorOption.fontInfo);
        final x = point.x - elementBounds.origin.x - layoutInfo.contentLeft + viewModel.viewLayout.getCurrentScrollLeft();
        return Std.int(Math.max(0, Math.round(x / fontInfo.typicalHalfwidthCharacterWidth))) + 1;
    }

    function editorMouseEvent(button:MouseButton, position:Point, modifiers:glaze.Modifiers, clickCount:Int):EditorMouseEvent {
        final data = new EditorMouseEventData(
            button == MouseButton.Left,
            button == MouseButton.Middle,
            button == MouseButton.Right,
            modifiers.control,
            modifiers.shift,
            modifiers.alt,
            modifiers.platform,
            clickCount,
            position.x,
            position.y
        );
        return new EditorMouseEvent(data, mouseTargetAt(position));
    }

    /**
     * Monaco's `ViewController.dispatchMouse` for the content area
     * (`multiCursorModifier` 'alt', the default).
     */
    function dispatchMouse(point:Point, inSelectionMode:Bool, mouseDownCount:Int, altKey:Bool, shiftKey:Bool):Void {
        final viewModel = this.viewModel;
        final viewPosition = viewPositionAt(point);
        final position = viewModel.coordinatesConverter.convertViewPositionToModelPosition(viewPosition);
        final args:CoreCommandArgs = {
            source: 'mouse',
            position: position,
            viewPosition: viewPosition,
            revealType: NavigationCommandRevealType.Minimal
        };
        final hasMulticursorModifier = altKey;
        if (mouseDownCount >= 4) {
            CoreNavigationCommands.SelectAll.runCoreEditorCommand(viewModel, args);
        }
        else if (mouseDownCount == 3) {
            if (hasMulticursorModifier) {
                (inSelectionMode ? CoreNavigationCommands.LastCursorLineSelectDrag : CoreNavigationCommands.LastCursorLineSelect).runCoreEditorCommand(viewModel, args);
            }
            else {
                (inSelectionMode ? CoreNavigationCommands.LineSelectDrag : CoreNavigationCommands.LineSelect).runCoreEditorCommand(viewModel, args);
            }
        }
        else if (mouseDownCount == 2) {
            if (hasMulticursorModifier) {
                CoreNavigationCommands.LastCursorWordSelect.runCoreEditorCommand(viewModel, args);
            }
            else {
                (inSelectionMode ? CoreNavigationCommands.WordSelectDrag : CoreNavigationCommands.WordSelect).runCoreEditorCommand(viewModel, args);
            }
        }
        else {
            if (hasMulticursorModifier) {
                if (shiftKey) {
                    args.mouseColumn = mouseColumnAt(point);
                    args.doColumnSelect = true;
                    CoreNavigationCommands.ColumnSelect.runCoreEditorCommand(viewModel, args);
                }
                else if (inSelectionMode) {
                    CoreNavigationCommands.LastCursorMoveToSelect.runCoreEditorCommand(viewModel, args);
                }
                else {
                    CoreNavigationCommands.CreateCursor.runCoreEditorCommand(viewModel, args);
                }
            }
            else {
                if (inSelectionMode) {
                    CoreNavigationCommands.MoveToSelect.runCoreEditorCommand(viewModel, args);
                }
                else {
                    CoreNavigationCommands.MoveTo.runCoreEditorCommand(viewModel, args);
                }
            }
        }
    }

    public function handleMouseDown(event:MouseDownEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final e = editorMouseEvent(event.button, event.position, event.modifiers, event.clickCount);
        final type = e.target.type;
        if (event.button == MouseButton.Right) {
            // Monaco's context menu: the editor takes the focus, the cursor
            // moves to the click unless it is inside a selection
            focusHandle.focus(window, cx);
            syncFocus(window, cx);
            final position = e.target.position;
            if (position != null && (type == MouseTargetType.CONTENT_TEXT || type == MouseTargetType.CONTENT_EMPTY)) {
                var insideSelection = false;
                for (s in viewModel.getSelections()) {
                    if (!s.isEmpty() && s.containsPosition(position)) {
                        insideSelection = true;
                        break;
                    }
                }
                if (!insideSelection) {
                    dispatchMouse(event.position, false, 1, false, false);
                }
            }
            widget._fireMouseDown(e);
            widget._fireContextMenu(e);
            restartBlink();
            notifyChanged();
            return;
        }
        // Monaco's `MouseHandler._onMouseDown`: the content and the line
        // numbers start a mouse down operation; the rest of the gutter does
        // not steal the focus nor move the cursor
        if (event.button == MouseButton.Left && type == MouseTargetType.CONTENT_TEXT && startsDragAndDrop(e)) {
            // Monaco's `MouseDownOperation.start`: a single press on the
            // primary selection drags it (`dragAndDrop`), the cursor stays
            focusHandle.focus(window, cx);
            syncFocus(window, cx);
            mouseDown = true;
            mouseDragAndDrop = true;
            mouseDownOnLineNumbers = false;
            widget._fireMouseDown(e);
            notifyChanged();
            return;
        }
        if (event.button == MouseButton.Left && (type == MouseTargetType.CONTENT_TEXT || type == MouseTargetType.CONTENT_EMPTY || type == MouseTargetType.GUTTER_LINE_NUMBERS)) {
            focusHandle.focus(window, cx);
            syncFocus(window, cx);
            mouseDown = true;
            mouseDownCount = event.clickCount;
            mouseDownAlt = event.modifiers.alt;
            mouseDownShift = event.modifiers.shift;
            mouseDownOnLineNumbers = (type == MouseTargetType.GUTTER_LINE_NUMBERS);
            dispatchMouseFor(event.position, event.modifiers.shift);
            restartBlink();
        }
        widget._fireMouseDown(e);
        notifyChanged();
    }

    /**
     * Monaco's `ViewController.dispatchMouse` with `startedOnLineNumbers`:
     * a drag started on the line numbers works on whole lines.
     */
    function dispatchMouseFor(point:Point, inSelectionMode:Bool):Void {
        final viewModel = this.viewModel;
        if (!mouseDownOnLineNumbers) {
            dispatchMouse(point, inSelectionMode, mouseDownCount, mouseDownAlt, mouseDownShift);
            return;
        }
        final viewPosition = viewPositionAt(point);
        final position = viewModel.coordinatesConverter.convertViewPositionToModelPosition(viewPosition);
        final args:CoreCommandArgs = {source: 'mouse', position: position, viewPosition: viewPosition, revealType: NavigationCommandRevealType.Minimal};
        if (mouseDownAlt) {
            if (inSelectionMode) {
                CoreNavigationCommands.LastCursorLineSelect.runCoreEditorCommand(viewModel, args);
            }
            else {
                args.wholeLine = true;
                CoreNavigationCommands.CreateCursor.runCoreEditorCommand(viewModel, args);
            }
        }
        else {
            (inSelectionMode ? CoreNavigationCommands.LineSelectDrag : CoreNavigationCommands.LineSelect).runCoreEditorCommand(viewModel, args);
        }
    }

    var mouseDownOnLineNumbers:Bool = false;

    /** A press on the selection is dragging it (Monaco's `isDragAndDrop`). */
    var mouseDragAndDrop:Bool = false;

    /**
     * Monaco's conditions of a drag of the selection: `dragAndDrop` on, not
     * read only, no column selection, no Alt, a single click on the text of
     * the primary selection, not empty.
     */
    function startsDragAndDrop(e:EditorMouseEvent):Bool {
        final options = configuration.options;
        final position = e.target.position;
        if (position == null || options.get(EditorOption.readOnly) || !options.get(EditorOption.dragAndDrop) || options.get(EditorOption.columnSelection)
            || e.event.altKey || e.event.detail >= 2 || mouseDown) {
            return false;
        }
        final selection = widget.getSelection();
        return selection != null && !selection.isEmpty() && selection.containsPosition(position);
    }

    /**
     * Ends a drag of the selection without a drop (Escape, the focus lost).
     */
    public function cancelDragAndDrop():Bool {
        if (!mouseDragAndDrop) {
            return false;
        }
        mouseDragAndDrop = false;
        mouseDown = false;
        widget._fireMouseDropCanceled();
        notifyChanged();
        return true;
    }

    public function handleMouseMove(event:MouseMoveEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final relativeX = event.position.x - elementBounds.origin.x;
        setGutterHovered(relativeX >= 0 && relativeX < layoutInfo.contentLeft);
        if (!mouseDown || event.pressedButton == null) {
            widget._fireMouseMove(editorMouseEvent(MouseButton.Left, event.position, event.modifiers, 0));
            return;
        }
        if (mouseDragAndDrop) {
            widget._fireMouseDrag(editorMouseEvent(MouseButton.Left, event.position, event.modifiers, 0));
            notifyChanged();
            return;
        }
        dispatchMouseFor(event.position, true);
        viewModel.revealPrimaryCursor('mouse', true, true);
        notifyChanged();
    }

    /**
     * Called when the mouse enters or leaves the editor.
     */
    public function handleHover(hovered:Bool):Void {
        if (!hovered) {
            setGutterHovered(false);
            if (viewModel != null) {
                // Monaco's `onMouseLeave` (the hover and the link gesture hide)
                widget._fireMouseLeave({
                    event: new EditorMouseEventData(false, false, false, lastModifiers.control, lastModifiers.shift, lastModifiers.alt, lastModifiers.platform, 0),
                    target: null
                });
            }
        }
    }

    var lastModifiers:glaze.Modifiers = glaze.Modifiers.of();

    /**
     * Called when the modifier keys change while the editor has the focus:
     * Monaco's text area gets a `keydown` and a `keyup` for Ctrl and Meta
     * (the link gesture of go to definition listens to them); Glaze reports
     * the modifiers instead, turned into those events here.
     */
    public function handleModifiersChanged(modifiers:glaze.Modifiers):Void {
        final previous = lastModifiers;
        lastModifiers = modifiers;
        if (viewModel == null) {
            return;
        }
        inline function keyEvent(keyCode:cityscape.base.common.KeyCodes.KeyCode, code:String):cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent {
            return {
                ctrlKey: modifiers.control,
                shiftKey: modifiers.shift,
                altKey: modifiers.alt,
                metaKey: modifiers.platform,
                altGraphKey: false,
                keyCode: keyCode,
                code: code
            };
        }
        if (modifiers.platform != previous.platform) {
            final e = keyEvent(cityscape.base.common.KeyCodes.KeyCode.Meta, 'MetaLeft');
            modifiers.platform ? widget._fireKeyDown(e) : widget._fireKeyUp(e);
        }
        if (modifiers.control != previous.control) {
            final e = keyEvent(cityscape.base.common.KeyCodes.KeyCode.Ctrl, 'ControlLeft');
            modifiers.control ? widget._fireKeyDown(e) : widget._fireKeyUp(e);
        }
        if (modifiers.alt != previous.alt) {
            final e = keyEvent(cityscape.base.common.KeyCodes.KeyCode.Alt, 'AltLeft');
            modifiers.alt ? widget._fireKeyDown(e) : widget._fireKeyUp(e);
        }
        if (modifiers.shift != previous.shift) {
            final e = keyEvent(cityscape.base.common.KeyCodes.KeyCode.Shift, 'ShiftLeft');
            modifiers.shift ? widget._fireKeyDown(e) : widget._fireKeyUp(e);
        }
    }

    /**
     * Whether the mouse is over the gutter (Monaco's
     * `.margin-view-overlays:hover`: the folding controls of
     * `showFoldingControls: 'mouseover'` show).
     */
    public var gutterHovered(default, null):Bool = false;

    function setGutterHovered(hovered:Bool):Void {
        if (gutterHovered != hovered) {
            gutterHovered = hovered;
            notifyChanged();
        }
    }

    public function handleMouseUp(event:MouseUpEvent, window:Window, cx:App):Void {
        if (event.button == MouseButton.Left) {
            mouseDown = false;
            if (mouseDragAndDrop) {
                mouseDragAndDrop = false;
                if (viewModel != null) {
                    final e = editorMouseEvent(event.button, event.position, event.modifiers, event.clickCount);
                    widget._fireMouseDrop({event: e.event, target: e.target});
                }
            }
        }
        if (viewModel != null) {
            widget._fireMouseUp(editorMouseEvent(event.button, event.position, event.modifiers, event.clickCount));
            notifyChanged();
        }
    }

    public function onScroll(event:ScrollEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final lineHeight = configuration.options.get(EditorOption.lineHeight);
        final delta = event.delta.pixelDelta(lineHeight);
        var dx = -delta.x;
        var dy = -delta.y;
        if (event.modifiers.shift && dx == 0) {
            dx = dy;
            dy = 0;
        }
        viewModel.viewLayout.deltaScrollNow(dx, dy);
        cx.stopPropagation();
        notifyChanged();
    }

    //#endregion

    /**
     * Runs a folding command by its Monaco id (`editor.fold`,
     * `editor.foldAll`, `editor.foldLevel2`...) through the editor's
     * actions. Returns false when there is no such command or its arguments
     * are invalid.
     */
    public function runFoldingCommand(id:String, ?args:cityscape.contrib.folding.view.Folding.FoldingArguments):Bool {
        if (cityscape.contrib.folding.view.Folding.FoldingCommands.get(id) == null) {
            return false;
        }
        if ((id == 'editor.fold' || id == 'editor.unfold') && !cityscape.contrib.folding.view.Folding.FoldingAction.foldingArgumentsConstraint(args)) {
            return false;
        }
        widget.trigger('api', id, args);
        notifyChanged();
        return true;
    }

    //#region keys

    /**
     * A chord bound by the editor's keybindings was pressed while the editor
     * (or one of its widgets) has the focus: Monaco's keybinding service
     * resolves it against the editor's context keys and runs the command on
     * this editor. Returns whether the key was handled (otherwise the caller
     * lets the key go on to the next Glaze binding: an app shortcut).
     */
    public function onRunKeybinding(keypress:String, window:Window, cx:App):Bool {
        if (mouseDragAndDrop && keypress == 'Escape') {
            // Monaco's mouse move monitor ends on a key: the drop is canceled
            return cancelDragAndDrop();
        }
        syncFocus(window, cx);
        widget._fireKeyDown(KeyboardEvents.fromDispatchString(keypress));
        keyDownFiredFor = keypress;
        final handled = context.codeEditorService.withInvokingEditor(widget, () -> {
            return context.keybindingService.dispatchKeypress(keypress, KeyboardEvents.labelOf(keypress), widget.contextKeyService);
        });
        if (handled) {
            keyDownFiredFor = null;
            restartBlink();
            notifyChanged();
        }
        return handled;
    }

    /**
     * A key no keybinding handled: the editor's `onKeyDown` listeners get
     * it, and Enter is typed (Monaco's textarea input).
     */
    public function onKeyDown(event:KeyDownEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final ks = event.keystroke;
        if (mouseDragAndDrop && ks.key == 'escape') {
            // Monaco's mouse move monitor ends on a key: the drop is canceled
            cancelDragAndDrop();
            cx.stopPropagation();
            return;
        }
        final dispatch = KeyboardEvents.dispatchStringOf(ks);
        if (dispatch == null || dispatch != keyDownFiredFor) {
            final e = KeyboardEvents.fromKeystroke(ks);
            if (e != null) {
                widget._fireKeyDown(e);
            }
        }
        final alreadyDispatched = dispatch != null && dispatch == keyDownFiredFor;
        keyDownFiredFor = null;
        final keybindingService = context.keybindingService;
        if (dispatch != null && !alreadyDispatched && keybindingService.inChordMode) {
            // Monaco dispatches every key: in chord mode, a key with no Glaze
            // binding ends the chord ("is not a command") and is not typed
            context.codeEditorService.withInvokingEditor(widget, () -> {
                return keybindingService.dispatchKeypress(dispatch, KeyboardEvents.labelOf(dispatch), widget.contextKeyService);
            });
            cx.stopPropagation();
            return;
        }
        final mods = ks.modifiers;
        if (ks.key == 'enter' && !mods.control && !mods.platform && !mods.alt) {
            if (configuration.options.get(EditorOption.readOnly)) {
                return;
            }
            widget._typeFromKeyboard('\n');
            restartBlink();
            cx.stopPropagation();
            notifyChanged();
        }
    }

    //#endregion

    //#region cursor blink

    function stopBlink():Void {
        if (blinkStop != null) {
            blinkStop();
            blinkStop = null;
            #if cityscape_debug_counters
            cityscape.base.common.DebugCounters.timers--;
            #end
        }
    }

    /**
     * Monaco's `blink` cursor: visible, then on and off every 500 ms while
     * the editor has focus.
     */
    public function restartBlink():Void {
        stopBlink();
        cursorVisible = true;
        final style = configuration.options.get(EditorOption.cursorBlinking);
        if (style == TextEditorCursorBlinkingStyle.Solid) {
            return;
        }
        blinkStop = ceramic.Timer.interval(this, 0.5, () -> {
            cursorVisible = !cursorVisible;
            notifyChanged();
        });
        #if cityscape_debug_counters
        cityscape.base.common.DebugCounters.timers++;
        #end
    }

    //#endregion

    //#region clipboard

    function copySelection(cx:App):Null<String> {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return null;
        }
        final selections = viewModel.getSelections();
        final ranges:Array<Range> = [for (s in selections) s];
        final emptySelectionClipboard = configuration.options.get(EditorOption.emptySelectionClipboard);
        final text = viewModel.getPlainTextToCopy(ranges, emptySelectionClipboard, false);
        final multicursorText:Null<Array<String>> = Std.isOfType(text, String) ? null : cast text;
        final str:String = multicursorText == null ? cast text : multicursorText.join(model.getEOL());
        if (str.length > 0) {
            cx.writeToClipboard(ClipboardItem.newString(str));
        }
        var isFromEmptySelection = emptySelectionClipboard;
        for (s in selections) {
            if (!s.isEmpty()) {
                isFromEmptySelection = false;
                break;
            }
        }
        lastCopiedText = str;
        lastCopiedIsFromEmptySelection = isFromEmptySelection;
        lastCopiedMulticursorText = multicursorText;
        return str;
    }

    /**
     * A paste from the platform (Glaze's input handler): Monaco's paste.
     */
    public function paste(item:ClipboardItem, window:Window, cx:Context<Dynamic>):Void {
        final text = item != null ? item.text() : null;
        if (viewModel != null && text != null) {
            pasteText(text);
            notifyChanged();
        }
    }

    function pasteText(text:String):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        // The metadata of the last copy applies to its own text only
        final fromLastCopy = (lastCopiedText != null && lastCopiedText == text);
        final pasteOnNewLine = fromLastCopy && lastCopiedIsFromEmptySelection;
        final multicursorText = fromLastCopy ? lastCopiedMulticursorText : null;
        widget._pasteFromKeyboard(text, pasteOnNewLine, multicursorText, null);
        viewModel.revealPrimaryCursor('keyboard', true);
    }

    /**
     * Types text at the cursors (Monaco's `Handler.Type` from the keyboard:
     * auto closing, auto indentation, electric characters...).
     */
    public function type(text:String):Void {
        if (viewModel == null || text.length == 0) {
            return;
        }
        widget._typeFromKeyboard(text);
        restartBlink();
    }

    //#endregion

    //#region text input (IME), model offsets in UTF-16 code units

    function offsetOf(p:Position):Int {
        return model.getOffsetAt(p);
    }

    public function textForRange(range:glaze.Range, adjustedRange:Ref<Null<glaze.Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        if (model == null) {
            return null;
        }
        final start = model.getPositionAt(range.start);
        final end = model.getPositionAt(range.end);
        return model.getValueInRange(new Range(start.lineNumber, start.column, end.lineNumber, end.column));
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        if (viewModel == null) {
            return null;
        }
        final s = viewModel.getSelection();
        final a = offsetOf(s.getSelectionStart());
        final b = offsetOf(s.getPosition());
        return a <= b ? new UTF16Selection(new glaze.Range(a, b), false) : new UTF16Selection(new glaze.Range(b, a), true);
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<glaze.Range> {
        return markedRange;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {
        if (markedRange != null && viewModel != null) {
            viewModel.endComposition('keyboard');
            viewModel.onCompositionEnd();
        }
        markedRange = null;
    }

    /**
     * Replaces a range of model offsets (the selection when null) with
     * `text`: typed from the keyboard (`source` 'keyboard': auto closing and
     * the other interceptors) or composed (no source: the text as is).
     */
    function replaceOffsets(range:Null<glaze.Range>, text:String, source:Null<String>):Void {
        if (range != null) {
            final start = model.getPositionAt(range.start);
            final end = model.getPositionAt(range.end);
            viewModel.setSelections(source, [new Selection(start.lineNumber, start.column, end.lineNumber, end.column)]);
        }
        if (text.length == 0) {
            // removes the range (the composed text was deleted)
            if (!viewModel.getSelection().isEmpty()) {
                viewModel.executeEdits(source, [for (sel in viewModel.getSelections()) {range: sel, text: ''}], (_) -> null);
            }
            return;
        }
        if (source == 'keyboard') {
            widget._typeFromKeyboard(text);
        }
        else {
            viewModel.type(text, source);
        }
        restartBlink();
    }

    public function replaceTextInRange(range:Null<glaze.Range>, text:String, window:Window, cx:Context<Dynamic>):Void {
        if (viewModel == null || configuration.options.get(EditorOption.readOnly)) {
            return;
        }
        // Enter and tab arrive as keys (`onKeyDown`)
        if (text == '\n' || text == '\r' || text == '\r\n' || text == '\t') {
            return;
        }
        final composing = (markedRange != null);
        if (range == null && markedRange != null) {
            range = markedRange;
        }
        markedRange = null;
        if (composing) {
            // the composition ends with the committed text
            replaceOffsets(range, text, null);
            viewModel.endComposition('keyboard');
            viewModel.onCompositionEnd();
        }
        else {
            replaceOffsets(range, text, 'keyboard');
        }
        notifyChanged();
    }

    public function replaceAndMarkTextInRange(range:Null<glaze.Range>, newText:String, newSelectedRange:Null<glaze.Range>, window:Window, cx:Context<Dynamic>):Void {
        if (viewModel == null || configuration.options.get(EditorOption.readOnly)) {
            return;
        }
        if (markedRange == null) {
            viewModel.onCompositionStart();
            viewModel.startComposition();
        }
        if (range == null && markedRange != null) {
            range = markedRange;
        }
        final startOffset = range != null ? range.start : offsetOf(viewModel.getSelections()[0].getStartPosition());
        replaceOffsets(range, newText, null);
        markedRange = newText.length > 0 ? new glaze.Range(startOffset, startOffset + newText.length) : null;
        if (newSelectedRange != null) {
            final p = model.getPositionAt(startOffset + newSelectedRange.end);
            viewModel.setSelections('ime', [new Selection(p.lineNumber, p.column, p.lineNumber, p.column)]);
        }
        notifyChanged();
    }

    public function boundsForRange(rangeUtf16:glaze.Range, elementBounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        if (viewModel == null) {
            return null;
        }
        final p = model.getPositionAt(rangeUtf16.start);
        final viewPos = viewModel.coordinatesConverter.convertModelPositionToViewPosition(p);
        final layout = viewModel.viewLayout;
        final layoutInfo = configuration.options.get(EditorOption.layoutInfo);
        final line = renderViewLine(viewPos.lineNumber);
        final x = this.elementBounds.origin.x + layoutInfo.contentLeft + line.columnToX(viewPos.column) - layout.getCurrentScrollLeft();
        final y = this.elementBounds.origin.y + layout.getVerticalOffsetForLineNumber(viewPos.lineNumber) - layout.getCurrentScrollTop();
        return new Bounds(new Point(x, y), new Size(2, configuration.options.get(EditorOption.lineHeight)));
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        if (viewModel == null) {
            return null;
        }
        return offsetOf(modelPositionAt(point));
    }

    public function textLengthUtf16(window:Window, cx:Context<Dynamic>):Null<Int> {
        return model == null ? null : model.getValueLength();
    }

    public function acceptsTextInput(window:Window, cx:Context<Dynamic>):Bool {
        return viewModel != null && !configuration.options.get(EditorOption.readOnly);
    }

    //#endregion

}

/**
 * Receives the view events of the view model (Monaco's view parts each
 * receive them; the Glaze view repaints).
 */
class CityscapeViewEventHandler extends ViewEventHandler {

    final view:CityscapeView;

    public function new(view:CityscapeView) {
        super();
        this.view = view;
    }

    override public function handleEvents(events:Array<ViewEvent>):Void {
        var flush = false;
        var paint = false;
        var flushed = false;
        for (i in 0...events.length) {
            final e = events[i];
            if (e.type == ViewEventType.ViewFlushed) {
                flushed = true;
            }
            if (e.type != ViewEventType.ViewScrollChanged) {
                paint = true;
            }
            switch (e.type) {
                case ViewEventType.ViewFlushed | ViewEventType.ViewLinesInserted | ViewEventType.ViewLinesDeleted | ViewEventType.ViewLineMappingChanged | ViewEventType.ViewConfigurationChanged | ViewEventType.ViewThemeChanged | ViewEventType.ViewTokensColorsChanged:
                    flush = true;
                case ViewEventType.ViewRevealRangeRequest:
                    view.onRevealRange(cast e);
                case ViewEventType.ViewLinesChanged:
                    final changed:ViewLinesChangedEvent = cast e;
                    view.invalidateLines(changed.fromLineNumber, changed.fromLineNumber + changed.count - 1);
                case ViewEventType.ViewTokensChanged:
                    final changed:ViewTokensChangedEvent = cast e;
                    for (r in changed.ranges) {
                        view.invalidateLines(r.fromLineNumber, r.toLineNumber);
                    }
                case ViewEventType.ViewCursorStateChanged:
                    // the selections are part of the input with `renderWhitespace: 'selection'`
                    if (view.configuration.options.get(EditorOption.renderWhitespace) == 'selection') {
                        final changed:ViewCursorStateChangedEvent = cast e;
                        view.invalidateSelectionLines(changed.selections);
                    }
                case ViewEventType.ViewScrollChanged | ViewEventType.ViewFocusChanged | ViewEventType.ViewCompositionStart | ViewEventType.ViewCompositionEnd | ViewEventType.ViewLanguageConfigurationChanged:
                    // the rendering of the lines stays the same
                case _:
                    // decorations, view zones and anything else: every line is checked again
                    view.invalidateAllLines();
            }
        }
        if (paint) {
            view.invalidatePaint();
        }
        view.onViewEvents(flush, flushed);
    }

}

/**
 * The Glaze view of a `CityscapeView`'s painting: its element, rendered again
 * when the editor view notifies (`CityscapeView.paintView`).
 */
class CityscapePaintView extends GlazeModel implements glaze.Render {

    final element:CityscapeViewElement;

    public function new(view:Entity<CityscapeView>) {
        super();
        element = new CityscapeViewElement(view);
    }

    public function render(window:Window, cx:Context<Dynamic>):glaze.IntoElement {
        return element;
    }

}

/**
 * The kit scrollbar handle of a Cityscape view: GPUI offsets (0 at the top,
 * negative down) over Monaco's scroll position (AUDIT B.1).
 */
class CityscapeScrollHandle implements ScrollbarHandleImpl implements glaze.kit.base.Scrollbar.ScrollbarThumbPadding {

    final view:CityscapeView;
    var dragging:Bool = false;

    public function new(view:CityscapeView) {
        this.view = view;
    }

    public function viewportBounds():Bounds {
        final viewModel = view.viewModel;
        final b = view.elementBounds;
        if (viewModel == null) {
            return b;
        }
        final layoutInfo = view.configuration.options.get(EditorOption.layoutInfo);
        return new Bounds(new Point(b.origin.x + layoutInfo.contentLeft, b.origin.y), new Size(layoutInfo.contentWidth, b.size.height));
    }

    public function offset():Point {
        final viewModel = view.viewModel;
        if (viewModel == null) {
            return new Point(0, 0);
        }
        return new Point(-viewModel.viewLayout.getCurrentScrollLeft(), -viewModel.viewLayout.getCurrentScrollTop());
    }

    public function setOffset(offset:Point):Void {
        final viewModel = view.viewModel;
        if (viewModel == null) {
            return;
        }
        viewModel.viewLayout.setScrollPosition({scrollLeft: -offset.x, scrollTop: -offset.y}, ScrollType.Immediate);
    }

    public function contentSize():Size {
        final viewModel = view.viewModel;
        if (viewModel == null) {
            return new Size(0, 0);
        }
        final layout = viewModel.viewLayout;
        // `scrollBeyondLastLineGap`: the exact height (Monaco's scroll state
        // keeps integers), so that the thumb follows gpui-kit's rule exactly
        final exact = layout.exactContentHeight > 0 ? Math.max(layout.exactContentHeight, layout.exactHeight) : layout.getScrollHeight();
        return new Size(layout.getScrollWidth(), exact);
    }

    /**
     * The vertical padding left out of the thumb: the editor's padding with
     * the Cityscape option `scrollbarThumbExcludesPadding`, else 0.
     */
    public function thumbVerticalPadding():Float {
        final options = view.configuration.options;
        if (!options.get(EditorOption.scrollbarThumbExcludesPadding)) {
            return 0;
        }
        final padding = options.get(EditorOption.padding);
        return padding.top + padding.bottom;
    }

    public function startDrag():Void {
        dragging = true;
    }

    public function endDrag():Void {
        dragging = false;
    }

}

/**
 * The line measurer of a view's line breaks: the editor font with the
 * view's `preferColorEmoji` option (an emoji is wider in the color font).
 */
class ViewLineMeasurer implements cityscape.view.MeasuredLineBreaksComputer.ILineMeasurer {

    final view:CityscapeView;

    public function new(view:CityscapeView) {
        this.view = view;
    }

    public function measure(text:String, fontInfo:cityscape.common.config.FontInfo):Array<Float> {
        return view.measurements.measureWith(text, fontInfo, view.preferColorEmoji());
    }

}
