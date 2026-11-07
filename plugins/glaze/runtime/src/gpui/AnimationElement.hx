// Ported from gpui-pre 0.3.10: src/elements/animation.rs (`AnimationElement`, `AnimationExt::with_animation(s)`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A GPUI element that applies an animation to another element.
 * Build one with `div().withAnimation(...)` / `withAnimations(...)`, or
 * `AnimationExt` (`using gpui.AnimationExt;`) for other elements.
 *
 * The animator is called during `requestLayout` with the eased value; while
 * the animation runs, the element requests an animation frame (or, with
 * `Animation.withMaxFps`, a timer notifying its view). Times come from
 * `cx.backgroundExecutor().now()`, so tests drive them with the
 * `TestDispatcher` clock.
 */
class AnimationElement<E:Element> extends Element implements ParentElement {

    final id:ElementId;

    var element:Null<E>;

    final animations:Array<Animation>;

    final animator:(E, Int, Float) -> E;

    var rendered:Null<AnyElement> = null;

    public function new(id:ElementIdArg, element:E, animations:Array<Animation>, animator:(E, Int, Float) -> E) {
        this.id = id;
        this.element = element;
        this.animations = animations;
        this.animator = animator;
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    /**
     * Returns a new `AnimationElement<E>` after applying the given function
     * to the element being animated.
     */
    public function mapElement(f:(E) -> E):AnimationElement<E> {
        if (element != null) element = f(element);
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        if (element != null && Std.isOfType(element, ParentElement)) {
            (cast element : ParentElement).extend(elements);
        }
    }

    /**
     * Add a single child element to the animated element (when it is a `ParentElement`).
     */
    public function child(child:IntoElement):AnimationElement<E> {
        if (child != null) extend([child]);
        return this;
    }

    /**
     * Add multiple child elements to the animated element (when it is a `ParentElement`).
     */
    public function children(children:Array<IntoElement>):AnimationElement<E> {
        extend([for (child in children) if (child != null) (child : AnyElement)]);
        return this;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.withElementState(globalId, AnimationState, (box, window) -> {
            final now = cx.backgroundExecutor().now();
            if (box.value == null) {
                box.value = new AnimationState(now);
            }
            final state = box.value;
            state.advance(animations, now, cx.syncedAnimationEpoch, cx.reduceMotion());
            final animationIx = state.frameAnimationIx;
            final delta = state.frameDelta;
            final done = state.frameDone;

            final element = this.element;
            this.element = null;
            final anyElement = (animator(element, animationIx, delta) : Element).intoAnyElement();
            rendered = anyElement;

            if (!done) {
                final maxFps = animations[animationIx].maxFps;
                if (maxFps != null && Math.isFinite(maxFps) && maxFps > 0.0) {
                    if (!state.delayedFramePending) {
                        state.delayedFramePending = true;
                        final view = window.currentView();
                        final interval = SpringMath.f32(1.0 / maxFps);
                        cx.backgroundExecutor().timer(interval).then(_ -> {
                            state.delayedFramePending = false;
                            if (!window.isDestroyed()) {
                                cx.update(cx -> cx.notify(view));
                            }
                        });
                    }
                }
                else {
                    window.requestAnimationFrame();
                }
            }

            return anyElement.requestLayout(window, cx);
        });
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        rendered.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final rendered = this.rendered;
        this.rendered = null;
        rendered.paint(window, cx);
    }

}
