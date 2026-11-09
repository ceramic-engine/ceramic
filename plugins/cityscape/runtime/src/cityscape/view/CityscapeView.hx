// New code for Cityscape (not a port): the state of one editor view in Glaze,
// what Monaco splits between `View` (browser/view.ts), its view parts
// (viewLines, lineNumbers, selections, viewCursors, currentLineHighlight,
// decorations, indentGuides, rulers, overviewRuler) and the mouse handler.
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.CharCode;
import cityscape.base.common.Event;
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
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.viewLayout.ViewLayout;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.contrib.folding.view.Folding;
import cityscape.contrib.wordOperations.view.WordOperations;
import cityscape.view.EditorBrowser;
import cityscape.view.CoreCommands;
import cityscape.view.DecorationStyleResolver;
import cityscape.view.MeasuredLineBreaksComputer;
import cityscape.view.config.EditorConfiguration;
import glaze.App;
import glaze.Bounds;
import glaze.ClipboardItem;
import glaze.Context;
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
        final dom = output.characterMapping.getDomPosition(c);
        final rendered = runs.renderedOffsetOf(dom.partIndex, dom.charIndex);
        return layout.xForIndex(offsets.utf16ToByte(rendered));
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
 * The Glaze view of a Cityscape editor: one per editor, holding its view
 * model (selections, scroll, wrapping) over a text model that other editors
 * may show too. Implements the text input of Glaze (IME) and the scrollbar
 * handle of the kit.
 *
 * The keys, the mouse and the text input run Monaco's commands (core
 * commands, word operations, typing through the cursor controller of the
 * view model), which is why the view is the `ICodeEditor` of the commands.
 * TODO(step 3, keybindings): the keys are mapped here until the keybinding
 * service of step 3 maps them (Monaco's default keybindings of macOS and
 * the other platforms).
 */
class CityscapeView extends GlazeModel implements glaze.EntityInputHandler implements ICodeEditor implements IFoldingEditor {

    public final context:Cityscape;
    public final editorId:Int;

    public var model(default, null):Null<ITextModel> = null;
    public var viewModel(default, null):Null<ViewModel> = null;
    public final configuration:EditorConfiguration;
    public final measurements:EditorFontMeasurements;
    public final resolver:DecorationStyleResolver;
    public final theme:ViewTheme;
    public final scrollHandle:CityscapeScrollHandle;
    public final focusHandle:glaze.FocusHandle;

    final app:App;
    var eventHandler:Null<CityscapeViewEventHandler> = null;
    var outgoingListener:Null<IDisposable> = null;

    /**
     * `wrappingIndentColumns` (loreline-monaco's `[loreline]` patch): -1 for
     * Monaco's tab stops.
     */
    public var wrappingIndentColumns(default, null):Int = -1;

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

    /**
     * Saved view states of the models this editor showed (the plan: the
     * editor keeps a view state per displayed model).
     */
    final savedViewStates:Map<String, {selections:Array<Selection>, scrollTop:Float, scrollLeft:Float, folding:Null<FoldingStateMemento>}> = new Map();

    // Editor events (Monaco's `ICodeEditor` events the contributions use)
    final _onDidChangeModel = new VoidEmitter();
    final _onDidChangeModelContent = new Emitter<IModelContentChangedEvent>();
    final _onDidChangeCursorPosition = new VoidEmitter();
    final _onDidChangeModelLanguageConfiguration = new VoidEmitter();
    final _onMouseDown = new Emitter<EditorMouseEvent>();
    final _onMouseUp = new Emitter<EditorMouseEvent>();

    /**
     * The editor contributions by id (Monaco's `getContribution`).
     */
    final contributions:Map<String, Any> = new Map();

    /**
     * The folding of this editor (`editor.contrib.folding`).
     */
    public final foldingController:FoldingController;

    /**
     * The keys of the folding actions (TODO(step 3, keybindings): the
     * keybinding service of the editor replaces this adapter).
     */
    final foldingKeybindings:FoldingKeybindings = new FoldingKeybindings();

