// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`DiffLinePosition`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * A one-based source line, independent of the visual layout.
 *
 * The file is identified by its `DiffFile.path`, which stays stable when a
 * newer revision of the patch reorders its files.
 */
class DiffLinePosition {

    final _path:String;

    final _side:DiffSide;

    final _line:Int;

    /** Creates a position, clamping the line to at least one. */
    public function new(path:String, side:DiffSide, line:Int) {
        _path = path;
        _side = side;
        _line = line < 1 ? 1 : line;
    }

    /** The `DiffFile.path` of the file. */
    public inline function path():String {
        return _path;
    }

    public inline function side():DiffSide {
        return _side;
    }

    public inline function line():Int {
        return _line;
    }

    public function equals(other:Null<DiffLinePosition>):Bool {
        return other != null && other._path == _path && other._side == _side && other._line == _line;
    }

    /** A string identifying the position, for maps (Rust `Hash`). */
    public function key():String {
        return (_side == Original ? 'o' : 'm') + _line + ':' + _path;
    }

    public function toString():String {
        return 'DiffLinePosition { path: "$_path", side: $_side, line: $_line }';
    }

}
