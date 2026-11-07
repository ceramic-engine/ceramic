// Ported from gpui-kit 0.8.1: crates/component/src/theme/color.rs (ShadcnColors, ShadcnColor, from_hsl_channel)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

import glaze.Hsla;
import glaze.util.MathUtil;

/**
 * The shadcn palette of `default-colors.json`: black, white, and the scales
 * (50 to 950) of every named color.
 */
@:allow(glaze.kit.theme)
class ShadcnColors {

    /**
     * The color scales read from the file (Rust: the `ColorScales` fields).
     */
    public static final NAMES:Array<String> = [
        'slate', 'gray', 'zinc', 'neutral', 'stone', 'red', 'orange', 'amber', 'yellow', 'lime',
        'green', 'emerald', 'teal', 'cyan', 'sky', 'blue', 'indigo', 'violet', 'purple',
        'fuchsia', 'pink', 'rose'
    ];

    public final black:Hsla;

    public final white:Hsla;

    public final scales:Map<String, Map<Int, Hsla>>;

    function new(black:Hsla, white:Hsla, scales:Map<String, Map<Int, Hsla>>) {

        this.black = black;
        this.white = white;
        this.scales = scales;

    }

    public static function parse(json:Dynamic):ShadcnColors {

        final scales = new Map<String, Map<Int, Hsla>>();
        for (name in NAMES) {
            final list:Array<Dynamic> = Reflect.field(json, name);
            if (list == null) throw 'missing field `$name`';
            final map = new Map<Int, Hsla>();
            for (item in list) {
                final scale:Null<Int> = item.scale;
                map.set(scale != null ? scale : 0, fromHslChannel(item.hslChannel));
            }
            scales.set(name, map);
        }
        return new ShadcnColors(
            fromHslChannel(Reflect.field(json, 'black').hslChannel),
            fromHslChannel(Reflect.field(json, 'white').hslChannel),
            scales
        );

    }

    /**
     * Parse an `Hsla` from a string in the format "210 40% 98%".
     */
    static function fromHslChannel(s:String):Hsla {

        final parts = [for (part in ~/\s+/g.split(StringTools.trim(s))) if (part.length > 0) part];
        if (parts.length != 3) {
            throw "expected hslChannel has 3 parts, e.g: '210 40% 98%'";
        }

        function parseNumber(s:String):Float {
            while (StringTools.endsWith(s, '%')) s = s.substring(0, s.length - 1);
            final value = MathUtil.parseFloat(s);
            if (value == null) throw 'failed to parse number';
            return value;
        }

        return Color.hsl(parseNumber(parts[0]), parseNumber(parts[1]), parseNumber(parts[2]));

    }

}
