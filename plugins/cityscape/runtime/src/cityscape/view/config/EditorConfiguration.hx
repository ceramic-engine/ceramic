// Ported from vscode src/vs/editor/browser/config/editorConfiguration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.config;

import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Objects;
import cityscape.base.common.Platform;
import cityscape.common.config.EditorConfiguration.IEditorConfiguration;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.FontInfo;
import cityscape.common.core.Dimension.IDimension;
import cityscape.platform.accessibility.common.Accessibility.AccessibilitySupport;

/**
 * The option validation and computation parts of editorConfiguration.ts.
 *
 * The `EditorConfiguration` class is below: its environment (outer size,
 * pixel ratio, font measurement) is given by the Glaze view
 * (`cityscape.view.EditorFontMeasurements`) through
 * `_readEnvConfiguration` / `_readFontInfo`, overridden like Monaco's
 * `TestConfiguration` does.
 */
class EditorConfigurationUtils {

    /**
     * Number of decimal digits of `n` (1 for 0).
     */
    public static function digitCount(n:Float):Int {
        var r = 0;
        while (n != 0) {
            n = Math.floor(n / 10);
            r++;
        }
        return r != 0 ? r : 1;
    }

    /**
     * A copy of `options` with the compatibility values of older Monaco
     * versions migrated (`MigrateOptions`).
     */
    public static function deepCloneAndMigrateOptions(_options:IEditorOptions):IEditorOptions {
        final options = Objects.deepClone(_options);
        MigrateOptions.migrateOptions(options);
        return options;
    }

}

/**
 * The validated options, indexed by option id.
 */
class ValidatedEditorOptions {

    final _values:Array<Any> = [];

    public function new() {}

    public function _read<V>(option:EditorOption<V>):V {
        return cast this._values[option];
    }

    public function get<V>(id:EditorOption<V>):V {
        return cast this._values[id];
    }

    public function _write<V>(option:EditorOption<V>, value:V):Void {
        this._values[option] = value;
    }

}

/**
 * The computed options, indexed by option id.
 */
class ComputedEditorOptions implements IComputedEditorOptions {

    final _values:Array<Any> = [];

    public function new() {}

    public function _read<V>(id:EditorOption<V>):V {
        if ((id : Int) >= this._values.length) {
            throw 'Cannot read uninitialized value';
        }
        return cast this._values[id];
    }

    public function get<V>(id:EditorOption<V>):V {
        return this._read(id);
    }

    public function _write<V>(id:EditorOption<V>, value:V):Void {
        this._values[id] = value;
    }

}

class EditorOptionsUtil {

