// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`DiffAnnotation`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

import gpui.ElementId;

/**
 * Application-owned content attached to a source line or to a whole file.
 *
 * The stable ID belongs to the annotation itself, while the target uses the
 * file path and, for a line, its side and one-based source line, independent
 * of folding.
 */
class DiffAnnotation {

    final _id:ElementId;

    final _path:String;

    final _position:Null<DiffLinePosition>;

    function new(id:ElementId, path:String, position:Null<DiffLinePosition>) {
        _id = id;
        _path = path;
        _position = position;
    }

    /** Attaches content beneath a source line. */
    public static function line(id:ElementId, position:DiffLinePosition):DiffAnnotation {
        return new DiffAnnotation(id, position.path(), position);
    }

    /** Attaches content beneath the header of the file at `path`. */
    public static function file(id:ElementId, path:String):DiffAnnotation {
        return new DiffAnnotation(id, path, null);
    }

    public function id():ElementId {
        return _id;
    }

    /** The `DiffFile.path` of the annotated file. */
    public function path():String {
        return _path;
    }

    /** The annotated line, or null for a file annotation. */
    public function position():Null<DiffLinePosition> {
        return _position;
    }

}
