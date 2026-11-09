// Ported from vscode src/vs/editor/common/viewModel/viewModelImpl.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Strings;
import cityscape.common.CursorCommon;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.ICursorState;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.EditorTheme;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.common.Model;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelEvents;
import cityscape.common.TextModelGuides;
import cityscape.common.ViewEventHandler;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel;
import cityscape.common.ViewModelEventDispatcher.CursorStateChangedEvent;
import cityscape.common.ViewModelEventDispatcher.FocusChangedEvent;
import cityscape.common.ViewModelEventDispatcher.HiddenAreasChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelContentChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelDecorationsChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelLanguageChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelLanguageConfigurationChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelOptionsChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ModelTokensChangedEvent;
import cityscape.common.ViewModelEventDispatcher.OutgoingViewModelEvent;
import cityscape.common.ViewModelEventDispatcher.ReadOnlyEditAttemptEvent;
import cityscape.common.ViewModelEventDispatcher.ScrollChangedEvent;
import cityscape.common.ViewModelEventDispatcher.ViewModelEventDispatcher;
import cityscape.common.ViewModelEventDispatcher.ViewModelEventsCollector;
import cityscape.common.ViewModelEventDispatcher.ViewZonesChangedOutgoingEvent;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.cursor.Cursor.CursorsController;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.viewLayout.ViewLayout;
import cityscape.common.viewModel.GlyphLanesModel.GlyphMarginLanesModel;
import cityscape.common.viewModel.ViewModelDecorations;
import cityscape.common.viewModel.ViewModelLines;
import haxe.extern.EitherType;

/**
 * The view model of an editor: Monaco's `ViewModel` (viewModelImpl.ts).
 *
 * Differences, all temporary or documented:
 * - The cursors are Monaco's `CursorsController` (common/cursor). Monaco's
 *   `languageConfigurationService` is the one of the `Cityscape` context.
 * - Cityscape: hidden ranges inside lines (`hidden`, `replacement`,
 *   `revealOnCursorLine` decoration options) are injections of this view
 *   (`ViewInjectedTextProvider`), so two editors on one model hide
 *   independently (docs/DEVIATIONS.md, "Hidden text inside a line").
 * - Monaco's `RunOnceScheduler` for the view line count of the
 *   configuration runs synchronously.
 * - No minimap: `getMinimapDecorationsInRange` and
 *   `getMinimapLinesRenderingData` are not ported.
 */
class ViewModel implements IViewModel {

    static inline final USE_IDENTITY_LINES_COLLECTION = true;

    final _editorId:Int;
    final _configuration:IEditorConfiguration;
    public final model:ITextModel;
    final _eventDispatcher:ViewModelEventDispatcher;
    public final onEvent:Event<OutgoingViewModelEvent>;
    public var cursorConfig(default, null):CursorConfiguration;
    final _cursor:CursorsController;
    final languageConfigurationService:ILanguageConfigurationService;
    var _hasFocus:Bool;
    final _viewportStart:ViewportStart;
    final _lines:IViewModelLines;
    public final coordinatesConverter:ICoordinatesConverter;
    public final viewLayout:ViewLayout;
    final _decorations:ViewModelDecorations;
    public final glyphLanes:IGlyphMarginLanesModel;
    final _attachedView:IAttachedView;

    final _disposables:Array<IDisposable> = [];

    final hiddenAreasModel = new HiddenAreasModel();
    var previousHiddenAreas:Array<Range> = [];

    public function new(editorId:Int, configuration:IEditorConfiguration, model:ITextModel, domLineBreaksComputerFactory:ILineBreaksComputerFactory, monospaceLineBreaksComputerFactory:ILineBreaksComputerFactory, ?wrappingIndentColumns:Int, ?context:cityscape.Cityscape) {
        this._editorId = editorId;
        this._configuration = configuration;
        this.model = model;
        this._eventDispatcher = new ViewModelEventDispatcher();
        this.onEvent = this._eventDispatcher.onEvent;
        // Monaco's theme service, global `TokenizationRegistry` and language
        // configuration service are the context's (the context of the model
        // when none is given)
        final ctx:Null<cityscape.Cityscape> = context != null ? context : (Std.isOfType(model, cityscape.common.model.TextModel) ? (cast model : cityscape.common.model.TextModel).context : null);
        this.languageConfigurationService = (ctx != null ? ctx : cityscape.Cityscape.defaultContext).languageConfigurationService;
        this.cursorConfig = new CursorConfiguration(this.model.getLanguageId(), this.model.getOptions(), this._configuration, this.languageConfigurationService);
        this._hasFocus = false;
        this._viewportStart = ViewportStart.create(this.model);
        this.glyphLanes = new GlyphMarginLanesModel(0);
        this._attachedView = model.onBeforeAttached();


        if (USE_IDENTITY_LINES_COLLECTION && this.model.isTooLargeForTokenization()) {

            this._lines = new ViewModelLinesFromModelAsIs(this.model);

        } else {
            final options = this._configuration.options;
            final fontInfo = options.get(EditorOption.fontInfo);
            final wrappingStrategy = options.get(EditorOption.wrappingStrategy);
            final wrappingInfo = options.get(EditorOption.wrappingInfo);
            final wrappingIndent = options.get(EditorOption.wrappingIndent);
            final wordBreak = options.get(EditorOption.wordBreak);

            this._recomputeHiddenRanges();

            this._lines = new ViewModelLinesFromProjectedModel(
                this._editorId,
                this.model,
                domLineBreaksComputerFactory,
                monospaceLineBreaksComputerFactory,
                fontInfo,
                this.model.getOptions().tabSize,
                wrappingStrategy,
                wrappingInfo.wrappingColumn,
                wrappingIndent,
                wordBreak,
                wrappingIndentColumns == null ? -1 : wrappingIndentColumns,
                this._viewInjectedTextAt
            );
        }

        this.coordinatesConverter = this._lines.createCoordinatesConverter();

        this._cursor = new CursorsController(model, this, this.coordinatesConverter, this.cursorConfig);
        this._disposables.push(this._cursor);

        this.viewLayout = new ViewLayout(this._configuration, this.getLineCount());

        this._disposables.push(this.viewLayout.onDidScroll((e) -> {
            if (e.scrollTopChanged) {
                this._handleVisibleLinesChanged();
            }
            if (e.scrollTopChanged) {
                this._viewportStart.invalidate();
            }
            this._eventDispatcher.emitSingleViewEvent(new ViewScrollChangedEvent(e));
            this._eventDispatcher.emitOutgoingEvent(new ScrollChangedEvent(
                e.oldScrollWidth, e.oldScrollLeft, e.oldScrollHeight, e.oldScrollTop,
                e.scrollWidth, e.scrollLeft, e.scrollHeight, e.scrollTop
            ));
        }));

        this._disposables.push(this.viewLayout.onDidContentSizeChange((e) -> {
            this._eventDispatcher.emitOutgoingEvent(e);
        }));

        this._decorations = new ViewModelDecorations(this._editorId, this.model, this._configuration, this._lines, this.coordinatesConverter);

        this._registerModelEvents();

        if (ctx != null) {
            this._disposables.push(ctx.tokenizationRegistry.onDidChange((e) -> {
                if (e.changedColorMap) {
                    this._eventDispatcher.emitSingleViewEvent(new ViewTokensColorsChangedEvent());
                }
            }));
            this._disposables.push(ctx.themeService.onDidColorThemeChange((theme) -> {
                this._invalidateDecorationsColorCache();
                this._eventDispatcher.emitSingleViewEvent(new ViewThemeChangedEvent(theme));
            }));
        }

        this._disposables.push(this._configuration.onDidChangeFast((e) -> {
            final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
            try {
                this._onConfigurationChanged(eventsCollector, e);
            } catch (err:haxe.Exception) {
                this._eventDispatcher.endEmitViewEvents();
                throw err;
            }
            this._eventDispatcher.endEmitViewEvents();
        }));

        this._updateConfigurationViewLineCountNow();
    }

