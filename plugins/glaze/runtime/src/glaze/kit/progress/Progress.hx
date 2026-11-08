// Ported from gpui-kit 0.8.1: crates/component/src/progress/progress.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.progress;

import glaze.Animation;
import glaze.App;
import glaze.Background;
import glaze.Component;
import glaze.Easing;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Progress.ProgressIndicator;
import glaze.kit.base.Progress.ProgressTrack;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.Transition;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

using glaze.AnimationExt;
using glaze.kit.base.StyledExt;

/**
 * A progress bar: a pill track with the indicator filling `value` percent
 * of it (animated with the theme's motion), or sliding while `loading`.
 *
 * The theme's motion tokens are not ported yet: the transition uses their
 * default values (180ms, `cubic-bezier(0.2, 0, 0, 1)`).
 */
class Progress extends Component implements Styled implements Sizable {

    final id:ElementId;

    final progressStyle:StyleRefinement = new StyleRefinement();

    @prop var color:Null<Hsla> = null;

    var valueValue:Float = 0.;

    @prop var accessibilityLabel:Null<String> = null;

    var size:Size = Medium;

    @prop var loading:Bool = false;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public function color(color:IntoHsla):Progress {
        this.color = color;
        return this;
    }

    /** The value, clamped to 0..100. */
    public function value(value:Float):Progress {
        valueValue = value < 0. ? 0. : (value > 100. ? 100. : value);
        return this;
    }

    @:allow(tests)
    function getAccessibilityLabel():Null<String> {
        return accessibilityLabel;
    }

    public inline function style():StyleRefinement {
        return progressStyle;
    }

    public function withSize(size:IntoSize):Progress {
        this.size = size;
        return this;
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final bg:Background = color != null ? Background.fromHsla(color) : theme.tokens.progressBar.background;
        final value = valueValue;
        final loading = this.loading;
        final reduceMotion = cx.reduceMotion();

        final innerStyle = new StyleRefinement();
        innerStyle.cornerRadiusTopLeft = progressStyle.cornerRadiusTopLeft;
        innerStyle.cornerRadiusTopRight = progressStyle.cornerRadiusTopRight;
        innerStyle.cornerRadiusBottomRight = progressStyle.cornerRadiusBottomRight;
        innerStyle.cornerRadiusBottomLeft = progressStyle.cornerRadiusBottomLeft;

        final dims:Array<Pixels> = switch size {
            case XSmall: [4., 2.];
            case Small: [6., 3.];
            case Medium: [8., 4.];
            case Large: [10., 5.];
            case Size(s): [s, s / 2.];
        };
        final height = dims[0];
        // The bar reads as a pill of half its own height, and squares off with
        // the rest of the UI when the theme has no radius.
        final radius:Pixels = theme.radius == 0. ? 0. : dims[1];

        final animatedValue = Motion.transition(
            TransitionId.named(id, 'indicator'),
            value,
            new Transition(0.18).easing(glaze.kit.base.motion.Easing.cubicBezier(0.2, 0.0, 0.0, 1.0)),
            window,
            cx
        );

        final progress = glaze.kit.base.Progress.component(id).value(value).indeterminate(loading);
        if (accessibilityLabel != null) {
            progress.accessibilityLabel(accessibilityLabel);
        }
        progress.wFull().relative().h(height).rounded(radius).refineStyle(progressStyle);

        progress.child(
            ProgressTrack.component()
                .absolute()
                .sizeFull()
                .bg(bg.opacity(0.2))
                .rounded(radius)
                .refineStyle(innerStyle)
        );

        final indicator = ProgressIndicator.component()
            .absolute()
            .top0()
            .left0()
            .hFull()
            .bg(bg)
            .rounded(radius)
            .refineStyle(innerStyle);
        if (loading && !reduceMotion) {
            progress.child(indicator.intoDiv().withAnimation('progress-loading', new Animation(1.).repeat(), (element, delta) -> {
                final start = glaze.Prelude.relative(Easing.easeInOut(Math.min(Math.max(f32(f32(delta - 0.5) / 0.5), 0.), 1.)));
                final end = glaze.Prelude.relative(Easing.easeInOut(f32(1.0 - delta)));
                if (delta > 0.5) element.left(start);
                return element.right(end);
            }));
        }
        else if (loading) {
            progress.child(indicator.left(glaze.Prelude.relative(0.325)).right(glaze.Prelude.relative(0.325)));
        }
        else {
            final fraction = f32(animatedValue / 100.);
            progress.child(indicator.w(glaze.Prelude.relative(fraction < 0. ? 0. : (fraction > 1. ? 1. : fraction))));
        }
        return progress;
    }

}
