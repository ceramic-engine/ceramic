// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The severity of a diagnostic (`Hint` by default).
 */
enum abstract DiagnosticSeverity(Int) {

    var Hint = 0;

    var Error = 1;

    var Warning = 2;

    var Info = 3;

    public static inline function defaultValue():DiagnosticSeverity {
        return Hint;
    }

    /**
     * Rust `From<lsp_types::DiagnosticSeverity>`: 1 error, 2 warning,
     * 3 information, 4 hint, anything else info.
     */
    public static function fromLsp(value:Int):DiagnosticSeverity {
        return switch value {
            case 1: Error;
            case 2: Warning;
            case 3: Info;
            case 4: Hint;
            case _: Info; // Default to Info if unknown
        }
    }

    public function toString():String {
        return switch (cast this:DiagnosticSeverity) {
            case Hint: 'Hint';
            case Error: 'Error';
            case Warning: 'Warning';
            case Info: 'Info';
        }
    }

}
