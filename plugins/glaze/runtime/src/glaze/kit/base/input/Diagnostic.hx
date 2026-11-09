// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A diagnostic (the data of gpui-kit's `Diagnostic`, as the inspector's
 * `rustToStyle` reports its errors). gpui-kit's code editor, which paints
 * them, is not part of Glaze: Cityscape shows diagnostics as markers.
 *
 * Build diagnostics with `new` and the `with*` builders.
 */
class Diagnostic {

    /**
     * The range at which the message applies.
     *
     * This is the column, character range within a single line.
     */
    public var range:LspRange;

    /**
     * The diagnostic's severity. Can be omitted. If omitted it is up to the
     * client to interpret diagnostics as error, warning, info or hint.
     */
    public var severity:DiagnosticSeverity;

    /** The diagnostic's code. Can be omitted. */
    public var code:Null<String>;

    /** The `href` of lsp_types `CodeDescription` */
    public var codeDescription:Null<String>;

    /**
     * A human-readable string describing the source of this
     * diagnostic, e.g. 'typescript' or 'super lint'.
     */
    public var source:Null<String>;

    /** The diagnostic's message. */
    public var message:String;

    /**
     * A data entry field that is preserved between a `textDocument/publishDiagnostics`
     * notification and `textDocument/codeAction` request (a JSON value).
     */
    public var data:Null<Dynamic>;

    public function new(start:LspPosition, end:LspPosition, message:String) {
        this.range = new LspRange(start, end);
        this.severity = DiagnosticSeverity.defaultValue();
        this.message = message;
    }

    public function withSeverity(severity:DiagnosticSeverity):Diagnostic {
        this.severity = severity;
        return this;
    }

    public function withCode(code:String):Diagnostic {
        this.code = code;
        return this;
    }

    public function withSource(source:String):Diagnostic {
        this.source = source;
        return this;
    }

}