    public function dispose():Void {
        // First remove listeners, as disposing the lines might end up sending
        // model decoration changed events ... and we no longer care about them ...
        for (d in this._disposables) {
            d.dispose();
        }
        this._disposables.resize(0);
        this.viewLayout.dispose();
        this._decorations.dispose();
        this._lines.dispose();
        this._viewportStart.dispose();
        this._eventDispatcher.dispose();
        this.model.onBeforeDetached(this._attachedView);
    }

    public function createLineBreaksComputer():ILineBreaksComputer {
        return this._lines.createLineBreaksComputer();
    }

    public function addViewEventHandler(eventHandler:ViewEventHandler):Void {
        this._eventDispatcher.addViewEventHandler(eventHandler);
    }

    public function removeViewEventHandler(eventHandler:ViewEventHandler):Void {
        this._eventDispatcher.removeViewEventHandler(eventHandler);
    }

    function _updateConfigurationViewLineCountNow():Void {
        this._configuration.setViewLineCount(this._lines.getViewLineCount());
    }

    function getModelVisibleRanges():Array<Range> {
        final linesViewportData = this.viewLayout.getLinesViewportData();
        final viewVisibleRange = new Range(
            linesViewportData.startLineNumber,
            this.getLineMinColumn(linesViewportData.startLineNumber),
            linesViewportData.endLineNumber,
            this.getLineMaxColumn(linesViewportData.endLineNumber)
        );
        final modelVisibleRanges = this._toModelVisibleRanges(viewVisibleRange);
        return modelVisibleRanges;
    }

    public function visibleLinesStabilized():Void {
        final modelVisibleRanges = this.getModelVisibleRanges();
        this._attachedView.setVisibleLines([for (r in modelVisibleRanges) {startLineNumber: r.startLineNumber, endLineNumber: r.endLineNumber}], true);
    }

    function _handleVisibleLinesChanged():Void {
        final modelVisibleRanges = this.getModelVisibleRanges();
        this._attachedView.setVisibleLines([for (r in modelVisibleRanges) {startLineNumber: r.startLineNumber, endLineNumber: r.endLineNumber}], false);
    }

    public function setHasFocus(hasFocus:Bool):Void {
        this._hasFocus = hasFocus;
        this._cursor.setHasFocus(hasFocus);
        this._eventDispatcher.emitSingleViewEvent(new ViewFocusChangedEvent(hasFocus));
        this._eventDispatcher.emitOutgoingEvent(new FocusChangedEvent(!hasFocus, hasFocus));
    }

    public function hasFocus():Bool {
        return this._hasFocus;
    }

    public function onCompositionStart():Void {
        this._eventDispatcher.emitSingleViewEvent(new ViewCompositionStartEvent());
    }

    public function onCompositionEnd():Void {
        this._eventDispatcher.emitSingleViewEvent(new ViewCompositionEndEvent());
    }

    function _captureStableViewport():StableViewport {
        // We might need to restore the current start view range, so save it (if available)
        // But only if the scroll position is not at the top of the file
        if (this._viewportStart.isValid && this.viewLayout.getCurrentScrollTop() > 0) {
            final previousViewportStartViewPosition = new Position(this._viewportStart.viewLineNumber, this.getLineMinColumn(this._viewportStart.viewLineNumber));
            final previousViewportStartModelPosition = this.coordinatesConverter.convertViewPositionToModelPosition(previousViewportStartViewPosition);
            return new StableViewport(previousViewportStartModelPosition, this._viewportStart.startLineDelta);
        }
        return new StableViewport(null, 0);
    }

    function _onConfigurationChanged(eventsCollector:ViewModelEventsCollector, e:ConfigurationChangedEvent):Void {
        final stableViewport = this._captureStableViewport();
        final options = this._configuration.options;
        final fontInfo = options.get(EditorOption.fontInfo);
        final wrappingStrategy = options.get(EditorOption.wrappingStrategy);
        final wrappingInfo = options.get(EditorOption.wrappingInfo);
        final wrappingIndent = options.get(EditorOption.wrappingIndent);
        final wordBreak = options.get(EditorOption.wordBreak);

        if (this._lines.setWrappingSettings(fontInfo, wrappingStrategy, wrappingInfo.wrappingColumn, wrappingIndent, wordBreak)) {
            this._emitLineMappingFlush(eventsCollector);
        }

        if (e.hasChanged(EditorOption.readOnly)) {
            // Must read again all decorations due to readOnly filtering
            this._decorations.reset();
            eventsCollector.emitViewEvent(new ViewDecorationsChangedEvent(null));
        }

        if (e.hasChanged(EditorOption.renderValidationDecorations)) {
            this._decorations.reset();
            eventsCollector.emitViewEvent(new ViewDecorationsChangedEvent(null));
        }

        eventsCollector.emitViewEvent(new ViewConfigurationChangedEvent(e));
        this.viewLayout.onConfigurationChanged(e);

        stableViewport.recoverViewportStart(this.coordinatesConverter, this.viewLayout);

        if (CursorConfiguration.shouldRecreate(e)) {
            this._updateCursorConfig();
        }
    }

    function _updateCursorConfig():Void {
        this.cursorConfig = new CursorConfiguration(this.model.getLanguageId(), this.model.getOptions(), this._configuration, this.languageConfigurationService);
        this._cursor.updateConfiguration(this.cursorConfig);
    }

    /**
     * Cityscape: changes `wrappingIndentColumns` (loreline-monaco's
     * `[loreline]` wrapping patch, see `MonospaceLineBreaksComputer`).
     */
    public function setWrappingIndentColumns(wrappingIndentColumns:Int):Void {
        final options = this._configuration.options;
        final stableViewport = this._captureStableViewport();
        final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
        if (this._lines.setWrappingSettings(options.get(EditorOption.fontInfo), options.get(EditorOption.wrappingStrategy), options.get(EditorOption.wrappingInfo).wrappingColumn, options.get(EditorOption.wrappingIndent), options.get(EditorOption.wordBreak), wrappingIndentColumns)) {
            this._emitLineMappingFlush(eventsCollector);
        }
        stableViewport.recoverViewportStart(this.coordinatesConverter, this.viewLayout);
        this._eventDispatcher.endEmitViewEvents();
    }

    function _emitLineMappingFlush(eventsCollector:ViewModelEventsCollector):Void {
        eventsCollector.emitViewEvent(new ViewFlushedEvent());
        eventsCollector.emitViewEvent(new ViewLineMappingChangedEvent());
        eventsCollector.emitViewEvent(new ViewDecorationsChangedEvent(null));
        this._cursor.onLineMappingChanged(eventsCollector);
        this._decorations.onLineMappingChanged();
        this.viewLayout.onFlushed(this.getLineCount());
        this._updateConfigurationViewLineCountNow();
    }

