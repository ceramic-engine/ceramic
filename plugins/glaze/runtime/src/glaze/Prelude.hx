// Ported from gpui-pre 0.3.10: src/geometry.rs, src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

import glaze.util.MathUtil;

/**
 * GPUI free functions. Use with `import glaze.Prelude.*;`.
 */
class Prelude {

    // Geometry

    /**
     * Constructs a `Point`.
     */
    public static inline function point(x:Float, y:Float):Point {

        return new Point(x, y);

    }

    /**
     * Constructs a `Size`.
     */
    public static inline function size(width:Float, height:Float):Size {

        return new Size(width, height);

    }

    /**
     * Constructs a `Bounds` from an origin and a size.
     */
    public static inline function bounds(origin:Point, size:Size):Bounds {

        return new Bounds(origin, size);

    }

    /**
     * Constructs a `Radians` from a raw value.
     */
    public static inline function radians(value:Float):Radians {

        return value;

    }

    /**
     * Constructs a `Percentage`, a fraction between 0 and 1.
     */
    public static inline function percentage(value:Float):Percentage {

        return value;

    }

    /**
     * Constructs a `DefiniteLength` relative to the parent size (1.0 is 100%).
     */
    public static inline function relative(fraction:Float):DefiniteLength {

        return DefiniteLength.Fraction(fraction);

    }

    /**
     * The golden ratio as a relative length, `~(1.0 + sqrt(5.0)) / 2.0`.
     */
    public static inline function phi():DefiniteLength {

        return relative(1.618034);

    }

    /**
     * Constructs a `Rems` value.
     */
    public static inline function rems(rems:Float):Rems {

        return rems;

    }

    /**
     * Constructs a `Pixels` value.
     */
    public static inline function px(pixels:Float):Pixels {

        return pixels;

    }

    /**
     * An automatic `Length`.
     */
    public static inline function auto():Length {

        return Length.Auto;

    }

    // Colors

    /**
     * Creates an opaque color from a `0xRRGGBB` number.
     */
    public static inline function rgb(hex:Int):Rgba {

        return Rgba.fromRgbHex(hex);

    }

    /**
     * Creates a color from a `0xRRGGBBAA` number.
     */
    public static inline function rgba(hex:Int):Rgba {

        return Rgba.fromRgbaHex(hex);

    }

    /**
     * Creates an `Hsla` color, clamping every component to 0.0 to 1.0.
     */
    public static inline function hsla(h:Float, s:Float, l:Float, a:Float):Hsla {

        return new Hsla(
            MathUtil.clamp(h, 0.0, 1.0),
            MathUtil.clamp(s, 0.0, 1.0),
            MathUtil.clamp(l, 0.0, 1.0),
            MathUtil.clamp(a, 0.0, 1.0)
        );

    }

    /**
     * Pure black.
     */
    public static inline function black():Hsla {

        return Hsla.black();

    }

    /**
     * Transparent black.
     */
    public static inline function transparentBlack():Hsla {

        return Hsla.transparentBlack();

    }

    /**
     * Transparent white.
     */
    public static inline function transparentWhite():Hsla {

        return Hsla.transparentWhite();

    }

    /**
     * Grey with the given lightness and opacity, clamped to 0.0 to 1.0.
     */
    public static inline function opaqueGrey(lightness:Float, opacity:Float):Hsla {

        return Hsla.opaqueGrey(lightness, opacity);

    }

    /**
     * Pure white.
     */
    public static inline function white():Hsla {

        return Hsla.white();

    }

    /**
     * The color red.
     */
    public static inline function red():Hsla {

        return Hsla.red();

    }

    /**
     * The color blue.
     */
    public static inline function blue():Hsla {

        return Hsla.blue();

    }

    /**
     * The color green.
     */
    public static inline function green():Hsla {

        return Hsla.green();

    }

    /**
     * The color yellow.
     */
    public static inline function yellow():Hsla {

        return Hsla.yellow();

    }

    // Backgrounds

