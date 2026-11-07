// Ported from lsp-types 0.97 (src/lib.rs, Position), as re-exported by gpui-kit 0.8.1: crates/base/src/input/mod.rs
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A position in a text document: zero-based line and character offset
 * (lsp_types `Position`, renamed: it clashes with `glaze.Position`).
 *
 * The input engine measures `character` in characters (see
 * `RopeExt.positionToOffset`).
 */
class LspPosition {

    public final line:Int;

    public final character:Int;

    public inline function new(line:Int, character:Int) {
        this.line = line;
        this.character = character;
    }

    public function equals(other:Null<LspPosition>):Bool {
        return other != null && other.line == line && other.character == character;
    }

    public function toString():String {
        return 'Position { line: ' + line + ', character: ' + character + ' }';
    }

}