    function _registerModelEvents():Void {

        this._disposables.push(this.model.onDidChangeContentOrInjectedText((e) -> {
            final isContentChange = Std.isOfType(e, InternalModelContentChangeEvent);
            final contentEvent:Null<InternalModelContentChangeEvent> = isContentChange ? cast e : null;

            // Cityscape: the hidden ranges moved with the edit
            this._recomputeHiddenRanges();

            final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
            try {
                var hadOtherModelChange = false;
                var hadModelLineChangeThatChangedLineMapping = false;

                final changes:Array<ModelRawChange> = (contentEvent != null ? contentEvent.rawContentChangedEvent.changes : cast (cast e : ModelInjectedTextChangedEvent).changes);
                final versionId:Null<Int> = (contentEvent != null ? contentEvent.rawContentChangedEvent.versionId : null);

                // Do a first pass to compute line mappings, and a second pass to actually interpret them
                final lineBreaksComputer = this._lines.createLineBreaksComputer();
                for (change in changes) {
                    switch (change.changeType) {
                        case RawContentChangedType.LinesInserted:
                            final change:ModelRawLinesInserted = cast change;
                            for (lineIdx in 0...change.detail.length) {
                                final line = change.detail[lineIdx];
                                var injectedText = change.injectedTexts[lineIdx];
                                if (injectedText != null) {
                                    injectedText = injectedText.filter(element -> (element.ownerId == 0 || element.ownerId == this._editorId));
                                }
                                lineBreaksComputer.addRequest(line, this._mergeViewInjectedText(change.fromLineNumber + lineIdx, injectedText), null);
                            }
                        case RawContentChangedType.LineChanged:
                            final change:ModelRawLineChanged = cast change;
                            var injectedText:Null<Array<LineInjectedText>> = null;
                            if (change.injectedText != null) {
                                injectedText = change.injectedText.filter(element -> (element.ownerId == 0 || element.ownerId == this._editorId));
                            }
                            lineBreaksComputer.addRequest(change.detail, this._mergeViewInjectedText(change.lineNumber, injectedText), null);
                        case _:
                    }
                }
                final lineBreaks = lineBreaksComputer.finalize();
                var lineBreakIndex = 0;

                for (change in changes) {
                    switch (change.changeType) {
                        case RawContentChangedType.Flush:
                            this._lines.onModelFlushed();
                            eventsCollector.emitViewEvent(new ViewFlushedEvent());
                            this._decorations.reset();
                            this.viewLayout.onFlushed(this.getLineCount());
                            hadOtherModelChange = true;
                        case RawContentChangedType.LinesDeleted:
                            final change:ModelRawLinesDeleted = cast change;
                            final linesDeletedEvent = this._lines.onModelLinesDeleted(versionId, change.fromLineNumber, change.toLineNumber);
                            if (linesDeletedEvent != null) {
                                eventsCollector.emitViewEvent(linesDeletedEvent);
                                this.viewLayout.onLinesDeleted(linesDeletedEvent.fromLineNumber, linesDeletedEvent.toLineNumber);
                            }
                            hadOtherModelChange = true;
                        case RawContentChangedType.LinesInserted:
                            final change:ModelRawLinesInserted = cast change;
                            final insertedLineBreaks = lineBreaks.slice(lineBreakIndex, lineBreakIndex + change.detail.length);
                            lineBreakIndex += change.detail.length;
                            final linesInsertedEvent = this._lines.onModelLinesInserted(versionId, change.fromLineNumber, change.toLineNumber, insertedLineBreaks);
                            if (linesInsertedEvent != null) {
                                eventsCollector.emitViewEvent(linesInsertedEvent);
                                this.viewLayout.onLinesInserted(linesInsertedEvent.fromLineNumber, linesInsertedEvent.toLineNumber);
                            }
                            hadOtherModelChange = true;
                        case RawContentChangedType.LineChanged:
                            final change:ModelRawLineChanged = cast change;
                            final changedLineBreakData = lineBreaks[lineBreakIndex++];
                            final r = this._lines.onModelLineChanged(versionId, change.lineNumber, changedLineBreakData);
                            hadModelLineChangeThatChangedLineMapping = r.lineMappingChanged;
                            if (r.linesChangedEvent != null) {
                                eventsCollector.emitViewEvent(r.linesChangedEvent);
                            }
                            if (r.linesInsertedEvent != null) {
                                eventsCollector.emitViewEvent(r.linesInsertedEvent);
                                this.viewLayout.onLinesInserted(r.linesInsertedEvent.fromLineNumber, r.linesInsertedEvent.toLineNumber);
                            }
                            if (r.linesDeletedEvent != null) {
                                eventsCollector.emitViewEvent(r.linesDeletedEvent);
                                this.viewLayout.onLinesDeleted(r.linesDeletedEvent.fromLineNumber, r.linesDeletedEvent.toLineNumber);
                            }
                        case RawContentChangedType.EOLChanged:
                            // Nothing to do. The new version will be accepted below
                        case _:
                    }
                }

                if (versionId != null) {
                    this._lines.acceptVersionId(versionId);
                }
                this.viewLayout.onHeightMaybeChanged();

                if (!hadOtherModelChange && hadModelLineChangeThatChangedLineMapping) {
                    eventsCollector.emitViewEvent(new ViewLineMappingChangedEvent());
                    eventsCollector.emitViewEvent(new ViewDecorationsChangedEvent(null));
                    this._cursor.onLineMappingChanged(eventsCollector);
                    this._decorations.onLineMappingChanged();
                }
            } catch (err:haxe.Exception) {
                this._eventDispatcher.endEmitViewEvents();
                throw err;
            }
            this._eventDispatcher.endEmitViewEvents();

            // Update the configuration and reset the centered view line
            final viewportStartWasValid = this._viewportStart.isValid;
            this._viewportStart.invalidate();
            this._configuration.setModelLineCount(this.model.getLineCount());
            this._updateConfigurationViewLineCountNow();

            // Recover viewport
            if (!this._hasFocus && this.model.getAttachedEditorCount() >= 2 && viewportStartWasValid) {
                final modelRange = this.model._getTrackedRange(this._viewportStart.modelTrackedRange);
                if (modelRange != null) {
                    final viewPosition = this.coordinatesConverter.convertModelPositionToViewPosition(modelRange.getStartPosition());
                    final viewPositionTop = this.viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber);
                    this.viewLayout.setScrollPosition({scrollTop: viewPositionTop + this._viewportStart.startLineDelta}, ScrollType.Immediate);
                }
            }

            final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
            if (contentEvent != null) {
                eventsCollector.emitOutgoingEvent(new ModelContentChangedEvent(contentEvent.contentChangedEvent));
            }
            this._cursor.onModelContentChanged(eventsCollector, e);
            // Cityscape: `revealOnCursorLine` hidden ranges follow the cursors
            this._updateHiddenRangesForCursors(eventsCollector);
            this._eventDispatcher.endEmitViewEvents();

            this._handleVisibleLinesChanged();
        }));

