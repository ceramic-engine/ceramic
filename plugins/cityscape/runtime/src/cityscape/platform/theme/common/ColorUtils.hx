// Ported from vscode src/vs/platform/theme/common/colorUtils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common;

import cityscape.base.common.Color;
import cityscape.base.common.JsValues;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import haxe.extern.EitherType;

//  ------ API types

typedef ColorIdentifier = String;

typedef ColorContribution = {
    final id:ColorIdentifier;
    final description:String;
    final defaults:Null<EitherType<ColorDefaults, ColorValue>>;
    final needsTransparency:Bool;
    final deprecationMessage:Null<String>;
}

enum abstract ColorTransformType(Int) from Int to Int {
    var Darken = 0;
    var Lighten = 1;
    var Transparent = 2;
    var Opaque = 3;
    var OneOf = 4;
    var LessProminent = 5;
    var IfDefinedThenElse = 6;
}

/**
 * Monaco's `ColorTransform` union (`{ op: ColorTransformType.Darken; value; factor }`...)
 * as one class: `op` tells which fields are set. Created by `ColorUtils.darken`,
 * `lighten`, `transparent`, `opaque`, `oneOf`, `ifDefinedThenElse` and
 * `lessProminent`.
 */
class ColorTransform {

    public final op:ColorTransformType;

    /**
     * Darken, Lighten, Transparent, Opaque, LessProminent.
     */
    public final value:Null<ColorValue>;

    /**
     * Darken, Lighten, Transparent, LessProminent.
     */
    public final factor:Float;

    /**
     * Opaque, LessProminent.
     */
    public final background:Null<ColorValue>;

    /**
     * OneOf.
     */
    public final values:Null<Array<ColorValue>>;

    /**
     * LessProminent.
     */
    public final transparency:Float;

    /**
     * IfDefinedThenElse: `if` in Monaco (a Haxe keyword).
     */
    public final ifColor:Null<ColorIdentifier>;

    /**
     * IfDefinedThenElse: `then` in Monaco.
     */
    public final thenColor:Null<ColorValue>;

    /**
     * IfDefinedThenElse: `else` in Monaco (a Haxe keyword).
     */
    public final elseColor:Null<ColorValue>;

    public function new(op:ColorTransformType, ?value:ColorValue, factor:Float = 0, ?background:ColorValue, ?values:Array<ColorValue>, transparency:Float = 0, ?ifColor:ColorIdentifier, ?thenColor:ColorValue, ?elseColor:ColorValue) {
        this.op = op;
        this.value = value;
        this.factor = factor;
        this.background = background;
        this.values = values;
        this.transparency = transparency;
        this.ifColor = ifColor;
        this.thenColor = thenColor;
        this.elseColor = elseColor;
    }

}

typedef ColorDefaults = {
    var light:Null<ColorValue>;
    var dark:Null<ColorValue>;
    var hcDark:Null<ColorValue>;
    var hcLight:Null<ColorValue>;
}

/**
 * A Color Value is either a color literal, a reference to an other color or a derived color:
 * a `Color`, a `String` (`#rrggbb` hex literal or a `ColorIdentifier`) or a `ColorTransform`.
 */
abstract ColorValue(Any) from Color from String from ColorTransform to Any {}

interface IColorRegistry {

    /**
     * Register a color to the registry.
     * @param id The color id as used in theme description files
     * @param defaults The default values (`ColorDefaults`, a `ColorValue` or null)
     * @param needsTransparency Whether the color requires transparency
     * @param description the description
     */
    function registerColor(id:String, defaults:Null<EitherType<ColorDefaults, ColorValue>>, description:String, needsTransparency:Bool = false, ?deprecationMessage:String):ColorIdentifier;

    /**
     * Register a color to the registry.
     */
    function deregisterColor(id:String):Void;

    /**
     * Get all color contributions
     */
    function getColors():Array<ColorContribution>;

    /**
     * Gets the default color of the given id
     */
    function resolveDefaultColor(id:ColorIdentifier, theme:IColorTheme):Null<Color>;

    // TODO: onDidChangeSchema, getColorSchema, getColorReferenceSchema and
    // notifyThemeUpdate (JSON schemas of the settings editor) are not ported.

}

/**
 * The color registry: the class `ColorRegistry` of colorUtils.ts (renamed,
 * `ColorRegistry` is the module of colorRegistry.ts).
 */
class ColorRegistryImpl implements IColorRegistry {

    final colorsById:Map<String, ColorContribution>;

