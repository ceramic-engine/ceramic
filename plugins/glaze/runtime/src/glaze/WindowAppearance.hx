// Ported from gpui-pre 0.3.10: src/platform.rs (WindowAppearance)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The appearance of the window, as defined by the operating system.
 *
 * On macOS, this corresponds to named `NSAppearance` values. Through Ceramic
 * (`ceramic.Screen.systemAppearance`) only `Light` and `Dark` are reported:
 * the effective appearance of a macOS application is never a vibrant one.
 */
enum abstract WindowAppearance(Int) {

    /**
     * A light appearance (the default).
     *
     * On macOS, this corresponds to the `aqua` appearance.
     */
    var Light = 0;

    /**
     * A light appearance with vibrant colors.
     *
     * On macOS, this corresponds to the `NSAppearanceNameVibrantLight` appearance.
     */
    var VibrantLight = 1;

    /**
     * A dark appearance.
     *
     * On macOS, this corresponds to the `darkAqua` appearance.
     */
    var Dark = 2;

    /**
     * A dark appearance with vibrant colors.
     *
     * On macOS, this corresponds to the `NSAppearanceNameVibrantDark` appearance.
     */
    var VibrantDark = 3;

    /** Whether this is `Dark` or `VibrantDark`. */
    public inline function isDark():Bool {
        return abstract == Dark || abstract == VibrantDark;
    }

    /** The Rust `Debug` name. */
    public function toString():String {
        return switch abstract {
            case VibrantLight: 'VibrantLight';
            case Dark: 'Dark';
            case VibrantDark: 'VibrantDark';
            case _: 'Light';
        }
    }

    /** The appearance for Ceramic's system appearance. */
    public static function fromCeramic(appearance:ceramic.SystemAppearance):WindowAppearance {
        return appearance == ceramic.SystemAppearance.DARK ? Dark : Light;
    }

}
