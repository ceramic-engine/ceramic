// Ported from gpui-pre 0.3.10: src/spring.rs (SpringTarget)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * A value that can be targeted by a one-dimensional spring.
 *
 * Implementations may project the spring coordinate into a richer output,
 * allowing a discrete state or a path through a multidimensional value to be
 * driven by one spring.
 *
 * Rust's associated type `Output` is the type parameter `O`. The built-in
 * implementations are `SpringValueTarget` (`f32`, `Pixels`, `Rems`) and
 * `SpringPhaseTarget` (`bool`, `AnimationPhase`).
 */
interface SpringTarget<O> {

    /**
     * Returns the target in the spring's coordinate space.
     */
    function target():Float;

    /**
     * Projects a spring coordinate into the animated output.
     */
    function resolve(value:Float):O;

}
