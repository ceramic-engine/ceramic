// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * A background: a solid color, a linear gradient, or a pattern.
 *
 * The layout mirrors the `#[repr(C)]` Rust struct read by the shaders:
 * a tag, a color space, a solid color, one float parameter and two color stops.
 * Rust's `colors: [LinearColorStop; 2]` becomes the `colors0` and `colors1` fields.
 *
 * Immutable: every operation returns a new instance.
 */
class Background {

    /**
     * The kind of background.
     */
    public final tag:BackgroundTag;

    /**
     * The color space used to interpolate gradients.
     */
    public final colorSpace:ColorSpace;

    /**
     * The color of solid and pattern backgrounds.
     */
    public final solid:Hsla;

    /**
     * Gradient angle in degrees (linear gradients), or the packed pattern
     * parameters (`PatternSlash`), or the cell size (`Checkerboard`).
     */
    public final gradientAngleOrPatternHeight:Float;

    /**
     * First color stop of a linear gradient (`colors[0]` in Rust).
     */
    public final colors0:LinearColorStop;

    /**
     * Second color stop of a linear gradient (`colors[1]` in Rust).
     */
    public final colors1:LinearColorStop;

    /**
     * Without arguments, creates the default background (solid transparent black).
     */
    public inline function new(tag:BackgroundTag = Solid, colorSpace:ColorSpace = Srgb, ?solid:Hsla,
        gradientAngleOrPatternHeight:Float = 0, ?colors0:LinearColorStop, ?colors1:LinearColorStop) {

        this.tag = tag;
        this.colorSpace = colorSpace;
        this.solid = solid != null ? solid : new Hsla();
        this.gradientAngleOrPatternHeight = gradientAngleOrPatternHeight;
        this.colors0 = colors0 != null ? colors0 : new LinearColorStop();
        this.colors1 = colors1 != null ? colors1 : new LinearColorStop();

    }

    /**
     * A solid background (`From<Hsla> for Background`).
     */
    public static inline function fromHsla(value:Hsla):Background {

        return new Background(Solid, Srgb, value);

    }

    /**
     * A solid background (`From<Rgba> for Background`).
     */
    public static inline function fromRgba(value:Rgba):Background {

        return new Background(Solid, Srgb, Hsla.fromRgba(value));

    }

    /**
     * Returns the solid color if this is a solid background, `null` otherwise.
     */
    public inline function asSolid():Null<Hsla> {

        return tag == Solid ? solid : null;

    }

    /**
     * Returns a copy using the given color space for color interpolation.
     *
     * Named `color_space()` in Rust, renamed because of the `colorSpace` field.
     */
    public inline function withColorSpace(colorSpace:ColorSpace):Background {

        return new Background(tag, colorSpace, solid, gradientAngleOrPatternHeight, colors0, colors1);

    }

    /**
     * Returns a copy with the alpha of every color multiplied by `factor`.
     */
    public inline function opacity(factor:Float):Background {

        return new Background(
            tag,
            colorSpace,
            solid.opacity(factor),
            gradientAngleOrPatternHeight,
            colors0.opacity(factor),
            colors1.opacity(factor)
        );

    }

    /**
     * Whether the background is fully transparent.
     */
    public function isTransparent():Bool {

        return switch tag {
            case Solid: solid.isTransparent();
            case LinearGradient: colors0.color.isTransparent() && colors1.color.isTransparent();
            case PatternSlash: solid.isTransparent();
            case Checkerboard: solid.isTransparent();
        }

    }

    /**
     * Structural equality.
     */
    public function equals(other:Background):Bool {

        return other != null
            && tag == other.tag
            && colorSpace == other.colorSpace
            && solid.equals(other.solid)
            && gradientAngleOrPatternHeight == other.gradientAngleOrPatternHeight
            && colors0.equals(other.colors0)
            && colors1.equals(other.colors1);

    }

    public function toString():String {

        return switch tag {
            case Solid: 'Solid($solid)';
            case LinearGradient: 'LinearGradient($gradientAngleOrPatternHeight, $colors0, $colors1)';
            case PatternSlash: 'PatternSlash($solid, $gradientAngleOrPatternHeight)';
            case Checkerboard: 'Checkerboard($solid, $gradientAngleOrPatternHeight)';
        }

    }

}
