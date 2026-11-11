// Ported from vscode src/vs/editor/browser/widget/diffEditor/diffEditorWidget.ts
// and components/diffEditorEditors.ts (the options of the two editors).
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.diff.LegacyLinesDiffComputer.IDiffComputationResult;
import cityscape.common.diff.LegacyLinesDiffComputer.ILineChange;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.view.EditorBrowser;
import cityscape.view.StableEditorScroll;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorDecorations;
import cityscape.view.widget.diffEditor.DiffEditorOptions;
import cityscape.view.widget.diffEditor.DiffEditorUtils;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;
import cityscape.view.widget.diffEditor.DiffEditorViewZones;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService;
import cityscape.view.widget.diffEditor.HideUnchangedRegionsFeature;

/**
 * The view state of a diff editor (Monaco's `IDiffEditorViewState`).
 */
typedef IDiffEditorViewState = {
    var original:Null<cityscape.common.EditorCommon.IEditorViewState>;
    var modified:Null<cityscape.common.EditorCommon.IEditorViewState>;
    @:optional var modelState:Any;
}

/**
 * What the diff editor paints in its view zones (given by the component).
 */
interface IDiffEditorPainters extends IDiffEditorZonePainters extends ICollapsedCodeBarPainter {}

/**
 * Monaco's `DiffEditorWidget` without its DOM: the logic of a diff editor
 * over two code editors (the original on the left, the modified on the
 * right). `CityscapeDiffEditor` places the two editors, sets the width
 * (`setWidth`) and paints the overview ruler; this class keeps the diff,
 * the decorations, the view zones, the hidden unchanged regions and the
 * scrolling of the two editors in step.
 *
 * Monaco's observables are replaced by update methods: `_update` runs
 * when the diff, the unchanged regions or the options change.
 */
class DiffEditorWidget implements IDisposable {

    public final original:CodeEditorWidget;
    public final modified:CodeEditorWidget;

    /**
     * The gutter menu between the editors (Monaco's `DiffEditorGutter`,
     * drawn by `CityscapeDiffEditor`).
     */
    public final gutter:DiffEditorGutter;

    final _options:DiffEditorOptions;
    final _painters:IDiffEditorPainters;
    final _store = new DisposableStore();

    var _diffModel:Null<DiffEditorViewModel> = null;
    final _diffModelStore = new DisposableStore();

    final _decorations:DiffEditorDecorations;
    final _viewZoneManager:DiffEditorViewZones;
    final _unchangedRangesFeature:HideUnchangedRegionsFeature;

    final origViewZoneIdsToIgnore = new Map<String, Bool>();
    final modViewZoneIdsToIgnore = new Map<String, Bool>();
    var isUpdatingViewZones = false;
    final _originalViewZones:ViewZoneSet;
    final _modifiedViewZones:ViewZoneSet;

    final _onDidUpdateDiff = new VoidEmitter();
    /**
     * Fired when the diff changed (Monaco's `onDidUpdateDiff`).
     */
    public var onDidUpdateDiff(get, never):VoidEvent;
    inline function get_onDidUpdateDiff() return _onDidUpdateDiff.event;

    final _onDidChangeModel = new VoidEmitter();
    public var onDidChangeModel(get, never):VoidEvent;
    inline function get_onDidChangeModel() return _onDidChangeModel.event;

    final _onDidChange = new VoidEmitter();
    /**
     * Fired when something the component paints changed (the diff, the
     * regions, the options, the layout): the component renders again.
     */
    public var onDidChange(get, never):VoidEvent;
    inline function get_onDidChange() return _onDidChange.event;

    /**
     * Applies the options of the original editor (the component routes them
     * through `CityscapeEditor.updateOptions`).
     */
    public var applyOriginalOptions:(options:IEditorOptions) -> Void;

    /**
     * Applies the options of the modified editor.
     */
    public var applyModifiedOptions:(options:IEditorOptions) -> Void;

    /**
     * Where the diffs of the next models are computed (null: the default
     * of the platform, see `DiffComputationMode`).
     */
    public var computationMode:Null<DiffComputationMode> = null;

    var _lastRenderSideBySide:Null<Bool> = null;
    var _appliedOptionsVersion:Int = -1;
    var _disposed = false;

