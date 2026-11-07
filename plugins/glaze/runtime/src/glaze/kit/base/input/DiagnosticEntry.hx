// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * A diagnostic with its byte range in the rope. Rust derefs to the
 * `Diagnostic`: `message`, `severity` and `diagnosticRange` forward to it.
 */
class DiagnosticEntry {

    /** The byte range of the diagnostic in the rope. */
    public final range:Range;

    public final diagnostic:Diagnostic;

    public inline function new(range:Range, diagnostic:Diagnostic) {
        this.range = range;
        this.diagnostic = diagnostic;
    }

    public var message(get, never):String;

    inline function get_message():String {
        return diagnostic.message;
    }

    public var severity(get, never):DiagnosticSeverity;

    inline function get_severity():DiagnosticSeverity {
        return diagnostic.severity;
    }

}
