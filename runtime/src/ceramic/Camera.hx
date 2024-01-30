package ceramic;

// Some ideas and snippets directly extracted from:
// https://github.com/deepnight/ld48-NuclearBlaze/blob/master/src/game/gm/Camera.hx

class Camera extends Entity {

    /**
     * Camera x position
     */
    public var x:Float = 0;

    /**
     * Camera y position
     */
    public var y:Float = 0;

    /**
     * Set camera x & y position
     * @param x
     * @param y
     */
    inline public function pos(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
    }

    /**
     * `true` if the camera should follow its target
     */
    public var followTarget:Bool = false;

    /**
     * If `true`, camera will try to stay inside content bounds. If not possible, it will be centered.
     */
    public var clampToContentBounds:Bool = true;

    /**
     * Percentage of viewport width where camera will "brake" to stay inside content bounds
     */
    public var brakeNearBoundsX:Float = 0.02;

    /**
     * Percentage of viewport height where camera will "brake" to stay inside content bounds
     */
    public var brakeNearBoundsY:Float = 0.03;

    /**
     * Set `brakeNearBoundsX`& `brakeNearBoundsY`
     * @param brakeNearBoundsX
     * @param brakeNearBoundsY
     */
    inline public function brakeNearBounds(brakeNearBoundsX:Float, brakeNearBoundsY:Float):Void {
        this.brakeNearBoundsX = brakeNearBoundsX;
        this.brakeNearBoundsY = brakeNearBoundsY;
    }

    /**
     * Target x position
     */
    public var targetX:Float = 0;

    /**
     * Target y position
     */
    public var targetY:Float = 0;

    /**
     * Set `targetX` & `targetY`, which define the position the camera may follow if `followTarget` is `true`
     * @param targetX
     * @param targetY
     */
    inline public function target(targetX:Float, targetY:Float):Void {
        this.targetX = targetX;
        this.targetY = targetY;
    }

    /**
     * Tracking x speed factor
     */
    public var trackSpeedX:Float = 20.0;

    /**
     * Tracking y speed factor
     */
    public var trackSpeedY:Float = 15.0;

    /**
     * Affects tracking curve. Should be above 0 and below or equal to 1.
     */
    public var trackCurve:Float = 0.8;

    /**
     * Zoom scaling factor
     */
    public var zoom:Float = 1.0;

    /**
     * Horizontal dead zone (percentage between 0 and 1 relative to viewport width)
     */
    public var deadZoneX:Float = 0.04;

    /**
     * Horizontal dead zone (percentage between 0 and 1 relative to viewport height)
     */
    public var deadZoneY:Float = 0.1;

    /**
     * Horizontal friction.
     * More the value is below 1.0, higher is the friction.
     */
    public var frictionX:Float = 1.0;

    /**
     * Vertical friction.
     * More the value is below 1.0, higher is the friction.
     */
    public var frictionY:Float = 1.0;

    /**
     * Content x (top left corner) position
     */
    public var contentX:Float = 0;

    /**
     * Content y (top left corner) position
     */
    public var contentY:Float = 0;

    /**
     * Content width
     */
    public var contentWidth:Float = 0;

    /**
     * Content height
     */
    public var contentHeight:Float = 0;

    /**
     * Viewport width: the actual visible with on this camera
     */
    public var viewportWidth:Float = 0;

    /**
     * Viewport height: the actual visible height on this camera
     */
    public var viewportHeight:Float = 0;

    /**
     * A threshold value to stop the camera if its movement is lower than this value
     */
    public var movementThreshold:Float = 0.00001;

    /**
     * Translation X that should be applied to the
     * content so that the camera is pointing to the correct area.
     * This value is computed by the camera when it is updated.
     */
    public var contentTranslateX:Float = 0.0;

    /**
     * Translation Y that should be applied to the
     * content so that the camera is pointing to the correct area
     * This value is computed by the camera when it is updated.
     */
    public var contentTranslateY:Float = 0.0;

    /**
     * The transform to apply to the content
     * in order to reflect camera position.
     */
    public var contentTransform:Transform = new Transform();

    var hasPrevTransform:Bool = false;

    var dx:Float = 0;

    var dy:Float = 0;

    final averageFrameTime:Float = 1.0 / 60;

    public function new() {

        super();

    }