    /**
     * Ids in registration order (`Object.keys` order).
     */
    final colorIds:Array<String>;

    public function new() {
        this.colorsById = new Map();
        this.colorIds = [];
    }

    public function registerColor(id:String, defaults:Null<EitherType<ColorDefaults, ColorValue>>, description:String, needsTransparency:Bool = false, ?deprecationMessage:String):ColorIdentifier {
        final colorContribution:ColorContribution = {
            id: id,
            description: description,
            defaults: defaults,
            needsTransparency: needsTransparency,
            deprecationMessage: deprecationMessage
        };
        if (!this.colorsById.exists(id)) {
            this.colorIds.push(id);
        }
        this.colorsById.set(id, colorContribution);
        return id;
    }

    public function deregisterColor(id:String):Void {
        if (this.colorsById.remove(id)) {
            this.colorIds.remove(id);
        }
    }

    public function getColors():Array<ColorContribution> {
        return [for (id in this.colorIds) this.colorsById.get(id)];
    }

    public function resolveDefaultColor(id:ColorIdentifier, theme:IColorTheme):Null<Color> {
        final colorDesc = this.colorsById.get(id);
        if (colorDesc != null && colorDesc.defaults != null) {
            final defaults = colorDesc.defaults;
            final colorValue:Null<ColorValue> = ColorUtils.isColorDefaults(defaults) ? ColorUtils.defaultsForScheme((cast defaults : ColorDefaults), theme.type) : (cast defaults : ColorValue);
            return ColorUtils.resolveColorValue(colorValue, theme);
        }
        return null;
    }

    public function toString():String {
        final sorter = (a:String, b:String) -> {
            final cat1 = a.indexOf('.') == -1 ? 0 : 1;
            final cat2 = b.indexOf('.') == -1 ? 0 : 1;
            if (cat1 != cat2) {
                return cat1 - cat2;
            }
            return a < b ? -1 : a > b ? 1 : 0;
        };

        final keys = this.colorIds.copy();
        haxe.ds.ArraySort.sort(keys, sorter);
        return [for (k in keys) '- `' + k + '`: ' + this.colorsById.get(k).description].join('\n');
    }

}

/**
 * Module functions of colorUtils.ts.
 */
class ColorUtils {

    public static final DEFAULT_COLOR_CONFIG_VALUE = 'default';

    /**
     * Returns the css variable name for the given color identifier. Dots (`.`) are replaced with hyphens (`-`) and
     * everything is prefixed with `--vscode-`.
     *
     * @sample `editorSuggestWidget.background` is `--vscode-editorSuggestWidget-background`.
     */
    public static function asCssVariableName(colorIdent:ColorIdentifier):String {
        return '--vscode-' + StringTools.replace(colorIdent, '.', '-');
    }

    public static function asCssVariable(color:ColorIdentifier):String {
        return 'var(' + asCssVariableName(color) + ')';
    }

    public static function asCssVariableWithDefault(color:ColorIdentifier, defaultCssValue:String):String {
        return 'var(' + asCssVariableName(color) + ', ' + defaultCssValue + ')';
    }

