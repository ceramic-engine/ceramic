// Ported from gpui-pre 0.3.10: src/elements/animation.rs (`AnimationExt`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An extension trait for adding the animation wrapper to both Elements and Components.
 * Use it with `using glaze.AnimationExt;` (`Div` has the same methods built in).
 */
class AnimationExt {

    /**
     * Render this component or element with an animation.
     */
    public static function withAnimation<E:Element>(element:E, id:ElementIdArg, animation:Animation, animator:(E, Float) -> E):AnimationElement<E> {
        return new AnimationElement<E>(id, element, [animation], (element, _, value) -> animator(element, value));
    }

    /**
     * Render this component or element with a chain of animations.
     */
    public static function withAnimations<E:Element>(element:E, id:ElementIdArg, animations:Array<Animation>, animator:(E, Int, Float) -> E):AnimationElement<E> {
        return new AnimationElement<E>(id, element, animations, animator);
    }

    /**
     * Render this component or element with a spring animation.
     */
    public static function withSpring<E:Element, T>(element:E, id:ElementIdArg, animation:SpringAnimation<T>, animator:(E, T) -> E):SpringAnimationElement<E, T> {
        return new SpringAnimationElement<E, T>(id, element, animation, animator);
    }

}
