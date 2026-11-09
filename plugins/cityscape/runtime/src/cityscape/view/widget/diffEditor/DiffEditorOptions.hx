// Ported from vscode src/vs/editor/browser/widget/diffEditor/diffEditorOptions.ts
// and src/vs/editor/common/config/diffEditor.ts (the defaults), with the
// option types of src/vs/editor/common/config/editorOptions.ts
// (IDiffEditorBaseOptions).
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.common.config.EditorOptions;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;

typedef IDiffEditorExperimentalOptions = {
    /**
     * Defaults to false.
     */
    @:optional var showMoves:Bool;
    @:optional var showEmptyDecorations:Bool;
    /**
     * Only applies when `renderSideBySide` is set to false.
     */
    @:optional var useTrueInlineView:Bool;
}

typedef IDiffEditorHideUnchangedRegionsOptions = {
    @:optional var enabled:Bool;
    @:optional var revealLineCount:Int;
    @:optional var minimumLineCount:Int;
    @:optional var contextLineCount:Int;
}

/**
 * Configuration options for the diff editor (Monaco's `IDiffEditorBaseOptions`).
 */
typedef IDiffEditorBaseOptions = {
    /**
     * Allow the user to resize the diff editor split view.
     * Defaults to true.
     */
    @:optional var enableSplitViewResizing:Bool;
    /**
     * The default ratio when rendering side-by-side editors.
     * Must be a number between 0 and 1, min sizes apply.
     * Defaults to 0.5
     */
    @:optional var splitViewDefaultRatio:Float;
    /**
     * Render the differences in two side-by-side editors.
     * Defaults to true.
     */
    @:optional var renderSideBySide:Bool;
    /**
     * When `renderSideBySide` is enabled, `useInlineViewWhenSpaceIsLimited` is set,
     * and the diff editor has a width less than `renderSideBySideInlineBreakpoint`, the inline view is used.
     */
    @:optional var renderSideBySideInlineBreakpoint:Int;
    /**
     * When `renderSideBySide` is enabled, `useInlineViewWhenSpaceIsLimited` is set,
     * and the diff editor has a width less than `renderSideBySideInlineBreakpoint`, the inline view is used.
     */
    @:optional var useInlineViewWhenSpaceIsLimited:Bool;
    /**
     * If set, the diff editor is optimized for small views.
     * Defaults to `false`.
     */
    @:optional var compactMode:Bool;
    /**
     * Timeout in milliseconds after which diff computation is cancelled.
     * Defaults to 5000.
     */
    @:optional var maxComputationTime:Int;
    /**
     * Maximum supported file size in MB.
     * Defaults to 50.
     */
    @:optional var maxFileSize:Int;
    /**
     * Compute the diff by ignoring leading/trailing whitespace
     * Defaults to true.
     */
    @:optional var ignoreTrimWhitespace:Bool;
    /**
     * Render +/- indicators for added/deleted changes.
     * Defaults to true.
     */
    @:optional var renderIndicators:Bool;
    /**
     * Shows icons in the glyph margin to revert changes.
     * Default to true.
     */
    @:optional var renderMarginRevertIcon:Bool;
    /**
     * Indicates if the gutter menu should be rendered.
     */
    @:optional var renderGutterMenu:Bool;
    /**
     * Original model should be editable?
     * Defaults to false.
     */
    @:optional var originalEditable:Bool;
    /**
     * Should the diff editor enable code lens?
     * Defaults to false.
     */
    @:optional var diffCodeLens:Bool;
    /**
     * Is the diff editor should render overview ruler
     * Defaults to true
     */
    @:optional var renderOverviewRuler:Bool;
    /**
     * Control the wrapping of the diff editor: `'off'`, `'on'` or `'inherit'`.
     */
    @:optional var diffWordWrap:String;
    /**
     * Diff Algorithm: `'legacy'` or `'advanced'`.
     */
    @:optional var diffAlgorithm:String;
    /**
     * Whether the diff editor aria label should be verbose.
     */
    @:optional var accessibilityVerbose:Bool;
    @:optional var experimental:IDiffEditorExperimentalOptions;
    /**
     * Is the diff editor inside another editor
     * Defaults to false
     */
    @:optional var isInEmbeddedEditor:Bool;
    /**
     * If the diff editor should only show the difference review mode.
     */
    @:optional var onlyShowAccessibleDiffViewer:Bool;
    @:optional var hideUnchangedRegions:IDiffEditorHideUnchangedRegionsOptions;
}