    public function new(original:CodeEditorWidget, modified:CodeEditorWidget, options:Null<IDiffEditorOptions>, painters:IDiffEditorPainters) {
        this.original = original;
        this.modified = modified;
        this._painters = painters;
        this._options = new DiffEditorOptions(options);
        this.gutter = new DiffEditorGutter(this);
        this.applyOriginalOptions = (o) -> original.updateOptions(o);
        this.applyModifiedOptions = (o) -> modified.updateOptions(o);

        original.setContextValue('isInDiffLeftEditor', true);
        modified.setContextValue('isInDiffRightEditor', true);

        final editors = {original: original, modified: modified};

        this._decorations = new DiffEditorDecorations(original, modified);

        this._unchangedRangesFeature = new HideUnchangedRegionsFeature(editors, () -> this._diffModel, this._options, painters);

        this._viewZoneManager = new DiffEditorViewZones(
            editors,
            () -> this._diffModel,
            this._options,
            () -> isUpdatingViewZones || this._unchangedRangesFeature.isUpdatingHiddenAreas,
            origViewZoneIdsToIgnore,
            modViewZoneIdsToIgnore,
            painters
        );
        this._viewZoneManager.onInvalidate = () -> this._updateViewZones();

        this._originalViewZones = new ViewZoneSet(original, (isUpdatingOrigViewZones) -> {
            isUpdatingViewZones = isUpdatingOrigViewZones;
        }, origViewZoneIdsToIgnore);
        var scrollState:Null<StableEditorScrollState> = null;
        final modifiedScrollEditor = new ScrollStateEditor(modified);
        this._modifiedViewZones = new ViewZoneSet(modified, (isUpdatingModViewZones) -> {
            isUpdatingViewZones = isUpdatingModViewZones;
            if (isUpdatingViewZones) {
                scrollState = StableEditorScrollState.capture(modifiedScrollEditor);
            }
            else {
                if (scrollState != null) {
                    scrollState.restore(modifiedScrollEditor);
                }
                scrollState = null;
            }
        }, modViewZoneIdsToIgnore);

        this._store.add(this._options.onDidChange(() -> {
            this._options.setModel(this._diffModel);
            this._update();
        }));

        // The mouse on the bars of the hidden regions
        this._store.add(original.onMouseDown((e) -> this._onZoneMouseDown(original, e)));
        this._store.add(modified.onMouseDown((e) -> this._onZoneMouseDown(modified, e)));

        this._updateEditorOptions();
    }

    public function dispose():Void {
        if (_disposed) {
            return;
        }
        _disposed = true;
        this.setModel(null);
        _store.dispose();
        _diffModelStore.dispose();
        _decorations.dispose();
        _viewZoneManager.dispose();
        _unchangedRangesFeature.dispose();
        _originalViewZones.dispose();
        _modifiedViewZones.dispose();
        _onDidUpdateDiff.dispose();
        _onDidChange.dispose();
        _onDidChangeModel.dispose();
    }

    //#region options of the two editors (diffEditorEditors.ts)

    function _updateEditorOptions():Void {
        final renderSideBySide = this._options.renderSideBySide;
        this.applyModifiedOptions(this._adjustOptionsForRightHandSide(this._options.editorOptions()));
        this.applyOriginalOptions(this._adjustOptionsForLeftHandSide(this._options.editorOptions()));
        _lastRenderSideBySide = renderSideBySide;
        _appliedOptionsVersion = this._options.version;
    }

    function _adjustOptionsForLeftHandSide(changedOptions:Dynamic):IEditorOptions {
        final result:Dynamic = this._adjustOptionsForSubEditor(changedOptions);
        if (!this._options.renderSideBySide) {
            // never wrap hidden editor
            result.wordWrapOverride1 = 'off';
            result.wordWrapOverride2 = 'off';
            result.stickyScroll = {enabled: false};

            // Disable unicode highlighting for the original side in inline mode, as they are not shown anyway.
            result.unicodeHighlight = {nonBasicASCII: false, ambiguousCharacters: false, invisibleCharacters: false};
        }
        else {
            final unicodeHighlight:Dynamic = Reflect.field(this._options.editorOptions(), 'unicodeHighlight');
            result.unicodeHighlight = unicodeHighlight != null ? unicodeHighlight : {};
            result.wordWrapOverride1 = this._options.diffWordWrap;
        }
        result.glyphMargin = this._options.renderSideBySide;

        final originalAriaLabel:Null<String> = Reflect.field(changedOptions, 'originalAriaLabel');
        if (originalAriaLabel != null) {
            result.ariaLabel = originalAriaLabel;
        }
        result.readOnly = !this._options.originalEditable;
        result.dropIntoEditor = {enabled: !result.readOnly};
        result.extraEditorClassName = 'original-in-monaco-diff-editor';
        return result;
    }

