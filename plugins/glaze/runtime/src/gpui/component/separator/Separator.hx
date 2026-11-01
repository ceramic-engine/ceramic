// Ported from gpui-kit 0.8.1: crates/component/src/separator.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.separator;

import gpui.App;
import gpui.Axis;
import gpui.Div;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.PathBuilder;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * The line style of a `Separator`.
 */
enum abstract SeparatorStyle(Int) {
    var Solid;
    var Dashed;
}

/**
 * A horizontal or vertical line, solid or dashed, with an optional label.
 */
class Separator implements RenderOnce implements Styled {

    final base:Div;

    final separatorStyle:StyleRefinement = new StyleRefinement();

    var labelValue:Null<String> = null;

    final axis:Axis;

    var colorValue:Null<Hsla> = null;

    var lineStyle:SeparatorStyle = Solid;

    function new(base:Div, axis:Axis) {
        this.base = base;
        this.axis = axis;
    }

    /**
     * Creates a vertical separator (full height).
     */
    public static function vertical():Separator {
        return new Separator(div().hFull(), Vertical);
    }

    /**
     * Creates a horizontal separator.
     */
    public static function horizontal():Separator {
        return new Separator(div(), Horizontal);
    }

    /**
     * Creates a vertical dashed separator.
     */
    public static function verticalDashed():Separator {
        return vertical().dashed();
    }

    /**
     * Creates a horizontal dashed separator.
     */
    public static function horizontalDashed():Separator {
        return horizontal().dashed();
    }

    public inline function style():StyleRefinement {
        return separatorStyle;
    }

    /**
     * Sets the label shown in the middle of the line.
     */
    public function label(label:String):Separator {
        labelValue = label;
        return this;
    }

    /**
     * Sets the line color (default: the theme's `border`).
     */
    public function color(color:IntoHsla):Separator {
        colorValue = color;
        return this;
    }

    /**
     * Use the dashed line style.
     */
    public function dashed():Separator {
        lineStyle = Dashed;
        return this;
    }

    static function renderBase(axis:Axis):Div {
        final base = div().absolute();
        return switch axis {
            case Vertical: base.w(gpui.Prelude.px(1.)).hFull();
            case Horizontal: base.h(gpui.Prelude.px(1.)).wFull();
        }
    }

    static function renderSolid(axis:Axis, color:Hsla):Div {
        return renderBase(axis).bg(color);
    }

    static function renderDashed(axis:Axis, color:Hsla):Div {
        return renderBase(axis).child(
            canvas((_, _, _) -> null, (bounds, _, window, _) -> {
                final builder = PathBuilder.stroke(gpui.Prelude.px(1.)).dashArray([gpui.Prelude.px(4.), gpui.Prelude.px(2.)]);
                switch axis {
                    case Horizontal:
                        final x = bounds.origin.x;
                        final y = bounds.origin.y + 0.5;
                        builder.moveTo(point(x, y));
                        builder.lineTo(point(x + bounds.size.width, y));
                    case Vertical:
                        final x = bounds.origin.x + 0.5;
                        final y = bounds.origin.y;
                        builder.moveTo(point(x, y));
                        builder.lineTo(point(x, y + bounds.size.height));
                }
                final line = try builder.build() catch (_:Dynamic) null;
                if (line != null) {
                    window.paintPath(line, color);
                }
            }).sizeFull()
        );
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final color = colorValue != null ? colorValue : theme.border;

        final element = base
            .flex()
            .flexShrink0()
            .itemsCenter()
            .justifyCenter()
            .refineStyle(separatorStyle)
            .child(switch lineStyle {
                case Solid: renderSolid(axis, color);
                case Dashed: renderDashed(axis, color);
            });
        if (labelValue != null) {
            element.child(
                div()
                    .px2()
                    .py1()
                    .mxAuto()
                    .textXs()
                    .bg(theme.tokens.background.background)
                    .textColor(theme.mutedForeground)
                    .child(labelValue)
            );
        }
        return element;
    }

}