        this._disposables.push(this.model.onDidChangeTokens((e) -> {
            final viewRanges:Array<{fromLineNumber:Int, toLineNumber:Int}> = [];
            for (j in 0...e.ranges.length) {
                final modelRange = e.ranges[j];
                final viewStartLineNumber = this.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelRange.fromLineNumber, 1)).lineNumber;
                final viewEndLineNumber = this.coordinatesConverter.convertModelPositionToViewPosition(new Position(modelRange.toLineNumber, this.model.getLineMaxColumn(modelRange.toLineNumber))).lineNumber;
                viewRanges[j] = {
                    fromLineNumber: viewStartLineNumber,
                    toLineNumber: viewEndLineNumber
                };
            }
            this._eventDispatcher.emitSingleViewEvent(new ViewTokensChangedEvent(viewRanges));
            this._eventDispatcher.emitOutgoingEvent(new ModelTokensChangedEvent(e));
        }));

        this._disposables.push(this.model.onDidChangeLanguageConfiguration((e) -> {
            this._eventDispatcher.emitSingleViewEvent(new ViewLanguageConfigurationEvent());
            this._updateCursorConfig();
            this._eventDispatcher.emitOutgoingEvent(new ModelLanguageConfigurationChangedEvent(e));
        }));

        this._disposables.push(this.model.onDidChangeLanguage((e) -> {
            this._updateCursorConfig();
            this._eventDispatcher.emitOutgoingEvent(new ModelLanguageChangedEvent(e));
        }));

        this._disposables.push(this.model.onDidChangeOptions((e) -> {
            // A tab size change causes a line mapping changed event => all view parts will repaint OK, no further event needed here
            if (this._lines.setTabSize(this.model.getOptions().tabSize)) {
                final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
                this._emitLineMappingFlush(eventsCollector);
                this._eventDispatcher.endEmitViewEvents();
            }

            this._updateCursorConfig();

            this._eventDispatcher.emitOutgoingEvent(new ModelOptionsChangedEvent(e));
        }));

        this._disposables.push(this.model.onDidChangeDecorations((e) -> {
            this._decorations.onModelDecorationsChanged();
            // Cityscape: hidden ranges may have changed
            this._updateHiddenRanges();
            this._eventDispatcher.emitSingleViewEvent(new ViewDecorationsChangedEvent(e));
            this._eventDispatcher.emitOutgoingEvent(new ModelDecorationsChangedEvent(e));
        }));
    }

    public function setHiddenAreas(ranges:Array<Range>, ?source:Any):Void {
        this.hiddenAreasModel.setHiddenAreas(source, ranges);
        final mergedRanges = this.hiddenAreasModel.getMergedRanges();
        if (mergedRanges == this.previousHiddenAreas) {
            return;
        }

        this.previousHiddenAreas = mergedRanges;

        final stableViewport = this._captureStableViewport();

        var lineMappingChanged = false;
        final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
        lineMappingChanged = this._lines.setHiddenAreas(mergedRanges);
        if (lineMappingChanged) {
            eventsCollector.emitViewEvent(new ViewFlushedEvent());
            eventsCollector.emitViewEvent(new ViewLineMappingChangedEvent());
            eventsCollector.emitViewEvent(new ViewDecorationsChangedEvent(null));
            this._cursor.onLineMappingChanged(eventsCollector);
            this._decorations.onLineMappingChanged();
            this.viewLayout.onFlushed(this.getLineCount());
            this.viewLayout.onHeightMaybeChanged();
        }

        final firstModelLineInViewPort:Null<Int> = stableViewport.viewportStartModelPosition != null ? stableViewport.viewportStartModelPosition.lineNumber : null;
        var firstModelLineIsHidden = false;
        if (firstModelLineInViewPort != null && firstModelLineInViewPort != 0) {
            for (range in mergedRanges) {
                if (range.startLineNumber <= firstModelLineInViewPort && firstModelLineInViewPort <= range.endLineNumber) {
                    firstModelLineIsHidden = true;
                    break;
                }
            }
        }
        if (!firstModelLineIsHidden) {
            stableViewport.recoverViewportStart(this.coordinatesConverter, this.viewLayout);
        }
        this._eventDispatcher.endEmitViewEvents();
        this._updateConfigurationViewLineCountNow();

        if (lineMappingChanged) {
            this._eventDispatcher.emitOutgoingEvent(new HiddenAreasChangedEvent());
        }
    }

    public function getVisibleRangesPlusViewportAboveBelow():Array<Range> {
        final layoutInfo = this._configuration.options.get(EditorOption.layoutInfo);
        final lineHeight = this._configuration.options.get(EditorOption.lineHeight);
        final linesAround = Std.int(Math.max(20, Math.round(layoutInfo.height / lineHeight)));
        final partialData = this.viewLayout.getLinesViewportData();
        final startViewLineNumber = Std.int(Math.max(1, partialData.completelyVisibleStartLineNumber - linesAround));
        final endViewLineNumber = Std.int(Math.min(this.getLineCount(), partialData.completelyVisibleEndLineNumber + linesAround));

        return this._toModelVisibleRanges(new Range(
            startViewLineNumber, this.getLineMinColumn(startViewLineNumber),
            endViewLineNumber, this.getLineMaxColumn(endViewLineNumber)
        ));
    }

    public function getVisibleRanges():Array<Range> {
        final visibleViewRange = this.getCompletelyVisibleViewRange();
        return this._toModelVisibleRanges(visibleViewRange);
    }

    public function getHiddenAreas():Array<Range> {
        return this._lines.getHiddenAreas();
    }

    function _toModelVisibleRanges(visibleViewRange:Range):Array<Range> {
        final visibleRange = this.coordinatesConverter.convertViewRangeToModelRange(visibleViewRange);
        final hiddenAreas = this._lines.getHiddenAreas();

        if (hiddenAreas.length == 0) {
            return [visibleRange];
        }

        final result:Array<Range> = [];
        var startLineNumber = visibleRange.startLineNumber;
        var startColumn = visibleRange.startColumn;
        final endLineNumber = visibleRange.endLineNumber;
        final endColumn = visibleRange.endColumn;
        for (i in 0...hiddenAreas.length) {
            final hiddenStartLineNumber = hiddenAreas[i].startLineNumber;
            final hiddenEndLineNumber = hiddenAreas[i].endLineNumber;

            if (hiddenEndLineNumber < startLineNumber) {
                continue;
            }
            if (hiddenStartLineNumber > endLineNumber) {
                continue;
            }

            if (startLineNumber < hiddenStartLineNumber) {
                result.push(new Range(
                    startLineNumber, startColumn,
                    hiddenStartLineNumber - 1, this.model.getLineMaxColumn(hiddenStartLineNumber - 1)
                ));
            }
            startLineNumber = hiddenEndLineNumber + 1;
            startColumn = 1;
        }

        if (startLineNumber < endLineNumber || (startLineNumber == endLineNumber && startColumn < endColumn)) {
            result.push(new Range(
                startLineNumber, startColumn,
                endLineNumber, endColumn
            ));
        }

        return result;
    }

    /**
     * Replaces `getCompletelyVisibleViewRange` when set: vscode's cursor
     * tests replace the method (`cursorMoveCommand.test.ts`), which Haxe
     * cannot do on an interface method.
     * @internal
     */
    public var _getCompletelyVisibleViewRangeOverride:Null<() -> Range> = null;

    public function getCompletelyVisibleViewRange():Range {
        if (this._getCompletelyVisibleViewRangeOverride != null) {
            return this._getCompletelyVisibleViewRangeOverride();
        }
        final partialData = this.viewLayout.getLinesViewportData();
        final startViewLineNumber = partialData.completelyVisibleStartLineNumber;
        final endViewLineNumber = partialData.completelyVisibleEndLineNumber;

        return new Range(
            startViewLineNumber, this.getLineMinColumn(startViewLineNumber),
            endViewLineNumber, this.getLineMaxColumn(endViewLineNumber)
        );
    }

    public function getCompletelyVisibleViewRangeAtScrollTop(scrollTop:Float):Range {
        final partialData = this.viewLayout.getLinesViewportDataAtScrollTop(scrollTop);
        final startViewLineNumber = partialData.completelyVisibleStartLineNumber;
        final endViewLineNumber = partialData.completelyVisibleEndLineNumber;

        return new Range(
            startViewLineNumber, this.getLineMinColumn(startViewLineNumber),
            endViewLineNumber, this.getLineMaxColumn(endViewLineNumber)
        );
    }

    public function saveState():{scrollLeft:Float, firstPosition:Position, firstPositionDeltaTop:Float} {
        final compatViewState = this.viewLayout.saveState();

        final scrollTop = compatViewState.scrollTop;
        final firstViewLineNumber = this.viewLayout.getLineNumberAtVerticalOffset(scrollTop);
        final firstPosition = this.coordinatesConverter.convertViewPositionToModelPosition(new Position(firstViewLineNumber, this.getLineMinColumn(firstViewLineNumber)));
        final firstPositionDeltaTop = this.viewLayout.getVerticalOffsetForLineNumber(firstViewLineNumber) - scrollTop;

        return {
            scrollLeft: compatViewState.scrollLeft,
            firstPosition: firstPosition,
            firstPositionDeltaTop: firstPositionDeltaTop
        };
    }

    public function reduceRestoreState(state:{scrollLeft:Float, firstPosition:IPosition, firstPositionDeltaTop:Float}):{scrollLeft:Float, scrollTop:Float} {
        final modelPosition = this.model.validatePosition(state.firstPosition);
        final viewPosition = this.coordinatesConverter.convertModelPositionToViewPosition(modelPosition);
        final scrollTop = this.viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber) - state.firstPositionDeltaTop;
        return {
            scrollLeft: state.scrollLeft,
            scrollTop: scrollTop
        };
    }

    function getTabSize():Int {
        return this.model.getOptions().tabSize;
    }

    public function getLineCount():Int {
        return this._lines.getViewLineCount();
    }

    /**
     * Gives a hint that a lot of requests are about to come in for these line numbers.
     */
    public function setViewport(startLineNumber:Int, endLineNumber:Int, centeredLineNumber:Int):Void {
        this._viewportStart.update(this, startLineNumber);
    }

    public function getActiveIndentGuide(lineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo {
        return this._lines.getActiveIndentGuide(lineNumber, minLineNumber, maxLineNumber);
    }

    public function getLinesIndentGuides(startLineNumber:Int, endLineNumber:Int):Array<Int> {
        return this._lines.getViewLinesIndentGuides(startLineNumber, endLineNumber);
    }

    public function getBracketGuidesInRangeByLine(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>> {
        return this._lines.getViewLinesBracketGuides(startLineNumber, endLineNumber, activePosition, options);
    }

    public function getLineContent(lineNumber:Int):String {
        return this._lines.getViewLineContent(lineNumber);
    }

    public function getLineLength(lineNumber:Int):Int {
        return this._lines.getViewLineLength(lineNumber);
    }

    public function getLineMinColumn(lineNumber:Int):Int {
        return this._lines.getViewLineMinColumn(lineNumber);
    }

    public function getLineMaxColumn(lineNumber:Int):Int {
        return this._lines.getViewLineMaxColumn(lineNumber);
    }

    public function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int {
        final result = Strings.firstNonWhitespaceIndex(this.getLineContent(lineNumber));
        if (result == -1) {
            return 0;
        }
        return result + 1;
    }

    public function getLineLastNonWhitespaceColumn(lineNumber:Int):Int {
        final result = Strings.lastNonWhitespaceIndex(this.getLineContent(lineNumber));
        if (result == -1) {
            return 0;
        }
        return result + 2;
    }

    public function getDecorationsInViewport(visibleRange:Range):Array<ViewModelDecoration> {
        return this._decorations.getDecorationsViewportData(visibleRange).decorations;
    }

    public function getInjectedTextAt(viewPosition:Position):Null<InjectedText> {
        return this._lines.getInjectedTextAt(viewPosition);
    }

    public function getViewportViewLineRenderingData(visibleRange:Range, lineNumber:Int):ViewLineRenderingData {
        final allInlineDecorations = this._decorations.getDecorationsViewportData(visibleRange).inlineDecorations;
        final inlineDecorations = allInlineDecorations[lineNumber - visibleRange.startLineNumber];
        return this._getViewLineRenderingData(lineNumber, inlineDecorations);
    }

    public function getViewLineRenderingData(lineNumber:Int):ViewLineRenderingData {
        final inlineDecorations = this._decorations.getInlineDecorationsOnLine(lineNumber);
        return this._getViewLineRenderingData(lineNumber, inlineDecorations);
    }

    function _getViewLineRenderingData(lineNumber:Int, inlineDecorations:Array<InlineDecoration>):ViewLineRenderingData {
        final mightContainRTL = this.model.mightContainRTL();
        final mightContainNonBasicASCII = this.model.mightContainNonBasicASCII();
        final tabSize = this.getTabSize();
        final lineData = this._lines.getViewLineData(lineNumber);

        if (lineData.inlineDecorations != null) {
            inlineDecorations = inlineDecorations.concat([for (d in lineData.inlineDecorations) d.toInlineDecoration(lineNumber)]);
        }

        return new ViewLineRenderingData(
            lineData.minColumn,
            lineData.maxColumn,
            lineData.content,
            lineData.continuesWithWrappedLine,
            mightContainRTL,
            mightContainNonBasicASCII,
            lineData.tokens,
            inlineDecorations,
            tabSize,
            lineData.startVisibleColumn
        );
    }

    public function getViewLineData(lineNumber:Int):ViewLineData {
        return this._lines.getViewLineData(lineNumber);
    }

    public function getAllOverviewRulerDecorations(theme:EditorTheme):Array<OverviewRulerDecorationsGroup> {
        final decorations = this.model.getOverviewRulerDecorations(this._editorId, EditorViewOptions.filterValidationDecorations(this._configuration.options));
        final result = new OverviewRulerDecorations();
        for (decoration in decorations) {
            final decorationOptions:Null<ModelDecorationOptions> = Std.isOfType(decoration.options, ModelDecorationOptions) ? cast decoration.options : null;
            if (decorationOptions == null) {
                continue;
            }
            final opts = decorationOptions.overviewRuler;
            final lane:Int = opts != null ? opts.position : 0;
            if (lane == 0) {
                continue;
            }
            final color = opts.getColor(theme.value);
            final viewStartLineNumber = this.coordinatesConverter.getViewLineNumberOfModelPosition(decoration.range.startLineNumber, decoration.range.startColumn);
            final viewEndLineNumber = this.coordinatesConverter.getViewLineNumberOfModelPosition(decoration.range.endLineNumber, decoration.range.endColumn);

            result.accept(color, decorationOptions.zIndex, viewStartLineNumber, viewEndLineNumber, lane);
        }
        return result.asArray;
    }

    function _invalidateDecorationsColorCache():Void {
        final decorations = this.model.getOverviewRulerDecorations();
        for (decoration in decorations) {
            final opts:Null<ModelDecorationOptions> = Std.isOfType(decoration.options, ModelDecorationOptions) ? cast decoration.options : null;
            if (opts != null && opts.overviewRuler != null) {
                opts.overviewRuler.invalidateCachedColor();
            }
            // No minimap (`opts.minimap.invalidateCachedColor()`)
        }
    }

    public function getValueInRange(range:Range, eol:EndOfLinePreference):String {
        final modelRange = this.coordinatesConverter.convertViewRangeToModelRange(range);
        return this.model.getValueInRange(modelRange, eol);
    }

    public function getValueLengthInRange(range:Range, eol:EndOfLinePreference):Int {
        final modelRange = this.coordinatesConverter.convertViewRangeToModelRange(range);
        return this.model.getValueLengthInRange(modelRange, eol);
    }

    public function modifyPosition(position:Position, offset:Int):Position {
        final modelPosition = this.coordinatesConverter.convertViewPositionToModelPosition(position);
        final resultModelPosition = this.model.modifyPosition(modelPosition, offset);
        return this.coordinatesConverter.convertModelPositionToViewPosition(resultModelPosition);
    }

    public function deduceModelPositionRelativeToViewPosition(viewAnchorPosition:Position, deltaOffset:Int, lineFeedCnt:Int):Position {
        final modelAnchor = this.coordinatesConverter.convertViewPositionToModelPosition(viewAnchorPosition);
        if (this.model.getEOL().length == 2) {
            // This model uses CRLF, so the delta must take that into account
            if (deltaOffset < 0) {
                deltaOffset -= lineFeedCnt;
            } else {
                deltaOffset += lineFeedCnt;
            }
        }

        final modelAnchorOffset = this.model.getOffsetAt(modelAnchor);
        final resultOffset = modelAnchorOffset + deltaOffset;
        return this.model.getPositionAt(resultOffset);
    }

    public function getPlainTextToCopy(modelRanges:Array<Range>, emptySelectionClipboard:Bool, forceCRLF:Bool):EitherType<String, Array<String>> {
        final newLineCharacter = forceCRLF ? '\r\n' : this.model.getEOL();

        modelRanges = modelRanges.copy();
        haxe.ds.ArraySort.sort(modelRanges, Range.compareRangesUsingStarts);

        var hasEmptyRange = false;
        var hasNonEmptyRange = false;
        for (range in modelRanges) {
            if (range.isEmpty()) {
                hasEmptyRange = true;
            } else {
                hasNonEmptyRange = true;
            }
        }

        if (!hasNonEmptyRange) {
            // all ranges are empty
            if (!emptySelectionClipboard) {
                return '';
            }

            final modelLineNumbers = [for (r in modelRanges) r.startLineNumber];

            var result = '';
            for (i in 0...modelLineNumbers.length) {
                if (i > 0 && modelLineNumbers[i - 1] == modelLineNumbers[i]) {
                    continue;
                }
                result += this.model.getLineContent(modelLineNumbers[i]) + newLineCharacter;
            }
            return result;
        }

        if (hasEmptyRange && emptySelectionClipboard) {
            // mixed empty selections and non-empty selections
            final result:Array<String> = [];
            var prevModelLineNumber = 0;
            for (modelRange in modelRanges) {
                final modelLineNumber = modelRange.startLineNumber;
                if (modelRange.isEmpty()) {
                    if (modelLineNumber != prevModelLineNumber) {
                        result.push(this.model.getLineContent(modelLineNumber));
                    }
                } else {
                    result.push(this.model.getValueInRange(modelRange, forceCRLF ? EndOfLinePreference.CRLF : EndOfLinePreference.TextDefined));
                }
                prevModelLineNumber = modelLineNumber;
            }
            return result.length == 1 ? result[0] : result;
        }

        final result:Array<String> = [];
        for (modelRange in modelRanges) {
            if (!modelRange.isEmpty()) {
                result.push(this.model.getValueInRange(modelRange, forceCRLF ? EndOfLinePreference.CRLF : EndOfLinePreference.TextDefined));
            }
        }
        return result.length == 1 ? result[0] : result;
    }

    /**
     * TODO(step 3): rich text copy (`tokenizeLineToHTML` and the token color
     * map) comes with the clipboard contribution.
     */
    public function getRichTextToCopy(modelRanges:Array<Range>, emptySelectionClipboard:Bool):Null<{html:String, mode:String}> {
        return null;
    }

    //#region cursor operations

    public function getPrimaryCursorState():CursorState {
        return this._cursor.getPrimaryCursorState();
    }

    public function getLastAddedCursorIndex():Int {
        return this._cursor.getLastAddedCursorIndex();
    }

    public function getCursorStates():Array<CursorState> {
        return this._cursor.getCursorStates();
    }

    public function setCursorStates(source:Null<String>, reason:CursorChangeReason, states:Null<Array<PartialCursorState>>):Bool {
        return this._withViewEventsCollector(eventsCollector -> this._cursor.setStates(eventsCollector, source, reason, states));
    }

    public function getCursorColumnSelectData():IColumnSelectData {
        return this._cursor.getCursorColumnSelectData();
    }

    public function getCursorAutoClosedCharacters():Array<Range> {
        return this._cursor.getAutoClosedCharacters();
    }

    public function setCursorColumnSelectData(columnSelectData:IColumnSelectData):Void {
        this._cursor.setCursorColumnSelectData(columnSelectData);
    }

    public function getPrevEditOperationType():EditOperationType {
        return this._cursor.getPrevEditOperationType();
    }

    public function setPrevEditOperationType(type:EditOperationType):Void {
        this._cursor.setPrevEditOperationType(type);
    }

    public function getSelection():Selection {
        return this._cursor.getSelection();
    }

    public function getSelections():Array<Selection> {
        return this._cursor.getSelections();
    }

    /**
     * Cityscape: the selections in view coordinates (the primary one first).
     */
    public function getViewSelections():Array<Selection> {
        return [for (state in this._cursor.getCursorStates()) state.viewState.selection];
    }

    public function getPosition():Position {
        return this._cursor.getPrimaryCursorState().modelState.position;
    }

    /**
     * Sets the selections (model coordinates), the primary one first
     * (Monaco takes `ISelection`s: `Selection` instances here).
     */
    public function setSelections(source:Null<String>, selections:Array<Selection>, reason:CursorChangeReason = CursorChangeReason.NotSet):Void {
        this._withViewEventsCollector(eventsCollector -> {
            this._cursor.setStates(eventsCollector, source, reason, CursorState.fromSelections(selections));
            return null;
        });
    }

    public function saveCursorState():Array<ICursorState> {
        return this._cursor.saveState();
    }

    public function restoreCursorState(states:Array<ICursorState>):Void {
        this._withViewEventsCollector(eventsCollector -> {
            this._cursor.restoreState(eventsCollector, states);
            return null;
        });
    }

    function _executeCursorEdit(callback:(eventsCollector:ViewModelEventsCollector) -> Void):Void {
        if (this._cursor.context.cursorConfig.readOnly) {
            // we cannot edit when read only...
            this._eventDispatcher.emitOutgoingEvent(new ReadOnlyEditAttemptEvent());
            return;
        }
        this._withViewEventsCollector(eventsCollector -> {
            callback(eventsCollector);
            return null;
        });
    }

    public function executeEdits(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, cursorStateComputer:ICursorStateComputer):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.executeEdits(eventsCollector, source, edits, cursorStateComputer));
    }

    public function startComposition():Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.startComposition(eventsCollector));
    }

    public function endComposition(?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.endComposition(eventsCollector, source));
    }

    public function type(text:String, ?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.type(eventsCollector, text, source));
    }

    public function compositionType(text:String, replacePrevCharCnt:Int, replaceNextCharCnt:Int, positionDelta:Int, ?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.compositionType(eventsCollector, text, replacePrevCharCnt, replaceNextCharCnt, positionDelta, source));
    }

    public function paste(text:String, pasteOnNewLine:Bool, ?multicursorText:Array<String>, ?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.paste(eventsCollector, text, pasteOnNewLine, multicursorText, source));
    }

    public function cut(?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.cut(eventsCollector, source));
    }

    public function executeCommand(command:ICommand, ?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.executeCommand(eventsCollector, command, source));
    }

    public function executeCommands(commands:Array<Null<ICommand>>, ?source:String):Void {
        this._executeCursorEdit(eventsCollector -> this._cursor.executeCommands(eventsCollector, commands, source));
    }

    /**
     * Cityscape (the view's typing before the editor commands): applies edits
     * and sets the selections after them, in one cursor edit.
     */
    public function executeEditsMinimal(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, selectionsAfter:Array<Selection>):Void {
        this.executeEdits(source, edits, (_) -> selectionsAfter);
    }

    public function revealAllCursors(source:Null<String>, revealHorizontal:Bool, ?minimalReveal:Bool):Void {
        this._withViewEventsCollector(eventsCollector -> {
            this._cursor.revealAll(eventsCollector, source, minimalReveal == true, VerticalRevealType.Simple, revealHorizontal, ScrollType.Smooth);
            return null;
        });
    }

    public function revealPrimaryCursor(source:Null<String>, revealHorizontal:Bool, ?minimalReveal:Bool):Void {
        this._withViewEventsCollector(eventsCollector -> {
            this._cursor.revealPrimary(eventsCollector, source, minimalReveal == true, VerticalRevealType.Simple, revealHorizontal, ScrollType.Smooth);
            return null;
        });
    }

    public function revealTopMostCursor(source:Null<String>):Void {
        final viewPosition = this._cursor.getTopMostViewPosition();
        final viewRange = new Range(viewPosition.lineNumber, viewPosition.column, viewPosition.lineNumber, viewPosition.column);
        this._withViewEventsCollector(eventsCollector -> {
            eventsCollector.emitViewEvent(new ViewRevealRangeRequestEvent(source, false, viewRange, null, VerticalRevealType.Simple, true, ScrollType.Smooth));
            return null;
        });
    }

    public function revealBottomMostCursor(source:Null<String>):Void {
        final viewPosition = this._cursor.getBottomMostViewPosition();
        final viewRange = new Range(viewPosition.lineNumber, viewPosition.column, viewPosition.lineNumber, viewPosition.column);
        this._withViewEventsCollector(eventsCollector -> {
            eventsCollector.emitViewEvent(new ViewRevealRangeRequestEvent(source, false, viewRange, null, VerticalRevealType.Simple, true, ScrollType.Smooth));
            return null;
        });
    }

    public function revealRange(source:Null<String>, revealHorizontal:Bool, viewRange:Range, verticalType:VerticalRevealType, scrollType:ScrollType):Void {
        this._withViewEventsCollector(eventsCollector -> {
            eventsCollector.emitViewEvent(new ViewRevealRangeRequestEvent(source, false, viewRange, null, verticalType, revealHorizontal, scrollType));
            return null;
        });
    }

    /**
     * Monaco's `_withViewEventsCollector` (Monaco also batches the changes
     * of its observables, `_transactionalTarget`, not ported). Cityscape:
     * the `revealOnCursorLine` hidden ranges follow the cursors.
     */
    function _withViewEventsCollector<T>(callback:(eventsCollector:ViewModelEventsCollector) -> T):T {
        final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
        var result:T;
        try {
            result = callback(eventsCollector);
            this._updateHiddenRangesForCursors(eventsCollector);
        }
        catch (e:haxe.Exception) {
            this._eventDispatcher.endEmitViewEvents();
            throw e;
        }
        this._eventDispatcher.endEmitViewEvents();
        return result;
    }

    /**
     * Cityscape: updates the hidden ranges revealed on cursor lines after the
     * cursors may have moved.
     */
    function _updateHiddenRangesForCursors(eventsCollector:ViewModelEventsCollector):Void {
        if (this._hiddenDecorationsByLine.keys().hasNext()) {
            this._updateHiddenRanges(eventsCollector);
        }
    }

    //#endregion

    //#region hidden ranges inside lines (Cityscape)

    /**
     * The view's own injections by model line: hidden ranges of the
     * decorations, minus those revealed on cursor lines.
     */
    var _hiddenByLine:Map<Int, Array<LineInjectedText>> = new Map();

    /**
     * The decorations with hidden ranges, by model line (before the
     * `revealOnCursorLine` filter).
     */
    var _hiddenDecorationsByLine:Map<Int, Array<{decoration:IModelDecoration, startColumn:Int, endColumn:Int}>> = new Map();

    function _viewInjectedTextAt(modelLineNumber:Int):Null<Array<LineInjectedText>> {
        return _hiddenByLine.get(modelLineNumber);
    }

    function _mergeViewInjectedText(lineNumber:Int, injectedText:Null<Array<LineInjectedText>>):Null<Array<LineInjectedText>> {
        final lines = Std.downcast(this._lines, ViewModelLinesFromProjectedModel);
        if (lines == null) {
            return injectedText;
        }
        return lines.mergeViewInjectedText(lineNumber, injectedText);
    }

    static function isHiddenDecoration(options:IModelDecorationOptions):Bool {
        return options.hidden == true || options.replacement != null;
    }

    function _cursorModelLines():Map<Int, Bool> {
        final result = new Map<Int, Bool>();
        final selections = (this._cursor != null ? this._cursor.getSelections() : [new Selection(1, 1, 1, 1)]);
        for (s in selections) {
            for (line in s.startLineNumber...s.endLineNumber + 1) {
                result.set(line, true);
            }
        }
        return result;
    }

    /**
     * Rebuilds the hidden range injections from the decorations of the model
     * (the lines are not projected again: see `_updateHiddenRanges`).
     */
    function _recomputeHiddenRanges():Void {
        final byDecorationLine = new Map<Int, Array<{decoration:IModelDecoration, startColumn:Int, endColumn:Int}>>();
        for (decoration in this.model.getAllDecorations(this._editorId)) {
            if (!isHiddenDecoration(decoration.options)) {
                continue;
            }
            final range = decoration.range;
            for (line in range.startLineNumber...range.endLineNumber + 1) {
                final startColumn = (line == range.startLineNumber ? range.startColumn : 1);
                final endColumn = (line == range.endLineNumber ? range.endColumn : this.model.getLineMaxColumn(line));
                if (endColumn <= startColumn && decoration.options.replacement == null) {
                    continue;
                }
                var list = byDecorationLine.get(line);
                if (list == null) {
                    list = [];
                    byDecorationLine.set(line, list);
                }
                list.push({decoration: decoration, startColumn: startColumn, endColumn: endColumn});
            }
        }
        this._hiddenDecorationsByLine = byDecorationLine;
        this._hiddenByLine = this._computeHiddenByLine();
    }

    function _computeHiddenByLine():Map<Int, Array<LineInjectedText>> {
        final cursorLines = this._cursorModelLines();
        final result = new Map<Int, Array<LineInjectedText>>();
        for (line => list in this._hiddenDecorationsByLine) {
            final injected:Array<LineInjectedText> = [];
            // Sorted by start column; overlapping hidden ranges are merged
            final sorted = list.copy();
            haxe.ds.ArraySort.sort(sorted, (a, b) -> a.startColumn - b.startColumn);
            var lastEnd = 0;
            for (item in sorted) {
                final options = item.decoration.options;
                if (options.revealOnCursorLine == true && cursorLines.exists(line)) {
                    continue;
                }
                var startColumn = item.startColumn;
                if (startColumn < lastEnd) {
                    startColumn = lastEnd;
                }
                final replacedLength = item.endColumn - startColumn;
                if (replacedLength < 0) {
                    continue;
                }
                final replacement = options.replacement;
                final injectedOptions:InjectedTextOptions = {
                    content: replacement != null ? replacement.content : '',
                    inlineClassName: replacement != null ? replacement.inlineClassName : null,
                    inlineStyle: replacement != null ? replacement.inlineStyle : null,
                    cursorStops: replacement != null ? replacement.cursorStops : null,
                    attachedData: replacement != null ? replacement.attachedData : null,
                    replacedLength: replacedLength
                };
                injected.push(new LineInjectedText(item.decoration.ownerId, line, startColumn, injectedOptions, 0));
                lastEnd = item.endColumn;
            }
            if (injected.length > 0) {
                result.set(line, injected);
            }
        }
        return result;
    }

    static function sameInjections(a:Null<Array<LineInjectedText>>, b:Null<Array<LineInjectedText>>):Bool {
        if (a == null || b == null) {
            return a == b;
        }
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            final x = a[i];
            final y = b[i];
            if (x.column != y.column || x.options.content != y.options.content || x.options.replacedLength != y.options.replacedLength) {
                return false;
            }
        }
        return true;
    }

    /**
     * Recomputes the hidden ranges and projects again the model lines whose
     * hidden ranges changed (after a change of the decorations or of the
     * cursor lines).
     */
    function _updateHiddenRanges(?eventsCollector:ViewModelEventsCollector):Void {
        final lines = Std.downcast(this._lines, ViewModelLinesFromProjectedModel);
        if (lines == null) {
            return;
        }
        final old = this._hiddenByLine;
        this._recomputeHiddenRanges();
        final changedLines:Array<Int> = [];
        for (line => injected in this._hiddenByLine) {
            if (!sameInjections(old.get(line), injected)) {
                changedLines.push(line);
            }
        }
        for (line => injected in old) {
            if (!this._hiddenByLine.exists(line)) {
                changedLines.push(line);
            }
        }
        if (changedLines.length == 0) {
            return;
        }
        changedLines.sort((a, b) -> a - b);

        final ownCollector = (eventsCollector == null);
        final collector = ownCollector ? this._eventDispatcher.beginEmitViewEvents() : eventsCollector;

        final modelInjected = LineInjectedText.fromDecorations(this.model.getInjectedTextDecorations(this._editorId));
        final lineBreaksComputer = lines.createLineBreaksComputer();
        for (line in changedLines) {
            if (line > this.model.getLineCount()) {
                lineBreaksComputer.addRequest('', null, null);
                continue;
            }
            final injected = [for (t in modelInjected) if (t.lineNumber == line) t];
            lineBreaksComputer.addRequest(this.model.getLineContent(line), lines.mergeViewInjectedText(line, injected.length > 0 ? injected : null), null);
        }
        final lineBreaks = lineBreaksComputer.finalize();

        var lineMappingChanged = false;
        for (i in 0...changedLines.length) {
            final line = changedLines[i];
            if (line > this.model.getLineCount()) {
                continue;
            }
            final r = lines.onModelLineChanged(null, line, lineBreaks[i]);
            if (r.lineMappingChanged) {
                lineMappingChanged = true;
            }
            if (r.linesChangedEvent != null) {
                collector.emitViewEvent(r.linesChangedEvent);
            }
            if (r.linesInsertedEvent != null) {
                collector.emitViewEvent(r.linesInsertedEvent);
                this.viewLayout.onLinesInserted(r.linesInsertedEvent.fromLineNumber, r.linesInsertedEvent.toLineNumber);
            }
            if (r.linesDeletedEvent != null) {
                collector.emitViewEvent(r.linesDeletedEvent);
                this.viewLayout.onLinesDeleted(r.linesDeletedEvent.fromLineNumber, r.linesDeletedEvent.toLineNumber);
            }
        }
        this.viewLayout.onHeightMaybeChanged();
        collector.emitViewEvent(new ViewLineMappingChangedEvent());
        collector.emitViewEvent(new ViewDecorationsChangedEvent(null));
        this._decorations.onLineMappingChanged();
        this._cursor.onLineMappingChanged(collector);
        if (lineMappingChanged) {
            this._updateConfigurationViewLineCountNow();
        }

        if (ownCollector) {
            this._eventDispatcher.endEmitViewEvents();
        }
    }

    //#endregion

    //#region viewLayout

    public function changeWhitespace(callback:(accessor:IWhitespaceChangeAccessor) -> Void):Void {
        final hadAChange = this.viewLayout.changeWhitespace(callback);
        if (hadAChange) {
            this._eventDispatcher.emitSingleViewEvent(new ViewZonesChangedEvent());
            this._eventDispatcher.emitOutgoingEvent(new ViewZonesChangedOutgoingEvent());
        }
    }

    //#endregion

    public function batchEvents(callback:() -> Void):Void {
        final eventsCollector = this._eventDispatcher.beginEmitViewEvents();
        try {
            callback();
        } catch (e:haxe.Exception) {
            this._eventDispatcher.endEmitViewEvents();
            throw e;
        }
        this._eventDispatcher.endEmitViewEvents();
    }

    public function normalizePosition(position:Position, affinity:PositionAffinity):Position {
        return this._lines.normalizePosition(position, affinity);
    }

    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    public function getLineIndentColumn(lineNumber:Int):Int {
        return this._lines.getLineIndentColumn(lineNumber);
    }

}

