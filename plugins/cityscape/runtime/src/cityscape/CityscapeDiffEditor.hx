// New code for Cityscape (not a port): the diff editor as a persistent Glaze
// component, with the API of Monaco's standalone diff editor
// (monaco.editor.createDiffEditor, IStandaloneDiffEditor), over the port of
// Monaco's DiffEditorWidget (view/widget/diffEditor). The painting of its
// view zones, of the bars of the hidden regions and of the overview ruler
// follows style.css and overviewRulerFeature.ts.
package cityscape;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.diff.LegacyLinesDiffComputer.IDiffComputationResult;
import cityscape.common.diff.LegacyLinesDiffComputer.ILineChange;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import cityscape.view.Codicons;
import cityscape.view.EditorBrowser;
import cityscape.view.ViewTheme;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorDecorations.DiffEditorStyles;
import cityscape.view.widget.diffEditor.DiffEditorOptions;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;
import cityscape.view.widget.diffEditor.DiffEditorWidget;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService.DiffComputationMode;
import glaze.App;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.LinePaint;
import glaze.MouseButton;
import glaze.Point;
import glaze.Size;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.TextAlign;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A Cityscape diff editor: the original text on the left and the modified
 * text on the right (side by side), or the modified text with the deleted
 * lines between its lines (inline view, `renderSideBySide: false`, also
 * used when the editor is narrower than `renderSideBySideInlineBreakpoint`),
 * placed in a Glaze UI and sized by the flex layout of its parent:
 *
 * ```haxe
 * CityscapeDiffEditor.component()
 *     .model({original: originalModel, modified: modifiedModel})
 *     .options({ignoreTrimWhitespace: false, hideUnchangedRegions: {enabled: true}})
 *     .flex1()
 * ```
 *
 * The diff is computed off the frame (a background thread on the native
 * targets, the next frame on the web) and again 200 ms after an edit, like
 * Monaco's. The methods are Monaco's `IStandaloneDiffEditor`
 * (`setModel`, `getLineChanges`, `getOriginalEditor`, `getModifiedEditor`,
 * `onDidUpdateDiff`, `updateOptions`, `goToDiff`...). The two editors are
 * `CityscapeEditor`s (null before the first render).
 */
class CityscapeDiffEditor extends glaze.Component implements Styled {

    /**
     * The two models (Monaco's `setModel({original, modified})`).
     */
    @prop(unobserved) var model:Null<IDiffEditorModel> = null;

    /**
     * Monaco's diff editor options (`IDiffEditorOptions`: the options of the
     * two editors and the diff options), applied with `updateOptions` when
     * they change.
     */
    @prop(unobserved) var options:Null<IDiffEditorOptions> = null;

    /**
     * The context (languages, themes, keybindings). When null: the context
     * of the original model when it is a `TextModel`, else the default one.
     */
    @prop(unobserved) var context:Null<Cityscape> = null;

    /**
     * Where the diff is computed (null: a background thread on the native
     * targets, the next frame on the web; `'synchronous'` for tests).
     */
    @prop(unobserved) var computationMode:Null<DiffComputationMode> = null;

    /**
     * Called once with the diff editor, when its two editors exist (after
     * the first layout).
     */
    @prop(unobserved) var onCreate:Null<(editor:CityscapeDiffEditor) -> Void> = null;

    /**
     * The style of the diff editor's root element (`Styled`).
     */
    @prop(unobserved) var surfaceStyle:Null<StyleRefinement> = null;

    /**
     * Incremented when the diff editor paints something new (the diff, the
     * hidden regions, the scroll position of the overview ruler).
     */
    @observe var revision:Int = 0;

    var originalEditor:Null<CityscapeEditor> = null;
    var modifiedEditor:Null<CityscapeEditor> = null;
    var widget:Null<DiffEditorWidget> = null;
    var theme:Null<ViewTheme> = null;
    var painters:Null<DiffPainters> = null;
    final ownDisposables = new DisposableStore();
    final registeredStyles = new Map<String, Bool>();
    var stylesThemeVersion:Int = -1;
    var appliedModel:Null<IDiffEditorModel> = null;
    var appliedOptions:Null<IDiffEditorOptions> = null;
    var lastWidth:Float = -1;
    var rulerBounds:Null<Bounds> = null;
    var rulerDragging:Bool = false;
    var rulerDragOffset:Float = 0;

