// Ported from gpui-kit 0.8.1: crates/component/src/theme/schema.rs (SemanticThemeConfig and its sections, SemanticThemeConfigFile)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

import gpui.BoxShadow;
import gpui.FontWeight;
import gpui.Hsla;
import gpui.Pixels;
import gpui.Rgba;
import gpui.base.theme.SemanticThemeTokens;
import gpui.base.theme.TextStyleToken;

/**
 * A standalone semantic theme configuration: every value is optional and
 * overrides the matching semantic token.
 */
class SemanticThemeConfig {

    public var colors:SemanticColorConfig = new SemanticColorConfig();

    public var radius:SemanticRadiusConfig = new SemanticRadiusConfig();

    public var spacing:SemanticSpacingConfig = new SemanticSpacingConfig();

    public var typography:SemanticTypographyConfig = new SemanticTypographyConfig();

    public var shadow:SemanticShadowConfig = new SemanticShadowConfig();

    public function new() {}

    public static function fromJson(json:Dynamic):SemanticThemeConfig {

        final config = new SemanticThemeConfig();
        if (json == null) return config;
        if (!JsonValue.isObject(json)) throw 'invalid type for `tokens`, expected a map';
        final colors = JsonValue.optObject(json, 'colors');
        if (colors != null) {
            for (key in SemanticColorConfig.KEYS) {
                Reflect.setField(config.colors, camel(key), JsonValue.optString(colors, key));
            }
        }
        final radius = JsonValue.optObject(json, 'radius');
        if (radius != null) {
            for (key in SemanticRadiusConfig.KEYS) {
                Reflect.setField(config.radius, key, JsonValue.optFloat(radius, key));
            }
        }
        final spacing = JsonValue.optObject(json, 'spacing');
        if (spacing != null) {
            for (key in SemanticSpacingConfig.KEYS) {
                Reflect.setField(config.spacing, key, JsonValue.optFloat(spacing, key));
            }
        }
        final typography = JsonValue.optObject(json, 'typography');
        if (typography != null) {
            config.typography.sans = JsonValue.optString(typography, 'sans');
            config.typography.mono = JsonValue.optString(typography, 'mono');
            config.typography.xs = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'xs'));
            config.typography.sm = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'sm'));
            config.typography.md = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'md'));
            config.typography.lg = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'lg'));
            config.typography.xl = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'xl'));
            config.typography.monoMd = SemanticTextStyleConfig.fromJson(JsonValue.optObject(typography, 'mono_md'));
        }
        final shadow = JsonValue.optObject(json, 'shadow');
        if (shadow != null) {
            config.shadow.sm = shadowsFromJson(JsonValue.optArray(shadow, 'sm'));
            config.shadow.md = shadowsFromJson(JsonValue.optArray(shadow, 'md'));
            config.shadow.lg = shadowsFromJson(JsonValue.optArray(shadow, 'lg'));
        }
        return config;

    }

    static function camel(name:String):String {

        final parts = name.split('_');
        var result = parts[0];
        for (i in 1...parts.length) {
            result += parts[i].charAt(0).toUpperCase() + parts[i].substr(1);
        }
        return result;

    }

    /**
     * Reads serialized `BoxShadow`s (GPUI serializes a color as an `#rrggbbaa`
     * string and a point as `{ "x": .., "y": .. }`).
     */
    static function shadowsFromJson(list:Null<Array<Dynamic>>):Null<Array<BoxShadow>> {

        if (list == null) return null;
        return [for (item in list) {
            final color = Rgba.parse(JsonValue.optString(item, 'color'));
            final offset = JsonValue.optObject(item, 'offset');
            final shadow = new BoxShadow(JsonValue.optFloat(offset, 'x'), JsonValue.optFloat(offset, 'y'), Hsla.fromRgba(color))
                .withBlurRadius(JsonValue.optFloat(item, 'blur_radius'))
                .withSpreadRadius(JsonValue.optFloat(item, 'spread_radius'));
            if (JsonValue.optBool(item, 'inset') == true) shadow.withInset();
            shadow;
        }];

    }

    /**
     * Applies this configuration over `tokens`, in place.
     */
    @:allow(gpui.component.theme)
    function applyTo(tokens:SemanticThemeTokens):Void {

        for (key in SemanticColorConfig.KEYS) {
            final field = camel(key);
            final value:Null<String> = Reflect.field(colors, field);
            if (value != null) {
                final parsed = Color.tryParseColor(value);
                if (parsed != null) {
                    Reflect.setField(tokens.colors, field, parsed);
                }
            }
        }

        for (key in SemanticRadiusConfig.KEYS) {
            final value:Null<Float> = Reflect.field(radius, key);
            if (value != null) Reflect.setField(tokens.radius, key, value);
        }
        for (key in SemanticSpacingConfig.KEYS) {
            final value:Null<Float> = Reflect.field(spacing, key);
            if (value != null) Reflect.setField(tokens.spacing, key, value);
        }

        if (typography.sans != null) {
            tokens.typography.sans = typography.sans;
        }
        if (typography.mono != null) {
            tokens.typography.mono = typography.mono;
        }
        applyTextStyle(typography.xs, tokens.typography.xs);
        applyTextStyle(typography.sm, tokens.typography.sm);
        applyTextStyle(typography.md, tokens.typography.md);
        applyTextStyle(typography.lg, tokens.typography.lg);
        applyTextStyle(typography.xl, tokens.typography.xl);
        applyTextStyle(typography.monoMd, tokens.typography.monoMd);

        if (shadow.sm != null) {
            tokens.shadow.sm = shadow.sm.copy();
        }
        if (shadow.md != null) {
            tokens.shadow.md = shadow.md.copy();
        }
        if (shadow.lg != null) {
            tokens.shadow.lg = shadow.lg.copy();
        }

    }

    static function applyTextStyle(config:SemanticTextStyleConfig, token:TextStyleToken):Void {

        if (config.size != null) {
            token.size = config.size;
        }
        if (config.lineHeight != null) {
            token.lineHeight = config.lineHeight;
        }
        if (config.weight != null) {
            token.weight = config.weight;
        }

    }

}

