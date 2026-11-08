// Ported from gpui-kit 0.8.1: crates/component/src/icon.rs, crates/assets/src/icon.rs (IconNamed)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Model;
import glaze.Pixels;
import glaze.Radians;
import glaze.Render;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Svg;
import glaze.Svg.Transformation;
import glaze.Window;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;
import haxe.io.Bytes;

using glaze.AbsoluteLengthTools;

/**
 * A named icon that resolves to a path in an application's asset source.
 * Implement this for custom icon sets accepted by `Icon`.
 */
interface IconNamed {

    function path():String;

}

/**
 * Where an icon draws from: an asset path, or raw SVG bytes.
 */
enum IconSource {
    Path(path:String);
    Data(data:Bytes);
}

/**
 * Rust `impl Into<Icon>`: an `Icon`, an `IconName` or any `IconNamed`.
 */
abstract IntoIcon(Icon) from Icon to Icon {

    @:from static inline function fromIconName(name:IconName):IntoIcon {
        return Icon.build(name.path());
    }

    @:from static inline function fromIconNamed(name:IconNamed):IntoIcon {
        return Icon.build(name.path());
    }

}

/**
 * The global icon path resolver (see `Icon.setIconResolver`).
 */
class IconResolver {

    public final resolve:(String, App) -> Null<String>;

    public function new(resolve:(String, App) -> Null<String>) {
        this.resolve = resolve;
    }

}

/**
 * An SVG icon from the asset bundle (or raw SVG data), sized by the text
 * size it inherits (or `Sizable`), tinted by the text color it inherits (or
 * `textColor`).
 *
 * Rust's `Icon` is both a `RenderOnce` component and a `Render` view
 * (`Icon::view`). Here the view is a separate model, `IconView`, so that a
 * plain icon stays a light object.
 */
class Icon implements RenderOnce implements Styled implements Sizable {

    final iconStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var source:IconSource = Path('');

    @:allow(glaze.kit, tests)
    var textColorValue:Null<Hsla> = null;

    @:allow(glaze.kit, tests)
    var size:Null<Size> = null;

    @:allow(glaze.kit, tests)
    var transformation:Null<Transformation> = null;

    /**
     * `Icon.component(IconName.Search)` (Rust `Icon::new`), or `Icon.component()` for an
     * empty icon (Rust `Icon::default()`).
     */
    public function new(?icon:IntoIcon) {
        if (icon != null) {
            final other:Icon = icon;
            copyFrom(other);
        }
    }

    function copyFrom(other:Icon):Void {
        iconStyle.refine(other.iconStyle);
        source = other.source;
        textColorValue = other.textColorValue;
        size = other.size;
        transformation = other.transformation;
    }

    /**
     * An icon drawing the asset at `path`.
     */
    @:allow(glaze.kit)
    static function build(path:String):Icon {
        return Icon.component().path(path);
    }

    /**
     * A copy of this icon (data bytes are shared, like Rust's `Arc<[u8]>`).
     */
    public function clone():Icon {
        final icon = Icon.component();
        icon.copyFrom(this);
        return icon;
    }

    public inline function style():StyleRefinement {
        return iconStyle;
    }

    /**
     * Set the icon path of the Assets bundle, for example `icons/foo.svg`.
     * Replaces any previously set path or SVG data.
     */
    public function path(path:String):Icon {
        source = Path(path);
        return this;
    }

    /**
     * Set raw SVG bytes without registering an asset path. Replaces any
     * previously set path or data.
     */
    public function data(data:Bytes):Icon {
        source = Data(data);
        return this;
    }

    /**
     * Create a new view for the icon.
     */
    public function view(cx:AppContext):Entity<IconView> {
        final icon = this;
        return (cx:App).newEntity((_:Context<IconView>) -> new IconView(icon));
    }

    /**
     * Set the SVG transformation, replacing any previous transformation or rotation.
     */
    public function transform(transformation:Transformation):Icon {
        this.transformation = transformation;
        return this;
    }

    /**
     * An icon without source (Rust `Icon::empty()`).
     */
    public static function empty():Icon {
        return Icon.component();
    }

    /**
     * Rotate the icon by the given angle. Replaces any previous
     * transformation or rotation.
     */
    public function rotate(radians:Radians):Icon {
        transformation = Transformation.rotated(radians);
        return this;
    }

    /**
     * The icon color (Rust overrides `Styled::text_color` to keep it apart
     * from the style refinement).
     */
    public function textColor(color:IntoHsla):Icon {
        textColorValue = color;
        return this;
    }

    public function withSize(size:IntoSize):Icon {
        this.size = size;
        return this;
    }

    @:allow(glaze.kit, tests)
    function resolved(cx:App):Icon {
        switch source {
            case Path(path):
                source = Path(resolveIconPath(path, cx));
            case Data(_):
        }
        return this;
    }

    @:allow(glaze.kit, tests)
    function intoSvg(textSize:Pixels, fallbackColor:Hsla):Svg {
        final textColor = textColorValue != null ? textColorValue : fallbackColor;
        final hasBaseSize = iconStyle.sizeWidth != null || iconStyle.sizeHeight != null;

        final svg = glaze.Prelude.svg();
        svg.style().refine(iconStyle);
        svg.flexShrink0().textColor(textColor);
        if (!hasBaseSize) {
            svg.size(textSize);
        }
        if (size != null) {
            switch size {
                case Size(px): svg.size(px);
                case XSmall: svg.size3();
                case Small: svg.size3p5();
                case Medium: svg.size4();
                case Large: svg.size6();
            }
        }
        switch source {
            case Path(path): svg.path(path);
            case Data(data): svg.data(data);
        }
        if (transformation != null) {
            svg.withTransformation(transformation);
        }
        return svg;
    }

    public function render(window:Window, cx:App):IntoElement {
        final textStyle = window.textStyle();
        final textSize = textStyle.fontSize.toPixels(window.remSize());
        return resolved(cx).intoSvg(textSize, textStyle.color);
    }

    /**
     * Set the hook every `Icon` drawn from an asset path asks for the path to
     * draw, including the icons components draw inside their own controls.
     *
     * The resolver receives the icon's path (for example `icons/check.svg`)
     * and returns the path to draw in its place, or null to keep it. Call
     * `App.refreshWindows` after changing what it returns. Icons created
     * with `data` are not resolved.
     */
    public static function setIconResolver(cx:AppContext, resolver:(String, App) -> Null<String>):Void {
        (cx:App).setGlobal(new IconResolver(resolver), IconResolver);
    }

    /**
     * Return the path to draw for the icon at `path`: the answer of the
     * resolver set with `setIconResolver`, or `path` itself.
     */
    public static function resolveIconPath(path:String, cx:AppContext):String {
        final app:App = cx;
        final resolver = app.tryGlobal(IconResolver);
        if (resolver != null && path.length > 0) {
            final resolved = resolver.resolve(path, app);
            return resolved != null ? resolved : path;
        }
        return path;
    }

}

/**
 * The view of an icon (Rust `impl Render for Icon`, `Icon::view`): drawn
 * with the theme's foreground when it has no color of its own.
 */
class IconView extends Model implements Render {

    public final icon:Icon;

    public function new(icon:Icon) {
        super();
        this.icon = icon;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final textSize = window.textStyle().fontSize.toPixels(window.remSize());
        return icon.clone().resolved(cx.app).intoSvg(textSize, Theme.global(cx.app).foreground);
    }

}