    /**
     * Whether the mouse is over the gutter (Monaco's
     * `.margin-view-overlays:hover`: the folding controls of
     * `showFoldingControls: 'mouseover'` show).
     */
    public var gutterHovered(default, null):Bool = false;

    public function new(cx:Context<CityscapeView>, context:Cityscape, editorId:Int, options:IEditorOptions) {
        super();
        this.app = cx.app;
        this.context = context;
        this.editorId = editorId;
        this.theme = new ViewTheme(context.themeService, context.tokenizationRegistry);
        this.measurements = EditorFontMeasurements.forApp(cx.app);
        this.resolver = new DecorationStyleResolver(theme, context.decorationStyles);
        this.configuration = new EditorConfiguration(false, withDefaultLigatures(options), {width: 600, height: 400}, (bare) -> measurements.readFontInfo(bare));
        this.scrollHandle = new CityscapeScrollHandle(this);
        this.focusHandle = cx.app.focusHandle();
        this.foldingController = new FoldingController(this);
        contributions.set(FoldingController.ID, foldingController);
    }

    /**
     * Monaco's default `fontLigatures: false` is `'"liga" off, "calt" off'`;
     * Glaze turns ligatures on when nothing is said (AUDIT A.2.3): the
     * option is resolved as is, the features are always explicit.
     */
    static function withDefaultLigatures(options:IEditorOptions):IEditorOptions {
        return options;
    }

    function notifyChanged():Void {
        app.notify(entityId);
    }

    /**
     * Releases the view model and the timers (the component calls it when
     * it leaves the tree).
     */
    public function disposeView():Void {
        detachModel();
        foldingController.dispose();
        _onDidChangeModel.dispose();
        _onDidChangeModelContent.dispose();
        _onDidChangeCursorPosition.dispose();
        _onDidChangeModelLanguageConfiguration.dispose();
        _onMouseDown.dispose();
        _onMouseUp.dispose();
        configuration.dispose();
        theme.dispose();
        stopBlink();
    }

    //#region model