    function _adjustOptionsForRightHandSide(changedOptions:Dynamic):IEditorOptions {
        final result:Dynamic = this._adjustOptionsForSubEditor(changedOptions);
        final modifiedAriaLabel:Null<String> = Reflect.field(changedOptions, 'modifiedAriaLabel');
        if (modifiedAriaLabel != null) {
            result.ariaLabel = modifiedAriaLabel;
        }
        result.wordWrapOverride1 = this._options.diffWordWrap;
        result.revealHorizontalRightPadding = 15 + OverviewRulerFeature.ENTIRE_DIFF_OVERVIEW_WIDTH;
        result.scrollbar.verticalHasArrows = false;
        result.extraEditorClassName = 'modified-in-monaco-diff-editor';
        return result;
    }

    function _adjustOptionsForSubEditor(options:Dynamic):Dynamic {
        final clonedOptions:Dynamic = {};
        for (field in Reflect.fields(options)) {
            Reflect.setField(clonedOptions, field, Reflect.field(options, field));
        }
        clonedOptions.inDiffEditor = true;
        clonedOptions.automaticLayout = false;

        // Clone scrollbar options before changing them
        final scrollbar:Dynamic = {};
        final givenScrollbar:Dynamic = Reflect.field(options, 'scrollbar');
        if (givenScrollbar != null) {
            for (field in Reflect.fields(givenScrollbar)) {
                Reflect.setField(scrollbar, field, Reflect.field(givenScrollbar, field));
            }
        }
        clonedOptions.scrollbar = scrollbar;
        clonedOptions.folding = false;
        clonedOptions.codeLens = this._options.diffCodeLens;
        clonedOptions.fixedOverflowWidgets = true;

        // Clone minimap options before changing them
        clonedOptions.minimap = {enabled: false};

        if (this._options.hideUnchangedRegions) {
            clonedOptions.stickyScroll = {enabled: false};
        }
        else {
            clonedOptions.stickyScroll = Reflect.field(this._options.editorOptions(), 'stickyScroll');
        }
        return clonedOptions;
    }

    //#endregion

    /**
     * The options of the diff editor.
     */
    public function getOptions():DiffEditorOptions {
        return this._options;
    }

    /**
     * The width of the diff editor (the inline view is used below
     * `renderSideBySideInlineBreakpoint` with `useInlineViewWhenSpaceIsLimited`).
     */
    public function setWidth(width:Float):Void {
        this._options.setWidth(width);
    }

    public function getViewModel():Null<DiffEditorViewModel> {
        return this._diffModel;
    }

    public function getModel():Null<IDiffEditorModel> {
        return this._diffModel != null ? this._diffModel.model : null;
    }

    public function setModel(model:Null<IDiffEditorModel>):Void {
        final current = this._diffModel;
        if (current != null && model != null && current.model.original == model.original && current.model.modified == model.modified) {
            return;
        }
        if (current == null && model == null) {
            return;
        }
        _diffModelStore.clear();
        if (current != null) {
            current.dispose();
        }
        this._diffModel = null;
        this.original.setModel(model != null ? model.original : null);
        this.modified.setModel(model != null ? model.modified : null);
        if (model != null) {
            final vm = new DiffEditorViewModel(model, this._options, this.computationMode);
            this._diffModel = vm;
            _diffModelStore.add(vm.onDidChangeDiff(() -> {
                this._update();
                this._onDidUpdateDiff.fire();
            }));
            _diffModelStore.add(vm.onDidChangeUnchangedRegions(() -> this._update()));
            for (m in [model.original, model.modified]) {
                _diffModelStore.add(m.onWillDispose(() -> {
                    cityscape.base.common.Errors.onUnexpectedError(new cityscape.base.common.Errors.BugIndicatingError('TextModel got disposed before DiffEditorWidget model got reset'));
                    this.setModel(null);
                }));
            }
        }
        this._options.setModel(this._diffModel);
        this._updateEditorOptions();
        this._update();
        this._onDidChangeModel.fire();
    }

