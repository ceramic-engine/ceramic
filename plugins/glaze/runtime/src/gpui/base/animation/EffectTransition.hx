// Ported from gpui-kit 0.8.1: crates/base/src/animation.rs (EffectTransition)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.animation;

import gpui.Animation;
import gpui.AnimationElement;
import gpui.AnimationExt;
import gpui.Element;
import gpui.ElementIdArg;
import gpui.IntoLength;
import gpui.Pixels;
import gpui.Styled;

/**
 * A composable transition that applies concrete fade, slide, and size effects
 * to an element.
 *
 * This is distinct from `gpui.base.motion.Transition`, which is a timing
 * policy for a caller-chosen value and never picks a visual property. Prefer
 * `motion` for new code.
 *
 * ```haxe
 * new EffectTransition(0.15)
 *     .ease(Easings.easeOutCubic)
 *     .slideY(px(-4), px(0))
 *     .fade(0.0, 1.0)
 *     .apply(element, 'enter-anim');
 * ```
 *
 * Builders mutate and return this transition (Rust consumes `self`). The
 * deprecated Rust alias `animation::Transition` is not ported.
 */
class EffectTransition {

    /**
     * The duration, in seconds (Rust `Duration`).
     */
    public var duration:Float;

    var easing:Float->Float;

    final effects:Array<TransitionEffect> = [];

    public function new(duration:Float) {

        this.duration = duration;
        this.easing = Easings.easeOutCubic;

    }

    /**
     * Set the easing function.
     */
    public function ease(easing:Float->Float):EffectTransition {

        this.easing = easing;
        return this;

    }

    /**
     * Animate vertical offset from `from` to `to`.
     */
    public function slideY(from:Pixels, to:Pixels):EffectTransition {

        effects.push(SlideY(from, to));
        return this;

    }

    /**
     * Animate horizontal offset from `from` to `to`.
     */
    public function slideX(from:Pixels, to:Pixels):EffectTransition {

        effects.push(SlideX(from, to));
        return this;

    }

    /**
     * Animate opacity from `from` to `to`.
     */
    public function fade(from:Float, to:Float):EffectTransition {

        effects.push(Fade(from, to));
        return this;

    }

    /**
     * Animate width from `from` to `to`.
     */
    public function width(from:Pixels, to:Pixels):EffectTransition {

        effects.push(Width(from, to));
        return this;

    }

    /**
     * Animate height from `from` to `to`.
     */
    public function height(from:Pixels, to:Pixels):EffectTransition {

        effects.push(Height(from, to));
        return this;

    }

    /**
     * Apply this transition to a styled element, returning an `AnimationElement`.
     */
    public function apply<E:Element & Styled>(element:E, id:ElementIdArg):AnimationElement<E> {

        final animation = new Animation(duration).withEasing(easing);
        final effects = this.effects.copy();
        return AnimationExt.withAnimation(element, id, animation, (el:E, delta:Float) -> {
            final style = el.style();
            for (effect in effects) {
                switch effect {
                    case SlideY(from, to):
                        final value:IntoLength = Lerp.pixels(from, to, delta);
                        style.insetTop = value;
                    case SlideX(from, to):
                        final value:IntoLength = Lerp.pixels(from, to, delta);
                        style.insetLeft = value;
                    case Fade(from, to):
                        style.opacity = Lerp.float(from, to, delta);
                    case Width(from, to):
                        final value:IntoLength = Lerp.pixels(from, to, delta);
                        style.sizeWidth = value;
                    case Height(from, to):
                        final value:IntoLength = Lerp.pixels(from, to, delta);
                        style.sizeHeight = value;
                }
            }
            return el;
        });

    }

}

private enum TransitionEffect {
    SlideY(from:Pixels, to:Pixels);
    SlideX(from:Pixels, to:Pixels);
    Fade(from:Float, to:Float);
    Width(from:Pixels, to:Pixels);
    Height(from:Pixels, to:Pixels);
}