    final _onDidUpdateDiff = new VoidEmitter();

    public function style():StyleRefinement {
        var style = surfaceStyle;
        if (style == null) {
            style = new StyleRefinement();
            (this : CityscapeDiffEditor).surfaceStyle(style);
        }
        return style;
    }

    override public function destroy():Void {
        ownDisposables.dispose();
        final w = widget;
        widget = null;
        if (w != null) {
            w.dispose();
        }
        final t = theme;
        theme = null;
        if (t != null) {
            t.dispose();
        }
        _onDidUpdateDiff.dispose();
    }

    function contextOf():Cityscape {
        if (context != null) {
            return context;
        }
        final m = model;
        if (m != null && Std.isOfType(m.original, TextModel)) {
            return (cast m.original : TextModel).context;
        }
        return Cityscape.defaultContext;
    }

    function onEditorCreated():Void {
        if (widget != null || originalEditor == null || modifiedEditor == null) {
            return;
        }
        final ctx = contextOf();
        theme = new ViewTheme(ctx.themeService, ctx.tokenizationRegistry);
        final painters = new DiffPainters(this);
        this.painters = painters;
        final w = new DiffEditorWidget(cast originalEditor.getEditor(), cast modifiedEditor.getEditor(), options, painters);
        w.computationMode = computationMode;
        final originalCityscapeEditor = originalEditor;
        final modifiedCityscapeEditor = modifiedEditor;
        w.applyOriginalOptions = (o) -> originalCityscapeEditor.updateOptions(o);
        w.applyModifiedOptions = (o) -> modifiedCityscapeEditor.updateOptions(o);
        // the options are applied again with the routes of the component
        @:privateAccess w._updateEditorOptions();
        widget = w;
        appliedOptions = options;
        ownDisposables.add(w.onDidChange(() -> {
            revision++;
        }));
        ownDisposables.add(w.onDidUpdateDiff(() -> _onDidUpdateDiff.fire()));
        ownDisposables.add(w.modified.onDidScrollChange((_) -> revision++));
        updateStyles();
        appliedModel = model;
        if (model != null) {
            w.setModel(model);
        }
        final callback = onCreate;
        if (callback != null) {
            callback(this);
        }
    }

