// Ported from gpui-kit 0.8.1: crates/story/src/stories/theme_story/checkerboard.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories.themestory;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.IntoElement;
import gpui.PaintQuad;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.SpringMath;
import gpui.Window;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

class Checkerboard implements RenderOnce implements ParentElement {

    final childElements:Array<AnyElement> = [];

    final isDark:Bool;

    public function new(isDark:Bool) {
        this.isDark = isDark;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Checkerboard {
        childElements.push(child.intoAnyElement());
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final squareSize = 12.;
        // Use a subtle difference for the checkerboard
        final c1 = isDark ? hsla(0., 0., 0.1, 1.) : hsla(0., 0., 1.0, 1.);
        final c2 = isDark ? hsla(0., 0., 0.13, 1.) : hsla(0., 0., 0.95, 1.);

        return div()
            .bg(c1)
            .rounded(Theme.global(cx).radiusLg)
            .overflowHidden()
            .sizeFull()
            .child(canvas((_, _, _) -> null, (bounds:Bounds, _, window:Window, _) -> {
                final size = squareSize;
                final rows = Std.int(Math.fceil(SpringMath.f32(bounds.size.height / size)));
                final cols = Std.int(Math.fceil(SpringMath.f32(bounds.size.width / size)));

                for (row in 0...rows) {
                    for (col in 0...cols) {
                        if ((row + col) % 2 == 0) {
                            final quad = new PaintQuad(new Bounds(new gpui.Point(SpringMath.f32(bounds.origin.x + size * col), SpringMath.f32(bounds.origin.y + size * row)),
                                new gpui.Size(size, size)));
                            quad.setSolidBackground(c2.h, c2.s, c2.l, c2.a);
                            window.paintQuad(quad);
                        }
                    }
                }
            })
                .absolute()
                .sizeFull())
            .children([for (element in childElements) (element : IntoElement)]);
    }

}
