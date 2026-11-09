// Ported from vscode src/vs/editor/contrib/colorPicker/browser/colorDetector.ts
// (the swatch of colorPicker.css `.colorpicker-color-decoration`)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Color;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.common.services.LanguageFeatureDebounce.FeatureDebounceInformation;
import cityscape.contrib.colorPicker.view.Color.ColorUtils;
import cityscape.contrib.colorPicker.view.Color.IColorData;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;

/**
 * Monaco's `ColorDecorationInjectedTextMarker`: the `attachedData` of the
 * swatches, which tells a click on a swatch.
 */
class ColorDecorationInjectedTextMarker {

    /** The marker object (immutable, shared by every editor). */
    public static final INSTANCE:ColorDecorationInjectedTextMarker = new ColorDecorationInjectedTextMarker();

    function new() {}

}

/**
 * Finds the colors of the model (the color providers, else the default
 * colors computer when `defaultColorDecorators` is on) and shows a swatch
 * of each before it (Monaco's `ColorDetector`): a `before` injected text
 * (Monaco's non breaking space) with the class name
 * `colorpicker-color-decoration` and a typed style per color (Monaco
 * creates a CSS rule per color): the color as background, a border of 0.1em
 * (`#000`, `#eee` in dark themes). Monaco's swatch is a 0.8em square with
 * margins; the line layout of Cityscape gives an injected text the width of
 * its characters, so the swatch is a square as wide as the space, centered
 * on the text (see DEVIATIONS.md). The colors are computed again 1 s after
 * an edit (the language feature debounce).
 */
class ColorDetector extends Disposable implements IEditorContribution {

    public static inline final ID:String = 'editor.contrib.colorDetector';

    public static inline final RECOMPUTE_TIME = 1000; // ms

    final _localToDispose = new DisposableStore();
    var _computePromise:Null<CancellationTokenSource>;
    var _timeoutTimer:Null<TimeoutTimer>;
    final _debounceInformation:FeatureDebounceInformation;

    var _decorationsIds:Array<String> = [];
    var _colorDatas:Map<String, IColorData> = new Map();

    final _colorDecoratorIds:IEditorDecorationsCollection;

    var _isColorDecoratorsEnabled:Bool;
    var _isDefaultColorDecoratorsEnabled:Bool;

    final _decoratorLimitReporter = new DecoratorLimitReporter();

    /** The colors of the last computation (for a new theme or font size). */
    var _lastColorData:Array<IColorData> = [];

    final _editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._register(_localToDispose);
        this._colorDecoratorIds = editor.createDecorationsCollection();
        final languageFeaturesService = editor.context.languageFeaturesService;
        this._debounceInformation = new FeatureDebounceInformation(ColorDetector.RECOMPUTE_TIME);
        this._register(_editor.onDidChangeModel(_ -> {
            this._isColorDecoratorsEnabled = this.isEnabled();
            this.updateColors();
        }));
        this._register(_editor.onDidChangeModelLanguage(_ -> this.updateColors()));
        this._register(languageFeaturesService.colorProvider.onDidChange(_ -> this.updateColors()));
        this._register(_editor.onDidChangeConfiguration(e -> {
            final prevIsEnabled = this._isColorDecoratorsEnabled;
            this._isColorDecoratorsEnabled = this.isEnabled();
            this._isDefaultColorDecoratorsEnabled = this._editor.getOption(EditorOption.defaultColorDecorators);
            final updatedColorDecoratorsSetting = prevIsEnabled != this._isColorDecoratorsEnabled || e.hasChanged(EditorOption.colorDecoratorsLimit);
            final updatedDefaultColorDecoratorsSetting = e.hasChanged(EditorOption.defaultColorDecorators);
            if (updatedColorDecoratorsSetting || updatedDefaultColorDecoratorsSetting) {
                if (this._isColorDecoratorsEnabled) {
                    this.updateColors();
                }
                else {
                    this.removeAllDecorations();
                }
            }
            else if (e.hasChanged(EditorOption.fontInfo) && this._isColorDecoratorsEnabled) {
                // the swatch is sized in em (Monaco's CSS follows the font by itself)
                this.updateColorDecorators(this._lastColorData);
            }
        }));
        // the border of the swatch depends on the theme (`.vs-dark` in Monaco's CSS)
        this._register(editor.context.themeService.onDidColorThemeChange(_ -> {
            if (this._isColorDecoratorsEnabled && this._lastColorData.length > 0) {
                this.updateColorDecorators(this._lastColorData);
            }
        }));