    function updateStyles():Void {
        final t = theme;
        if (t != null && t.version != stylesThemeVersion) {
            stylesThemeVersion = t.version;
            DiffEditorStyles.update(contextOf(), t, registeredStyles);
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final w = widget;
        if (w != null) {
            if (model != appliedModel) {
                appliedModel = model;
                w.setModel(model);
            }
            if (options != appliedOptions) {
                appliedOptions = options;
                if (options != null) {
                    w.updateOptions(options);
                }
            }
            updateStyles();
        }
        final ctx = contextOf();
        final diffOptions = w != null ? w.getOptions() : new DiffEditorOptions(options);
        final sideBySide = diffOptions.renderSideBySide;
        final showRuler = diffOptions.renderOverviewRuler;

        // The original editor: the left part (side by side), or the margin
        // of the original line numbers (inline view)
        final original = CityscapeEditor.component().at('original').context(ctx).onCreate(e -> {
            originalEditor = e;
            onEditorCreated();
        });
        final modified = CityscapeEditor.component().at('modified').context(ctx).onCreate(e -> {
            modifiedEditor = e;
            onEditorCreated();
        });

        final originalContainer = div().relative().flex().flexCol().minW0().minH0().overflowHidden();
        if (sideBySide) {
            originalContainer.w(relative(diffOptions.splitViewDefaultRatio));
        }
        else {
            var width = 0.0;
            if (!diffOptions.inlineViewHideOriginalLineNumbers && originalEditor != null && originalEditor.getEditor() != null) {
                width = Math.max(5, originalEditor.getLayoutInfo().decorationsLeft);
            }
            originalContainer.w(px(width)).flexShrink0();
        }
        originalContainer.child(original.flex1());

        final modifiedContainer = div().relative().flex().flexCol().flex1().minW0().minH0().overflowHidden();
        final border = theme != null ? theme.getColor('diffEditor.border') : null;
        if (sideBySide && border != null) {
            modifiedContainer.borderL(px(1)).borderColor(border);
        }
        modifiedContainer.child(modified.flex1());

        final editors = div().flex().flexRow().flex1().minW0().minH0()
            .child(originalContainer)
            .child(modifiedContainer);

        final root = div()
            .id('cityscape-diff-editor')
            .relative()
            .flex()
            .flexRow()
            .minW0()
            .minH0()
            .overflowHidden()
            .child(editors);
        if (showRuler) {
            root.child(
                div().w(px(OverviewRulerFeature.ENTIRE_DIFF_OVERVIEW_WIDTH)).flexShrink0().relative()
                    .onMouseDown(MouseButton.Left, (event, window, cx) -> onRulerMouseDown(event.position.y))
                    .onMouseMove((event, window, cx) -> onRulerMouseMove(event.position.y))
                    .onMouseUp(MouseButton.Left, (event, window, cx) -> rulerDragging = false)
                    .child(canvas((bounds, window, cx) -> {
                        rulerBounds = bounds;
                        return null;
                    }, (bounds, _, window, cx) -> paintOverviewRuler(bounds, window)).absolute().top0().left0().right0().bottom0())
            );
        }
        // The width of the diff editor, for the inline breakpoint
        root.child(canvas((bounds, window, cx) -> {
            reportWidth(bounds.size.width);
            return null;
        }, (_, _, _, _) -> {}).absolute().top0().left0().right0().h(px(0)));
        // read for the cache: a new revision renders again
        final _ = revision;
        final s = surfaceStyle;
        if (s != null) {
            root.refineStyle(s);
        }
        return root;
    }

    function reportWidth(width:Float):Void {
        if (width == lastWidth) {
            return;
        }
        lastWidth = width;
        final w = widget;
        if (w != null) {
            w.setWidth(width);
        }
    }

    //#region overview ruler (overviewRulerFeature.ts)

    function rulerColors():{insertColor:Null<Hsla>, removeColor:Null<Hsla>} {
        final t = theme;
        if (t == null) {
            return {insertColor: null, removeColor: null};
        }
        // `theme.getColor(diffOverviewRulerInserted) || (theme.getColor(diffInserted) || defaultInsertColor).transparent(2)`
        var insertColor = t.getColor('diffEditorOverview.insertedForeground');
        if (insertColor == null) {
            final c = t.getColor('diffEditor.insertedTextBackground');
            insertColor = c != null ? c.opacity(2) : Hsla.fromRgba(rgba(0x9bb95566));
        }
        var removeColor = t.getColor('diffEditorOverview.removedForeground');
        if (removeColor == null) {
            final c = t.getColor('diffEditor.removedTextBackground');
            removeColor = c != null ? c.opacity(2) : Hsla.fromRgba(rgba(0xff000066));
        }
        return {insertColor: insertColor, removeColor: removeColor};
    }

    function paintOverviewRuler(bounds:Bounds, window:Window):Void {
        final w = widget;
        final t = theme;
        if (w == null || t == null) {
            return;
        }
        // `.diffOverview` background (style.css: vs and vs-dark)
        final background = t.getColor('editor.background');
        final dark = background == null || background.l < 0.5;
        fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, dark ? hsla(0, 0, 1, 0.01) : hsla(0, 0, 0, 0.03));

        final colors = rulerColors();
        final viewModel = w.getViewModel();
        final diff = viewModel != null ? viewModel.diff : null;
        final mappings = diff != null ? diff.mappings : [];
        final one = OverviewRulerFeature.ONE_OVERVIEW_WIDTH;
        paintRulerZones(window, w.original, mappings.map(d -> (d.lineRangeMapping.original : LineRange)), colors.removeColor, bounds.origin.x, bounds.origin.y, one, bounds.size.height);
        paintRulerZones(window, w.modified, mappings.map(d -> (d.lineRangeMapping.modified : LineRange)), colors.insertColor, bounds.origin.x + one, bounds.origin.y, one, bounds.size.height);

        // `.diffViewport`: the visible part of the modified editor (ScrollbarState)
        final slider = sliderOf(w.modified, bounds.size.height);
        final sliderColor = t.getColor('scrollbarSlider.background');
        if (sliderColor != null && slider.size > 0) {
            fillRect(window, bounds.origin.x, bounds.origin.y + slider.position, bounds.size.width, slider.size, sliderColor);
        }
    }

