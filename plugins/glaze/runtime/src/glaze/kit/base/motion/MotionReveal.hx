// Ported from gpui-kit 0.8.1: crates/base/src/motion/reveal.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.AnyElement;
import glaze.App;
import glaze.AvailableSpace;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Element;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.GlobalElementId;
import glaze.IntoElement;
import glaze.IntoLength;
import glaze.LayoutId;
import glaze.Length;
import glaze.SizeOf;
import glaze.Style;
import glaze.Window;
import glaze.util.MathUtil;

import glaze.Prelude.px;
import glaze.Prelude.relative;

/**
 * A measured, clipped vertical reveal driven by normalized progress.
 *
 * The child is laid out at the full width, measured at its min-content
 * height, and shown through a clip whose height is that measured height times
 * `progress`. Until the first measure, a non-zero progress lets the child take
 * its natural height.
 */
class MotionReveal extends Element {

    final id:ElementId;

    final progress:Float;

    final child:AnyElement;

    public function new(id:ElementIdArg, progress:Float, child:IntoElement) {
        this.id = id;
        this.progress = MathUtil.clamp(progress, 0.0, 1.0);
        this.child = child;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final state = window.withElementState(globalId, RevealState, (box, _) -> {
            if (box.value == null) {
                box.value = new RevealState();
            }
            return box.value;
        });
        final style = new Style();
        style.sizeWidth = Length.Definite(relative(1.0));
        if (!state.measured) {
            if (!(progress > 0.0)) {
                final zero:IntoLength = px(0.0);
                style.sizeHeight = zero;
            }
        }
        else {
            final height:IntoLength = px(state.height * progress);
            style.sizeHeight = height;
        }
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final measured = child.layoutAsRoot(new SizeOf<AvailableSpace>(Definite(bounds.size.width), MinContent), window, cx);
        final changed = window.withElementState(globalId, RevealState, (box, _) -> {
            if (box.value == null) {
                box.value = new RevealState();
            }
            final state = box.value;
            final changed = !state.measured || state.height != measured.height;
            state.measured = true;
            state.height = measured.height;
            return changed;
        });
        if (changed) {
            window.requestAnimationFrame();
        }
        window.withContentMask(new ContentMask(bounds), window -> {
            child.prepaintAt(bounds.origin, window, cx);
            return null;
        });
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        window.withContentMask(new ContentMask(bounds), window -> {
            child.paint(window, cx);
            return null;
        });
    }

}

@:keep
private class RevealState {

    /** Whether `height` holds a measure (Rust `Option<Pixels>`). */
    public var measured:Bool = false;

    public var height:Float = 0.0;

    public function new() {}

}