    function _update():Void {
        if (_disposed) {
            return;
        }
        if (this._options.renderSideBySide != _lastRenderSideBySide || this._options.version != _appliedOptionsVersion) {
            this._updateEditorOptions();
        }
        this._decorations.update(this._diffModel, this._options);
        this._unchangedRangesFeature.update();
        this._updateViewZones();
        this._onDidChange.fire();
    }

    /**
     * Applies the zones of the alignment and of the hidden regions to the
     * two editors (Monaco's `applyViewZones` autoruns).
     */
    function _updateViewZones():Void {
        if (_disposed) {
            return;
        }
        final zones = this._viewZoneManager.computeViewZones();
        final hidden = this._unchangedRangesFeature.viewZones();
        this._originalViewZones.set(zones.orig.concat(hidden.origViewZones));
        this._modifiedViewZones.set(zones.mod.concat(hidden.modViewZones));
        this._onDidChange.fire();
    }

    function _onZoneMouseDown(editor:CodeEditorWidget, e:IEditorMouseEvent):Void {
        final target = e.target;
        if (target.type != MouseTargetType.CONTENT_VIEW_ZONE && target.type != MouseTargetType.GUTTER_VIEW_ZONE) {
            return;
        }
        final data = target.viewZoneData;
        if (data == null) {
            return;
        }
        this._unchangedRangesFeature.handleBarMouseDown(editor, data.viewZoneId, target.viewZoneOffsetY, target.type == MouseTargetType.GUTTER_VIEW_ZONE, e.event.detail, e.event.posy, e.event.leftButton);
    }

    /**
     * Runs the pending diff computation and view zone update now (tests).
     */
    public function _flush():Void {
        if (this._diffModel != null) {
            this._diffModel._flushPendingDiff();
        }
        this._viewZoneManager._flush();
    }

    //#region IDiffEditor

    public function getOriginalEditor():CodeEditorWidget {
        return this.original;
    }

    public function getModifiedEditor():CodeEditorWidget {
        return this.modified;
    }

    public function updateOptions(changedOptions:IDiffEditorOptions):Void {
        this._options.updateOptions(changedOptions);
    }

    public var ignoreTrimWhitespace(get, never):Bool;
    inline function get_ignoreTrimWhitespace():Bool return this._options.ignoreTrimWhitespace;

    public var maxComputationTime(get, never):Int;
    inline function get_maxComputationTime():Int return this._options.maxComputationTimeMs;

    public var renderSideBySide(get, never):Bool;
    inline function get_renderSideBySide():Bool return this._options.renderSideBySide;

    /**
     * The line changes (Monaco's deprecated `getLineChanges`), null before
     * the first diff.
     */
    public function getLineChanges():Null<Array<ILineChange>> {
        final diffState = this._diffModel != null ? this._diffModel.diff : null;
        if (diffState == null) {
            return null;
        }
        return toLineChanges(diffState);
    }

    public function getDiffComputationResult():Null<IDiffComputationResult> {
        final diffState = this._diffModel != null ? this._diffModel.diff : null;
        if (diffState == null) {
            return null;
        }

        return {
            changes: this.getLineChanges(),
            changes2: diffState.mappings.map(m -> m.lineRangeMapping),
            identical: diffState.identical,
            quitEarly: diffState.quitEarly,
        };
    }

    public function revert(diff:LineRangeMapping):Void {
        final model = this._diffModel;
        if (model == null || !model.isDiffUpToDate) {
            return;
        }

        this.modified.executeEdits('diffEditor', [
            {
                range: diff.modified.toExclusiveRange(),
                text: model.model.original.getValueInRange(diff.original.toExclusiveRange())
            }
        ]);
    }