    function paintRulerZones(window:Window, editor:CodeEditorWidget, ranges:Array<LineRange>, color:Null<Hsla>, x:Float, y:Float, width:Float, height:Float):Void {
        final vm = editor._getViewModel();
        if (vm == null || color == null) {
            return;
        }
        final lineHeight:Float = Math.floor(editor.getOption(EditorOption.lineHeight));
        final outerHeight = Math.max(1, vm.viewLayout.getScrollHeight());
        final heightRatio = height / outerHeight;
        final halfMinimumHeight = 2.0;
        for (r in ranges) {
            if (r.length <= 0) {
                continue;
            }
            final start = vm.coordinatesConverter.convertModelPositionToViewPosition(new Position(r.startLineNumber, 1));
            final end = vm.coordinatesConverter.convertModelPositionToViewPosition(new Position(r.endLineNumberExclusive, 1));
            // By computing the lineCount, we won't ask the view model later for the bottom vertical position.
            final lineCount = end.lineNumber - start.lineNumber;
            final offset1 = vm.viewLayout.getVerticalOffsetForLineNumber(start.lineNumber);
            final offset2 = lineCount == 0 ? vm.viewLayout.getVerticalOffsetForLineNumber(end.lineNumber) + lineHeight : offset1 + lineCount * lineHeight;
            final y1 = heightRatio * offset1;
            final y2 = heightRatio * offset2;
            var ycenter = (y1 + y2) / 2;
            var halfHeight = y2 - ycenter;
            if (halfHeight < halfMinimumHeight) {
                halfHeight = halfMinimumHeight;
            }
            if (ycenter - halfHeight < 0) {
                ycenter = halfHeight;
            }
            if (ycenter + halfHeight > height) {
                ycenter = height - halfHeight;
            }
            fillRect(window, x, y + ycenter - halfHeight, width, halfHeight * 2, color);
        }
    }

    /**
     * Monaco's `ScrollbarState` of the modified editor (no arrows).
     */
    static function sliderOf(editor:CodeEditorWidget, visibleSize:Float):{position:Float, size:Float, ratio:Float} {
        final scrollSize = editor.getScrollHeight();
        final scrollPosition = editor.getScrollTop();
        final computedRepresentableSize = Math.max(0, visibleSize);
        if (!(scrollSize > 0 && scrollSize > visibleSize)) {
            return {position: 0, size: Math.round(computedRepresentableSize), ratio: 0};
        }
        final computedSliderSize = Math.round(Math.max(20, Math.floor(visibleSize * computedRepresentableSize / scrollSize)));
        final computedSliderRatio = (computedRepresentableSize - computedSliderSize) / (scrollSize - visibleSize);
        return {position: Math.round(scrollPosition * computedSliderRatio), size: computedSliderSize, ratio: computedSliderRatio};
    }

    /**
     * Monaco delegates the pointer down to the scrollbar of the modified
     * editor: outside the slider, the slider is centered on the pointer,
     * then dragged.
     */
    function onRulerMouseDown(y:Float):Void {
        final w = widget;
        final b = rulerBounds;
        if (w == null || b == null) {
            return;
        }
        final slider = sliderOf(w.modified, b.size.height);
        final relativeY = y - b.origin.y;
        if (relativeY >= slider.position && relativeY < slider.position + slider.size) {
            rulerDragOffset = relativeY - slider.position;
        }
        else {
            rulerDragOffset = slider.size / 2;
            scrollRulerTo(relativeY);
        }
        rulerDragging = true;
    }

    function onRulerMouseMove(y:Float):Void {
        if (!rulerDragging) {
            return;
        }
        final b = rulerBounds;
        if (b == null) {
            return;
        }
        scrollRulerTo(y - b.origin.y);
    }

