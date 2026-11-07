// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/definitions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Range;

/**
 * The definitions of the symbol under a Cmd-hover.
 */
class HoverDefinition {

    /** The range of the symbol that triggered the hover. */
    public var symbolRange(default, null):Range = new Range(0, 0);

    public var locations(default, null):Array<LspLocationLink> = [];

    public function new() {}

    public function update(symbolRange:Range, locations:Array<LspLocationLink>):Void {
        clear();
        this.symbolRange = symbolRange;
        this.locations = locations;
    }

    public inline function isEmpty():Bool {
        return locations.length == 0;
    }

    public function clear():Void {
        symbolRange = new Range(0, 0);
        locations = [];
    }

    public inline function isSame(offset:Int):Bool {
        return symbolRange.contains(offset);
    }

}