    public function revertRangeMappings(diffs:Array<RangeMapping>):Void {
        final model = this._diffModel;
        if (model == null || !model.isDiffUpToDate) {
            return;
        }

        final changes:Array<IIdentifiedSingleEditOperation> = diffs.map(c -> ({
            range: c.modifiedRange,
            text: model.model.original.getValueInRange(c.originalRange)
        } : IIdentifiedSingleEditOperation));

        this.modified.executeEdits('diffEditor', changes);
    }

    function _goTo(diff:DiffMapping):Void {
        this.modified.setPosition(new Position(diff.lineRangeMapping.modified.startLineNumber, 1));
        this.modified.revealRangeInCenter(diff.lineRangeMapping.modified.toExclusiveRange());
    }

    /**
     * Goes to the next or previous change (`'next'` or `'previous'`).
     */
    public function goToDiff(target:String):Void {
        final diffs = this._diffModel != null && this._diffModel.diff != null ? this._diffModel.diff.mappings : null;
        if (diffs == null || diffs.length == 0) {
            return;
        }

        final position = this.modified.getPosition();
        final curLineNumber = position != null ? position.lineNumber : 1;

        var diff:Null<DiffMapping> = null;
        if (target == 'next') {
            for (d in diffs) {
                if (d.lineRangeMapping.modified.startLineNumber > curLineNumber) {
                    diff = d;
                    break;
                }
            }
            if (diff == null) {
                diff = diffs[0];
            }
        }
        else {
            var k = diffs.length - 1;
            while (k >= 0) {
                if (diffs[k].lineRangeMapping.modified.startLineNumber < curLineNumber) {
                    diff = diffs[k];
                    break;
                }
                k--;
            }
            if (diff == null) {
                diff = diffs[diffs.length - 1];
            }
        }
        this._goTo(diff);
        // The accessibility signals of Monaco are not ported
    }

    public function revealFirstDiff():Void {
        final diffModel = this._diffModel;
        if (diffModel == null) {
            return;
        }
        // wait for the diff computation to finish
        diffModel.waitForDiff(() -> {
            final diffs = diffModel.diff != null ? diffModel.diff.mappings : null;
            if (diffs == null || diffs.length == 0) {
                return;
            }
            this._goTo(diffs[0]);
        });
    }

    public function waitForDiff(callback:() -> Void):Void {
        final diffModel = this._diffModel;
        if (diffModel == null) {
            callback();
            return;
        }
        diffModel.waitForDiff(callback);
    }

    public function mapToOtherSide():{destination:CodeEditorWidget, destinationSelection:Null<Range>} {
        final isModifiedFocus = this.modified.hasWidgetFocus();
        final source = isModifiedFocus ? this.modified : this.original;
        final destination = isModifiedFocus ? this.original : this.modified;

        var destinationSelection:Null<Range> = null;

        final sourceSelection = source.getSelection();
        if (sourceSelection != null) {
            final diff = this._diffModel != null ? this._diffModel.diff : null;
            if (diff != null) {
                final mappings = diff.mappings.map(m -> isModifiedFocus ? m.lineRangeMapping.flip() : m.lineRangeMapping);
                final newRange1 = DiffEditorUtils.translatePosition(sourceSelection.getStartPosition(), mappings);
                final newRange2 = DiffEditorUtils.translatePosition(sourceSelection.getEndPosition(), mappings);
                destinationSelection = Range.plusRangeStatic(newRange1, newRange2);
            }
        }
        return {destination: destination, destinationSelection: destinationSelection};
    }

    public function switchSide():Void {
        final r = this.mapToOtherSide();
        r.destination.focus();
        if (r.destinationSelection != null) {
            r.destination.setSelection(r.destinationSelection);
        }
    }

    public function exitCompareMove():Void {
        final model = this._diffModel;
        if (model == null) {
            return;
        }
        model.movedTextToCompare = null;
        this._update();
    }

    public function collapseAllUnchangedRegions():Void {
        final model = this._diffModel;
        if (model == null) {
            return;
        }
        for (region in model.unchangedRegions) {
            region.collapseAll();
        }
    }

    public function showAllUnchangedRegions():Void {
        final model = this._diffModel;
        if (model == null) {
            return;
        }
        for (region in model.unchangedRegions) {
            region.showAll();
        }
    }