    function scrollRulerTo(relativeY:Float):Void {
        final w = widget;
        final b = rulerBounds;
        if (w == null || b == null) {
            return;
        }
        final slider = sliderOf(w.modified, b.size.height);
        if (slider.ratio <= 0) {
            return;
        }
        final desiredSliderPosition = relativeY - rulerDragOffset;
        w.modified.setScrollTop(Math.max(0, desiredSliderPosition / slider.ratio), cityscape.common.EditorCommon.ScrollType.Immediate);
    }

    //#endregion

    @:noCompletion public static inline function fillRect(window:Window, x:Float, y:Float, w:Float, h:Float, color:Null<Hsla>):Void {
        if (w <= 0 || h <= 0 || color == null) {
            return;
        }
        window.paintQuad(fill(new Bounds(new Point(x, y), new Size(w, h)), color));
    }

    @:noCompletion public function localize(key:String, defaultMessage:String, args:Array<Any>):String {
        return contextOf().nls.localize(key, defaultMessage, args);
    }

    //#region IStandaloneDiffEditor

    /**
     * The diff editor's logic (Monaco's `DiffEditorWidget`), null before the
     * first render.
     */
    public function getWidget():Null<DiffEditorWidget> {
        return widget;
    }

    @:noCompletion public function getTheme():Null<ViewTheme> {
        return theme;
    }

    public function getOriginalEditor():Null<CityscapeEditor> {
        return originalEditor;
    }

    public function getModifiedEditor():Null<CityscapeEditor> {
        return modifiedEditor;
    }

    public function getModel():Null<IDiffEditorModel> {
        return widget != null ? widget.getModel() : model;
    }

    /**
     * Shows two models (the `model` prop shows them too).
     */
    public function setModel(model:Null<IDiffEditorModel>):Void {
        this.model = model;
        appliedModel = model;
        if (widget != null) {
            widget.setModel(model);
        }
    }

    public function updateOptions(newOptions:IDiffEditorOptions):Void {
        if (widget != null) {
            widget.updateOptions(newOptions);
        }
        else {
            final merged:Dynamic = {};
            for (o in [options, newOptions]) {
                if (o != null) {
                    for (field in Reflect.fields(o)) {
                        Reflect.setField(merged, field, Reflect.field(o, field));
                    }
                }
            }
            options = merged;
        }
    }

    /**
     * Fired when the diff changed (Monaco's `onDidUpdateDiff`).
     */
    public var onDidUpdateDiff(get, never):VoidEvent;
    inline function get_onDidUpdateDiff() return _onDidUpdateDiff.event;

    /**
     * The line changes (Monaco's `getLineChanges`), null before the first diff.
     */
    public function getLineChanges():Null<Array<ILineChange>> {
        return widget != null ? widget.getLineChanges() : null;
    }

    public function getDiffComputationResult():Null<IDiffComputationResult> {
        return widget != null ? widget.getDiffComputationResult() : null;
    }

    /**
     * Goes to the next (`'next'`) or previous (`'previous'`) change.
     */
    public function goToDiff(target:String):Void {
        if (widget != null) {
            widget.goToDiff(target);
        }
    }

    public function revealFirstDiff():Void {
        if (widget != null) {
            widget.revealFirstDiff();
        }
    }

    /**
     * Calls `callback` once the diff is up to date (Monaco's `waitForDiff`).
     */
    public function waitForDiff(callback:() -> Void):Void {
        if (widget != null) {
            widget.waitForDiff(callback);
        }
        else {
            callback();
        }
    }

    public function revert(diff:LineRangeMapping):Void {
        if (widget != null) {
            widget.revert(diff);
        }
    }

    public function switchSide():Void {
        if (widget != null) {
            widget.switchSide();
        }
    }

    public function collapseAllUnchangedRegions():Void {
        if (widget != null) {
            widget.collapseAllUnchangedRegions();
        }
    }

    public function showAllUnchangedRegions():Void {
        if (widget != null) {
            widget.showAllUnchangedRegions();
        }
    }

    public function saveViewState():Null<IDiffEditorViewState> {
        return widget != null ? widget.saveViewState() : null;
    }

    public function restoreViewState(state:Null<IDiffEditorViewState>):Void {
        if (widget != null) {
            widget.restoreViewState(state);
        }
    }