/**
 * Standalone semantic theme configuration file: `{ "tokens": ... }`.
 */
class SemanticThemeConfigFile {

    public var tokens:SemanticThemeConfig = new SemanticThemeConfig();

    public function new() {}

    public static function parse(content:String):SemanticThemeConfigFile {

        final json:Dynamic = haxe.Json.parse(content);
        if (!JsonValue.isObject(json)) throw 'invalid type, expected a map';
        final file = new SemanticThemeConfigFile();
        file.tokens = SemanticThemeConfig.fromJson(Reflect.field(json, 'tokens'));
        return file;

    }

}

@:keep
class SemanticColorConfig {

    @:allow(gpui.component.theme)
    static final KEYS:Array<String> = [
        'background', 'foreground', 'surface', 'surface_foreground', 'primary', 'primary_foreground',
        'secondary', 'secondary_foreground', 'muted', 'muted_foreground', 'accent', 'accent_foreground',
        'destructive', 'destructive_foreground', 'border', 'input', 'ring'
    ];

    public var background:Null<String> = null;
    public var foreground:Null<String> = null;
    public var surface:Null<String> = null;
    public var surfaceForeground:Null<String> = null;
    public var primary:Null<String> = null;
    public var primaryForeground:Null<String> = null;
    public var secondary:Null<String> = null;
    public var secondaryForeground:Null<String> = null;
    public var muted:Null<String> = null;
    public var mutedForeground:Null<String> = null;
    public var accent:Null<String> = null;
    public var accentForeground:Null<String> = null;
    public var destructive:Null<String> = null;
    public var destructiveForeground:Null<String> = null;
    public var border:Null<String> = null;
    public var input:Null<String> = null;
    public var ring:Null<String> = null;

    public function new() {}

}

@:keep
class SemanticRadiusConfig {

    @:allow(gpui.component.theme)
    static final KEYS:Array<String> = ['none', 'sm', 'md', 'lg', 'xl', 'full'];

    public var none:Null<Float> = null;
    public var sm:Null<Float> = null;
    public var md:Null<Float> = null;
    public var lg:Null<Float> = null;
    public var xl:Null<Float> = null;
    public var full:Null<Float> = null;

    public function new() {}

}

@:keep
class SemanticSpacingConfig {

    @:allow(gpui.component.theme)
    static final KEYS:Array<String> = ['xxs', 'xs', 'sm', 'md', 'lg', 'xl', 'xxl'];

    public var xxs:Null<Float> = null;
    public var xs:Null<Float> = null;
    public var sm:Null<Float> = null;
    public var md:Null<Float> = null;
    public var lg:Null<Float> = null;
    public var xl:Null<Float> = null;
    public var xxl:Null<Float> = null;

    public function new() {}

}

class SemanticTextStyleConfig {

    public var size:Null<Float> = null;
    public var lineHeight:Null<Float> = null;
    public var weight:Null<Float> = null;

    public function new() {}

    public static function fromJson(json:Null<Dynamic>):SemanticTextStyleConfig {

        final config = new SemanticTextStyleConfig();
        if (json == null) return config;
        config.size = JsonValue.optFloat(json, 'size');
        config.lineHeight = JsonValue.optFloat(json, 'line_height');
        config.weight = JsonValue.optFloat(json, 'weight');
        return config;

    }

}

class SemanticTypographyConfig {

    public var sans:Null<String> = null;
    public var mono:Null<String> = null;
    public var xs:SemanticTextStyleConfig = new SemanticTextStyleConfig();
    public var sm:SemanticTextStyleConfig = new SemanticTextStyleConfig();
    public var md:SemanticTextStyleConfig = new SemanticTextStyleConfig();
    public var lg:SemanticTextStyleConfig = new SemanticTextStyleConfig();
    public var xl:SemanticTextStyleConfig = new SemanticTextStyleConfig();
    public var monoMd:SemanticTextStyleConfig = new SemanticTextStyleConfig();

    public function new() {}

}

class SemanticShadowConfig {

    public var sm:Null<Array<BoxShadow>> = null;
    public var md:Null<Array<BoxShadow>> = null;
    public var lg:Null<Array<BoxShadow>> = null;

    public function new() {}

}
