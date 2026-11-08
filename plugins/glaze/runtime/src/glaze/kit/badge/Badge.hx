// Ported from gpui-kit 0.8.1: crates/component/src/badge.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-001 (icon badge ring). See docs/DEVIATIONS.md.
package glaze.kit.badge;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Color;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * The kind of a `Badge`: a number, a dot or an icon.
 */
enum BadgeVariant {
    Number;
    Dot;
    Icon(icon:glaze.kit.Icon);
}

/**
 * A red (or colored) count, dot or icon on top of its children.
 */
class Badge extends Component implements ParentElement implements Sizable {

    final badgeStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the count (hidden at 0).
     */
    @prop var count:Int = 0;

    /**
     * Set the maximum number shown (default 99): above, `max+` is shown.
     */
    @prop var max:Int = 99;

    var variant:BadgeVariant = Number;

    final childElements:Array<AnyElement> = [];

    @prop var color:Null<Hsla> = null;

    var size:Size = Medium;

    public function new() {
        super();
    }

    /**
     * Rust keeps a style refinement on the badge (applied to its container)
     * without implementing `Styled`: this is it.
     */
    public inline function style():StyleRefinement {
        return badgeStyle;
    }

    /**
     * Show a dot instead of a number.
     */
    public function dot():Badge {
        variant = Dot;
        return this;
    }

    /**
     * Show an icon instead of a number.
     */
    public function icon(icon:IntoIcon):Badge {
        variant = BadgeVariant.Icon(icon);
        return this;
    }

    /**
     * Set the badge color (default: the theme's `red`).
     */
    public function color(color:IntoHsla):Badge {
        this.color = color;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Badge {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Badge {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function withSize(size:IntoSize):Badge {
        this.size = size;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final visible = switch variant {
            case Number: this.count > 0;
            case Dot | Icon(_): true;
        };

        final sizes:Array<Pixels> = switch size {
            case Large: [24., 14.];
            case Medium | Size(_): [16., 10.];
            case Small | XSmall: [10., 8.];
        };
        final iconSize = sizes[0];
        final textSize = sizes[1];

        final element = div().relative().refineStyle(badgeStyle);
        element.extend(childElements);
        if (visible) {
            final badge = glaze.kit.base.Prelude.hFlex()
                .absolute()
                .justifyCenter()
                .itemsCenter()
                .roundedFullStyle(cx)
                .bg(color != null ? color : theme.red)
                .textColor(Color.white())
                .textSize(textSize);
            switch variant {
                case Dot:
                    badge.top0().right0().size(px(6.));
                case Number:
                    final count = this.count > max ? '$max+' : '${this.count}';
                    final len = haxe.io.Bytes.ofString(count).length;
                    final position:Array<Pixels> = switch size {
                        case Large: [2., -len];
                        case Medium | Size(_): [-3., -3. * len];
                        case Small | XSmall: [-4., -4. * len];
                    };
                    badge.top(position[0])
                        .right(position[1])
                        .py0p5()
                        .px0p5()
                        .minW3p5()
                        .textSize(px(10.))
                        .lineHeight(relative(1.))
                        .child(count);
                case Icon(icon):
                    // Initial port deviation DEV-001 (see docs/DEVIATIONS.md): gpui-kit
                    // draws the ring as a border in the background color, which
                    // GPUI paints as a second quad over the colored disc, so both
                    // antialiased outer edges let the badge color leak around the
                    // ring. The ring is the padding of a disc in the background
                    // color around the colored disc instead.
                    badge.right0()
                        .bottom0()
                        .size(iconSize)
                        .bg(theme.background)
                        .p(px(1.))
                        .child(glaze.kit.base.Prelude.hFlex()
                            .sizeFull()
                            .justifyCenter()
                            .itemsCenter()
                            .roundedFullStyle(cx)
                            .bg(color != null ? color : theme.red)
                            .child(icon));
            }
            element.child(badge);
        }
        return element;
    }

}