    public function hasTextFocus():Bool {
        return widget != null && widget.hasTextFocus();
    }

    public var ignoreTrimWhitespace(get, never):Bool;
    function get_ignoreTrimWhitespace():Bool {
        return widget != null ? widget.ignoreTrimWhitespace : true;
    }

    public var maxComputationTime(get, never):Int;
    function get_maxComputationTime():Int {
        return widget != null ? widget.maxComputationTime : 5000;
    }

    public var renderSideBySide(get, never):Bool;
    function get_renderSideBySide():Bool {
        return widget != null ? widget.renderSideBySide : true;
    }

    //#endregion

}

/**
 * What the diff editor paints in its view zones (style.css): the diagonal
 * fill of the empty side, the deleted lines of the inline view, their
 * margin, and the bars of the hidden regions.
 */
private class DiffPainters implements IDiffEditorPainters {

    final owner:CityscapeDiffEditor;

    public function new(owner:CityscapeDiffEditor) {
        this.owner = owner;
    }

    function color(id:String):Null<Hsla> {
        final t = owner.getTheme();
        return t != null ? t.getColor(id) : null;
    }

    /**
     * `.diagonal-fill`: `linear-gradient(-45deg, fill 12.5%, #0000 12.5%,
     * #0000 50%, fill 50%, fill 62.5%, #0000 62.5%, #0000 100%)` in 8 px
     * tiles from the top left of the zone: bands where `(x + y) mod 8` is
     * between 6 and 8.
     */
    public function diagonalFill():ViewZonePainter {
        return (window, cx, bounds) -> {
            final c = color('diffEditor.diagonalFill');
            if (c == null) {
                return;
            }
            final builder = glaze.PathBuilder.fill();
            final h = bounds.size.height;
            final x0 = bounds.origin.x;
            final y0 = bounds.origin.y;
            var band = 6.0;
            final last = bounds.size.width + h + 8;
            while (band < last) {
                builder.addPolygon([
                    new Point(x0 + band, y0),
                    new Point(x0 + band + 2, y0),
                    new Point(x0 + band + 2 - h, y0 + h),
                    new Point(x0 + band - h, y0 + h)
                ], true);
                band += 8;
            }
            try {
                window.paintPath(builder.build(), c);
            }
            catch (e:Dynamic) {}
        };
    }

