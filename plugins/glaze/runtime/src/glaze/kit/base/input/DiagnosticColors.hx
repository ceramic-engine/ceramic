// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Hsla;

/**
 * Colors of the diagnostics of an editor (all transparent by default).
 */
class DiagnosticColors {

    public var error:Hsla;

    public var warning:Hsla;

    public var info:Hsla;

    public var hint:Hsla;

    public function new(?error:Hsla, ?warning:Hsla, ?info:Hsla, ?hint:Hsla) {
        this.error = error != null ? error : new Hsla();
        this.warning = warning != null ? warning : new Hsla();
        this.info = info != null ? info : new Hsla();
        this.hint = hint != null ? hint : new Hsla();
    }

    public inline function copy():DiagnosticColors {
        return new DiagnosticColors(error, warning, info, hint);
    }

}