        this._timeoutTimer = null;
        this._computePromise = null;
        this._isColorDecoratorsEnabled = this.isEnabled();
        this._isDefaultColorDecoratorsEnabled = this._editor.getOption(EditorOption.defaultColorDecorators);
        this.updateColors();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Monaco also reads the deprecated `[languageId].colorDecorators.enable`
     * setting; Cityscape has no language settings.
     */
    public function isEnabled():Bool {
        final model = this._editor.getModel();
        if (model == null) {
            return false;
        }
        return this._editor.getOption(EditorOption.colorDecorators);
    }

    public var limitReporter(get, never):DecoratorLimitReporter;
    function get_limitReporter():DecoratorLimitReporter {
        return this._decoratorLimitReporter;
    }

    public static function get(editor:ICodeEditor):Null<ColorDetector> {
        return editor.getContribution(ColorDetector.ID);
    }

    override public function dispose():Void {
        this.stop();
        this.removeAllDecorations();
        _decoratorLimitReporter.dispose();
        super.dispose();
    }

    /**
     * Runs a pending computation now (tests: Monaco waits for its timer).
     */
    public function _flushPendingUpdate():Void {
        if (this._timeoutTimer != null) {
            this._timeoutTimer.flush();
        }
    }

    function updateColors():Void {
        this.stop();

        if (!this._isColorDecoratorsEnabled) {
            return;
        }
        final model = this._editor.getModel();

        if (model == null || !this._editor.context.languageFeaturesService.colorProvider.has(model)) {
            return;
        }

        this._localToDispose.add(this._editor.onDidChangeModelContent(_ -> {
            if (this._timeoutTimer == null) {
                final timer = new TimeoutTimer();
                this._timeoutTimer = timer;
                timer.cancelAndSet(() -> {
                    this._timeoutTimer = null;
                    this.beginCompute();
                }, this._debounceInformation.get(model));
            }
        }));
        this.beginCompute();
    }

    function beginCompute():Void {
        final model = this._editor.getModel();
        if (model == null) {
            this.updateDecorations([]);
            this.updateColorDecorators([]);
            return;
        }
        final source = new CancellationTokenSource();
        this._computePromise = source;
        final start = haxe.Timer.stamp();
        ColorUtils.getColors(this._editor.context.languageFeaturesService.colorProvider, model, source.token, this._isDefaultColorDecoratorsEnabled).done(colors -> {
            if (source.token.isCancellationRequested) {
                return;
            }
            this._debounceInformation.update(model, (haxe.Timer.stamp() - start) * 1000);
            final colors:Array<IColorData> = colors != null ? colors : [];
            this.updateDecorations(colors);
            this.updateColorDecorators(colors);
            if (this._computePromise == source) {
                this._computePromise = null;
            }
        }, e -> {
            Errors.onUnexpectedError(e);
        });
    }

    function stop():Void {
        if (this._timeoutTimer != null) {
            this._timeoutTimer.cancel();
            this._timeoutTimer = null;
        }
        if (this._computePromise != null) {
            this._computePromise.cancel();
            this._computePromise = null;
        }
        this._localToDispose.clear();
    }

    function updateDecorations(colorDatas:Array<IColorData>):Void {
        final decorations:Array<IModelDeltaDecoration> = [for (c in colorDatas) {
            range: {
                startLineNumber: c.colorInfo.range.startLineNumber,
                startColumn: c.colorInfo.range.startColumn,
                endLineNumber: c.colorInfo.range.endLineNumber,
                endColumn: c.colorInfo.range.endColumn
            },
            options: cast ModelDecorationOptions.EMPTY
        }];

        this._editor.changeDecorations(changeAccessor -> {
            this._decorationsIds = changeAccessor.deltaDecorations(this._decorationsIds, decorations);

            this._colorDatas = new Map<String, IColorData>();
            for (i in 0...this._decorationsIds.length) {
                this._colorDatas.set(this._decorationsIds[i], colorDatas[i]);
            }
            return null;
        });
    }

    /**
     * The geometry of the swatches for the current font: the vertical
     * padding that makes the box of the non breaking space a square as wide
     * as a space, and the border width (0.1em).
     */
    function swatchGeometry():{padding:Float, borderWidth:Float, dark:Bool} {
        final fontInfo = this._editor.getOption(EditorOption.fontInfo);
        final fontSize = fontInfo.fontSize;
        // the content area of the font (what an inline box grows from), from
        // a line of the view; the usual 1.2em without a view (tests)
        var contentHeight = fontSize * 1.2;
        final view = EditorWidgets.viewOf(this._editor);
        if (view != null && this._editor.hasModel() && this._editor.getModel().getLineCount() > 0) {
            try {
                final line = view.renderViewLine(1);
                contentHeight = line.layout.ascent + line.layout.descent;
            }
            catch (e:Dynamic) {}
        }
        // a square as wide as the non breaking space it paints on
        final side = fontInfo.spaceWidth;
        return {
            padding: (side - contentHeight) / 2,
            borderWidth: fontSize * 0.1,
            dark: EditorWidgets.isDark(this._editor)
        };
    }