    public function deletedCode(originalRange:LineRange, diff:DetailedLineRangeMapping):ViewZonePainter {
        return (window, cx, bounds) -> {
            final w = owner.getWidget();
            final originalEditor = owner.getOriginalEditor();
            if (w == null || originalEditor == null || originalEditor.getView() == null) {
                return;
            }
            final view:CityscapeView = originalEditor.getView();
            final viewModel = view.viewModel;
            if (viewModel == null) {
                return;
            }
            final lineHeight:Float = w.modified.getOption(EditorOption.lineHeight);
            final scrollLeft = w.modified.getScrollLeft();
            final lineBackground = color('diffEditor.removedLineBackground') != null ? color('diffEditor.removedLineBackground') : color('diffEditor.removedTextBackground');
            final charBackground = color('diffEditor.removedTextBackground');
            CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, lineBackground);
            final painter = window.textPainter();
            final lineCount = viewModel.model.getLineCount();
            for (i in 0...originalRange.length) {
                final modelLineNumber = originalRange.startLineNumber + i;
                if (modelLineNumber > lineCount) {
                    break;
                }
                final viewLineNumber = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelLineNumber, 1)).lineNumber;
                final line = view.renderViewLine(viewLineNumber);
                final x = bounds.origin.x - scrollLeft;
                final y = bounds.origin.y + i * lineHeight;
                // `char-delete` ranges of the line
                if (diff.innerChanges != null) {
                    for (c in diff.innerChanges) {
                        final r = c.originalRange;
                        if (r.startLineNumber > modelLineNumber || r.endLineNumber < modelLineNumber) {
                            continue;
                        }
                        final startColumn = r.startLineNumber == modelLineNumber ? r.startColumn : 1;
                        final endColumn = r.endLineNumber == modelLineNumber ? r.endColumn : viewModel.model.getLineMaxColumn(modelLineNumber);
                        final x1 = line.columnToX(startColumn);
                        final x2 = r.endLineNumber == modelLineNumber ? line.columnToX(endColumn) : line.layout.width;
                        CityscapeDiffEditor.fillRect(window, x + x1, y, Math.max(0, x2 - x1), lineHeight, charBackground);
                    }
                }
                LinePaint.paintLineAligned(new Point(x, y), line.layout, lineHeight, TextAlign.Left, line.layout.width, line.decorationRuns, null, painter, null);
            }
        };
    }

    public function deletedCodeMargin(lineCount:Int, renderIndicators:Bool):ViewZonePainter {
        return (window, cx, bounds) -> {
            final w = owner.getWidget();
            if (w == null) {
                return;
            }
            // `.inline-deleted-margin-view-zone` has the `gutter-delete` background
            CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, gutterDeleteColor());
            if (!renderIndicators) {
                return;
            }
            final layoutInfo = w.modified.getLayoutInfo();
            final lineHeight:Float = w.modified.getOption(EditorOption.lineHeight);
            final signColor = color('editor.foreground');
            if (signColor == null) {
                return;
            }
            for (i in 0...lineCount) {
                Codicons.paintDiffSign(window, cx, bounds.origin.x + layoutInfo.decorationsLeft, bounds.origin.y + i * lineHeight, lineHeight, false, signColor.opacity(0.7));
            }
        };
    }

    function gutterDeleteColor():Null<Hsla> {
        final gutter = color('diffEditorGutter.removedLineBackground');
        if (gutter != null) {
            return gutter;
        }
        final line = color('diffEditor.removedLineBackground');
        return line != null ? line : color('diffEditor.removedTextBackground');
    }

    public function gutterDelete():ViewZonePainter {
        return (window, cx, bounds) -> {
            CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, gutterDeleteColor());
        };
    }

    /**
     * `.diff-hidden-lines .center`: the region background, the inset shadows
     * at its top and bottom, the unfold codicon over the gutter, then
     * "N hidden lines" (13 px, the UI font).
     */
    public function collapsedCodeBar(region:UnchangedRegion, hide:Bool, margin:Bool):ViewZonePainter {
        return (window, cx, bounds) -> {
            final background = color('diffEditor.unchangedRegionBackground');
            final foreground = color('diffEditor.unchangedRegionForeground');
            CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, background);
            // box-shadow: inset 0 -5px 5px -7px shadow, inset 0 5px 5px -7px shadow
            final shadow = color('diffEditor.unchangedRegionShadow');
            if (shadow != null) {
                for (k in 0...3) {
                    final a = shadow.opacity(0.18 * (3 - k) / 3);
                    CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y + k, bounds.size.width, 1, a);
                    CityscapeDiffEditor.fillRect(window, bounds.origin.x, bounds.origin.y + bounds.size.height - 1 - k, bounds.size.width, 1, a);
                }
            }
            if (hide || foreground == null) {
                return;
            }
            if (margin) {
                // the unfold codicon (16 px), centered in the gutter
                final size = 16.0;
                final left = bounds.origin.x + (bounds.size.width - size) / 2;
                final baseline = bounds.origin.y + (bounds.size.height - size) / 2 + size * Codicons.ASCENT;
                Codicons.paintIcon(window, cx, 'cityscape/codicon-unfold.svg', Codicons.UNFOLD_PATH, left, baseline, size, foreground);
                return;
            }
            final lineCount = region.getHiddenModifiedRange().length;
            final label = owner.localize('hiddenLines', '{0} hidden lines', [lineCount]);
            if (label.length == 0) {
                return;
            }
            var family = '.SystemUIFont';
            try {
                family = glaze.kit.theme.Theme.global(cx).fontFamily;
            }
            catch (e:Dynamic) {}
            final font = new glaze.Font(family);
            final fontSize = 13.0;
            final shaped = window.textSystem().shapeLine(label, fontSize, [new glaze.TextRun(glaze.util.Utf8.byteLength(label), font, foreground)]);
            final lineHeight = 14.0;
            shaped.paint(new Point(bounds.origin.x, bounds.origin.y + (bounds.size.height - lineHeight) / 2), lineHeight, TextAlign.Left, null, window.textPainter());
        };
    }

}