    public function saveViewState():IDiffEditorViewState {
        final originalViewState = this.original.saveViewState();
        final modifiedViewState = this.modified.saveViewState();
        return {
            original: originalViewState,
            modified: modifiedViewState,
            modelState: this._diffModel != null ? this._diffModel.serializeState() : null,
        };
    }

    public function restoreViewState(s:Null<IDiffEditorViewState>):Void {
        if (s != null && s.original != null && s.modified != null) {
            this.original.restoreViewState(s.original);
            this.modified.restoreViewState(s.modified);
            if (s.modelState != null && this._diffModel != null) {
                this._diffModel.restoreSerializedState(cast s.modelState);
            }
        }
    }

    public function hasTextFocus():Bool {
        return this.original.hasTextFocus() || this.modified.hasTextFocus();
    }

    public function getContentHeight():Float {
        return this.modified.getContentHeight();
    }

    //#endregion

    static function toLineChanges(state:DiffState):Array<ILineChange> {
        return state.mappings.map(x -> {
            final m = x.lineRangeMapping;
            var originalStartLineNumber:Int;
            var originalEndLineNumber:Int;
            var modifiedStartLineNumber:Int;
            var modifiedEndLineNumber:Int;
            var innerChanges = m.innerChanges;

            if (m.original.isEmpty) {
                // Insertion
                originalStartLineNumber = m.original.startLineNumber - 1;
                originalEndLineNumber = 0;
                innerChanges = null;
            }
            else {
                originalStartLineNumber = m.original.startLineNumber;
                originalEndLineNumber = m.original.endLineNumberExclusive - 1;
            }

            if (m.modified.isEmpty) {
                // Deletion
                modifiedStartLineNumber = m.modified.startLineNumber - 1;
                modifiedEndLineNumber = 0;
                innerChanges = null;
            }
            else {
                modifiedStartLineNumber = m.modified.startLineNumber;
                modifiedEndLineNumber = m.modified.endLineNumberExclusive - 1;
            }

            return ({
                originalStartLineNumber: originalStartLineNumber,
                originalEndLineNumber: originalEndLineNumber,
                modifiedStartLineNumber: modifiedStartLineNumber,
                modifiedEndLineNumber: modifiedEndLineNumber,
                charChanges: innerChanges != null ? innerChanges.map(m -> ({
                    originalStartLineNumber: m.originalRange.startLineNumber,
                    originalStartColumn: m.originalRange.startColumn,
                    originalEndLineNumber: m.originalRange.endLineNumber,
                    originalEndColumn: m.originalRange.endColumn,
                    modifiedStartLineNumber: m.modifiedRange.startLineNumber,
                    modifiedStartColumn: m.modifiedRange.startColumn,
                    modifiedEndLineNumber: m.modifiedRange.endLineNumber,
                    modifiedEndColumn: m.modifiedRange.endColumn,
                } : cityscape.common.diff.LegacyLinesDiffComputer.ICharChange)) : null
            } : ILineChange);
        });
    }

}

/**
 * A `CodeEditorWidget` as the editor of `StableEditorScrollState`.
 */
private class ScrollStateEditor implements IScrollStateEditor {

    final editor:CodeEditorWidget;

    public function new(editor:CodeEditorWidget) {
        this.editor = editor;
    }

    public function getScrollTop():Float {
        return editor.getScrollTop();
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void {
        editor.setScrollTop(newScrollTop, scrollType);
    }

    public function hasPendingScrollAnimation():Bool {
        return false;
    }

    public function getContentHeight():Float {
        return editor.getContentHeight();
    }

    public function getVisibleRanges():Array<Range> {
        return editor.getVisibleRanges();
    }

    public function getTopForLineNumber(lineNumber:Int):Float {
        return editor.getTopForLineNumber(lineNumber);
    }

    public function getTopForPosition(lineNumber:Int, column:Int):Float {
        return editor.getTopForPosition(lineNumber, column);
    }

    public function getPosition():Null<Position> {
        return editor.getPosition();
    }

}

/**
 * The constants of Monaco's `OverviewRulerFeature` (the ruler is painted
 * by `CityscapeDiffEditor`).
 */
class OverviewRulerFeature {
    public static inline final ONE_OVERVIEW_WIDTH = 15;
    public static inline final ENTIRE_DIFF_OVERVIEW_WIDTH = ONE_OVERVIEW_WIDTH * 2;
}
