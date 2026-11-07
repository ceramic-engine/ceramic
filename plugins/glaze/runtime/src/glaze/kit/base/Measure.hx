// Ported from gpui-kit 0.8.1: crates/base/src/measure.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * An elapsed-time measurement, logged when ended (Rust traces it with
 * `tracing::trace!`; here it goes to `ceramic.Shortcuts.log.debug`).
 *
 * Enabled by the `ZED_MEASUREMENTS` or `GLAZE_MEASUREMENTS` environment
 * variables, read once.
 */
class Measure {

    static var enabled:Null<Bool> = null;

    final name:String;

    final start:Float;

    public function new(name:String) {
        this.name = name;
        this.start = haxe.Timer.stamp();
    }

    public function end():Void {
        final duration = haxe.Timer.stamp() - start;
        ceramic.Shortcuts.log.debug('$name in ${Math.round(duration * 1000000) / 1000}ms');
    }

    public static function measurementEnabled():Bool {
        if (enabled == null) {
            enabled = ceramic.Platform.getEnv('ZED_MEASUREMENTS') != null || ceramic.Platform.getEnv('GLAZE_MEASUREMENTS') != null;
        }
        return enabled;
    }

    /**
     * Measures `f` when `condition` is true and measurement logging is enabled.
     */
    public static function measureIf(name:String, condition:Bool, f:() -> Void):Void {
        if (condition && measurementEnabled()) {
            final measure = new Measure(name);
            f();
            measure.end();
        }
        else {
            f();
        }
    }

    /**
     * Measures `f` when measurement logging is enabled.
     */
    public static function measure(name:String, f:() -> Void):Void {
        measureIf(name, true, f);
    }

}
