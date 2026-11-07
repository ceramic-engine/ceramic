// Ported from gpui-kit 0.8.1: crates/component/src/theme/mod.rs (ThemeMode)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

/**
 * The theme mode: light (the default) or dark.
 */
enum abstract ThemeMode(Int) {

    var Light = 0;

    var Dark = 1;

    public inline function isDark():Bool {

        return abstract == Dark;

    }

    /**
     * Return lower_case theme name: `light`, `dark`.
     */
    public function name():String {

        return abstract == Dark ? 'dark' : 'light';

    }

    /**
     * Parses the serialized name (`light` or `dark`, serde `snake_case`).
     * Throws on any other value, like serde.
     */
    public static function fromName(name:String):ThemeMode {

        return switch name {
            case 'light': Light;
            case 'dark': Dark;
            case _: throw 'unknown variant `$name`, expected `light` or `dark`';
        }

    }

    /**
     * The mode of a window appearance (Rust `From<WindowAppearance>`): dark
     * for `Dark` and `VibrantDark`.
     */
    public static function fromAppearance(appearance:glaze.WindowAppearance):ThemeMode {

        return appearance.isDark() ? Dark : Light;

    }

    /**
     * Total order, light first (Rust derives `Ord`).
     */
    public inline function compare(other:ThemeMode):Int {

        return this - (cast other:Int);

    }

}
