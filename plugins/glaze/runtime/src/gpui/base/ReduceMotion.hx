// Ported from gpui-kit 0.8.1: crates/base/src/reduce_motion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;

/**
 * Honors the operating system's reduced-motion preference.
 *
 * Every Base transition, spring, presence and reveal consults
 * `App.reduceMotion()`, but GPUI never reads the platform's setting into
 * that flag: it stays `false` until something sets it. `init` reads the
 * setting when Base initializes and writes it into the flag.
 *
 * Platform readings are not ported: Rust reads `NSWorkspace` on macOS,
 * `SystemParametersInfoW` on Windows and the XDG desktop portal on Linux,
 * none of which Ceramic exposes. The reading is pluggable instead:
 * `systemPreference` (a function returning `true`, `false`, or `null` when
 * the platform cannot say) and `followSystem` (called once, to subscribe to
 * changes and feed them to `applyPreference`). Both are `null` by default,
 * which leaves the flag alone, as Rust does on a platform it cannot read.
 *
 * An application owns the flag once it sets it. Base writes the flag only
 * while it still holds what Base last wrote (or GPUI's initial `false`), so
 * an application that calls `App.setReduceMotion` after `init` is never
 * overridden by a later reading, and one that wants to follow the system
 * again calls `applySystemReduceMotion`.
 *
 * Under the test dispatcher the platform is never consulted: a test wanting
 * reduced motion sets the flag itself.
 */
class ReduceMotion {

    /**
     * Reads the system preference: `true` to reduce motion, `false` not to,
     * `null` when unknown. `null` (the default) means no reading.
     */
    public static var systemPreference:Null<Void->Null<Bool>> = null;

    /**
     * Called once by the first `applySystemReduceMotion`, to follow the
     * platform's changes by calling `applyPreference` (Rust follows the Linux
     * portal's change signal this way). `null` by default.
     */
    public static var followSystem:Null<App->Void> = null;

    /**
     * Applies the system's reduced-motion preference when Base initializes.
     */
    public static function init(cx:App):Void {
        applySystemReduceMotion(cx);
    }

    /**
     * Reads the operating system's reduced-motion preference into
     * `App.setReduceMotion`.
     *
     * `init` calls this once. Call it again to re-read the preference on a
     * platform Base does not follow live.
     *
     * The application wins over the system: when the flag no longer holds
     * what Base last wrote, the application set it, and this call leaves it
     * alone. Where the platform cannot say the flag is left as it is, and
     * under the test dispatcher the platform is not asked at all.
     */
    public static function applySystemReduceMotion(cx:App):Void {
        if (cx.isTest()) {
            return;
        }
        final read = systemPreference;
        applyPreference(read != null ? read() : null, cx);
        final state = cx.defaultGlobal(SystemReduceMotion);
        if (!state.following) {
            state.following = true;
            final follow = followSystem;
            if (follow != null) {
                follow(cx);
            }
        }
    }

    /**
     * Writes one reading of the system preference into the flag, unless the
     * application has taken the flag over since the reading Base last
     * applied. `null` (unknown) leaves the flag alone.
     *
     * Public so that platform code (or `followSystem`) can feed readings.
     */
    public static function applyPreference(preference:Null<Bool>, cx:App):Void {
        if (preference == null) {
            return;
        }
        final reduce:Bool = preference;
        final state = cx.tryGlobal(SystemReduceMotion);
        final applied = state != null && state.hasApplied ? state.applied : false;
        if (cx.reduceMotion() != applied) {
            return;
        }
        cx.setReduceMotion(reduce);
        final state = cx.defaultGlobal(SystemReduceMotion);
        state.hasApplied = true;
        state.applied = reduce;
    }

}

/**
 * What Base last wrote into `App.setReduceMotion`, and whether it is already
 * listening for the platform to change its mind.
 */
@:keep
class SystemReduceMotion {

    /** Whether `applied` holds a value (Rust `Option<bool>`). */
    public var hasApplied:Bool = false;

    public var applied:Bool = false;

    public var following:Bool = false;

    public function new() {}

}