    /**
     * Validates every registered option, reading its value in `options` by
     * its name (the options not ported yet are ignored).
     */
    public static function validateOptions(options:IEditorOptions):ValidatedEditorOptions {
        final result = new ValidatedEditorOptions();
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            final value:Any = (editorOption.name == '_never_' ? null : Reflect.field(options, editorOption.name));
            result._write(cast editorOption.id, editorOption.validate(value));
        }
        return result;
    }

    public static function computeOptions(options:ValidatedEditorOptions, env:IEnvironmentalOptions):ComputedEditorOptions {
        final result = new ComputedEditorOptions();
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            result._write(cast editorOption.id, editorOption.compute(env, result, options._read(cast editorOption.id)));
        }
        return result;
    }

    static function _deepEquals(a:Any, b:Any):Bool {
        if (!JsValues.isObject(a) || !JsValues.isObject(b) || !JsValues.truthy(a) || !JsValues.truthy(b)) {
            return valueEquals(a, b);
        }
        if (JsValues.isArray(a) || JsValues.isArray(b)) {
            if (!(JsValues.isArray(a) && JsValues.isArray(b))) {
                return false;
            }
            final aa:Array<Any> = a;
            final ba:Array<Any> = b;
            if (aa.length != ba.length) {
                return false;
            }
            for (i in 0...aa.length) {
                if (!valueEquals(aa[i], ba[i])) {
                    return false;
                }
            }
            return true;
        }
        final aKeys = Reflect.fields(a);
        if (aKeys.length != Reflect.fields(b).length) {
            return false;
        }
        for (key in aKeys) {
            if (!_deepEquals(Reflect.field(a, key), Reflect.field(b, key))) {
                return false;
            }
        }
        return true;
    }

    /**
     * JavaScript's `===`: numbers, booleans and strings by value, the rest by
     * reference.
     */
    static function valueEquals(a:Any, b:Any):Bool {
        if (JsValues.isNumber(a) && JsValues.isNumber(b)) {
            return (a : Float) == (b : Float);
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        if (JsValues.isFunction(a) || JsValues.isFunction(b)) {
            return Reflect.compareMethods(a, b);
        }
        return a == b;
    }

    public static function checkEquals(a:ComputedEditorOptions, b:ComputedEditorOptions):Null<ConfigurationChangedEvent> {
        final result:Array<Bool> = [];
        var somethingChanged = false;
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            final changed = !EditorOptionsUtil._deepEquals(a._read(cast editorOption.id), b._read(cast editorOption.id));
            result[editorOption.id] = changed;
            if (changed) {
                somethingChanged = true;
            }
        }
        return (somethingChanged ? new ConfigurationChangedEvent(result) : null);
    }

    /**
     * Returns true if something changed.
     * Modifies `options`.
     */
    public static function applyUpdate(options:IEditorOptions, update:IEditorOptions):Bool {
        var changed = false;
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            if (Reflect.hasField(update, editorOption.name)) {
                #if cs
                // The raw values can have any type (an invalid input is kept and
                // rejected later by validate), and on C# a reflection call of the
                // generic `applyUpdate(value:Null<V>, update:V)` casts them to V
                // and throws. Every option's applyUpdate is EditorOptions.applyUpdate.
                final result = EditorOptions.applyUpdate((Reflect.field(options, editorOption.name) : Any), (Reflect.field(update, editorOption.name) : Any));
                #else
                final result = editorOption.applyUpdate(Reflect.field(options, editorOption.name), Reflect.field(update, editorOption.name));
                #end
                Reflect.setField(options, editorOption.name, result.newValue);
                changed = changed || result.didChange;
            }
        }
        return changed;
    }

}

typedef IEnvConfiguration = {
    var extraEditorClassName:String;
    var outerWidth:Float;
    var outerHeight:Float;
    var emptySelectionClipboard:Bool;
    var pixelRatio:Float;
    var accessibilitySupport:AccessibilitySupport;
}

/**
 * Monaco's `EditorConfiguration` (browser/config/editorConfiguration.ts).
 *
 * The container size is given with `observeContainer(dimension)` (the Glaze
 * layout gives the editor its bounds; Monaco measures a DOM node), and the
 * font is measured by `fontMeasurer` (Glaze's text system; Monaco measures
 * with the DOM). Editor zoom and tab focus mode are not ported (no zoom,
 * tab focus from the Glaze kit): their factors are 1 and false.
 */
class EditorConfiguration implements IEditorConfiguration {

    /**
     * Determined from empirical observations (read on use: the platform is
     * not known when statics initialize on the web).
     */
    static function GOLDEN_LINE_HEIGHT_RATIO():Float {
        return Platform.isMacintosh ? 1.5 : 1.35;
    }

    static inline final MINIMUM_LINE_HEIGHT = 8;

    final _onDidChange = new Emitter<ConfigurationChangedEvent>();
    public final onDidChange:Event<ConfigurationChangedEvent>;

    final _onDidChangeFast = new Emitter<ConfigurationChangedEvent>();
    public final onDidChangeFast:Event<ConfigurationChangedEvent>;

    public final isSimpleWidget:Bool;

    var _isDominatedByLongLines:Bool = false;
    var _viewLineCount:Int = 1;
    var _lineNumbersDigitCount:Int = 1;
    var _reservedHeight:Float = 0;
    var _glyphMarginDecorationLaneCount:Int = 1;
    var _outerWidth:Float = 100;
    var _outerHeight:Float = 100;

    /**
     * Measures a font for the editor (Glaze text system), or null for
     * Monaco's test metrics.
     */
    public var fontMeasurer:Null<(bareFontInfo:BareFontInfo) -> FontInfo> = null;

    /**
     * The pixel ratio of the screen.
     */
    public var pixelRatio:Float = 1;

    final _computeOptionsMemory:ComputeOptionsMemory = new ComputeOptionsMemory();