    /**
     * Creates a hatched pattern background. `width` and `interval` are packed
     * into the float parameter read by the shader.
     */
    public static function patternSlash(color:IntoHsla, width:Float, interval:Float):Background {

        // Rust: (width * 255.0) as u32, done in Float to avoid 32 bit Int overflow
        final widthScaled = Math.ffloor(width * 255.0);
        final intervalScaled = Math.ffloor(interval * 255.0);
        final height = (widthScaled > 0 ? widthScaled : 0.0) * 0xFFFF + (intervalScaled > 0 ? intervalScaled : 0.0);

        return new Background(PatternSlash, Srgb, color, height);

    }

    /**
     * Creates a checkerboard pattern background with cells of the given size.
     */
    public static inline function checkerboard(color:IntoHsla, size:Float):Background {

        return new Background(Checkerboard, Srgb, color, size);

    }

    /**
     * Creates a solid background.
     */
    public static inline function solidBackground(color:IntoHsla):Background {

        return new Background(Solid, Srgb, color);

    }

    /**
     * Creates a linear gradient background.
     *
     * `angle` is in degrees (0 to 360): `0` points to the top, increasing
     * values rotate clockwise (like CSS `linear-gradient`).
     */
    public static inline function linearGradient(angle:Float, from:LinearColorStop, to:LinearColorStop):Background {

        return new Background(LinearGradient, Srgb, null, angle, from, to);

    }

    /**
     * Creates a linear gradient color stop. `percentage` is in the range 0.0 to 1.0.
     */
    public static inline function linearColorStop(color:IntoHsla, percentage:Float):LinearColorStop {

        return new LinearColorStop(color, percentage);

    }

    // Pixel buffers

    /**
     * Converts one pixel from RGBA with premultiplied alpha to BGRA with
     * straight alpha, in place, at `offset` in `color`.
     */
    public static function swapRgbaPaToBgra(color:haxe.io.Bytes, offset:Int = 0):Void {

        final r = color.get(offset);
        color.set(offset, color.get(offset + 2));
        color.set(offset + 2, r);
        final alpha = color.get(offset + 3);
        if (alpha > 0) {
            final a = alpha / 255.0;
            color.set(offset, MathUtil.toU8(color.get(offset) / a));
            color.set(offset + 1, MathUtil.toU8(color.get(offset + 1) / a));
            color.set(offset + 2, MathUtil.toU8(color.get(offset + 2) / a));
        }

    }

/// Elements