/**
 * Configuration options for the diff editor: the options of its two
 * editors (`IEditorOptions`) and the diff options.
 */
typedef IDiffEditorOptions = IEditorOptions & IDiffEditorBaseOptions;

/**
 * Monaco's `ValidDiffEditorBaseOptions` (all fields set).
 */
class ValidDiffEditorBaseOptions {
    public var enableSplitViewResizing:Bool;
    public var splitViewDefaultRatio:Float;
    public var renderSideBySide:Bool;
    public var renderMarginRevertIcon:Bool;
    public var maxComputationTime:Int;
    public var maxFileSize:Int;
    public var ignoreTrimWhitespace:Bool;
    public var renderIndicators:Bool;
    public var originalEditable:Bool;
    public var diffCodeLens:Bool;
    public var renderOverviewRuler:Bool;
    public var diffWordWrap:String;
    public var diffAlgorithm:String;
    public var accessibilityVerbose:Bool;
    public var showMoves:Bool;
    public var showEmptyDecorations:Bool;
    public var useTrueInlineView:Bool;
    public var hideUnchangedRegionsEnabled:Bool;
    public var hideUnchangedRegionsContextLineCount:Int;
    public var hideUnchangedRegionsMinimumLineCount:Int;
    public var hideUnchangedRegionsRevealLineCount:Int;
    public var isInEmbeddedEditor:Bool;
    public var onlyShowAccessibleDiffViewer:Bool;
    public var renderSideBySideInlineBreakpoint:Int;
    public var useInlineViewWhenSpaceIsLimited:Bool;
    public var renderGutterMenu:Bool;
    public var compactMode:Bool;

    public function new() {}

    /**
     * `diffEditorDefaultOptions` (src/vs/editor/common/config/diffEditor.ts).
     */
    public static function defaults():ValidDiffEditorBaseOptions {
        final o = new ValidDiffEditorBaseOptions();
        o.enableSplitViewResizing = true;
        o.splitViewDefaultRatio = 0.5;
        o.renderSideBySide = true;
        o.renderMarginRevertIcon = true;
        o.renderGutterMenu = true;
        o.maxComputationTime = 5000;
        o.maxFileSize = 50;
        o.ignoreTrimWhitespace = true;
        o.renderIndicators = true;
        o.originalEditable = false;
        o.diffCodeLens = false;
        o.renderOverviewRuler = true;
        o.diffWordWrap = 'inherit';
        o.diffAlgorithm = 'advanced';
        o.accessibilityVerbose = false;
        o.showMoves = false;
        o.showEmptyDecorations = true;
        o.useTrueInlineView = false;
        o.hideUnchangedRegionsEnabled = false;
        o.hideUnchangedRegionsContextLineCount = 3;
        o.hideUnchangedRegionsMinimumLineCount = 3;
        o.hideUnchangedRegionsRevealLineCount = 20;
        o.isInEmbeddedEditor = false;
        o.onlyShowAccessibleDiffViewer = false;
        o.renderSideBySideInlineBreakpoint = 900;
        o.useInlineViewWhenSpaceIsLimited = true;
        o.compactMode = false;
        return o;
    }

