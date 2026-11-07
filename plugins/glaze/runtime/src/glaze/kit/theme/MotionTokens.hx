// Ported from gpui-kit 0.8.1: crates/component/src/theme/motion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

import gpui.Rems;
import gpui.base.motion.Easing;
import gpui.base.motion.Spring;

/**
 * Semantic motion policy shared by styled components (durations in seconds).
 *
 * The values are immutable policies (`Easing`, `Spring`), so a theme copy
 * shares its tokens.
 */
class MotionTokens {

    public var durationInstant:Float = 0.;

    public var durationFast:Float = 0.120;

    public var durationNormal:Float = 0.180;

    public var durationSlow:Float = 0.280;

    public var easingEnter:Easing = Easing.cubicBezier(0.16, 1.0, 0.3, 1.0);

    public var easingExit:Easing = Easing.cubicBezier(0.4, 0.0, 1.0, 1.0);

    public var easingMove:Easing = Easing.cubicBezier(0.2, 0.0, 0.0, 1.0);

    public var springControl:Spring = new Spring(0.180);

    public var springMove:Spring = new Spring(0.280).withDamping(0.85).withEpsilon(0.1);

    public var distanceShort:Rems = 0.25;

    public var distanceMedium:Rems = 0.5;

    public function new() {}

    public function copy():MotionTokens {
        final tokens = new MotionTokens();
        tokens.durationInstant = durationInstant;
        tokens.durationFast = durationFast;
        tokens.durationNormal = durationNormal;
        tokens.durationSlow = durationSlow;
        tokens.easingEnter = easingEnter;
        tokens.easingExit = easingExit;
        tokens.easingMove = easingMove;
        tokens.springControl = springControl;
        tokens.springMove = springMove;
        tokens.distanceShort = distanceShort;
        tokens.distanceMedium = distanceMedium;
        return tokens;
    }

}
