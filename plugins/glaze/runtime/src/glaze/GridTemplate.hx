// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A simplified representation of the grid-template-* value.
 *
 * Port addition without GPUI equivalent: a template may instead list its
 * tracks (`ofTracks`, `gridTemplateCols([...])`), each with its own size.
 */
class GridTemplate {

    /** How this template directive should be repeated */
    public final repeat:Int;

    /** The minimum size in the repeat(<>, minmax(_, 1fr)) equation */
    public final minSize:GridTemplateMinSize;

    /**
     * The tracks of an explicit template (port addition), `null` for GPUI's
     * `repeat(<repeat>, minmax(<minSize>, 1fr))`. When set, `repeat` is the
     * number of tracks and `minSize` is not used.
     */
    public final tracks:Null<Array<GridTrack>>;

    public inline function new(repeat:Int, minSize:GridTemplateMinSize = Zero, ?tracks:Array<GridTrack>) {
        this.repeat = repeat;
        this.minSize = minSize;
        this.tracks = tracks;
    }

    /**
     * A template made of the given tracks, in order (CSS
     * `grid-template-columns: 140px 1fr`). The array is kept: do not change
     * it afterwards.
     */
    public static function ofTracks(tracks:Array<GridTrack>):GridTemplate {
        return new GridTemplate(tracks.length, Zero, tracks);
    }

    public function equals(other:GridTemplate):Bool {
        if (other == null || repeat != other.repeat || minSize != other.minSize)
            return false;
        final a = tracks;
        final b = other.tracks;
        if (a == null || b == null)
            return a == b;
        if (a == b)
            return true;
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

}
