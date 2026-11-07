// Ported from gpui-kit 0.8.1: crates/component/src/tab/tab.rs (TabVariant, FolderTabMetrics, TabStyle)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.tab;

import gpui.App;
import gpui.Background;
import gpui.IntoBackground;
import gpui.Edges;
import gpui.Hsla;
import gpui.Pixels;
import gpui.component.Size;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

/**
 * Tab variants.
 */
enum abstract TabVariant(Int) {

    var Tab;
    var Outline;
    var Pill;
    var Segmented;
    var Underline;

    /**
     * Tabs shaped like a folder's index tabs, as in a web browser: the
     * selected tab rises from the bar with rounded top corners and curves out
     * into the content below it.
     */
    var Folder;

    /** The default, `Tab`. */
    public static inline function defaultValue():TabVariant {
        return Tab;
    }

    @:allow(gpui.component.tab)
    function height(size:Size):Pixels {
        final self:TabVariant = cast this;
        return switch size {
            case XSmall: self == Underline ? 26. : 20.;
            case Small: self == Underline ? 30. : 24.;
            case Large: self == Underline ? 44. : 36.;
            case _: self == Underline ? 36. : 32.;
        }
    }

    @:allow(gpui.component.tab)
    function innerHeight(size:Size):Pixels {
        final self:TabVariant = cast this;
        return switch size {
            case XSmall: switch self {
                    case Tab | Outline | Pill: 18.;
                    case Segmented | Folder: 16.;
                    case Underline: 20.;
                }
            case Small: switch self {
                    case Tab | Outline | Pill: 22.;
                    case Segmented | Folder: 18.;
                    case Underline: 22.;
                }
            case Large: switch self {
                    case Tab | Outline | Pill: 36.;
                    case Segmented | Folder: 28.;
                    case Underline: 32.;
                }
            case _: switch self {
                    case Tab: 30.;
                    case Outline | Pill: 26.;
                    case Segmented | Folder: 24.;
                    case Underline: 26.;
                }
        }
    }

    /** Default px(12) to match a dock tab bar's px_3 */
    @:allow(gpui.component.tab)
    function innerPaddings(size:Size):Edges {
        final self:TabVariant = cast this;
        var paddingX:Float = switch size {
            case XSmall: 8.;
            case Small: 10.;
            case Large: 16.;
            case _: 12.;
        }
        // A folder tab pads its content itself, see `FolderTabMetrics`.
        if (self == Underline || self == Folder) {
            paddingX = 0.;
        }
        return new Edges(0., paddingX, 0., paddingX);
    }

    @:allow(gpui.component.tab)
    function innerMargins(size:Size):Edges {
        final self:TabVariant = cast this;
        if (self != Underline) return new Edges(0., 0., 0., 0.);
        return switch size {
            case XSmall: new Edges(1., 0., 2., 0.);
            case Small: new Edges(2., 0., 3., 0.);
            case Large: new Edges(5., 0., 6., 0.);
            case _: new Edges(3., 0., 4., 0.);
        }
    }

    @:allow(gpui.component.tab)
    function normal(cx:App):TabStyle {
        final theme = Theme.global(cx);
        final self:TabVariant = cast this;
        final style = new TabStyle();
        switch self {
            case Tab:
                style.fg = theme.tabForeground;
                style.bg = theme.transparent;
                style.borders = new Edges(0., 1., 0., 1.);
                style.borderColor = theme.transparent;
            case Outline:
                style.fg = theme.tabForeground;
                style.bg = theme.transparent;
                style.borders = new Edges(1., 1., 1., 1.);
                style.borderColor = theme.border;
            case Pill:
                style.fg = theme.foreground;
                style.bg = theme.transparent;
            case Segmented:
                style.fg = theme.tabForeground;
                style.bg = theme.transparent;
            case Underline:
                style.fg = theme.tabForeground;
                style.bg = theme.transparent;
                style.innerBg = theme.transparent;
                style.borders = new Edges(0., 0., 2., 0.);
                style.borderColor = theme.transparent;
            case Folder:
                style.fg = theme.tabForeground;
                style.bg = theme.transparent;
        }
        return style;
    }

    @:allow(gpui.component.tab)
    function hovered(selected:Bool, cx:App):TabStyle {
        final theme = Theme.global(cx);
        final self:TabVariant = cast this;
        final style = new TabStyle();
        switch self {
            case Tab:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
                style.borders = new Edges(0., 1., 0., 1.);
                style.borderColor = theme.transparent;
            case Outline:
                style.fg = theme.secondaryForeground;
                style.bg = theme.tokens.secondaryHover.background;
                style.borders = new Edges(1., 1., 1., 1.);
                style.borderColor = theme.border;
            case Pill:
                style.fg = theme.secondaryForeground;
                style.bg = theme.tokens.secondary.background;
            case Segmented:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
                style.innerBg = selected ? theme.tokens.background.background : (theme.transparent : IntoBackground);
            case Underline:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
                style.innerBg = theme.transparent;
                style.borders = new Edges(0., 0., 2., 0.);
                style.borderColor = theme.transparent;
            // The hover fill is an inset rounded layer, see `Tab.render`.
            case Folder:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
        }
        return style;
    }

