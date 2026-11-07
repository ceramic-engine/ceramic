// Ported from gpui-kit 0.8.1: crates/component/src/skeleton.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.skeleton;

import glaze.Animation;
import glaze.App;
import glaze.Easing;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.AnimationExt;
using glaze.kit.base.StyledExt;

/**
 * A placeholder block pulsing while content loads.
 */
class Skeleton implements RenderOnce implements Styled {

    final skeletonStyle:StyleRefinement = new StyleRefinement();

    var secondaryValue:Bool = false;

    public function new() {}

    public inline function style():StyleRefinement {
        return skeletonStyle;
    }

    /**
     * Use the secondary (lighter) color.
     */
    public function secondary():Skeleton {
        secondaryValue = true;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return div()
            .wFull()
            .h4()
            .bg(secondaryValue ? theme.skeleton.opacity(0.5) : theme.skeleton)
            .refineStyle(skeletonStyle)
            .withAnimation('skeleton', new Animation(2.).repeat().withEasing(Easing.bounce(Easing.easeInOut)), (element, delta) -> {
                final v = glaze.SpringMath.f32(1.0 - glaze.SpringMath.f32(delta * 0.5));
                return element.opacity(v);
            });
    }

}