    public function setModel(model:Null<ITextModel>):Void {
        if (this.model == model) {
            return;
        }
        detachModel();
        this.model = model;
        if (model == null) {
            return;
        }
        final factory = createLineBreaksComputerFactory();
        final viewModel = new ViewModel(editorId, configuration, model, new MeasuredLineBreaksComputerFactory(measurements), factory, wrappingIndentColumns, context);
        this.viewModel = viewModel;
        final handler = new CityscapeViewEventHandler(this);
        this.eventHandler = handler;
        viewModel.addViewEventHandler(handler);
        outgoingListener = viewModel.onEvent(e -> onOutgoingEvent(e));
        configuration.setModelLineCount(model.getLineCount());
        _onDidChangeModel.fire();
        final saved = savedViewStates.get(model.id);
        if (saved != null) {
            viewModel.setSelections('restoreViewState', saved.selections);
            foldingController.restoreViewState(saved.folding);
            viewModel.viewLayout.setScrollPosition({scrollTop: saved.scrollTop, scrollLeft: saved.scrollLeft}, ScrollType.Immediate);
        }
        renderCache = new Map();
        maxLineWidth = 0;
        lastVisibleStart = -1;
        lastVisibleEnd = -1;
        notifyChanged();
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

    function detachModel():Void {
        final viewModel = this.viewModel;
        final model = this.model;
        if (viewModel != null && model != null) {
            savedViewStates.set(model.id, {
                selections: viewModel.getSelections(),
                scrollTop: viewModel.viewLayout.getCurrentScrollTop(),
                scrollLeft: viewModel.viewLayout.getCurrentScrollLeft(),
                folding: foldingController.saveViewState()
            });
            if (outgoingListener != null) {
                outgoingListener.dispose();
                outgoingListener = null;
            }
            if (eventHandler != null) {
                viewModel.removeViewEventHandler(eventHandler);
            }
            viewModel.dispose();
            // Monaco's `_detachModel`: the decorations of this editor go
            model.removeAllDecorationsWithOwnerId(editorId);
        }
        this.viewModel = null;
        this.eventHandler = null;
    }

    function createLineBreaksComputerFactory():MonospaceLineBreaksComputerFactory {
        final options = configuration.options;
        return MonospaceLineBreaksComputerFactory.create(options.get(EditorOption.wordWrapBreakBeforeCharacters), options.get(EditorOption.wordWrapBreakAfterCharacters));
    }

    /**
     * The events of the view model as editor events (Monaco's
     * `CodeEditorWidget` turns them into its own events).
     */
    function onOutgoingEvent(e:OutgoingViewModelEvent):Void {
        switch (e.kind) {
            case OutgoingViewModelEventKind.ModelContentChanged:
                _onDidChangeModelContent.fire((cast e : ModelContentChangedEvent).event);
            case OutgoingViewModelEventKind.CursorStateChanged:
                _onDidChangeCursorPosition.fire();
            case OutgoingViewModelEventKind.ModelLanguageConfigurationChanged:
                _onDidChangeModelLanguageConfiguration.fire();
            case _:
        }
    }

    public function updateOptions(options:IEditorOptions):Void {
        configuration.updateOptions(options);
        renderCache = new Map();
        notifyChanged();
    }

    public function setWrappingIndentColumns(value:Int):Void {
        if (wrappingIndentColumns == value) {
            return;
        }
        wrappingIndentColumns = value;
        if (viewModel != null) {
            viewModel.setWrappingIndentColumns(value);
        }
        renderCache = new Map();
        notifyChanged();
    }

    @:allow(cityscape.view.CityscapeViewEventHandler)
    function onViewEvents(flush:Bool):Void {
        if (flush) {
            renderCache = new Map();
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

    //#endregion

    //#region layout and rendering

    /**
     * Called by the element at prepaint with its bounds (window coordinates).
     */
    public function layoutTo(bounds:Bounds, scaleFactor:Float):Void {
        elementBounds = bounds;
        if (configuration.pixelRatio != scaleFactor) {
            configuration.pixelRatio = scaleFactor;
            configuration.recomputeOptions();
        }
        configuration.observeContainer({width: bounds.size.width, height: bounds.size.height});
    }

    public inline function fontInfo():FontInfo {
        return configuration.options.get(EditorOption.fontInfo);
    }

    function baseFont(weight:Null<Float>, italic:Bool, features:Null<String>):Font {
        final info = fontInfo();
        final w = weight != null ? weight : EditorFontMeasurements.parseFontWeight(info.fontWeight);
        final f = EditorFontMeasurements.parseFontFeatureSettings(features != null ? features : info.fontFeatureSettings);
        return measurements.resolveEditorFont(info.fontFamily, w, italic, f);
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
            for (s in viewModel.getViewSelections()) {
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
     * input, the fonts and the theme stay the same).
     */
    public function renderViewLine(viewLineNumber:Int, ?visibleRange:Range):RenderedViewLine {
        final created = createRenderLineInput(viewLineNumber, visibleRange);
        final input = created.input;
        final fontGeneration = app.textSystem().fontGeneration;
        final cached = renderCache.get(viewLineNumber);
        if (cached != null && cached.fontGeneration == fontGeneration && cached.themeVersion == theme.version && cached.input.equals(input)) {
            return cached;
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
        renderCache.set(viewLineNumber, rendered);
        if (layout.width > maxLineWidth) {
            maxLineWidth = layout.width;
            viewModel.viewLayout.setMaxLineWidth(maxLineWidth);
        }
        return rendered;
    }

    /**
     * Drops the cached lines outside `[start, end]` (called after a paint).
     */
    public function trimRenderCache(start:Int, end:Int):Void {
        final remove = [for (k in renderCache.keys()) if (k < start - 20 || k > end + 20) k];
        for (k in remove) {
            renderCache.remove(k);
        }
    }

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

    /**
     * Monaco's mouse target (`MouseTargetFactory`, in model coordinates like
     * the targets of the editor's mouse events): the margin parts, the text,
     * or the empty content after a line or after the lines.
     */
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
        return new MouseTarget(MouseTargetType.CONTENT_TEXT, position, mouseColumn, Range.fromPositions(position, position));
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

    function editorMouseEvent(button:glaze.MouseButton, position:Point, modifiers:glaze.Modifiers, clickCount:Int):EditorMouseEvent {
        final data = new EditorMouseEventData(
            button == glaze.MouseButton.Left,
            button == glaze.MouseButton.Middle,
            button == glaze.MouseButton.Right,
            modifiers.control,
            modifiers.shift,
            modifiers.alt,
            modifiers.platform,
            clickCount
        );
        return new EditorMouseEvent(data, mouseTargetAt(position));
    }

    public function handleMouseDown(event:MouseDownEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final e = editorMouseEvent(event.button, event.position, event.modifiers, event.clickCount);
        final type = e.target.type;
        // Monaco's `MouseHandler._onMouseDown`: the content and the line
        // numbers start a mouse down operation; the rest of the gutter does
        // not steal the focus nor move the cursor
        if (event.button == glaze.MouseButton.Left && (type == MouseTargetType.CONTENT_TEXT || type == MouseTargetType.CONTENT_EMPTY || type == MouseTargetType.GUTTER_LINE_NUMBERS)) {
            focusHandle.focus(window, cx);
            mouseDown = true;
            mouseDownCount = event.clickCount;
            mouseDownAlt = event.modifiers.alt;
            mouseDownShift = event.modifiers.shift;
            dispatchMouse(event.position, event.modifiers.shift, mouseDownCount, mouseDownAlt, mouseDownShift);
            restartBlink();
        }
        _onMouseDown.fire(e);
        notifyChanged();
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
            return;
        }
        dispatchMouse(event.position, true, mouseDownCount, mouseDownAlt, mouseDownShift);
        viewModel.revealPrimaryCursor('mouse', true, true);
        notifyChanged();
    }

    /**
     * Called when the mouse enters or leaves the editor.
     */
    public function handleHover(hovered:Bool):Void {
        if (!hovered) {
            setGutterHovered(false);
        }
    }

    function setGutterHovered(hovered:Bool):Void {
        if (gutterHovered != hovered) {
            gutterHovered = hovered;
            notifyChanged();
        }
    }

    public function handleMouseUp(event:MouseUpEvent, window:Window, cx:App):Void {
        if (event.button == glaze.MouseButton.Left) {
            mouseDown = false;
        }
        if (viewModel != null) {
            _onMouseUp.fire(editorMouseEvent(event.button, event.position, event.modifiers, event.clickCount));
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

    //#region cursor blink

    function stopBlink():Void {
        if (blinkStop != null) {
            blinkStop();
            blinkStop = null;
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
    }

    //#endregion

    //#region editing: Monaco's commands (ICodeEditor)

    public function _getViewModel():Null<IViewModel> {
        return this.viewModel;
    }

    public function getTextModel():Null<ITextModel> {
        return this.model;
    }

    public function getOption<V>(id:EditorOption<V>):V {
        return configuration.options.get(id);
    }

    public function getSelections():Null<Array<Selection>> {
        return viewModel != null ? viewModel.getSelections() : null;
    }

    public function revealPosition(position:IPosition, ?scrollType:ScrollType):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final validated = model.validatePosition(position);
        final viewRange = viewModel.coordinatesConverter.convertModelRangeToViewRange(new Range(validated.lineNumber, validated.column, validated.lineNumber, validated.column));
        viewModel.revealRange('api', true, viewRange, VerticalRevealType.Simple, scrollType != null ? scrollType : ScrollType.Smooth);
    }

    //#endregion

    //#region the editor of the contributions (IFoldingEditor)

    public function getFoldingContext():Cityscape {
        return context;
    }

    public function getContribution(id:String):Null<Any> {
        return contributions.get(id);
    }

    public function getModel():Null<ITextModel> {
        return this.model;
    }

    public function getSelection():Null<Selection> {
        return viewModel != null ? viewModel.getSelection() : null;
    }

    public function getPosition():Null<Position> {
        return viewModel != null ? viewModel.getPosition() : null;
    }

    public function setSelections(selections:Array<Selection>):Void {
        if (viewModel != null) {
            viewModel.setSelections('api', selections);
            notifyChanged();
        }
    }

    public function setSelection(selection:Selection):Void {
        setSelections([selection]);
    }

    public function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T> {
        if (model == null) {
            // callback will not be called
            return null;
        }
        final result = model.changeDecorations(callback, editorId);
        notifyChanged();
        return result;
    }

    public function removeDecorations(decorationIds:Array<String>):Void {
        if (model == null || decorationIds.length == 0) {
            return;
        }
        model.changeDecorations(changeAccessor -> changeAccessor.deltaDecorations(decorationIds, []), editorId);
        notifyChanged();
    }

    public function setHiddenAreas(ranges:Array<Range>, source:Any):Void {
        if (viewModel != null) {
            viewModel.setHiddenAreas(ranges, source);
            notifyChanged();
        }
    }

    public function revealPositionInCenterIfOutsideViewport(position:Position, ?scrollType:ScrollType):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final validated = model.validatePosition(position);
        final viewRange = viewModel.coordinatesConverter.convertModelRangeToViewRange(new Range(validated.lineNumber, validated.column, validated.lineNumber, validated.column));
        viewModel.revealRange('api', true, viewRange, VerticalRevealType.CenterIfOutsideViewport, scrollType != null ? scrollType : ScrollType.Smooth);
    }

    public function getScrollTop():Float {
        return viewModel != null ? viewModel.viewLayout.getCurrentScrollTop() : 0;
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void {
        if (viewModel != null) {
            viewModel.viewLayout.setScrollPosition({scrollTop: newScrollTop}, scrollType != null ? scrollType : ScrollType.Immediate);
            notifyChanged();
        }
    }

    public function hasPendingScrollAnimation():Bool {
        // smooth scrolling is the kit's (no pending Monaco animation)
        return false;
    }

    public function getContentHeight():Float {
        if (viewModel == null) {
            return -1;
        }
        final layout = Std.downcast(viewModel.viewLayout, ViewLayout);
        return layout != null ? layout.getContentHeight() : viewModel.viewLayout.getScrollHeight();
    }

    public function getVisibleRanges():Array<Range> {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return [];
        }
        final data = viewModel.viewLayout.getLinesViewportData();
        final viewRange = new Range(data.startLineNumber, viewModel.getLineMinColumn(data.startLineNumber), data.endLineNumber, viewModel.getLineMaxColumn(data.endLineNumber));
        return [viewModel.coordinatesConverter.convertViewRangeToModelRange(viewRange)];
    }

    public function getTopForLineNumber(lineNumber:Int):Float {
        return getTopForPosition(lineNumber, 1);
    }

    public function getTopForPosition(lineNumber:Int, column:Int):Float {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return -1;
        }
        final validated = model.validatePosition(new Position(lineNumber, column));
        final viewPosition = viewModel.coordinatesConverter.convertModelPositionToViewPosition(validated);
        return viewModel.viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber);
    }

    public function onDidChangeModel(listener:() -> Void):IDisposable {
        return _onDidChangeModel.event(listener);
    }

    public function onDidChangeConfiguration(listener:(e:ConfigurationChangedEvent) -> Void):IDisposable {
        return configuration.onDidChange(listener);
    }

    public function onDidChangeModelLanguageConfiguration(listener:() -> Void):IDisposable {
        return _onDidChangeModelLanguageConfiguration.event(listener);
    }

    public function onDidChangeModelContent(listener:(e:IModelContentChangedEvent) -> Void):IDisposable {
        return _onDidChangeModelContent.event(listener);
    }

    public function onDidChangeCursorPosition(listener:() -> Void):IDisposable {
        return _onDidChangeCursorPosition.event(listener);
    }

    public function onMouseDown(listener:(e:EditorMouseEvent) -> Void):IDisposable {
        return _onMouseDown.event(listener);
    }

    public function onMouseUp(listener:(e:EditorMouseEvent) -> Void):IDisposable {
        return _onMouseUp.event(listener);
    }

    /**
     * Runs a folding command by its Monaco id (`editor.fold`,
     * `editor.foldAll`, `editor.foldLevel2`...).
     * TODO(step 3, commands): through the command registry of the editor.
     */
    public function runFoldingCommand(id:String, ?args:FoldingArguments):Bool {
        final result = FoldingCommands.run(this, id, args);
        notifyChanged();
        return result;
    }

    //#endregion

    //#region editing: Monaco's commands (ICodeEditor)

    public function pushUndoStop():Bool {
        if (model == null || configuration.options.get(EditorOption.readOnly)) {
            // read only editor => sorry!
            return false;
        }
        model.pushStackElement();
        return true;
    }

    public function executeCommands(source:Null<String>, commands:Array<Null<ICommand>>):Void {
        if (viewModel == null) {
            return;
        }
        viewModel.executeCommands(commands, source);
    }

    /**
     * Types text at the cursors (Monaco's `Handler.Type` from the keyboard:
     * auto closing, auto indentation, electric characters...).
     */
    public function type(text:String):Void {
        final viewModel = this.viewModel;
        if (viewModel == null || text.length == 0) {
            return;
        }
        viewModel.type(text, 'keyboard');
        restartBlink();
    }

    function runCommand(command:EditorCommand):Void {
        command.runEditorCommand(context, this, null);
    }

    function copySelection(cx:App):Null<String> {
        final viewModel = this.viewModel;
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
        // The metadata of the last copy applies to its own text only
        final fromLastCopy = (lastCopiedText != null && lastCopiedText == text);
        final pasteOnNewLine = fromLastCopy && lastCopiedIsFromEmptySelection;
        final multicursorText = fromLastCopy ? lastCopiedMulticursorText : null;
        viewModel.paste(text, pasteOnNewLine, multicursorText, 'keyboard');
        viewModel.revealPrimaryCursor('keyboard', true);
    }

    /**
     * The keys of Monaco's default keybindings that the editor handles
     * (moves, selections, edits, clipboard, undo).
     */
    public function onKeyDown(event:KeyDownEvent, window:Window, cx:App):Void {
        final viewModel = this.viewModel;
        if (viewModel == null) {
            return;
        }
        final ks = event.keystroke;
        // The folding actions (Monaco's keybindings of folding.ts)
        if (foldingKeybindings.handleKeyDown(this, ks)) {
            restartBlink();
            cx.stopPropagation();
            notifyChanged();
            return;
        }
        final mods = ks.modifiers;
        final shift = mods.shift;
        final mac = Platform.isMac();
        // Cmd on macOS, Ctrl elsewhere
        final platform = mods.platform || (mods.control && !mac);
        // The word modifier: Alt on macOS, Ctrl elsewhere
        final word = mac ? mods.alt : mods.control;
        var handled = true;
        switch (ks.key) {
            case 'backspace':
                if (word) {
                    runCommand(WordCommands.deleteWordLeft);
                }
                else {
                    runCommand(CoreEditingCommands.DeleteLeft);
                }
            case 'delete':
                if (word) {
                    runCommand(WordCommands.deleteWordRight);
                }
                else {
                    runCommand(CoreEditingCommands.DeleteRight);
                }
            case 'enter':
                type('\n');
            case 'tab':
                runCommand(shift ? CoreEditingCommands.Outdent : CoreEditingCommands.Tab);
            case 'escape':
                if (viewModel.getSelections().length > 1) {
                    CoreNavigationCommands.RemoveSecondaryCursors.runCoreEditorCommand(viewModel, {source: 'keyboard'});
                }
                else {
                    CoreNavigationCommands.CancelSelection.runCoreEditorCommand(viewModel, {source: 'keyboard'});
                }
            case 'left':
                if (mac && mods.platform) {
                    runCommand(shift ? CoreNavigationCommands.CursorHomeSelect : CoreNavigationCommands.CursorHome);
                }
                else if (word) {
                    runCommand(shift ? WordCommands.cursorWordLeftSelect : WordCommands.cursorWordLeft);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorLeftSelect : CoreNavigationCommands.CursorLeft);
                }
            case 'right':
                if (mac && mods.platform) {
                    runCommand(shift ? CoreNavigationCommands.CursorEndSelect : CoreNavigationCommands.CursorEnd);
                }
                else if (word) {
                    runCommand(shift ? WordCommands.cursorWordEndRightSelect : WordCommands.cursorWordEndRight);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorRightSelect : CoreNavigationCommands.CursorRight);
                }
            case 'up':
                if (mac && mods.platform) {
                    runCommand(shift ? CoreNavigationCommands.CursorTopSelect : CoreNavigationCommands.CursorTop);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorUpSelect : CoreNavigationCommands.CursorUp);
                }
            case 'down':
                if (mac && mods.platform) {
                    runCommand(shift ? CoreNavigationCommands.CursorBottomSelect : CoreNavigationCommands.CursorBottom);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorDownSelect : CoreNavigationCommands.CursorDown);
                }
            case 'home':
                if (mods.control && !mac) {
                    runCommand(shift ? CoreNavigationCommands.CursorTopSelect : CoreNavigationCommands.CursorTop);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorHomeSelect : CoreNavigationCommands.CursorHome);
                }
            case 'end':
                if (mods.control && !mac) {
                    runCommand(shift ? CoreNavigationCommands.CursorBottomSelect : CoreNavigationCommands.CursorBottom);
                }
                else {
                    runCommand(shift ? CoreNavigationCommands.CursorEndSelect : CoreNavigationCommands.CursorEnd);
                }
            case 'pageup':
                runCommand(shift ? CoreNavigationCommands.CursorPageUpSelect : CoreNavigationCommands.CursorPageUp);
            case 'pagedown':
                runCommand(shift ? CoreNavigationCommands.CursorPageDownSelect : CoreNavigationCommands.CursorPageDown);
            case 'a' if (platform):
                CoreNavigationCommands.SelectAll.runCoreEditorCommand(viewModel, {});
            case 'c' if (platform):
                copySelection(cx);
            case 'x' if (platform):
                copySelection(cx);
                viewModel.cut('keyboard');
            case 'v' if (platform):
                final item = cx.readFromClipboard();
                final text = item != null ? item.text() : null;
                if (text != null) {
                    pasteText(text);
                }
            case 'z' if (platform):
                runCommand(shift ? CoreEditingCommands.Redo : CoreEditingCommands.Undo);
            case 'y' if (platform && !mac):
                runCommand(CoreEditingCommands.Redo);
            case _:
                handled = false;
        }
        if (handled) {
            restartBlink();
            cx.stopPropagation();
            notifyChanged();
        }
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
        viewModel.type(text, source);
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

