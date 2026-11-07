// Ported from gpui-kit 0.8.1: crates/component/src/dialog/entrance.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dialog;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Element;
import gpui.GlobalElementId;
import gpui.LayoutId;
import gpui.Pixels;
import gpui.Point;
import gpui.SpringMath.f32;
import gpui.Window;

/**
 * The entrance presentation shared by Dialog and AlertDialog.
 *
 * Closing animates the surface and backdrop back out. Reduced motion displays
 * the final state for every option, and `DialogEntrance.None` opens and
 * closes in a single frame.
 */
enum abstract DialogEntrance(Int) {
    /** Slide down from the window top while fading in, preserving the legacy entrance (the default). */
    var SlideDown = 0;
    /** Fade in at the final position without movement. */
    var Fade = 1;
    /**
     * Fade in while settling from just above the final position.
     *
     * Travel comes from the theme's short motion distance and is limited by
     * the space above the resolved surface inside the window.
     */
    var FadeSlide = 2;
    /** Show the surface and backdrop immediately without entrance animation. */
    var None = 3;

    public function toString():String {
        return switch (cast this : DialogEntrance) {
            case SlideDown: 'SlideDown';
            case Fade: 'Fade';
            case FadeSlide: 'FadeSlide';
            case None: 'None';
        }
    }
}

/**
 * Applies presentation travel after Positioner has resolved the resting bounds.
 * Paint, hit testing, and accessibility follow the same offset.
 */
@:allow(gpui.component.dialog, tests)
class EntranceSurface extends Element {

    final child:AnyElement;

    final travel:Pixels;

    final topLimit:Pixels;

    var progress:Float = 0.;

    function new(child:AnyElement, travel:Pixels, topLimit:Pixels) {
        this.child = child;
        this.travel = travel;
        this.topLimit = topLimit;
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(_:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final available = Math.max(f32((bounds.top():Float) - (topLimit:Float)), 0.);
        final travel = Math.min(Math.max((this.travel:Float), 0.), available);
        final clamped = progress < 0. ? 0. : progress > 1. ? 1. : progress;
        final offset = new Point(0., f32(-travel * f32(1. - clamped)));
        window.withElementOffset(offset, window -> child.prepaint(window, cx));
    }

    public function paint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }

}
