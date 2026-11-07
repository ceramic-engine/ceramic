// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

/**
 * Why setting range highlights or revealing a range was rejected. Existing
 * highlights and reveals stay unchanged.
 */
enum RangeHighlightError {
    /** The view renders HTML, which records no source positions to address its text by. */
    Unsupported;
    /**
     * The range at this index, the highlight's or the one revealed, is
     * reversed, out of bounds, or not on a character boundary.
     */
    InvalidRange(index:Int);
}

class RangeHighlightErrorTools {

    /** Rust `Display`. */
    public static function toString(error:RangeHighlightError):String {
        return switch error {
            case Unsupported: 'HTML views do not support ranges of their text';
            case InvalidRange(ix): 'range $ix is not a range of the text';
        }
    }

}

/** Thrown by the setters that return `Result<(), RangeHighlightError>` in Rust. */
class RangeHighlightException extends haxe.Exception {

    public final error:RangeHighlightError;

    public function new(error:RangeHighlightError) {
        super(RangeHighlightErrorTools.toString(error));
        this.error = error;
    }

}
