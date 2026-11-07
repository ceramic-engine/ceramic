// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Identifies a reference point on a 2D box, used to anchor positioned elements.
 */
enum abstract Anchor(Int) {

    /**
     * The top left corner.
     */
    var TopLeft = 0;

    /**
     * The top right corner.
     */
    var TopRight = 1;

    /**
     * The bottom left corner.
     */
    var BottomLeft = 2;

    /**
     * The bottom right corner.
     */
    var BottomRight = 3;

    /**
     * The top center position.
     */
    var TopCenter = 4;

    /**
     * The bottom center position.
     */
    var BottomCenter = 5;

    /**
     * The left center position.
     */
    var LeftCenter = 6;

    /**
     * The right center position.
     */
    var RightCenter = 7;

    /**
     * Returns the directly opposite anchor.
     */
    public function opposite():Anchor {

        return switch (cast this:Anchor) {
            case TopLeft: BottomRight;
            case TopRight: BottomLeft;
            case BottomLeft: TopRight;
            case BottomRight: TopLeft;
            case TopCenter: BottomCenter;
            case BottomCenter: TopCenter;
            case LeftCenter: RightCenter;
            case RightCenter: LeftCenter;
        }

    }

    /**
     * Returns the anchor across from this one, moving along the specified axis.
     */
    public function otherSideAlong(axis:Axis):Anchor {

        return switch axis {
            case Vertical: switch (cast this:Anchor) {
                case TopLeft: BottomLeft;
                case TopRight: BottomRight;
                case BottomLeft: TopLeft;
                case BottomRight: TopRight;
                case TopCenter: BottomCenter;
                case BottomCenter: TopCenter;
                case LeftCenter: LeftCenter;
                case RightCenter: RightCenter;
            }
            case Horizontal: switch (cast this:Anchor) {
                case TopLeft: TopRight;
                case TopRight: TopLeft;
                case BottomLeft: BottomRight;
                case BottomRight: BottomLeft;
                case TopCenter: TopCenter;
                case BottomCenter: BottomCenter;
                case LeftCenter: RightCenter;
                case RightCenter: LeftCenter;
            }
        }

    }

    /**
     * Returns whether the anchor is center-positioned.
     */
    public inline function isCenter():Bool {

        return this >= 4;

    }

    /**
     * Returns whether the anchor is bottom-positioned.
     */
    public inline function isBottom():Bool {

        final self:Anchor = cast this;
        return self == BottomCenter || self == BottomLeft || self == BottomRight;

    }

    public function toString():String {

        return switch (cast this:Anchor) {
            case TopLeft: 'TopLeft';
            case TopRight: 'TopRight';
            case BottomLeft: 'BottomLeft';
            case BottomRight: 'BottomRight';
            case TopCenter: 'TopCenter';
            case BottomCenter: 'BottomCenter';
            case LeftCenter: 'LeftCenter';
            case RightCenter: 'RightCenter';
        }

    }

}