private class Platform {
    public static inline function isMac():Bool {
        return cityscape.base.common.Platform.isMacintosh;
    }
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
        for (e in events) {
            switch (e.type) {
                case ViewEventType.ViewFlushed | ViewEventType.ViewLinesInserted | ViewEventType.ViewLinesDeleted | ViewEventType.ViewLineMappingChanged | ViewEventType.ViewConfigurationChanged | ViewEventType.ViewThemeChanged | ViewEventType.ViewTokensColorsChanged:
                    flush = true;
                case ViewEventType.ViewRevealRangeRequest:
                    view.onRevealRange(cast e);
                case _:
            }
        }
        view.onViewEvents(flush);
    }

}

/**
 * The kit scrollbar handle of a Cityscape view: GPUI offsets (0 at the top,
 * negative down) over Monaco's scroll position (AUDIT B.1).
 */
class CityscapeScrollHandle implements ScrollbarHandleImpl {

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
        return new Size(viewModel.viewLayout.getScrollWidth(), viewModel.viewLayout.getScrollHeight());
    }

    public function startDrag():Void {
        dragging = true;
    }

    public function endDrag():Void {
        dragging = false;
    }

}

/**
 * The word commands the keys of the view run (immutable, shared).
 */
private class WordCommands {
    public static final cursorWordLeft = new CursorWordLeft();
    public static final cursorWordLeftSelect = new CursorWordLeftSelect();
    public static final cursorWordEndRight = new CursorWordEndRight();
    public static final cursorWordEndRightSelect = new CursorWordEndRightSelect();
    public static final deleteWordLeft = new DeleteWordLeft();
    public static final deleteWordRight = new DeleteWordRight();
}
