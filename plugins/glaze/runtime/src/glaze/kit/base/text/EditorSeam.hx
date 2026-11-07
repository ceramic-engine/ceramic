// Ported from gpui-kit 0.8.1: crates/base/src/text/editor_seam.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Bounds;
import glaze.Hsla;
import glaze.Range;
import glaze.TextLayout;

/**
 * Crate-private plumbing behind `EditorHost`.
 *
 * A text leaf whose `InlineState` carries an `editorKey` reports its
 * laid-out `TextLayout` to the sink installed for the duration of
 * `EditorHost.collectLeafGeometry`, and takes extra range backgrounds (the
 * host's selection and decorations) from it. `TextView` never sets a key or
 * installs a sink, so read-only rendering is unchanged.
 *
 * The sink is frame-local: it is written during prepaint and read by the host
 * afterwards; nothing here reaches back into an entity.
 */
class EditorSeam {

    /** Rust's thread-local `SINK` (the port is single threaded). */
    static var sink:Null<EditorSink> = null;

    /** Run `f` with `sink` installed; restores the previous sink afterwards, also when `f` throws. */
    public static function withSink<R>(sink:EditorSink, f:() -> R):R {
        final previous = EditorSeam.sink;
        EditorSeam.sink = sink;
        try {
            final result = f();
            EditorSeam.sink = previous;
            return result;
        }
        catch (e:Dynamic) {
            EditorSeam.sink = previous;
            throw glaze.util.Exceptions.rethrow(e);
        }
    }

    public static inline function current():Null<EditorSink> {
        return sink;
    }

}

/** Rust `EditorSink`. */
interface EditorSink {
    /** The leaf `key` was laid out this frame as one `TextLayout`. */
    function report(key:Int, layout:TextLayout):Void;
    /**
     * The leaf `key` is laid out in pieces this frame (a mixed text / image /
     * custom-inline paragraph rendered by `InlineFlow`); drops pieces reported
     * for it earlier in the frame.
     */
    function beginPieces(key:Int):Void;
    /** One single-line text fragment of `key`, whose index 0 is the leaf's byte `start`. */
    function reportTextPiece(key:Int, start:Int, layout:TextLayout):Void;
    /** An inline atom (image, custom node) of `key` covering the leaf bytes `range`, drawn in `bounds`. */
    function reportBoxPiece(key:Int, range:Range, bounds:Bounds):Void;
    /** A line with no fragment (e.g. after a trailing hard break). */
    function reportEmptyPiece(key:Int, start:Int, bounds:Bounds):Void;
    /** Extra backgrounds to paint behind the leaf `key`, in its text's bytes. */
    function backgrounds(key:Int):Array<RangedColor>;
}
