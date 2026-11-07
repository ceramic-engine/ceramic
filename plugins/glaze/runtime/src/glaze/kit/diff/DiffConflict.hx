// Ported from gpui-kit 0.8.1: crates/component/src/diff/conflict.rs (`DiffConflict`, `DiffConflictResolution`, `ConflictPart`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

import glaze.Range;

/**
 * A parsed merge conflict in a working file.
 *
 * Source coordinates are one-based, half-open ranges, allowing empty parts.
 * Returned by `DiffFile.conflicts` in source order; its index is the index
 * accepted by `DiffState.resolveConflict`. Fields are private and only the
 * parser constructs these snapshots.
 */
@:allow(glaze.kit.diff)
class DiffConflict {

    var _lines:Range;
    var _currentLines:Range;
    var _baseLines:Null<Range>;
    var _incomingLines:Range;
    var current:Range;
    var base:Null<Range>;
    var incoming:Range;
    var _currentLabel:String;
    var _baseLabel:String;
    var _incomingLabel:String;

    function new() {}

    /** One-based working-file lines, including markers, with an exclusive end. */
    public function lines():Range {
        return _lines;
    }

    /** Current-side source lines, with an exclusive end; may be empty. */
    public function currentLines():Range {
        return _currentLines;
    }

    /** Base source lines for diff3, with an exclusive end; may be empty. */
    public function baseLines():Null<Range> {
        return _baseLines;
    }

    /** Incoming-side source lines, with an exclusive end; may be empty. */
    public function incomingLines():Range {
        return _incomingLines;
    }

    /** The label from the opening marker. */
    public function currentLabel():String {
        return _currentLabel;
    }

    /** The base marker label, or null for a two-way conflict. */
    public function baseLabel():Null<String> {
        return base != null ? _baseLabel : null;
    }

    /** The label from the closing marker. */
    public function incomingLabel():String {
        return _incomingLabel;
    }

    /** Every line of the region, in file order. */
    function sourceLines():Range {
        return new Range(current.start, incoming.end);
    }

    function part(part:ConflictPart):Null<Range> {
        return switch (part) {
            case Current: current;
            case Base: base;
            case Incoming: incoming;
        }
    }

    function label(part:ConflictPart):String {
        return switch (part) {
            case Current: _currentLabel;
            case Base: _baseLabel;
            case Incoming: _incomingLabel;
        }
    }

    /** The part a line of the region belongs to. */
    function partOf(ix:Int):Null<ConflictPart> {
        for (p in [ConflictPart.Current, ConflictPart.Base, ConflictPart.Incoming]) {
            final range = part(p);
            if (range != null && range.contains(ix))
                return p;
        }
        return null;
    }

    /** The lines a resolution keeps. */
    function kept(resolution:DiffConflictResolution):Array<Range> {
        return switch (resolution) {
            case Current: [current];
            case Incoming: [incoming];
            case Both: [current, incoming];
        }
    }

}