    public static function isColorDefaults(value:Any):Bool {
        return value != null && JsValues.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Color) && !Std.isOfType(value, ColorTransform)
            && Reflect.hasField(value, 'light') && Reflect.hasField(value, 'dark');
    }

    /**
     * `colorDesc.defaults[theme.type]`.
     */
    public static function defaultsForScheme(defaults:ColorDefaults, scheme:ColorScheme):Null<ColorValue> {
        return switch (scheme) {
            case ColorScheme.DARK: defaults.dark;
            case ColorScheme.LIGHT: defaults.light;
            case ColorScheme.HIGH_CONTRAST_DARK: defaults.hcDark;
            case ColorScheme.HIGH_CONTRAST_LIGHT: defaults.hcLight;
            case _: null;
        }
    }

    static var _colorRegistry:Null<ColorRegistryImpl> = null;

    /**
     * Register a color to the registry. Color registrations are static
     * definitions shared by all `Cityscape` contexts: register only colors
     * whose id and defaults are the same for every editor.
     */
    public static function registerColor(id:String, defaults:Null<EitherType<ColorDefaults, ColorValue>>, description:String, needsTransparency:Bool = false, ?deprecationMessage:String):ColorIdentifier {
        return getColorRegistry().registerColor(id, defaults, description, needsTransparency, deprecationMessage);
    }

    /**
     * The color registry. Built on first use with the colors of
     * colorRegistry.ts (`ColorRegistry.registerAllColors`).
     */
    public static function getColorRegistry():IColorRegistry {
        if (_colorRegistry == null) {
            _colorRegistry = new ColorRegistryImpl();
            ColorRegistry.registerAllColors();
        }
        return _colorRegistry;
    }

    // ----- color functions

    public static function executeTransform(transform:ColorTransform, theme:IColorTheme):Null<Color> {
        switch (transform.op) {
            case ColorTransformType.Darken:
                final c = resolveColorValue(transform.value, theme);
                return c != null ? c.darken(transform.factor) : null;

            case ColorTransformType.Lighten:
                final c = resolveColorValue(transform.value, theme);
                return c != null ? c.lighten(transform.factor) : null;

            case ColorTransformType.Transparent:
                final c = resolveColorValue(transform.value, theme);
                return c != null ? c.transparent(transform.factor) : null;

            case ColorTransformType.Opaque:
                final backgroundColor = resolveColorValue(transform.background, theme);
                if (backgroundColor == null) {
                    return resolveColorValue(transform.value, theme);
                }
                final c = resolveColorValue(transform.value, theme);
                return c != null ? c.makeOpaque(backgroundColor) : null;

            case ColorTransformType.OneOf:
                for (candidate in transform.values) {
                    final color = resolveColorValue(candidate, theme);
                    if (color != null) {
                        return color;
                    }
                }
                return null;

            case ColorTransformType.IfDefinedThenElse:
                return resolveColorValue(theme.defines(transform.ifColor) ? transform.thenColor : transform.elseColor, theme);

            case ColorTransformType.LessProminent:
                final from = resolveColorValue(transform.value, theme);
                if (from == null) {
                    return null;
                }

                final backgroundColor = resolveColorValue(transform.background, theme);
                if (backgroundColor == null) {
                    return from.transparent(transform.factor * transform.transparency);
                }

                return from.isDarkerThan(backgroundColor)
                    ? Color.getLighterColor(from, backgroundColor, transform.factor).transparent(transform.transparency)
                    : Color.getDarkerColor(from, backgroundColor, transform.factor).transparent(transform.transparency);

            case _:
                throw 'Unexpected color transform: ' + transform.op;
        }
    }

    public static function darken(colorValue:ColorValue, factor:Float):ColorTransform {
        return new ColorTransform(ColorTransformType.Darken, colorValue, factor);
    }

    public static function lighten(colorValue:ColorValue, factor:Float):ColorTransform {
        return new ColorTransform(ColorTransformType.Lighten, colorValue, factor);
    }

    public static function transparent(colorValue:ColorValue, factor:Float):ColorTransform {
        return new ColorTransform(ColorTransformType.Transparent, colorValue, factor);
    }

    public static function opaque(colorValue:ColorValue, background:ColorValue):ColorTransform {
        return new ColorTransform(ColorTransformType.Opaque, colorValue, 0, background);
    }

    public static function oneOf(colorValues:haxe.Rest<ColorValue>):ColorTransform {
        return new ColorTransform(ColorTransformType.OneOf, null, 0, null, colorValues.toArray());
    }

    public static function ifDefinedThenElse(ifArg:ColorIdentifier, thenArg:ColorValue, elseArg:ColorValue):ColorTransform {
        return new ColorTransform(ColorTransformType.IfDefinedThenElse, null, 0, null, null, 0, ifArg, thenArg, elseArg);
    }

    public static function lessProminent(colorValue:ColorValue, backgroundColorValue:ColorValue, factor:Float, transparency:Float):ColorTransform {
        return new ColorTransform(ColorTransformType.LessProminent, colorValue, factor, backgroundColorValue, null, transparency);
    }

    // ----- implementation

    /**
     * @param colorValue Resolve a color value in the context of a theme
     */
    public static function resolveColorValue(colorValue:Null<ColorValue>, theme:IColorTheme):Null<Color> {
        if (colorValue == null) {
            return null;
        }
        else if (Std.isOfType(colorValue, String)) {
            final s:String = cast colorValue;
            if (s.length > 0 && StringTools.fastCodeAt(s, 0) == '#'.code) {
                return Color.fromHex(s);
            }
            return theme.getColor(s);
        }
        else if (Std.isOfType(colorValue, Color)) {
            return (cast colorValue : Color);
        }
        else if (Std.isOfType(colorValue, ColorTransform)) {
            return executeTransform((cast colorValue : ColorTransform), theme);
        }
        return null;
    }

}
