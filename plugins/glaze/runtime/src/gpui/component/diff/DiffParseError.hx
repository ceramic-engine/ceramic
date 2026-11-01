// Ported from gpui-kit 0.8.1: crates/component/src/diff/parser.rs (`DiffParseError`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * A malformed or unsupported unified diff, with its one-based patch line.
 * Thrown by `DiffFile.parse` (Rust returns it in a `Result`).
 */
class DiffParseError {

    final _line:Int;

    final _message:String;

    @:allow(gpui.component.diff)
    function new(line:Int, message:String) {
        _line = line;
        _message = message;
    }

    public function line():Int {
        return _line;
    }

    public function message():String {
        return _message;
    }

    public function toString():String {
        return 'patch line $_line: $_message';
    }

}
