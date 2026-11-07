// Ported from gpui-kit 0.8.1: crates/component/src/progress/progress_circle.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.progress;

import glaze.AnyElement;
import glaze.Animation;
import glaze.App;
import glaze.Bounds;
import glaze.Easing;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.SpringMath;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.Transition;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.base.plot.shape.Arc;
import glaze.kit.base.plot.shape.Arc.ArcData;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.canvas;
import glaze.Prelude.px;
import glaze.Prelude.relative;

using glaze.AnimationExt;
using glaze.kit.base.StyledExt;

/**
 * What the arc canvas computes in prepaint.
 */
private class CircleState {

    public final startValue:Float;

    public final endValue:Float;

    public final innerRadius:Float;

    public final outerRadius:Float;

    public final bounds:Bounds;

    public function new(startValue:Float, endValue:Float, innerRadius:Float, outerRadius:Float, bounds:Bounds) {
        this.startValue = startValue;
        this.endValue = endValue;
        this.innerRadius = innerRadius;
        this.outerRadius = outerRadius;
        this.bounds = bounds;
    }

}

/**
 * A circular progress indicator element.
 */
class ProgressCircle implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final id:ElementId;

    final circleStyle:StyleRefinement = new StyleRefinement();

    var colorValue:Null<Hsla> = null;

    var valueValue:Float = 0.;

    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    var size:Size = Medium;

    final childElements:Array<AnyElement> = [];

    var loadingValue:Bool = false;

    /** Create a new circular progress indicator. */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Enable indeterminate loading animation: the value is ignored and an
     * infinite rotating arc animation is shown instead.
     */
    public function loading(loading:Bool):ProgressCircle {
        loadingValue = loading;
        return this;
    }

    /** Set the color of the progress circle. */
    public function color(color:IntoHsla):ProgressCircle {
        colorValue = color;
        return this;
    }

    /** Set the percentage value of the progress circle (between 0 and 100). */
    public function value(value:Float):ProgressCircle {
        final v = SpringMath.f32(value);
        valueValue = v < 0. ? 0. : (v > 100. ? 100. : v);
        return this;
    }

    /** Set the accessible name exposed by the progress indicator. */
    public function accessibilityLabel(label:String):ProgressCircle {
        accessibilityLabelValue = label;
        return this;
    }

    public inline function style():StyleRefinement {
        return circleStyle;
    }

    public function withSize(size:IntoSize):ProgressCircle {
        this.size = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ProgressCircle {
        if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Render the arc canvas. `startValue` and `endValue` are in 0 to 100
     * percent. The progress arc is skipped when `endValue <= 0`.
     */
    static function renderCircle(startValue:Float, endValue:Float, color:Hsla):IntoElement {
        return canvas((bounds:Bounds, _, _) -> {
            final strokeWidth = Math.min(f(bounds.size.width * f(0.15)), 5.);
            final actualSize = Math.min(bounds.size.width, bounds.size.height);
            final actualRadius = f(f(actualSize - strokeWidth) / 2.);
            return new CircleState(startValue, endValue, f(actualRadius - f(strokeWidth / 2.)), f(actualRadius + f(strokeWidth / 2.)), bounds);
        }, (_, prepaint:CircleState, window:Window, _) -> {
            final arc = new Arc().innerRadius(prepaint.innerRadius).outerRadius(prepaint.outerRadius);

            arc.paint(new ArcData(null, 0, 100., 0., Arc.TAU), color.opacity(0.2), prepaint.bounds, window);

            if (prepaint.endValue > 0.) {
                final startAngle = f(f(prepaint.startValue / 100.) * Arc.TAU);
                final endAngle = f(f(prepaint.endValue / 100.) * Arc.TAU);
                arc.paint(new ArcData(null, 1, prepaint.endValue, startAngle, endAngle), color, prepaint.bounds, window);
            }
        }).absolute().sizeFull();
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final value = valueValue;
        final loading = loadingValue;
        final animated = Motion.transition(
            TransitionId.named(id, 'value'),
            value,
            new Transition(theme.motionTokens().durationNormal).easing(theme.motionTokens().easingMove),
            window,
            cx
        );
        // An overshooting theme curve may carry the value past either end,
        // but the ring cannot sweep more than once around.
        final animatedValue = animated < 0. ? 0. : (animated > 100. ? 100. : animated);

        final color:Hsla = colorValue != null ? colorValue : theme.progressBar;

        final progress = new glaze.kit.base.Progress(id).value(value).indeterminate(loading);
        if (accessibilityLabelValue != null) {
            progress.accessibilityLabel(accessibilityLabelValue);
        }
        progress.flex().itemsCenter().justifyCenter().lineHeight(glaze.Prelude.relative(1.));
        switch size {
            case XSmall: progress.size2();
            case Small: progress.size3();
            case Medium: progress.size4();
            case Large: progress.size5();
            case Size(s): progress.size(glaze.Prelude.px(f(s * f(0.75))));
        }
        progress.refineStyle(circleStyle);
        progress.extend(childElements);

        if (loading) {
            // Rust animates the base progress itself: its rendered div here.
            progress.render(window, cx);
            return progress.base.withAnimation('progress-circle-loading', new Animation(1.).repeat(), (element, delta) -> {
                final end = f(Easing.easeInOut(delta) * 100.);
                final t = f(f(delta - 0.5) / 0.5);
                final start = f(Easing.easeInOut(t < 0. ? 0. : (t > 1. ? 1. : t)) * 100.);
                return element.child(renderCircle(start, end, color));
            });
        }
        return progress.child(renderCircle(0., animatedValue, color));
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
