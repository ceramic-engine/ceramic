package ceramic;

// Some ideas and snippets directly extracted from:
// https://github.com/deepnight/ld48-NuclearBlaze/blob/master/src/game/gm/Camera.hx

/**
 * A flexible camera system for 2D games.
 *
 * Camera provides smooth scrolling, target following, boundary constraints,
 * and various effects for controlling the viewport in your game world.
 *
 * Features:
 * - Smooth target following with configurable speed and curves
 * - Dead zones to reduce camera movement for small target changes
 * - Content boundary clamping to keep camera within level bounds
 * - Zoom support
 * - Friction and braking near boundaries
 * - Anchor points for different camera behaviors
 *
 * The camera doesn't render anything itself - instead, you apply its
 * transform to your game visuals to create the scrolling effect.
 *
 * ```haxe
 * // Create a camera following the player
 * var camera = new Camera(screen.width, screen.height);
 * camera.followTarget = true;
 * camera.trackSpeedX = 15;
 * camera.trackSpeedY = 10;
 *
 * // In update loop
 * camera.target(player.x, player.y);
 * camera.update(delta);
 *
 * // Apply transform to layer
 * gameLayer.transform = camera.contentTransform;
 * ```
 *
 * @see Visual
 */
class Camera extends Entity {

    /**
     * Camera x position in world coordinates.
     * This is the left edge of what the camera sees.
     */
    public var x:Float = 0;

    /**
     * Camera y position in world coordinates.
     * This is the top edge of what the camera sees.
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
     * When true, the camera smoothly follows the target position.
     * Use target() or targetX/targetY to set what to follow.
     */
    public var followTarget:Bool = false;

    /**
     * If true, camera will try to stay inside content bounds.
     * When the viewport is larger than content, camera will be centered.
     * Useful for keeping the camera within level boundaries.
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
     * Affects the smoothness of camera tracking.
     * Lower values (0.1-0.5) create more easing/lag.
     * Higher values (0.8-1.0) create more direct following.
     * Must be between 0 (exclusive) and 1 (inclusive).
     */
    public var trackCurve:Float = 0.8;

    /**
     * Camera zoom level.
     * 1.0 = normal size
     * 2.0 = zoomed in 2x (objects appear larger)
     * 0.5 = zoomed out (objects appear smaller)
     */
    public var zoom:Float = 1.0;

    /**
     * Horizontal dead zone as percentage of viewport width (0-1).
     * Camera won't move until target moves outside this zone.
     * Reduces camera jitter from small movements.
     */
    public var deadZoneX:Float = 0.04;

    /**
     * Vertical dead zone as percentage of viewport height (0-1).
     * Camera won't move until target moves outside this zone.
     * Reduces camera jitter from small movements.
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
     * Viewport width: the visible area width for this camera.
     * Usually set to screen width or render area width.
     */
    public var viewportWidth:Float = 0;

    /**
     * Viewport height: the visible area height for this camera.
     * Usually set to screen height or render area height.
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

    final averageFrameTime:Float = 1.0 / 60;

    public function new() {

        super();

    }

    function internalUpdate(delta:Float):Void {

        if (contentWidth <= 0 || contentHeight <= 0) {
            return;
        }

        var invertedZoom = 1.0 / zoom;

        var speedX = delta * trackSpeedX * zoom;
        var speedY = delta * trackSpeedY * zoom;

        var dx:Float = 0;
        var dy:Float = 0;

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

    }

    public function update(delta:Float):Void {

        internalUpdate(delta);

        updateContentTransform();

    }

    public function stabilize(maxUpdates:Int = 128, delta:Float = 0.1, thresholdX:Float = 0.01, thresholdY:Float = 0.01) {

        for (_ in 0...maxUpdates) {

            var prevX = x;
            var prevY = y;

            internalUpdate(delta);

            if (Math.abs(x - prevX) < thresholdX && Math.abs(y - prevY) < thresholdY) {
                break;
            }
        }

        updateContentTransform();

    }

    public function updateContentTransform() {

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