    /**
     * The typed style of a swatch (colorPicker.css and Monaco's per color
     * rule `background-color: rgba(...)`).
     */
    static function swatchStyle(color:String, geometry:{padding:Float, borderWidth:Float, dark:Bool}):cityscape.common.DecorationStyle.IDecorationStyle {
        return {
            background: color,
            border: {color: geometry.dark ? "#eee" : "#000", width: geometry.borderWidth},
            paddingTop: geometry.padding,
            paddingBottom: geometry.padding,
            join: false
        };
    }

    function updateColorDecorators(colorData:Array<IColorData>):Void {
        this._lastColorData = colorData;

        final decorations:Array<IModelDeltaDecoration> = [];

        final limit = this._editor.getOption(EditorOption.colorDecoratorsLimit);
        final geometry = colorData.length > 0 ? swatchGeometry() : null;

        var i = 0;
        while (i < colorData.length && decorations.length < limit) {
            final c = colorData[i].colorInfo.color;
            final rgba = new RGBA(Math.round(c.red * 255), Math.round(c.green * 255), Math.round(c.blue * 255), c.alpha);
            final color = 'rgba(' + rgba.r + ', ' + rgba.g + ', ' + rgba.b + ', ' + JsValues.numberToString(rgba.a) + ')';

            decorations.push({
                range: {
                    startLineNumber: colorData[i].colorInfo.range.startLineNumber,
                    startColumn: colorData[i].colorInfo.range.startColumn,
                    endLineNumber: colorData[i].colorInfo.range.endLineNumber,
                    endColumn: colorData[i].colorInfo.range.endColumn
                },
                options: {
                    description: 'colorDetector',
                    before: {
                        content: ' ', // noBreakWhitespace
                        inlineClassName: 'colorpicker-color-decoration',
                        inlineClassNameAffectsLetterSpacing: true,
                        attachedData: ColorDecorationInjectedTextMarker.INSTANCE,
                        inlineStyle: swatchStyle(color, geometry)
                    }
                }
            });
            i++;
        }
        final limited:Null<Int> = limit < colorData.length ? limit : null;
        this._decoratorLimitReporter.update(colorData.length, limited);

        this._colorDecoratorIds.set(decorations);
    }

    function removeAllDecorations():Void {
        this._editor.removeDecorations(this._decorationsIds);
        this._decorationsIds = [];
        this._colorDecoratorIds.clear();
        this._lastColorData = [];
    }

    public function getColorData(position:Position):Null<IColorData> {
        final model = this._editor.getModel();
        if (model == null) {
            return null;
        }

        for (d in model.getDecorationsInRange(Range.fromPositions(position, position))) {
            final data = this._colorDatas.get(d.id);
            if (data != null) {
                return data;
            }
        }

        return null;
    }

    public function isColorDecoration(decoration:IModelDecoration):Bool {
        return this._colorDecoratorIds.has(decoration);
    }

    /**
     * The colors found, in order (tests).
     */
    public function getColorDatas():Array<IColorData> {
        return [for (id in this._decorationsIds) if (this._colorDatas.exists(id)) this._colorDatas.get(id)];
    }

    /**
     * The ranges of the swatches (tests).
     */
    public function getSwatchRanges():Array<Range> {
        return this._colorDecoratorIds.getRanges();
    }
}

/**
 * The number of colors found and the limit applied (Monaco's
 * `DecoratorLimitReporter`); `limited` is null when not limited (Monaco's
 * `false`).
 */
class DecoratorLimitReporter {
    final _onDidChange = new VoidEmitter();
    public final onDidChange:VoidEvent;

    var _computed:Int = 0;
    var _limited:Null<Int> = null;

    public function new() {
        this.onDidChange = _onDidChange.event;
    }

    public var computed(get, never):Int;
    function get_computed():Int {
        return this._computed;
    }

    public var limited(get, never):Null<Int>;
    function get_limited():Null<Int> {
        return this._limited;
    }

    public function update(computed:Int, limited:Null<Int>):Void {
        if (computed != this._computed || limited != this._limited) {
            this._computed = computed;
            this._limited = limited;
            this._onDidChange.fire();
        }
    }

    public function dispose():Void {
        _onDidChange.dispose();
    }
}