private class ViewportStart {

    public static function create(model:ITextModel):ViewportStart {
        final viewportStartLineTrackedRange = model._setTrackedRange(null, new Range(1, 1, 1, 1), TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges);
        return new ViewportStart(model, 1, false, viewportStartLineTrackedRange, 0);
    }

    public var viewLineNumber(get, never):Int;
    inline function get_viewLineNumber():Int {
        return this._viewLineNumber;
    }

    public var isValid(get, never):Bool;
    inline function get_isValid():Bool {
        return this._isValid;
    }

    public var modelTrackedRange(get, never):String;
    inline function get_modelTrackedRange():String {
        return this._modelTrackedRange;
    }

    public var startLineDelta(get, never):Float;
    inline function get_startLineDelta():Float {
        return this._startLineDelta;
    }

    final _model:ITextModel;
    var _viewLineNumber:Int;
    var _isValid:Bool;
    var _modelTrackedRange:String;
    var _startLineDelta:Float;

    function new(_model:ITextModel, _viewLineNumber:Int, _isValid:Bool, _modelTrackedRange:String, _startLineDelta:Float) {
        this._model = _model;
        this._viewLineNumber = _viewLineNumber;
        this._isValid = _isValid;
        this._modelTrackedRange = _modelTrackedRange;
        this._startLineDelta = _startLineDelta;
    }