    /**
     * Monaco's `validateDiffEditorOptions(options, defaults)`.
     */
    public static function validate(options:Any, defaults:ValidDiffEditorBaseOptions):ValidDiffEditorBaseOptions {
        final experimental:Any = JsValues.field(options, 'experimental');
        final hide:Any = JsValues.field(options, 'hideUnchangedRegions');
        final o = new ValidDiffEditorBaseOptions();
        o.enableSplitViewResizing = EditorOptions.boolean(JsValues.field(options, 'enableSplitViewResizing'), defaults.enableSplitViewResizing);
        o.splitViewDefaultRatio = EditorOptions.clampedFloat(JsValues.field(options, 'splitViewDefaultRatio'), 0.5, 0.1, 0.9);
        o.renderSideBySide = EditorOptions.boolean(JsValues.field(options, 'renderSideBySide'), defaults.renderSideBySide);
        o.renderMarginRevertIcon = EditorOptions.boolean(JsValues.field(options, 'renderMarginRevertIcon'), defaults.renderMarginRevertIcon);
        o.maxComputationTime = EditorOptions.clampedInt(JsValues.field(options, 'maxComputationTime'), defaults.maxComputationTime, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.maxFileSize = EditorOptions.clampedInt(JsValues.field(options, 'maxFileSize'), defaults.maxFileSize, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.ignoreTrimWhitespace = EditorOptions.boolean(JsValues.field(options, 'ignoreTrimWhitespace'), defaults.ignoreTrimWhitespace);
        o.renderIndicators = EditorOptions.boolean(JsValues.field(options, 'renderIndicators'), defaults.renderIndicators);
        o.originalEditable = EditorOptions.boolean(JsValues.field(options, 'originalEditable'), defaults.originalEditable);
        o.diffCodeLens = EditorOptions.boolean(JsValues.field(options, 'diffCodeLens'), defaults.diffCodeLens);
        o.renderOverviewRuler = EditorOptions.boolean(JsValues.field(options, 'renderOverviewRuler'), defaults.renderOverviewRuler);
        o.diffWordWrap = EditorOptions.stringSet(JsValues.field(options, 'diffWordWrap'), defaults.diffWordWrap, ['off', 'on', 'inherit']);
        o.diffAlgorithm = EditorOptions.stringSet(JsValues.field(options, 'diffAlgorithm'), defaults.diffAlgorithm, ['legacy', 'advanced'], ['smart' => 'legacy', 'experimental' => 'advanced']);
        o.accessibilityVerbose = EditorOptions.boolean(JsValues.field(options, 'accessibilityVerbose'), defaults.accessibilityVerbose);
        o.showMoves = EditorOptions.boolean(experimental != null ? JsValues.field(experimental, 'showMoves') : null, defaults.showMoves);
        o.showEmptyDecorations = EditorOptions.boolean(experimental != null ? JsValues.field(experimental, 'showEmptyDecorations') : null, defaults.showEmptyDecorations);
        o.useTrueInlineView = EditorOptions.boolean(experimental != null ? JsValues.field(experimental, 'useTrueInlineView') : null, defaults.useTrueInlineView);
        var enabled:Any = hide != null ? JsValues.field(hide, 'enabled') : null;
        if (enabled == null && experimental != null) {
            enabled = JsValues.field(experimental, 'collapseUnchangedRegions');
        }
        o.hideUnchangedRegionsEnabled = EditorOptions.boolean(enabled, defaults.hideUnchangedRegionsEnabled);
        o.hideUnchangedRegionsContextLineCount = EditorOptions.clampedInt(hide != null ? JsValues.field(hide, 'contextLineCount') : null, defaults.hideUnchangedRegionsContextLineCount, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.hideUnchangedRegionsMinimumLineCount = EditorOptions.clampedInt(hide != null ? JsValues.field(hide, 'minimumLineCount') : null, defaults.hideUnchangedRegionsMinimumLineCount, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.hideUnchangedRegionsRevealLineCount = EditorOptions.clampedInt(hide != null ? JsValues.field(hide, 'revealLineCount') : null, defaults.hideUnchangedRegionsRevealLineCount, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.isInEmbeddedEditor = EditorOptions.boolean(JsValues.field(options, 'isInEmbeddedEditor'), defaults.isInEmbeddedEditor);
        o.onlyShowAccessibleDiffViewer = EditorOptions.boolean(JsValues.field(options, 'onlyShowAccessibleDiffViewer'), defaults.onlyShowAccessibleDiffViewer);
        o.renderSideBySideInlineBreakpoint = EditorOptions.clampedInt(JsValues.field(options, 'renderSideBySideInlineBreakpoint'), defaults.renderSideBySideInlineBreakpoint, 0, EditorOptions.MAX_SAFE_SMALL_INTEGER);
        o.useInlineViewWhenSpaceIsLimited = EditorOptions.boolean(JsValues.field(options, 'useInlineViewWhenSpaceIsLimited'), defaults.useInlineViewWhenSpaceIsLimited);
        o.renderGutterMenu = EditorOptions.boolean(JsValues.field(options, 'renderGutterMenu'), defaults.renderGutterMenu);
        o.compactMode = EditorOptions.boolean(JsValues.field(options, 'compactMode'), defaults.compactMode);
        return o;
    }
}

/**
 * The options of a diff editor (Monaco's `DiffEditorOptions`, its derived
 * observables as getters): the raw options given (`editorOptions`, also
 * applied to the two editors) and the validated diff options. `onDidChange`
 * fires when the options or the width change.
 */
class DiffEditorOptions {

    final _onDidChange = new VoidEmitter();
    public var onDidChange(get, never):VoidEvent;
    inline function get_onDidChange() return _onDidChange.event;

    /**
     * The raw options merged with the validated ones (Monaco's `_options`).
     */
    var _editorOptions:Dynamic;
    var _valid:ValidDiffEditorBaseOptions;

    /**
     * The options changed by the last `updateOptions` (Monaco's
     * `changedOptions` of the change).
     */
    public var lastChangedOptions(default, null):Dynamic = null;

    var _diffEditorWidth:Float = 0;

    /**
     * Incremented by `updateOptions`.
     */
    public var version(default, null):Int = 0;

    /**
     * The view model, for the compact mode (Monaco's `_model`).
     */
    var _model:Null<DiffEditorViewModel> = null;

    /**
     * Whether a screen reader is used (Monaco's `_screenReaderMode`): never
     * here (no accessibility service).
     */
    final _screenReaderMode:Bool = false;

    public function new(options:Null<IDiffEditorOptions>) {
        final raw:Dynamic = options != null ? options : {};
        _valid = ValidDiffEditorBaseOptions.validate(raw, ValidDiffEditorBaseOptions.defaults());
        _editorOptions = copyFields(raw, {});
    }

    static function copyFields(from:Dynamic, to:Dynamic):Dynamic {
        if (from != null) {
            for (field in Reflect.fields(from)) {
                Reflect.setField(to, field, Reflect.field(from, field));
            }
        }
        return to;
    }

    /**
     * The options as given (editor options and diff options).
     */
    public function editorOptions():Dynamic {
        return _editorOptions;
    }

    /**
     * The validated diff options.
     */
    public function valid():ValidDiffEditorBaseOptions {
        return _valid;
    }

    public var couldShowInlineViewBecauseOfSize(get, never):Bool;
    function get_couldShowInlineViewBecauseOfSize():Bool {
        return _valid.renderSideBySide && this._diffEditorWidth <= _valid.renderSideBySideInlineBreakpoint;
    }

    public var renderOverviewRuler(get, never):Bool;
    inline function get_renderOverviewRuler():Bool {
        return _valid.renderOverviewRuler;
    }

    public var renderSideBySide(get, never):Bool;
    function get_renderSideBySide():Bool {
        if (this.compactMode) {
            if (this.shouldRenderInlineViewInSmartMode()) {
                return false;
            }
        }

        return _valid.renderSideBySide
            && !(_valid.useInlineViewWhenSpaceIsLimited && this.couldShowInlineViewBecauseOfSize && !this._screenReaderMode);
    }

    public var readOnly(get, never):Bool;
    function get_readOnly():Bool {
        return JsValues.truthy(JsValues.field(_editorOptions, 'readOnly'));
    }

    public var shouldRenderOldRevertArrows(get, never):Bool;
    function get_shouldRenderOldRevertArrows():Bool {
        if (!_valid.renderMarginRevertIcon) {
            return false;
        }
        if (!this.renderSideBySide) {
            return false;
        }
        if (this.readOnly) {
            return false;
        }
        if (this.shouldRenderGutterMenu) {
            return false;
        }
        return true;
    }

    public var shouldRenderGutterMenu(get, never):Bool;
    inline function get_shouldRenderGutterMenu():Bool return _valid.renderGutterMenu;
    public var renderIndicators(get, never):Bool;
    inline function get_renderIndicators():Bool return _valid.renderIndicators;
    public var enableSplitViewResizing(get, never):Bool;
    inline function get_enableSplitViewResizing():Bool return _valid.enableSplitViewResizing;
    public var splitViewDefaultRatio(get, never):Float;
    inline function get_splitViewDefaultRatio():Float return _valid.splitViewDefaultRatio;
    public var ignoreTrimWhitespace(get, never):Bool;
    inline function get_ignoreTrimWhitespace():Bool return _valid.ignoreTrimWhitespace;
    public var maxComputationTimeMs(get, never):Int;
    inline function get_maxComputationTimeMs():Int return _valid.maxComputationTime;
    public var showMoves(get, never):Bool;
    function get_showMoves():Bool return _valid.showMoves && this.renderSideBySide;
    public var isInEmbeddedEditor(get, never):Bool;
    inline function get_isInEmbeddedEditor():Bool return _valid.isInEmbeddedEditor;
    public var diffWordWrap(get, never):String;
    inline function get_diffWordWrap():String return _valid.diffWordWrap;
    public var originalEditable(get, never):Bool;
    inline function get_originalEditable():Bool return _valid.originalEditable;
    public var diffCodeLens(get, never):Bool;
    inline function get_diffCodeLens():Bool return _valid.diffCodeLens;
    public var accessibilityVerbose(get, never):Bool;
    inline function get_accessibilityVerbose():Bool return _valid.accessibilityVerbose;
    public var diffAlgorithm(get, never):String;
    inline function get_diffAlgorithm():String return _valid.diffAlgorithm;
    public var showEmptyDecorations(get, never):Bool;
    inline function get_showEmptyDecorations():Bool return _valid.showEmptyDecorations;
    public var onlyShowAccessibleDiffViewer(get, never):Bool;
    inline function get_onlyShowAccessibleDiffViewer():Bool return _valid.onlyShowAccessibleDiffViewer;
    public var compactMode(get, never):Bool;
    inline function get_compactMode():Bool return _valid.compactMode;

    var trueInlineDiffRenderingEnabled(get, never):Bool;
    inline function get_trueInlineDiffRenderingEnabled():Bool return _valid.useTrueInlineView;

    public var useTrueInlineDiffRendering(get, never):Bool;
    function get_useTrueInlineDiffRendering():Bool {
        return !this.renderSideBySide && this.trueInlineDiffRenderingEnabled;
    }

    public var hideUnchangedRegions(get, never):Bool;
    inline function get_hideUnchangedRegions():Bool return _valid.hideUnchangedRegionsEnabled;
    public var hideUnchangedRegionsRevealLineCount(get, never):Int;
    inline function get_hideUnchangedRegionsRevealLineCount():Int return _valid.hideUnchangedRegionsRevealLineCount;
    public var hideUnchangedRegionsContextLineCount(get, never):Int;
    inline function get_hideUnchangedRegionsContextLineCount():Int return _valid.hideUnchangedRegionsContextLineCount;
    public var hideUnchangedRegionsMinimumLineCount(get, never):Int;
    inline function get_hideUnchangedRegionsMinimumLineCount():Int return _valid.hideUnchangedRegionsMinimumLineCount;

    public function updateOptions(changedOptions:IDiffEditorOptions):Void {
        final newDiffEditorOptions = ValidDiffEditorBaseOptions.validate(changedOptions, _valid);
        copyFields(changedOptions, _editorOptions);
        _valid = newDiffEditorOptions;
        lastChangedOptions = changedOptions;
        version++;
        _onDidChange.fire();
    }

    public function setWidth(width:Float):Void {
        if (width == this._diffEditorWidth) {
            return;
        }
        this._diffEditorWidth = width;
        _onDidChange.fire();
    }

    public function setModel(model:Null<DiffEditorViewModel>):Void {
        this._model = model;
    }

    /**
     * Monaco's `shouldRenderInlineViewInSmartMode` (`derivedConstOnceDefined`:
     * the first defined value is kept for the view model).
     */
    var _smartModeModel:Null<DiffEditorViewModel> = null;
    var _smartModeValue:Null<Bool> = null;

    function shouldRenderInlineViewInSmartMode():Bool {
        final model = this._model;
        if (model != _smartModeModel) {
            _smartModeModel = model;
            _smartModeValue = null;
        }
        if (_smartModeValue == null && model != null) {
            final diffs = model.diff;
            if (diffs != null) {
                _smartModeValue = isSimpleDiff(diffs, this.trueInlineDiffRenderingEnabled);
            }
        }
        return _smartModeValue == true;
    }

    public var inlineViewHideOriginalLineNumbers(get, never):Bool;
    inline function get_inlineViewHideOriginalLineNumbers():Bool return this.compactMode;

    static function isSimpleDiff(diff:DiffState, supportsTrueDiffRendering:Bool):Bool {
        for (m in diff.mappings) {
            if (!(isInsertion(m.lineRangeMapping) || isDeletion(m.lineRangeMapping) || (supportsTrueDiffRendering && DiffEditorViewZones.allowsTrueInlineDiffRendering(m.lineRangeMapping)))) {
                return false;
            }
        }
        return true;
    }

    static function isInsertion(mapping:LineRangeMapping):Bool {
        return mapping.original.length == 0;
    }

    static function isDeletion(mapping:LineRangeMapping):Bool {
        return mapping.modified.length == 0;
    }

}