    /**
     * Construct a new `Div` element.
     */
    public static inline function div(#if glaze_inspector ?pos:haxe.PosInfos #end):Div {

        return new Div(#if glaze_inspector pos #end);

    }

    /**
     * Construct a canvas element with the given paint callback.
     * Useful for adding short term custom drawing to a view.
     */
    public static inline function canvas<T>(prepaint:(Bounds, Window, App) -> T, paint:(Bounds, T, Window, App) -> Void):Canvas<T> {

        return new Canvas<T>(prepaint, paint);

    }

    /**
     * Construct a container query element with the given render callback.
     * The callback receives the size the element was assigned during layout and
     * returns the contents to display within it.
     */
    public static inline function containerQuery(render:(Size, Window, App) -> IntoElement):ContainerQuery {

        return new ContainerQuery(render);

    }

    /**
     * Builds a `Deferred` element, which delays the layout and paint of its child.
     */
    public static inline function deferred(child:IntoElement):Deferred {

        return new Deferred(child);

    }

    /**
     * Creates a quad with the given parameters, to give to `Window.paintQuad()`.
     */
    public static function quad(bounds:Bounds, cornerRadii:Corners, background:IntoBackground, borderWidths:Edges, borderColor:IntoHsla, borderStyle:glaze.scene.BorderStyle):PaintQuad {

        final result = new PaintQuad(bounds, cornerRadii);
        result.background = background;
        result.withBorderWidths(borderWidths);
        result.withBorderColor(borderColor);
        result.borderStyle = borderStyle;
        return result;

    }

    /**
     * Creates a filled quad with the given bounds and background color.
     */
    public static function fill(bounds:Bounds, background:IntoBackground):PaintQuad {

        final result = new PaintQuad(bounds);
        result.background = background;
        return result;

    }

    /**
     * Creates a rectangle outline with the given bounds, border color, and a 1px border width.
     */
    public static function outline(bounds:Bounds, borderColor:IntoHsla, borderStyle:glaze.scene.BorderStyle):PaintQuad {

        final result = new PaintQuad(bounds);
        result.setSolidBackground(0, 0, 0, 0);
        result.setBorderWidths(1, 1, 1, 1);
        result.withBorderColor(borderColor);
        result.borderStyle = borderStyle;
        return result;

    }

/// SVG

    /**
     * Create a new SVG element (give it a `path()` and a `textColor()`).
     */
    public static inline function svg(#if glaze_inspector ?pos:haxe.PosInfos #end):Svg {
        return new Svg(#if glaze_inspector pos #end);
    }

/// Images (img.rs, image_cache.rs)

    /**
     * Create a new image element. `source`: an asset source path or a URI
     * (`String`), a `Resource`, a `RenderImage`, an `Image`, a
     * `ceramic.Texture` or a loading function.
     */
    public static inline function img(source:IntoImageSource #if glaze_inspector , ?pos:haxe.PosInfos #end):Img {
        return new Img(source #if glaze_inspector , pos #end);
    }

    /**
     * An element showing a Ceramic visual (a quad, a mesh, text, a whole
     * sub scene...), rendered into a texture and drawn in order with the
     * other elements, sized by the layout (the visual's size by default).
     * See `VisualElement`. Specific to the Haxe port.
     */
    public static inline function visual(visual:ceramic.Visual #if glaze_inspector , ?pos:haxe.PosInfos #end):VisualElement {
        return new VisualElement(visual #if glaze_inspector , pos #end);
    }

    /**
     * An image cache element: its child `img` elements use the given cache
     * (an `ImageCacheProvider`, or an `ImageCache` such as a
     * `RetainAllImageCache` entity). Rust `image_cache`.
     */
    public static inline function imageCache(provider:IntoImageCacheProvider):ImageCacheElement {
        return new ImageCacheElement(provider);
    }

    /**
     * Constructs a retain-all image cache that uses the element state associated with the given ID.
     */
    public static inline function retainAll(id:ElementIdArg):RetainAllImageCacheProvider {
        return new RetainAllImageCacheProvider(id);
    }

/// Text

    /**
     * Create a new `Text` element whose id is derived from the call site
     * (Rust `text!`): each call site gets its own id. Differences with
     * GPUI: the location is the file and line (Haxe `PosInfos`), not the column.
     */
    public static function text(value:String, ?pos:haxe.PosInfos):Text {
        final location = pos != null ? pos.fileName + '/' + pos.lineNumber : '';
        return new Text(ElementId.Integer(Text.hashTextMacroLocation(location)), value);
    }

/// Lists and anchored (uniform_list.rs, list.rs, anchored.rs)

    /**
     * Lazy rendering for a set of items that are of uniform height: `renderItems`
     * renders the items of `start...end` (Rust `uniform_list`).
     */
    public static inline function uniformList(id:ElementIdArg, itemCount:Int, renderItems:(Int, Int, Window, App) -> Array<IntoElement>):UniformList {
        return new UniformList(id, itemCount, renderItems);
    }

    /**
     * Construct a new list element with variable item heights (Rust `list`).
     */
    public static inline function list(state:ListState, renderItem:(Int, Window, App) -> IntoElement):ListElement {
        return new ListElement(state, renderItem);
    }

    /**
     * An element that will avoid overflowing the window bounds (Rust `anchored`).
     * Its children should have no margin to avoid measurement issues.
     */
    public static inline function anchored():Anchored {
        return new Anchored();
    }

}
