// Ported from gpui-pre 0.3.10: src/colors.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * The default set of colors for GPUI, used to style base components, examples and more.
 */
class Colors {

    /**
     * Text color.
     */
    public final text:Rgba;

    /**
     * Selected text color.
     */
    public final selectedText:Rgba;

    /**
     * Background color.
     */
    public final background:Rgba;

    /**
     * Disabled color.
     */
    public final disabled:Rgba;

    /**
     * Selected color.
     */
    public final selected:Rgba;

    /**
     * Border color.
     */
    public final border:Rgba;

    /**
     * Separator color.
     */
    public final separator:Rgba;

    /**
     * Container color.
     */
    public final container:Rgba;

    public function new(text:Rgba, selectedText:Rgba, background:Rgba, disabled:Rgba,
        selected:Rgba, border:Rgba, separator:Rgba, container:Rgba) {

        this.text = text;
        this.selectedText = selectedText;
        this.background = background;
        this.disabled = disabled;
        this.selected = selected;
        this.border = border;
        this.separator = separator;
        this.container = container;

    }

    /**
     * The default colors (light).
     */
    public static inline function defaultValue():Colors {

        return light();

    }

    /**
     * The default colors for the given appearance.
     */
    public static function forAppearance(appearance:DefaultAppearance):Colors {

        return appearance == Dark ? dark() : light();

    }

    /**
     * The default dark colors.
     */
    public static function dark():Colors {

        return new Colors(
            Rgba.fromRgbHex(0xffffff), // text
            Rgba.fromRgbHex(0xffffff), // selectedText
            Rgba.fromRgbHex(0x222222), // background
            Rgba.fromRgbHex(0x565656), // disabled
            Rgba.fromRgbHex(0x2457ca), // selected
            Rgba.fromRgbHex(0x000000), // border
            Rgba.fromRgbHex(0xd9d9d9), // separator
            Rgba.fromRgbHex(0x262626) // container
        );

    }

    /**
     * The default light colors.
     */
    public static function light():Colors {

        return new Colors(
            Rgba.fromRgbHex(0x252525), // text
            Rgba.fromRgbHex(0xffffff), // selectedText
            Rgba.fromRgbHex(0xffffff), // background
            Rgba.fromRgbHex(0xb0b0b0), // disabled
            Rgba.fromRgbHex(0x2a63d9), // selected
            Rgba.fromRgbHex(0xd9d9d9), // border
            Rgba.fromRgbHex(0xe6e6e6), // separator
            Rgba.fromRgbHex(0xf4f5f5) // container
        );

    }

}
