// Ported from lsp-types 0.97 (src/lib.rs, DiagnosticRelatedInformation), as used by gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Represents a related message and source code location for a diagnostic.
 * gpui-kit also names it `RelatedInformation`.
 */
class DiagnosticRelatedInformation {

    /** The location of this related diagnostic information. */
    public final location:LspLocation;

    /** The message of this related diagnostic information. */
    public final message:String;

    public inline function new(location:LspLocation, message:String) {
        this.location = location;
        this.message = message;
    }

    public function equals(other:Null<DiagnosticRelatedInformation>):Bool {
        return other != null && message == other.message && location.equals(other.location);
    }

}
