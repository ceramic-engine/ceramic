// Ported from gpui-kit 0.8.1: crates/component/src/spinner.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.spinner;

import gpui.Animation;
import gpui.App;
import gpui.Easing;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.Svg;
import gpui.Svg.Transformation;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;

import gpui.Prelude.*;

using gpui.AbsoluteLengthTools;
using gpui.AnimationExt;

/**
 * A spinner: an icon (`IconName.Loader` by default) turning with an
 * easing, one turn per `speed` seconds (0.8 by default).
 *
 * Rust animates the `Icon` component; GPUI's `AnimationExt` needs an
 * element here, so the icon is resolved to its `svg()` element (with the
 * text size and color of the spinner) and that element is animated.
 */
class Spinner implements RenderOnce implements Sizable {

    var size:Size = Medium;

    var iconValue:Icon = new Icon(IconName.Loader);

    var speed:Float = 0.8;

    var easing:(Float) -> Float = Easing.easeInOut;

    var colorValue:Null<Hsla> = null;

    public function new() {}

    /**
     * Set the icon to use for the spinner.
     */
    public function icon(icon:IntoIcon):Spinner {
        iconValue = icon;
        return this;
    }

    /**
     * Set the color of the spinner.
     */
    public function color(color:Hsla):Spinner {
        colorValue = color;
        return this;
    }

    /**
     * Set the easing of the rotation.
     */
    public function ease(easing:(Float) -> Float):Spinner {
        this.easing = easing;
        return this;
    }

    public function withSize(size:IntoSize):Spinner {
        this.size = size;
        return this;
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    public function render(window:Window, cx:App):IntoElement {
        final icon = iconValue.clone().withSize(size);
        if (colorValue != null) {
            icon.textColor(colorValue);
        }
        final textStyle = window.textStyle();
        final svg:Svg = icon.resolved(cx).intoSvg(textStyle.fontSize.toPixels(window.remSize()), textStyle.color);
        return div().child(
            svg.withAnimation('circle', new Animation(speed).repeat().withEasing(easing), (svg, delta) -> {
                // Rust `Transformation::rotate(percentage(delta))`: percentage to radians in f32
                return svg.withTransformation(Transformation.rotated(f32(f32(f32(delta) * f32(Math.PI)) * 2.)));
            })
        );
    }

}