    /**
     * Raw options as they were passed in and merged with all calls to `updateOptions`.
     */
    final _rawOptions:IEditorOptions;

    /**
     * Validated version of `_rawOptions`.
     */
    var _validatedOptions:ValidatedEditorOptions;

    /**
     * Complete options which are a combination of passed in options and env values.
     */
    public var options(default, null):IComputedEditorOptions;

    public function new(isSimpleWidget:Bool, options:IEditorOptions, ?dimension:IDimension, ?fontMeasurer:(bareFontInfo:BareFontInfo) -> FontInfo, ?pixelRatio:Float) {
        this.onDidChange = _onDidChange.event;
        this.onDidChangeFast = _onDidChangeFast.event;
        this.isSimpleWidget = isSimpleWidget;
        this.fontMeasurer = fontMeasurer;
        if (pixelRatio != null) {
            this.pixelRatio = pixelRatio;
        }
        if (dimension != null) {
            this._outerWidth = dimension.width;
            this._outerHeight = dimension.height;
        }

        this._rawOptions = EditorConfigurationUtils.deepCloneAndMigrateOptions(options);
        this._validatedOptions = EditorOptionsUtil.validateOptions(this._rawOptions);
        this.options = this._computeOptions();
    }

    public function dispose():Void {
        _onDidChange.dispose();
        _onDidChangeFast.dispose();
    }

    function _recomputeOptions():Void {
        final newOptions = this._computeOptions();
        final changeEvent = EditorOptionsUtil.checkEquals(cast this.options, newOptions);
        if (changeEvent == null) {
            // nothing changed!
            return;
        }

        this.options = newOptions;
        this._onDidChangeFast.fire(changeEvent);
        this._onDidChange.fire(changeEvent);
    }

    /**
     * Recomputes the options (after a change of `fontMeasurer`, of the
     * fonts loaded or of `pixelRatio`).
     */
    public function recomputeOptions():Void {
        _recomputeOptions();
    }

    function _computeOptions():ComputedEditorOptions {
        final partialEnv = this._readEnvConfiguration();
        final bareFontInfo = EditorConfiguration.createBareFontInfoFromValidatedSettings(this._validatedOptions, partialEnv.pixelRatio, this.isSimpleWidget);
        final fontInfo = this._readFontInfo(bareFontInfo);
        final env:IEnvironmentalOptions = {
            memory: this._computeOptionsMemory,
            outerWidth: partialEnv.outerWidth,
            outerHeight: partialEnv.outerHeight - this._reservedHeight,
            fontInfo: fontInfo,
            extraEditorClassName: partialEnv.extraEditorClassName,
            isDominatedByLongLines: this._isDominatedByLongLines,
            viewLineCount: this._viewLineCount,
            lineNumbersDigitCount: this._lineNumbersDigitCount,
            emptySelectionClipboard: partialEnv.emptySelectionClipboard,
            pixelRatio: partialEnv.pixelRatio,
            tabFocusMode: false,
            accessibilitySupport: partialEnv.accessibilitySupport,
            glyphMarginDecorationLaneCount: this._glyphMarginDecorationLaneCount
        };
        return EditorOptionsUtil.computeOptions(this._validatedOptions, env);
    }

    /**
     * `BareFontInfo.createFromValidatedSettings` (fontInfo.ts). The font
     * variations option is not ported: `'normal'`.
     */
    public static function createBareFontInfoFromValidatedSettings(options:ValidatedEditorOptions, pixelRatio:Float, ignoreEditorZoom:Bool):BareFontInfo {
        final fontFamily = options.get(EditorOption.fontFamily);
        var fontWeight = options.get(EditorOption.fontWeight);
        var fontSize = options.get(EditorOption.fontSize);
        final fontFeatureSettings = options.get(EditorOption.fontLigatures);
        final fontVariationSettings = 'normal';
        var lineHeight = options.get(EditorOption.lineHeight);
        final letterSpacing = options.get(EditorOption.letterSpacing);

        if (lineHeight == 0) {
            lineHeight = GOLDEN_LINE_HEIGHT_RATIO() * fontSize;
        } else if (lineHeight < MINIMUM_LINE_HEIGHT) {
            // Values too small to be line heights in pixels are in ems.
            lineHeight = lineHeight * fontSize;
        }

        // Enforce integer, minimum constraints
        lineHeight = Math.round(lineHeight);
        if (lineHeight < MINIMUM_LINE_HEIGHT) {
            lineHeight = MINIMUM_LINE_HEIGHT;
        }

        return @:privateAccess new BareFontInfo({
            pixelRatio: pixelRatio,
            fontFamily: fontFamily,
            fontWeight: fontWeight,
            fontSize: fontSize,
            fontFeatureSettings: fontFeatureSettings,
            fontVariationSettings: fontVariationSettings,
            lineHeight: lineHeight,
            letterSpacing: letterSpacing
        });
    }

