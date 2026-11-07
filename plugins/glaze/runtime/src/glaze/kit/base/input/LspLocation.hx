// Ported from lsp-types 0.97 (src/lib.rs, Location), as used by gpui-kit 0.8.1: crates/base/src/input/editor
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Represents a location inside a resource, such as a line inside a text file
 * (lsp_types `Location`; the `Uri` is kept as a string).
 */
class LspLocation {

    public final uri:String;

    public final range:LspRange;

    public inline function new(uri:String, range:LspRange) {
        this.uri = uri;
        this.range = range;
    }

    public function equals(other:Null<LspLocation>):Bool {
        return other != null && uri == other.uri && range.equals(other.range);
    }

}