    public function dispose():Void {
        this._model._setTrackedRange(this._modelTrackedRange, null, TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges);
    }

    public function update(viewModel:IViewModel, startLineNumber:Int):Void {
        final position = viewModel.coordinatesConverter.convertViewPositionToModelPosition(new Position(startLineNumber, viewModel.getLineMinColumn(startLineNumber)));
        final viewportStartLineTrackedRange = viewModel.model._setTrackedRange(this._modelTrackedRange, new Range(position.lineNumber, position.column, position.lineNumber, position.column), TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges);
        final viewportStartLineTop = viewModel.viewLayout.getVerticalOffsetForLineNumber(startLineNumber);
        final scrollTop = viewModel.viewLayout.getCurrentScrollTop();

        this._viewLineNumber = startLineNumber;
        this._isValid = true;
        this._modelTrackedRange = viewportStartLineTrackedRange;
        this._startLineDelta = scrollTop - viewportStartLineTop;
    }

    public function invalidate():Void {
        this._isValid = false;
    }

}

private class OverviewRulerDecorations {

    final _asMap:Map<String, OverviewRulerDecorationsGroup> = new Map();
    public final asArray:Array<OverviewRulerDecorationsGroup> = [];

    public function new() {}

    public function accept(color:String, zIndex:Float, startLineNumber:Int, endLineNumber:Int, lane:Int):Void {
        final prevGroup = this._asMap.get(color);

        if (prevGroup != null) {
            final prevData = prevGroup.data;
            final prevLane = prevData[prevData.length - 3];
            final prevEndLineNumber = prevData[prevData.length - 1];
            if (prevLane == lane && prevEndLineNumber + 1 >= startLineNumber) {
                // merge into prev
                if (endLineNumber > prevEndLineNumber) {
                    prevData[prevData.length - 1] = endLineNumber;
                }
                return;
            }

            // push
            prevData.push(lane);
            prevData.push(startLineNumber);
            prevData.push(endLineNumber);
        } else {
            final group = new OverviewRulerDecorationsGroup(color, zIndex, [lane, startLineNumber, endLineNumber]);
            this._asMap.set(color, group);
            this.asArray.push(group);
        }
    }

}

