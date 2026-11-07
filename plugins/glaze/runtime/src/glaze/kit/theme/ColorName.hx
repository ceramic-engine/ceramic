// Ported from gpui-kit 0.8.1: crates/component/src/theme/color.rs (ColorName)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

import glaze.Hsla;

/**
 * The available color names.
 */
enum abstract ColorName(Int) {

    var White = 0;
    var Black = 1;
    var Neutral = 2;
    var Gray = 3;
    var Red = 4;
    var Orange = 5;
    var Amber = 6;
    var Yellow = 7;
    var Lime = 8;
    var Green = 9;
    var Emerald = 10;
    var Teal = 11;
    var Cyan = 12;
    var Sky = 13;
    var Blue = 14;
    var Indigo = 15;
    var Violet = 16;
    var Purple = 17;
    var Fuchsia = 18;
    var Pink = 19;
    var Rose = 20;

    static final DISPLAY_NAMES:Array<String> = [
        'White', 'Black', 'Neutral', 'Gray', 'Red', 'Orange', 'Amber', 'Yellow', 'Lime', 'Green',
        'Emerald', 'Teal', 'Cyan', 'Sky', 'Blue', 'Indigo', 'Violet', 'Purple', 'Fuchsia', 'Pink', 'Rose'
    ];

    /**
     * The name, as Rust's `Display` writes it (`Purple`).
     */
    public inline function toString():String {

        return DISPLAY_NAMES[this];

    }

    /**
     * Strict color name parser (case insensitive). `null` when invalid
     * (Rust: `TryFrom<&str>`).
     */
    public static function tryFrom(value:String):Null<ColorName> {

        return switch value.toLowerCase() {
            case 'white': White;
            case 'black': Black;
            case 'neutral': Neutral;
            case 'gray': Gray;
            case 'red': Red;
            case 'orange': Orange;
            case 'amber': Amber;
            case 'yellow': Yellow;
            case 'lime': Lime;
            case 'green': Green;
            case 'emerald': Emerald;
            case 'teal': Teal;
            case 'cyan': Cyan;
            case 'sky': Sky;
            case 'blue': Blue;
            case 'indigo': Indigo;
            case 'violet': Violet;
            case 'purple': Purple;
            case 'fuchsia': Fuchsia;
            case 'pink': Pink;
            case 'rose': Rose;
            case _: null;
        }

    }

    /**
     * Returns all available color names (without white and black).
     */
    public static function all():Array<ColorName> {

        return [
            Neutral, Gray, Red, Orange, Amber, Yellow, Lime, Green, Emerald, Teal, Cyan, Sky,
            Blue, Indigo, Violet, Purple, Fuchsia, Pink, Rose
        ];

    }

    /**
     * Returns the color for the given scale.
     *
     * The `scale` is any of `[50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]`,
     * falls back to 500 if out of range.
     */
    public function scale(scale:Int):Hsla {

        final colors = Color.shadcnColors();
        if (abstract == White) {
            return colors.white;
        }
        if (abstract == Black) {
            return colors.black;
        }

        final scales = colors.scales.get(DISPLAY_NAMES[this].toLowerCase());
        final color = scales.get(scale);
        return color != null ? color : scales.get(500);

    }

}
