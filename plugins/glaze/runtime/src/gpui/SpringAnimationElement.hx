// Ported from gpui-pre 0.3.10: src/elements/animation.rs (`SpringAnimationElement`, `AnimationExt::with_spring`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A GPUI element that drives another element with a spring.
 * Build one with `div().withSpring(...)`, or `AnimationExt` for other elements.
 * While the spring is not settled, the element requests an animation frame.
 */
class SpringAnimationElement<E:Element, T> extends Element implements ParentElement {

    final id:ElementId;

    var element:Null<E>;

    final config:SpringConfig;

    final target:Float;

    final epsilon:Float;

    final initial:Null<Float>;

    final playback:SpringPlayback;

    var animator:Null<(E, Float) -> E>;

    var rendered:Null<AnyElement> = null;

    public function new(id:ElementIdArg, element:E, animation:SpringAnimation<T>, animator:(E, T) -> E) {
        this.id = id;
        this.element = element;
        this.config = animation.config;
        final springTarget = animation.target;
        this.target = springTarget.target();
        this.epsilon = animation.epsilon;
        this.initial = animation.initial;
        this.playback = animation.playback;
        this.animator = (element, value) -> animator(element, springTarget.resolve(value));
    }

    override function elementId():Null<ElementId> {
        return id;
    }

    /**
     * Returns a new `SpringAnimationElement` after applying the given function
     * to the element being animated.
     */
    public function mapElement(f:(E) -> E):SpringAnimationElement<E, T> {
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
    public function child(child:IntoElement):SpringAnimationElement<E, T> {
        if (child != null) extend([child]);
        return this;
    }

    /**
     * Add multiple child elements to the animated element (when it is a `ParentElement`).
     */
    public function children(children:Array<IntoElement>):SpringAnimationElement<E, T> {
        extend([for (child in children) if (child != null) (child : AnyElement)]);
        return this;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.withElementState(globalId, SpringAnimationState, (box, window) -> {
            final now = cx.backgroundExecutor().now();
            if (box.value == null) {
                box.value = SpringAnimationState.create(config, target, initial, playback, now);
            }
            final state = box.value;
            final done = state.advance(config, target, epsilon, playback, now, cx.reduceMotion());

            final element = this.element;
            this.element = null;
            final animator = this.animator;
            this.animator = null;
            final anyElement = (animator(element, state.spring.position) : Element).intoAnyElement();
            rendered = anyElement;

            if (!done) {
                window.requestAnimationFrame();
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