private class HiddenAreasModel {

    final hiddenAreas:Array<{source:Any, ranges:Array<Range>}> = [];
    var shouldRecompute = false;
    var ranges:Array<Range> = [];

    public function new() {}

    public function setHiddenAreas(source:Any, ranges:Array<Range>):Void {
        for (entry in this.hiddenAreas) {
            if (entry.source == source) {
                if (rangeArraysEqual(entry.ranges, ranges)) {
                    return;
                }
                entry.ranges = ranges;
                this.shouldRecompute = true;
                return;
            }
        }
        this.hiddenAreas.push({source: source, ranges: ranges});
        this.shouldRecompute = true;
    }

    /**
     * The returned array is immutable.
     */
    public function getMergedRanges():Array<Range> {
        if (!this.shouldRecompute) {
            return this.ranges;
        }
        this.shouldRecompute = false;
        var newRanges:Array<Range> = [];
        for (entry in this.hiddenAreas) {
            newRanges = mergeLineRangeArray(newRanges, entry.ranges);
        }
        if (rangeArraysEqual(this.ranges, newRanges)) {
            return this.ranges;
        }
        this.ranges = newRanges;
        return this.ranges;
    }

    static function mergeLineRangeArray(arr1:Array<Range>, arr2:Array<Range>):Array<Range> {
        final result = [];
        var i = 0;
        var j = 0;
        while (i < arr1.length && j < arr2.length) {
            final item1 = arr1[i];
            final item2 = arr2[j];

            if (item1.endLineNumber < item2.startLineNumber - 1) {
                result.push(arr1[i++]);
            } else if (item2.endLineNumber < item1.startLineNumber - 1) {
                result.push(arr2[j++]);
            } else {
                final startLineNumber = Std.int(Math.min(item1.startLineNumber, item2.startLineNumber));
                final endLineNumber = Std.int(Math.max(item1.endLineNumber, item2.endLineNumber));
                result.push(new Range(startLineNumber, 1, endLineNumber, 1));
                i++;
                j++;
            }
        }
        while (i < arr1.length) {
            result.push(arr1[i++]);
        }
        while (j < arr2.length) {
            result.push(arr2[j++]);
        }
        return result;
    }