    @:allow(gpui.component.tab)
    function selected(cx:App):TabStyle {
        final theme = Theme.global(cx);
        final self:TabVariant = cast this;
        final style = new TabStyle();
        switch self {
            case Tab:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.tokens.tabActive.background;
                style.borders = new Edges(0., 1., 0., 1.);
                style.borderColor = theme.border;
            case Outline:
                style.fg = theme.primary;
                style.bg = theme.transparent;
                style.borders = new Edges(1., 1., 1., 1.);
                style.borderColor = theme.primary;
            case Pill:
                style.fg = theme.primaryForeground;
                style.bg = theme.tokens.primary.background;
            case Segmented:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
                style.innerBg = theme.tokens.background.background;
                style.shadow = true;
            case Underline:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
                style.borders = new Edges(0., 0., 2., 0.);
                style.borderColor = theme.primary;
            // The shape is painted by `folder_tab_shape`.
            case Folder:
                style.fg = theme.tabActiveForeground;
                style.bg = theme.transparent;
        }
        return style;
    }

    @:allow(gpui.component.tab)
    function disabled(selected:Bool, cx:App):TabStyle {
        final theme = Theme.global(cx);
        final self:TabVariant = cast this;
        final style = new TabStyle();
        switch self {
            case Tab:
                style.fg = theme.mutedForeground;
                style.bg = theme.transparent;
                style.borderColor = selected ? theme.border : theme.transparent;
                style.borders = new Edges(0., 1., 0., 1.);
            case Outline:
                style.fg = theme.mutedForeground;
                style.bg = theme.transparent;
                style.borders = new Edges(1., 1., 1., 1.);
                style.borderColor = selected ? theme.primary : theme.border;
            case Pill:
                style.fg = selected ? theme.primaryForeground.opacity(0.5) : theme.mutedForeground;
                style.bg = selected ? theme.primary.opacity(0.5) : theme.transparent;
            case Segmented:
                style.fg = theme.mutedForeground;
                style.bg = theme.tokens.tabBar.background;
                style.innerBg = selected ? theme.tokens.background.background : (theme.transparent : IntoBackground);
            case Underline:
                style.fg = theme.mutedForeground;
                style.bg = theme.transparent;
                style.borderColor = selected ? theme.border : theme.transparent;
                style.borders = new Edges(0., 0., 2., 0.);
            case Folder:
                style.fg = theme.mutedForeground;
                style.bg = theme.transparent;
        }
        return style;
    }

    @:allow(gpui.component.tab)
    function tabBarRadius(size:Size, cx:App):Pixels {
        final self:TabVariant = cast this;
        if (self != Segmented) {
            return 0.;
        }
        final theme = Theme.global(cx);
        return switch size {
            case XSmall | Small: theme.radius;
            case Large: theme.radiusLg;
            case _: theme.radiusLg;
        }
    }

    @:allow(gpui.component.tab)
    function radius(size:Size, cx:App):Pixels {
        final self:TabVariant = cast this;
        final theme = Theme.global(cx);
        return switch self {
            case Outline | Pill: theme.radiusFull();
            case Segmented: switch size {
                    case XSmall | Small: theme.radius;
                    case Large: theme.radiusLg;
                    case _: theme.radiusLg;
                }
            case _: 0.;
        }
    }

    @:allow(gpui.component.tab)
    function innerRadius(size:Size, cx:App):Pixels {
        final self:TabVariant = cast this;
        return switch self {
            // The inset the active pill sits at, taken off the bar's own radius
            // so the two curves stay concentric. Floored at zero: a square bar
            // has nothing to inset from.
            case Segmented: switch size {
                    case Large: Math.max(f32(tabBarRadius(size, cx) - 3.), 0.);
                    case _: Math.max(f32(tabBarRadius(size, cx) - 2.), 0.);
                }
            case _: 0.;
        }
    }

    /** How far a tab's painting reaches past its bounds on either side. */
    @:allow(gpui.component.tab)
    function overhang(size:Size, cx:App):Pixels {
        final self:TabVariant = cast this;
        return switch self {
            case Folder: new FolderTabMetrics(size, cx).radius;
            case _: 0.;
        }
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

}

/** Room between two `TabVariant.Folder` tabs, holding their separator. */
@:allow(gpui.component.tab)
class FolderTabConstants {
    static inline final FOLDER_TAB_GAP:Float = 4.;
}

/**
 * Geometry of `TabVariant.Folder`.
 */
@:allow(gpui.component.tab)
class FolderTabMetrics {

    /**
     * Bar space above the tabs. The content sits this much above the tab's
     * center so that it centers on the whole bar.
     */
    final topPadding:Pixels;

    /**
     * Radius of the top corners and of the curves joining the selected tab
     * to the content below.
     */
    final radius:Pixels;

    final paddingX:Pixels;

    final separatorHeight:Pixels;

    function new(size:Size, cx:App) {
        final theme = Theme.global(cx);
        final values:{top:Float, padding:Float, separator:Float, radius:Float} = switch size {
            case XSmall: {top: 2., padding: 8., separator: 12., radius: theme.radius};
            case Small: {top: 4., padding: 8., separator: 12., radius: theme.radius};
            case Large: {top: 8., padding: 16., separator: 16., radius: theme.radiusLg};
            case _: {top: 4., padding: 12., separator: 16., radius: theme.radiusLg};
        }
        topPadding = values.top;
        // Past a third of the height a curve reaches under its neighbor's
        // hover fill.
        radius = Math.min(values.radius, gpui.SpringMath.f32(TabVariant.Folder.height(size) / 3.));
        paddingX = values.padding;
        separatorHeight = values.separator;
    }

}

/** The colors and borders of a tab in one state. */
@:allow(gpui.component.tab)
class TabStyle {

    var borders:Edges = new Edges(0., 0., 0., 0.);
    var borderColor:Hsla = transparentWhite();
    var bg:IntoBackground = transparentWhite();
    var fg:Hsla = transparentWhite();
    var shadow:Bool = false;
    var innerBg:IntoBackground = transparentWhite();

    function new() {}

}