    public function update(delta:Float):Void {

        if (contentWidth <= 0 || contentHeight <= 0) {
            return;
        }

        var invertedZoom = 1.0 / zoom;

        var speedX = delta * trackSpeedX * zoom;
        var speedY = delta * trackSpeedY * zoom;

        // Follow target (if any)
        if (followTarget) {
            var angle = angleTo(x, y, targetX, targetY);
            var distanceX = Math.abs(targetX - x);
            if (distanceX >= deadZoneX * viewportWidth * invertedZoom) {
                dx += Math.cos(angle) * (trackCurve * (distanceX - deadZoneX * viewportWidth * invertedZoom)) * speedX;
                if (dx > distanceX)
                    dx = distanceX;
            }
            var distanceY = Math.abs(targetY - y);
            if (distanceY >= deadZoneY * viewportHeight * invertedZoom) {
                dy += Math.sin(angle) * (trackCurve * (distanceY - deadZoneY * viewportHeight * invertedZoom)) * speedY;
                if (dy > distanceY)
                    dy = distanceY;
            }
        }

        var frictionX:Float = this.frictionX;
        var frictionY:Float = this.frictionY;
        if (clampToContentBounds) {

            // "brake" when approaching bounds

            var brakeDistanceX = brakeNearBoundsX * viewportWidth * invertedZoom;
            if (dx < 0) {
                var brakeRatio = (x - viewportWidth * invertedZoom * 0.5) / brakeDistanceX;
                if (brakeRatio < 0)
                    brakeRatio = 0;
                if (brakeRatio > 1)
                    brakeRatio = 1;
                frictionX *= brakeRatio;
            }
            else if (dx > 0) {
                var brakeRatio = ((contentWidth - viewportWidth * invertedZoom * 0.5) - x) / brakeDistanceX;
                if (brakeRatio < 0)
                    brakeRatio = 0;
                if (brakeRatio > 1)
                    brakeRatio = 1;
                frictionX *= brakeRatio;
            }
            var brakeDistanceY = brakeNearBoundsY * viewportHeight * invertedZoom;
            if (dy < 0) {
                var brakeRatio = (y - viewportHeight * invertedZoom * 0.5) / brakeDistanceY;
                if (brakeRatio < 0)
                    brakeRatio = 0;
                if (brakeRatio > 1)
                    brakeRatio = 1;
                frictionY *= brakeRatio;
            }
            else if (dy > 0) {
                var brakeRatio = ((contentHeight - viewportHeight * invertedZoom * 0.5) - y) / brakeDistanceY;
                if (brakeRatio < 0)
                    brakeRatio = 0;
                if (brakeRatio > 1)
                    brakeRatio = 1;
                frictionY *= brakeRatio;
            }
        }

        dx *= frictionX;
        dy *= frictionY;

        if (dx > movementThreshold || dx < -movementThreshold)
            x += dx;
        if (dy > movementThreshold || dy < -movementThreshold)
            y += dy;

        dx = 0;
        dy = 0;

        if (clampToContentBounds) {

            if (contentWidth < viewportWidth * invertedZoom) {
                x = contentWidth * 0.5;
            }
            else if (x < viewportWidth * invertedZoom * 0.5) {
                x = viewportWidth * invertedZoom * 0.5;
            }
            else if (x > contentWidth - viewportWidth * invertedZoom * 0.5) {
                x = contentWidth - viewportWidth * invertedZoom * 0.5;
            }

            if (contentHeight < viewportHeight * invertedZoom) {
                y = contentHeight * 0.5;
            }
            else if (y < viewportHeight * invertedZoom * 0.5) {
                y = viewportHeight * invertedZoom * 0.5;
            }
            else if (y > contentHeight - viewportHeight * invertedZoom * 0.5) {
                y = contentHeight - viewportHeight * invertedZoom * 0.5;
            }
        }

        contentTranslateX = (contentX - x) + viewportWidth * 0.5;
        contentTranslateY = (contentY - y) + viewportHeight * 0.5;

        contentTransform.identity();
        contentTransform.translate(contentTranslateX, contentTranslateY);
        contentTransform.translate(-viewportWidth * 0.5, -viewportHeight * 0.5);
        contentTransform.scale(zoom, zoom);
        contentTransform.translate(viewportWidth * 0.5, viewportHeight * 0.5);

    }

/// Internal

    inline static function angleTo(x0:Float, y0:Float, x1:Float, y1:Float):Float {

        return Math.atan2(y1 - y0, x1 - x0);

    }

}
