// Ported from gpui-pre 0.3.10: src/spring.rs (SpringTarget for f32, Pixels, Rems)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * A plain scalar spring target: `f32`, `Pixels` or `Rems` in Rust.
 * They are all `Float` abstracts here, so one implementation covers them:
 * the output converts implicitly to `Pixels` or `Rems`.
 */
class SpringValueTarget implements SpringTarget<Float> {

    public final value:Float;

    public inline function new(value:Float) {

        this.value = value;

    }

    public function target():Float {

        return value;

    }

    public function resolve(value:Float):Float {

        return value;

    }

}
