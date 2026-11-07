// Ported from gpui-kit 0.8.1: crates/base/src/number_input.rs (`NumberStep`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.App;

/**
 * Strategy used by numeric editors when stepping their value. Methods are in
 * `NumberStepTools`; a number converts implicitly through `IntoNumberStep`
 * (Rust `From<f64>`).
 */
@:using(glaze.kit.base.NumberStep.NumberStepTools)
enum NumberStep {
    Fixed(step:Float);
    ByValue(f:(Float, StepAction, App) -> Float);
}

class NumberStepTools {

    public static function byValue(f:(Float, StepAction, App) -> Float):NumberStep {
        return ByValue(f);
    }

    public static function value(self:NumberStep, current:Float, action:StepAction, cx:App):Float {
        return switch self {
            case Fixed(step): step;
            case ByValue(f): f(current, action, cx);
        }
    }

}

/**
 * Rust `impl Into<NumberStep>`: a `NumberStep`, or a number for `Fixed`.
 */
abstract IntoNumberStep(NumberStep) from NumberStep to NumberStep {

    @:from static inline function fromFloat(step:Float):IntoNumberStep {
        return Fixed(step);
    }

    @:from static inline function fromInt(step:Int):IntoNumberStep {
        return Fixed(step);
    }

}