    function _readEnvConfiguration():IEnvConfiguration {
        return {
            extraEditorClassName: '',
            outerWidth: this._outerWidth,
            outerHeight: this._outerHeight,
            emptySelectionClipboard: true,
            pixelRatio: this.pixelRatio,
            accessibilitySupport: AccessibilitySupport.Unknown
        };
    }

    function _readFontInfo(bareFontInfo:BareFontInfo):FontInfo {
        final measurer = this.fontMeasurer;
        if (measurer != null) {
            return measurer(bareFontInfo);
        }
        // Monaco's TestConfiguration metrics
        return new FontInfo({
            pixelRatio: 1,
            fontFamily: 'mockFont',
            fontWeight: 'normal',
            fontSize: 14,
            fontFeatureSettings: '"liga" off, "calt" off',
            fontVariationSettings: 'normal',
            lineHeight: 19,
            letterSpacing: 1.5,
            isMonospace: true,
            typicalHalfwidthCharacterWidth: 10,
            typicalFullwidthCharacterWidth: 20,
            canUseHalfwidthRightwardsArrow: true,
            spaceWidth: 10,
            middotWidth: 10,
            wsmiddotWidth: 10,
            maxDigitWidth: 10,
        }, true);
    }

    public function getRawOptions():IEditorOptions {
        return this._rawOptions;
    }

    public function updateOptions(_newOptions:IEditorOptions):Void {
        final newOptions = EditorConfigurationUtils.deepCloneAndMigrateOptions(_newOptions);

        final didChange = EditorOptionsUtil.applyUpdate(this._rawOptions, newOptions);
        if (!didChange) {
            return;
        }

        this._validatedOptions = EditorOptionsUtil.validateOptions(this._rawOptions);
        this._recomputeOptions();
    }

    public function observeContainer(?dimension:IDimension):Void {
        if (dimension == null) {
            return;
        }
        if (dimension.width == this._outerWidth && dimension.height == this._outerHeight) {
            return;
        }
        this._outerWidth = dimension.width;
        this._outerHeight = dimension.height;
        this._recomputeOptions();
    }

    public function setIsDominatedByLongLines(isDominatedByLongLines:Bool):Void {
        if (this._isDominatedByLongLines == isDominatedByLongLines) {
            return;
        }
        this._isDominatedByLongLines = isDominatedByLongLines;
        this._recomputeOptions();
    }

    public function setModelLineCount(modelLineCount:Int):Void {
        final lineNumbersDigitCount = EditorConfigurationUtils.digitCount(modelLineCount);
        if (this._lineNumbersDigitCount == lineNumbersDigitCount) {
            return;
        }
        this._lineNumbersDigitCount = lineNumbersDigitCount;
        this._recomputeOptions();
    }

    public function setViewLineCount(viewLineCount:Int):Void {
        if (this._viewLineCount == viewLineCount) {
            return;
        }
        this._viewLineCount = viewLineCount;
        this._recomputeOptions();
    }

    public function setReservedHeight(reservedHeight:Float):Void {
        if (this._reservedHeight == reservedHeight) {
            return;
        }
        this._reservedHeight = reservedHeight;
        this._recomputeOptions();
    }

    public function setGlyphMarginDecorationLaneCount(decorationLaneCount:Int):Void {
        if (this._glyphMarginDecorationLaneCount == decorationLaneCount) {
            return;
        }
        this._glyphMarginDecorationLaneCount = decorationLaneCount;
        this._recomputeOptions();
    }

}
