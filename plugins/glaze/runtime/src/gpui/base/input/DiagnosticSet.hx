// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/diagnostics.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;
import ropey.Rope;

using gpui.base.input.RopeExt;

/**
 * The diagnostics of an editor, with their byte ranges in its text.
 *
 * Rust keeps them in a `SumTree` whose summary is the range of the last
 * entry, and seeks it by byte offset. The port keeps an array in insertion
 * order: a seek stops on the first entry whose range ends at or after the
 * offset, which is where the tree cursor stops when the entries are pushed
 * in document order (the way every caller pushes them).
 */
class DiagnosticSet {

    var text:Rope;

    var diagnostics:Array<DiagnosticEntry>;

    public function new(text:Rope) {
        this.text = text.clone();
        this.diagnostics = [];
    }

    public function clone():DiagnosticSet {
        final result = new DiagnosticSet(text);
        result.diagnostics = diagnostics.copy();
        return result;
    }

    public function reset(text:Rope):Void {
        this.text = text.clone();
        clear();
    }

    public function push(diagnostic:Diagnostic):Void {
        final start = text.positionToOffset(diagnostic.range.start);
        final end = text.positionToOffset(diagnostic.range.end);

        diagnostics.push(new DiagnosticEntry(new Range(start, end), diagnostic));
    }

    public function extend(diagnostics:Iterable<Diagnostic>):Void {
        for (diagnostic in diagnostics)
            push(diagnostic);
    }

    public inline function len():Int {
        return diagnostics.length;
    }

    public function clear():Void {
        diagnostics = [];
    }

    public inline function isEmpty():Bool {
        return diagnostics.length == 0;
    }

    /** The entries starting before `range.end`, from the first one ending at or after `range.start`. */
    public function range(range:Range):Array<DiagnosticEntry> {
        final result:Array<DiagnosticEntry> = [];
        var i = 0;
        // cursor.seek(&range.start, Bias::Left)
        while (i < diagnostics.length && range.start > diagnostics[i].range.end)
            i++;
        while (i < diagnostics.length && diagnostics[i].range.start < range.end) {
            result.push(diagnostics[i]);
            i++;
        }
        return result;
    }

    public function forOffset(offset:Int):Null<DiagnosticEntry> {
        final entries = range(new Range(offset, offset + 1));
        return entries.length > 0 ? entries[0] : null;
    }

    public inline function iter():Array<DiagnosticEntry> {
        return diagnostics;
    }

}
