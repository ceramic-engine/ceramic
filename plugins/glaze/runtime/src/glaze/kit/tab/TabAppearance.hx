// New code for the Haxe port of gpui-kit (no gpui-kit origin): the geometry of `TabVariant.Custom`,
// addition KIT-001 in docs/DEVIATIONS.md. See NOTICE.md.
package glaze.kit.tab;

import glaze.Edges;
import glaze.Pixels;

/**
 * The geometry of `TabVariant.Custom` tabs (addition without upstream
 * equivalent, see docs/DEVIATIONS.md): a rectangular tab like
 * `TabVariant.Tab`, whose corners, paddings, height, text size and borders
 * are chosen by the application. Its colors come from the theme tokens
 * `tab.background` (inactive), `tab.hover.background`, `tab.hover.foreground`,
 * `tab.active.background`, `tab.active.foreground` and `tab.foreground`.
 *
 * Every value left unset keeps the metrics of `TabVariant.Tab` for the size
 * of the bar.
 */
class TabAppearance {

    /** Radius of the two top corners of a tab. */
    public var topRadiusValue:Pixels = 0.;

    /** Paddings of the tab content (label and children), `null` for those of `TabVariant.Tab`. */
    public var paddingsValue:Null<Edges> = null;

    /** Height of a tab, `null` for the height of `TabVariant.Tab`. */
    public var heightValue:Null<Pixels> = null;

    /** Text size of a tab, `null` for the text size of the bar's size. */
    public var textSizeValue:Null<Pixels> = null;

    /** Whether the bar draws its bottom border line. */
    public var bottomBorderValue:Bool = true;

    /** Whether a tab keeps its one pixel left and right borders. */
    public var sideBordersValue:Bool = true;

    /** Room between two tabs. */
    public var gapValue:Pixels = 0.;

    public function new() {}

    /** Sets the radius of the two top corners of a tab. */
    public function topRadius(radius:Pixels):TabAppearance {
        topRadiusValue = radius;
        return this;
    }

    /** Sets the paddings of the tab content. */
    public function paddings(top:Pixels, right:Pixels, bottom:Pixels, left:Pixels):TabAppearance {
        paddingsValue = new Edges(top, right, bottom, left);
        return this;
    }

    /** Sets the horizontal paddings of the tab content. */
    public function paddingX(padding:Pixels):TabAppearance {
        final current = paddingsValue;
        paddingsValue = new Edges(current != null ? current.top : 0., padding, current != null ? current.bottom : 0., padding);
        return this;
    }

    /** Sets the height of a tab. */
    public function height(height:Pixels):TabAppearance {
        heightValue = height;
        return this;
    }

    /** Sets the text size of a tab. */
    public function textSize(size:Pixels):TabAppearance {
        textSizeValue = size;
        return this;
    }

    /** Sets whether the bar draws its bottom border line (default true). */
    public function bottomBorder(visible:Bool):TabAppearance {
        bottomBorderValue = visible;
        return this;
    }

    /** Sets whether a tab keeps its one pixel left and right borders (default true). */
    public function sideBorders(visible:Bool):TabAppearance {
        sideBordersValue = visible;
        return this;
    }

    /** Sets the room between two tabs (default 0). */
    public function gap(gap:Pixels):TabAppearance {
        gapValue = gap;
        return this;
    }

}
