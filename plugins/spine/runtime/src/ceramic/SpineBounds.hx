package ceramic;

class SpineBounds {

    public var anchorX:Float = 0;

    public var anchorY:Float = 0;

    public var width:Float = 0;

    public var height:Float = 0;

    public function new() {}

    public static function computeAndExtractBounds(spine:Spine, ?bounds:SpineBounds):SpineBounds {

        if (bounds == null)
            bounds = new SpineBounds();

        // Maybe we should find another solution that doesn't mutate spine object
        var prevSkeletonOriginX = spine.skeletonOriginX;
        var prevSkeletonOriginY = spine.skeletonOriginY;
        var prevWidth = spine.width;
        var prevHeight = spine.height;
        var prevAnchorX = spine.anchorX;
        var prevAnchorY = spine.anchorY;
        var prevX = spine.x;
        var prevY = spine.y;
        @:privateAccess spine.computeBounds();
        bounds.anchorX = spine.anchorX;
        bounds.anchorY = spine.anchorY;
        bounds.width = spine.width;
        bounds.height = spine.height;
        spine.skeletonOriginX = prevSkeletonOriginX;
        spine.skeletonOriginY = prevSkeletonOriginY;
        spine.width = prevWidth;
        spine.height = prevHeight;
        spine.anchorX = prevAnchorX;
        spine.anchorY = prevAnchorY;
        spine.x = prevX;
        spine.y = prevY;

        return bounds;

    }

}