    static function rangeArraysEqual(arr1:Array<Range>, arr2:Array<Range>):Bool {
        if (arr1.length != arr2.length) {
            return false;
        }
        for (i in 0...arr1.length) {
            if (!arr1[i].equalsRange(arr2[i])) {
                return false;
            }
        }
        return true;
    }

}

/**
 * Maintain a stable viewport by trying to keep the first line in the viewport constant.
 */
private class StableViewport {

    public final viewportStartModelPosition:Null<Position>;
    public final startLineDelta:Float;

    public function new(viewportStartModelPosition:Null<Position>, startLineDelta:Float) {
        this.viewportStartModelPosition = viewportStartModelPosition;
        this.startLineDelta = startLineDelta;
    }

    public function recoverViewportStart(coordinatesConverter:ICoordinatesConverter, viewLayout:ViewLayout):Void {
        if (this.viewportStartModelPosition == null) {
            return;
        }
        final viewPosition = coordinatesConverter.convertModelPositionToViewPosition(this.viewportStartModelPosition);
        final viewPositionTop = viewLayout.getVerticalOffsetForLineNumber(viewPosition.lineNumber);
        viewLayout.setScrollPosition({scrollTop: viewPositionTop + this.startLineDelta}, ScrollType.Immediate);
    }

}
