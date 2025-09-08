package ceramic;

#if plugin_ui
import ceramic.View;
#end

using ceramic.Extensions;

/**
 * A component that enables smooth property transitions for Visual objects.
 * 
 * VisualTransition provides a declarative API for animating multiple visual
 * properties simultaneously with automatic interpolation and easing. It handles
 * the complexity of managing multiple concurrent tweens while providing a clean,
 * chainable interface.
 * 
 * Key features:
 * - Animate multiple properties in a single transition
 * - Automatic handling of transform interpolation
 * - Smart rotation with shortest-path calculation
 * - Property change detection to avoid unnecessary tweens
 * - Support for custom easing per transition
 * - "Eager" mode for immediate first-frame updates
 * 
 * Example usage:
 * ```haxe
 * // Using the static extension method
 * myVisual.transition(EASE_IN_OUT, 0.5, props -> {
 *     props.x = 200;
 *     props.y = 100;
 *     props.scale(2.0);
 *     props.alpha = 0.5;
 *     props.rotation = 180;
 * });
 * 
 * // Or as a component
 * var transition = new VisualTransition(ELASTIC_EASE_OUT, 0.3);
 * myVisual.component('transition', transition);
 * 
 * transition.run(null, 0.5, props -> {
 *     props.pos(100, 200);
 *     props.size(300, 200);
 * });
 * ```
 * 
 * Supported properties:
 * - Position: x, y, pos()
 * - Size: width, height, size()
 * - Scale: scaleX, scaleY, scale()
 * - Rotation: rotation (with shortest path)
 * - Transform: transform, translateX/Y, skewX/Y
 * - Appearance: alpha, color
 * - Anchor: anchorX, anchorY, anchor()
 * - Depth: depth
 * - View properties (when UI plugin is enabled)
 * 
 * @see Visual
 * @see Tween
 * @see Transform
 */
@:allow(ceramic.VisualTransitionProperties)
class VisualTransition extends Entity implements Component {

    static var _currentTransform:Transform = new Transform();

    static var _targetTransform:Transform = new Transform();

    static var _identityTransform:Transform = new Transform();

    /**
     * The Visual entity this transition component is attached to.
     * Set automatically when used as a component.
     */
    var entity:Visual;

    /**
     * Default easing function for transitions.
     * Can be overridden per transition in run() or eagerRun().
     */
    public var easing:Easing;

    /**
     * Default duration for transitions in seconds.
     * Can be overridden per transition in run() or eagerRun().
     */
    public var duration:Float;

    /**
     * Flag indicating if any property was modified in the current transition.
     * Used to determine if a tween needs to be created.
     */
    var anyPropertyChanged:Bool = false;

    /** Flag indicating if the X position was modified in the current transition. */
    var xChanged:Bool = false;
    /** Active tween responsible for animating the X position. */
    var xTween:Tween = null;
    /** Target X position value to animate towards. */
    var xTarget:Float = 0;
    /** Initial X position value when the transition began. */
    var xStart:Float = 0;
    /** Final X position value for the current tween segment. */
    var xEnd:Float = 0;

    /** Flag indicating if the Y position was modified in the current transition. */
    var yChanged:Bool = false;
    /** Active tween responsible for animating the Y position. */
    var yTween:Tween = null;
    /** Target Y position value to animate towards. */
    var yTarget:Float = 0;
    /** Initial Y position value when the transition began. */
    var yStart:Float = 0;
    /** Final Y position value for the current tween segment. */
    var yEnd:Float = 0;

    /** Flag indicating if the depth was modified in the current transition. */
    var depthChanged:Bool = false;
    /** Active tween responsible for animating the depth value. */
    var depthTween:Tween = null;
    /** Target depth value to animate towards. */
    var depthTarget:Float = 0;
    /** Initial depth value when the transition began. */
    var depthStart:Float = 0;
    /** Final depth value for the current tween segment. */
    var depthEnd:Float = 0;

    /** Flag indicating if the X scale was modified in the current transition. */
    var scaleXChanged:Bool = false;
    /** Active tween responsible for animating the X scale. */
    var scaleXTween:Tween = null;
    /** Target X scale value to animate towards. */
    var scaleXTarget:Float = 0;
    /** Initial X scale value when the transition began. */
    var scaleXStart:Float = 0;
    /** Final X scale value for the current tween segment. */
    var scaleXEnd:Float = 0;

    /** Flag indicating if the Y scale was modified in the current transition. */
    var scaleYChanged:Bool = false;
    /** Active tween responsible for animating the Y scale. */
    var scaleYTween:Tween = null;
    /** Target Y scale value to animate towards. */
    var scaleYTarget:Float = 0;
    /** Initial Y scale value when the transition began. */
    var scaleYStart:Float = 0;
    /** Final Y scale value for the current tween segment. */
    var scaleYEnd:Float = 0;

    /** Flag indicating if the X skew was modified in the current transition. */
    var skewXChanged:Bool = false;
    /** Active tween responsible for animating the X skew. */
    var skewXTween:Tween = null;
    /** Target X skew value to animate towards. */
    var skewXTarget:Float = 0;
    /** Initial X skew value when the transition began. */
    var skewXStart:Float = 0;
    /** Final X skew value for the current tween segment. */
    var skewXEnd:Float = 0;

    /** Flag indicating if the Y skew was modified in the current transition. */
    var skewYChanged:Bool = false;
    /** Active tween responsible for animating the Y skew. */
    var skewYTween:Tween = null;
    /** Target Y skew value to animate towards. */
    var skewYTarget:Float = 0;
    /** Initial Y skew value when the transition began. */
    var skewYStart:Float = 0;
    /** Final Y skew value for the current tween segment. */
    var skewYEnd:Float = 0;

    /** Flag indicating if the X anchor was modified in the current transition. */
    var anchorXChanged:Bool = false;
    /** Active tween responsible for animating the X anchor point. */
    var anchorXTween:Tween = null;
    /** Target X anchor value to animate towards. */
    var anchorXTarget:Float = 0;
    /** Initial X anchor value when the transition began. */
    var anchorXStart:Float = 0;
    /** Final X anchor value for the current tween segment. */
    var anchorXEnd:Float = 0;

    /** Flag indicating if the Y anchor was modified in the current transition. */
    var anchorYChanged:Bool = false;
    /** Active tween responsible for animating the Y anchor point. */
    var anchorYTween:Tween = null;
    /** Target Y anchor value to animate towards. */
    var anchorYTarget:Float = 0;
    /** Initial Y anchor value when the transition began. */
    var anchorYStart:Float = 0;
    /** Final Y anchor value for the current tween segment. */
    var anchorYEnd:Float = 0;

    /** Flag indicating if the rotation was modified in the current transition. */
    var rotationChanged:Bool = false;
    /** Active tween responsible for animating the rotation. */
    var rotationTween:Tween = null;
    /** Target rotation value in degrees to animate towards. */
    var rotationTarget:Float = 0;
    /** Initial rotation value in degrees when the transition began. */
    var rotationStart:Float = 0;
    /** Final rotation value in degrees for the current tween segment (adjusted for shortest path). */
    var rotationEnd:Float = 0;

    /** Flag indicating if the width was modified in the current transition. */
    var widthChanged:Bool = false;
    /** Active tween responsible for animating the width. */
    var widthTween:Tween = null;
    /** Target width value to animate towards. */
    var widthTarget:Float = 0;
    /** Initial width value when the transition began. */
    var widthStart:Float = 0;
    /** Final width value for the current tween segment. */
    var widthEnd:Float = 0;

    /** Flag indicating if the height was modified in the current transition. */
    var heightChanged:Bool = false;
    /** Active tween responsible for animating the height. */
    var heightTween:Tween = null;
    /** Target height value to animate towards. */
    var heightTarget:Float = 0;
    /** Initial height value when the transition began. */
    var heightStart:Float = 0;
    /** Final height value for the current tween segment. */
    var heightEnd:Float = 0;

    /** Flag indicating if the color was modified in the current transition. */
    var colorChanged:Bool = false;
    /** Active tween responsible for animating the color using RGB interpolation. */
    var colorTween:Tween = null;
    /** Target color value to animate towards. */
    var colorTarget:Color = Color.NONE;
    /** Initial color value when the transition began. */
    var colorStart:Color = Color.NONE;
    /** Final color value for the current tween segment. */
    var colorEnd:Color = Color.NONE;

    /** Flag indicating if the alpha was modified in the current transition. */
    var alphaChanged:Bool = false;
    /** Active tween responsible for animating the alpha (opacity). */
    var alphaTween:Tween = null;
    /** Target alpha value (0.0-1.0) to animate towards. */
    var alphaTarget:Float = 0;
    /** Initial alpha value when the transition began. */
    var alphaStart:Float = 0;
    /** Final alpha value for the current tween segment. */
    var alphaEnd:Float = 0;

    /** Flag indicating if the X translation was modified in the current transition. */
    var translateXChanged:Bool = false;
    /** Active tween responsible for animating the X translation. */
    var translateXTween:Tween = null;
    /** Target X translation value to animate towards. */
    var translateXTarget:Float = 0;
    /** Initial X translation value when the transition began. */
    var translateXStart:Float = 0;
    /** Final X translation value for the current tween segment. */
    var translateXEnd:Float = 0;

    /** Flag indicating if the Y translation was modified in the current transition. */
    var translateYChanged:Bool = false;
    /** Active tween responsible for animating the Y translation. */
    var translateYTween:Tween = null;
    /** Target Y translation value to animate towards. */
    var translateYTarget:Float = 0;
    /** Initial Y translation value when the transition began. */
    var translateYStart:Float = 0;
    /** Final Y translation value for the current tween segment. */
    var translateYEnd:Float = 0;

    /** Flag indicating if the transform was modified in the current transition. */
    var transformChanged:Bool = false;
    /** Flag indicating if a transform instance was directly assigned (vs. modified). */
    var transformAssigned:Bool = false;
    /** The transform instance that was directly assigned, if any. */
    var transformAssignedInstance:Transform = null;
    /** Active tween responsible for animating the transform using matrix interpolation. */
    var transformTween:Tween = null;
    /** Target transform matrix to animate towards. */
    var transformTarget:Transform = null;
    /** Initial transform matrix when the transition began. */
    var transformStart:Transform = null;
    /** Final transform matrix for the current tween segment. */
    var transformEnd:Transform = null;
    /** Flag indicating if the transform should be set to null at the end of the transition. */
    var transformEndToNull:Bool = false;
    /** Temporary transform instance used during the transition to avoid allocations. */
    var transformInTransition:Transform = null;

    #if plugin_ui
    /** Flag indicating if the X offset was modified in the current transition (UI plugin only). */
    var offsetXChanged:Bool = false;
    /** Active tween responsible for animating the X offset (UI plugin only). */
    var offsetXTween:Tween = null;
    /** Target X offset value to animate towards (UI plugin only). */
    var offsetXTarget:Float = 0;
    /** Initial X offset value when the transition began (UI plugin only). */
    var offsetXStart:Float = 0;
    /** Final X offset value for the current tween segment (UI plugin only). */
    var offsetXEnd:Float = 0;

    /** Flag indicating if the Y offset was modified in the current transition (UI plugin only). */
    var offsetYChanged:Bool = false;
    /** Active tween responsible for animating the Y offset (UI plugin only). */
    var offsetYTween:Tween = null;
    /** Target Y offset value to animate towards (UI plugin only). */
    var offsetYTarget:Float = 0;
    /** Initial Y offset value when the transition began (UI plugin only). */
    var offsetYStart:Float = 0;
    /** Final Y offset value for the current tween segment (UI plugin only). */
    var offsetYEnd:Float = 0;

    /** Flag indicating if the view width was modified in the current transition (UI plugin only). */
    var viewWidthChanged:Bool = false;
    /** Active tween responsible for animating the view width (UI plugin only). */
    var viewWidthTween:Tween = null;
    /** Target view width value to animate towards (UI plugin only). */
    var viewWidthTarget:Float = 0;
    /** Initial view width value when the transition began (UI plugin only). */
    var viewWidthStart:Float = 0;
    /** Final view width value for the current tween segment (UI plugin only). */
    var viewWidthEnd:Float = 0;

    /** Flag indicating if the view height was modified in the current transition (UI plugin only). */
    var viewHeightChanged:Bool = false;
    /** Active tween responsible for animating the view height (UI plugin only). */
    var viewHeightTween:Tween = null;
    /** Target view height value to animate towards (UI plugin only). */
    var viewHeightTarget:Float = 0;
    /** Initial view height value when the transition began (UI plugin only). */
    var viewHeightStart:Float = 0;
    /** Final view height value for the current tween segment (UI plugin only). */
    var viewHeightEnd:Float = 0;

    /** Flag indicating if the entity is a View (UI plugin only). Set during component binding. */
    var isView:Bool = false;
    #end

    /**
     * Create a new visual transition component.
     * 
     * @param easing Default easing function for transitions
     * @param duration Default duration in seconds (default: 0.3)
     */
    public function new(?easing:Easing, duration:Float = 0.3) {

        super();

        this.easing = easing;
        this.duration = duration;

    }

    function bindAsComponent() {

        #if plugin_ui
        isView = Std.isOfType(entity, View);
        #end

    }

/// Public API

    /**
     * Run a transition with the specified properties.
     * 
     * The callback receives a properties object where you can set
     * the target values for the transition. Only properties that
     * change from their current values will be animated.
     * 
     * @param easing Optional easing function (uses default if null)
     * @param duration Duration in seconds (uses default if -1)
     * @param cb Callback to set target property values
     * @return The tween instance, or null if no properties changed
     */
    inline public function run(?easing:Easing, duration:Float, cb:VisualTransitionProperties->Void):Null<Tween> {
        return _run(easing, duration, false, cb);
    }

    /**
     * Run an "eager" transition that updates on the first frame.
     * 
     * Same as run() but ensures the visual updates immediately
     * instead of waiting for the next frame. Useful for preventing
     * visual "pops" when starting transitions.
     * 
     * @param easing Optional easing function (uses default if null)
     * @param duration Duration in seconds (uses default if -1)
     * @param cb Callback to set target property values
     * @return The tween instance, or null if no properties changed
     */
    inline public function eagerRun(?easing:Easing, duration:Float, cb:VisualTransitionProperties->Void):Null<Tween> {
        return _run(easing, duration, true, cb);
    }

    function _run(easing:Easing, duration:Float, eager:Bool, cb:VisualTransitionProperties->Void):Null<Tween> {

        final NO_VALUE_FLOAT:Float = -999999999;

        // Compute proper transition easing and duration
        if (easing == null)
            easing = this.easing;
        if (duration == -1)
            duration = this.duration;

        // Initial "change" flag values
        anyPropertyChanged = false;
        xChanged = false;
        yChanged = false;
        depthChanged = false;
        scaleXChanged = false;
        scaleYChanged = false;
        translateXChanged = false;
        translateYChanged = false;
        skewXChanged = false;
        skewYChanged = false;
        anchorXChanged = false;
        anchorYChanged = false;
        rotationChanged = false;
        widthChanged = false;
        heightChanged = false;
        colorChanged = false;
        alphaChanged = false;
        transformAssigned = false;
        transformAssignedInstance = null;
        transformChanged = false;
        #if plugin_ui
        offsetXChanged = false;
        offsetYChanged = false;
        viewWidthChanged = false;
        viewHeightChanged = false;
        #end

        inline function copyCurrentTransform(transform) {
            _currentTransform.setToTransform(transform);
            _currentTransform.cleanChangedState();
            _currentTransform.changedDirty = false;
            return _currentTransform;
        }

        inline function copyTargetTransform(transform) {
            _targetTransform.setToTransform(transform);
            _targetTransform.cleanChangedState();
            _targetTransform.changedDirty = false;
            return _targetTransform;
        }

        #if plugin_ui
        var asView:View = isView ? cast entity : null;
        #end

        // Initial visual values
        //
        var xCurrent = entity.x;
        var yCurrent = entity.y;
        var depthCurrent = entity.depth;
        var scaleXCurrent = entity.scaleX;
        var scaleYCurrent = entity.scaleY;
        var translateXCurrent = entity.translateX;
        var translateYCurrent = entity.translateY;
        var skewXCurrent = entity.skewX;
        var skewYCurrent = entity.skewY;
        var anchorXCurrent = entity.anchorX;
        var anchorYCurrent = entity.anchorY;
        var rotationCurrent = entity.rotation;
        var widthCurrent = entity.width;
        var heightCurrent = entity.height;
        var colorCurrent = Color.NONE;
        var didRetrieveColorCurrent = false;
        if (entity.asQuad != null) {
            colorCurrent = entity.asQuad.color;
            didRetrieveColorCurrent = true;
        }
        else if (entity.asMesh != null) {
            colorCurrent = entity.asMesh.color;
            didRetrieveColorCurrent = true;
        }
        var alphaCurrent = entity.alpha;
        var transformCurrent = entity.transform != null ? copyCurrentTransform(entity.transform) : null;
        #if plugin_ui
        var offsetXCurrent = isView ? asView.offsetX : 0.0;
        var offsetYCurrent = isView ? asView.offsetY : 0.0;
        var viewWidthCurrent = isView ? asView.viewWidth : 0.0;
        var viewHeightCurrent = isView ? asView.viewHeight : 0.0;
        #end

        // Update target values with initial values
        xTarget = xCurrent;
        yTarget = yCurrent;
        depthTarget = depthCurrent;
        scaleXTarget = scaleXCurrent;
        scaleYTarget = scaleYCurrent;
        translateXTarget = translateXCurrent;
        translateYTarget = translateYCurrent;
        skewXTarget = skewXCurrent;
        skewYTarget = skewYCurrent;
        anchorXTarget = anchorXCurrent;
        anchorYTarget = anchorYCurrent;
        rotationTarget = rotationCurrent;
        widthTarget = widthCurrent;
        heightTarget = heightCurrent;
        colorTarget = colorCurrent;
        alphaTarget = alphaCurrent;
        transformTarget = transformCurrent != null ? copyTargetTransform(transformCurrent) : null;
        #if plugin_ui
        offsetXTarget = offsetXCurrent;
        offsetYTarget = offsetYCurrent;
        viewWidthTarget = viewWidthCurrent;
        viewHeightTarget = viewHeightCurrent;
        #end

        // Compute target values
        var props:VisualTransitionProperties = this;
        cb(props);

        // Check if transform was updated or not
        if (!transformChanged && transformTarget != null) {
            if (transformTarget.changedDirty)
                transformTarget.computeChanged();
            if (transformTarget.changed) {
                transformChanged = true;
                anyPropertyChanged = true;
            }
        }

        // Create tween if any value was changed
        var propsTween:Tween = null;

        if (anyPropertyChanged) {

            var tweenUpdate:(value:Float, time:Float)->Void = (value, _) -> {

                // Change values linked to this tween
                //
                if (xTween == propsTween)
                    entity.x = xStart + (xEnd - xStart) * value;
                if (yTween == propsTween)
                    entity.y = yStart + (yEnd - yStart) * value;
                if (depthTween == propsTween)
                    entity.depth = depthStart + (depthEnd - depthStart) * value;
                if (scaleXTween == propsTween)
                    entity.scaleX = scaleXStart + (scaleXEnd - scaleXStart) * value;
                if (scaleYTween == propsTween)
                    entity.scaleY = scaleYStart + (scaleYEnd - scaleYStart) * value;
                if (translateXTween == propsTween)
                    entity.translateX = translateXStart + (translateXEnd - translateXStart) * value;
                if (translateYTween == propsTween)
                    entity.translateY = translateYStart + (translateYEnd - translateYStart) * value;
                if (skewXTween == propsTween)
                    entity.skewX = skewXStart + (skewXEnd - skewXStart) * value;
                if (skewYTween == propsTween)
                    entity.skewY = skewYStart + (skewYEnd - skewYStart) * value;
                if (anchorXTween == propsTween)
                    entity.anchorX = anchorXStart + (anchorXEnd - anchorXStart) * value;
                if (anchorYTween == propsTween)
                    entity.anchorY = anchorYStart + (anchorYEnd - anchorYStart) * value;
                if (rotationTween == propsTween)
                    entity.rotation = rotationStart + (rotationEnd - rotationStart) * value;
                if (widthTween == propsTween)
                    entity.width = widthStart + (widthEnd - widthStart) * value;
                if (heightTween == propsTween)
                    entity.height = heightStart + (heightEnd - heightStart) * value;
                if (colorTween == propsTween) {
                    if (entity.asQuad != null)
                        entity.asQuad.color = Color.interpolate(colorStart, colorEnd, value);
                    else if (entity.asMesh != null)
                        entity.asMesh.color = Color.interpolate(colorStart, colorEnd, value);
                    else
                        entity.setProperty('color', Color.interpolate(colorStart, colorEnd, value));
                }
                if (alphaTween == propsTween)
                    entity.alpha = alphaStart + (alphaEnd - alphaStart) * value;
                if (transformTween == propsTween) {
                    if (value == 1 && transformAssigned) {
                        entity.transform = transformAssignedInstance;
                    }
                    else {
                        if (transformAssigned && value == 0)
                            entity.transform = null;
                        if (entity.transform == null) {
                            if (transformInTransition == null)
                                transformInTransition = TransformPool.get();
                            entity.transform = transformInTransition;
                        }
                        var interpolateTransformStart = transformStart != null ? transformStart : _identityTransform;
                        var interpolateTransformEnd = transformEnd != null ? transformEnd : _identityTransform;
                        entity.transform.setFromInterpolated(
                            interpolateTransformStart,
                            interpolateTransformEnd,
                            value
                        );
                    }
                }
                #if plugin_ui
                if (offsetXTween == propsTween)
                    asView.offsetX = offsetXStart + (offsetXEnd - offsetXStart) * value;
                if (offsetYTween == propsTween)
                    asView.offsetY = offsetYStart + (offsetYEnd - offsetYStart) * value;
                if (viewWidthTween == propsTween)
                    asView.viewWidth = viewWidthStart + (viewWidthEnd - viewWidthStart) * value;
                if (viewHeightTween == propsTween)
                    asView.viewHeight = viewHeightStart + (viewHeightEnd - viewHeightStart) * value;
                #end
            };
            propsTween = eager ? entity.eagerTween(easing, duration, 0, 1, tweenUpdate) : entity.tween(easing, duration, 0, 1, tweenUpdate);
            tweenUpdate = null;
            propsTween.onDestroy(this, propsTween -> {
                if (xTween == propsTween)
                    xTween = null;
                if (yTween == propsTween)
                    yTween = null;
                if (depthTween == propsTween)
                    depthTween = null;
                if (scaleXTween == propsTween)
                    scaleXTween = null;
                if (scaleYTween == propsTween)
                    scaleYTween = null;
                if (translateXTween == propsTween)
                    translateXTween = null;
                if (translateYTween == propsTween)
                    translateYTween = null;
                if (skewXTween == propsTween)
                    skewXTween = null;
                if (skewYTween == propsTween)
                    skewYTween = null;
                if (anchorXTween == propsTween)
                    anchorXTween = null;
                if (anchorYTween == propsTween)
                    anchorYTween = null;
                if (rotationTween == propsTween)
                    rotationTween = null;
                if (widthTween == propsTween)
                    widthTween = null;
                if (heightTween == propsTween)
                    heightTween = null;
                if (colorTween == propsTween)
                    colorTween = null;
                if (alphaTween == propsTween)
                    alphaTween = null;
                if (transformTween == propsTween)
                    transformTween = null;
                #if plugin_ui
                if (offsetXTween == propsTween)
                    offsetXTween = null;
                if (offsetYTween == propsTween)
                    offsetYTween = null;
                if (viewWidthTween == propsTween)
                    viewWidthTween = null;
                if (viewHeightTween == propsTween)
                    viewHeightTween = null;
                #end
            });

            if (xChanged) {
                xTween = propsTween;
                xStart = xCurrent;
                xEnd = xTarget;
            }
            if (yChanged) {
                yTween = propsTween;
                yStart = yCurrent;
                yEnd = yTarget;
            }
            if (depthChanged) {
                depthTween = propsTween;
                depthStart = depthCurrent;
                depthEnd = depthTarget;
            }
            if (scaleXChanged) {
                scaleXTween = propsTween;
                scaleXStart = scaleXCurrent;
                scaleXEnd = scaleXTarget;
            }
            if (scaleYChanged) {
                scaleYTween = propsTween;
                scaleYStart = scaleYCurrent;
                scaleYEnd = scaleYTarget;
            }
            if (translateXChanged) {
                translateXTween = propsTween;
                translateXStart = translateXCurrent;
                translateXEnd = translateXTarget;
            }
            if (translateYChanged) {
                translateYTween = propsTween;
                translateYStart = translateYCurrent;
                translateYEnd = translateYTarget;
            }
            if (skewXChanged) {
                skewXTween = propsTween;
                skewXStart = skewXCurrent;
                skewXEnd = skewXTarget;
            }
            if (skewYChanged) {
                skewYTween = propsTween;
                skewYStart = skewYCurrent;
                skewYEnd = skewYTarget;
            }
            if (anchorXChanged) {
                anchorXTween = propsTween;
                anchorXStart = anchorXCurrent;
                anchorXEnd = anchorXTarget;
            }
            if (anchorYChanged) {
                anchorYTween = propsTween;
                anchorYStart = anchorYCurrent;
                anchorYEnd = anchorYTarget;
            }
            if (rotationChanged) {
                rotationTween = propsTween;
                rotationStart = GeometryUtils.clampDegrees(rotationCurrent);
                rotationEnd = GeometryUtils.clampDegrees(rotationTarget);
                var rotationDelta = rotationEnd - rotationStart;
                if (rotationDelta > 180) {
                    rotationEnd -= 360;
                }
                else if (rotationDelta < -180) {
                    rotationEnd += 360;
                }
            }
            if (widthChanged) {
                widthTween = propsTween;
                widthStart = widthCurrent;
                widthEnd = widthTarget;
            }
            if (heightChanged) {
                heightTween = propsTween;
                heightStart = heightCurrent;
                heightEnd = heightTarget;
            }
            if (colorChanged) {
                colorTween = propsTween;
                if (!didRetrieveColorCurrent) {
                    didRetrieveColorCurrent = true;
                    colorCurrent = entity.getProperty('color');
                }
                colorStart = colorCurrent;
                colorEnd = colorTarget;
            }
            if (alphaChanged) {
                alphaTween = propsTween;
                alphaStart = alphaCurrent;
                alphaEnd = alphaTarget;
            }
            if (transformChanged) {
                transformTween = propsTween;
                if (transformCurrent != null) {
                    if (transformStart == null)
                        transformStart = TransformPool.get();
                    transformStart.setToTransform(transformCurrent);
                }
                else if (transformStart != null) {
                    transformStart.identity();
                }
                if (transformTarget != null) {
                    if (transformEnd == null)
                        transformEnd = TransformPool.get();
                    transformEnd.setToTransform(transformTarget);
                    transformEndToNull = false;
                }
                else if (transformEnd != null) {
                    transformEnd.identity();
                    transformEndToNull = true;
                }
            }
            #if plugin_ui
            if (offsetXChanged) {
                offsetXTween = propsTween;
                offsetXStart = offsetXCurrent;
                offsetXEnd = offsetXTarget;
            }
            if (offsetYChanged) {
                offsetYTween = propsTween;
                offsetYStart = offsetYCurrent;
                offsetYEnd = offsetYTarget;
            }
            if (viewWidthChanged) {
                viewWidthTween = propsTween;
                viewWidthStart = viewWidthCurrent;
                viewWidthEnd = viewWidthTarget;
            }
            if (viewHeightChanged) {
                viewHeightTween = propsTween;
                viewHeightStart = viewHeightCurrent;
                viewHeightEnd = viewHeightTarget;
            }
            #end
        }
        else {

            propsTween = eager ? entity.eagerTween(easing, duration, 0, 1, null) : entity.tween(easing, duration, 0, 1, null);

        }

        return propsTween;

    }

    override function destroy() {

        if (transformInTransition != null) {
            TransformPool.recycle(transformInTransition);
            transformInTransition = null;
        }

        if (transformStart != null) {
            TransformPool.recycle(transformStart);
            transformStart = null;
        }

        if (transformEnd != null) {
            TransformPool.recycle(transformEnd);
            transformEnd = null;
        }

        super.destroy();

    }

/// Static extension

    /**
     * Static extension method to run a transition on any Visual.
     * 
     * Creates a transition component if needed and runs the transition.
     * This is the most convenient way to use transitions:
     * 
     * ```haxe
     * myVisual.transition(EASE_OUT, 0.5, props -> {
     *     props.x = 100;
     *     props.alpha = 0;
     * });
     * ```
     * 
     * @param visual The visual to transition
     * @param easing Optional easing function
     * @param duration Duration in seconds
     * @param cb Callback to set target property values
     * @return The tween instance, or null if no properties changed
     */
    public static function transition(visual:Visual, ?easing:Easing, duration:Float, cb:VisualTransitionProperties->Void):Null<Tween> {

        var transitionComponent:VisualTransition = cast visual.component('transition');
        if (transitionComponent == null) {
            transitionComponent = new VisualTransition();
            visual.component('transition', transitionComponent);
        }

        return transitionComponent.run(easing, duration, cb);

    }

    /**
     * Static extension method to run an eager transition on any Visual.
     * 
     * Same as transition() but updates on the first frame.
     * 
     * @param visual The visual to transition
     * @param easing Optional easing function
     * @param duration Duration in seconds
     * @param cb Callback to set target property values
     * @return The tween instance, or null if no properties changed
     */
    public static function eagerTransition(visual:Visual, ?easing:Easing, duration:Float, cb:VisualTransitionProperties->Void):Null<Tween> {

        var transitionComponent:VisualTransition = cast visual.component('transition');
        if (transitionComponent == null) {
            transitionComponent = new VisualTransition();
            visual.component('transition', transitionComponent);
        }

        return transitionComponent.eagerRun(easing, duration, cb);

    }

}

/**
 * Property setter interface for visual transitions.
 * 
 * This abstract type provides a fluent API for setting target values
 * during a transition. Each property setter automatically marks the
 * property as changed and stores the target value.
 * 
 * The interface includes convenience methods for setting related
 * properties together:
 * - pos(x, y) - Set position
 * - size(width, height) - Set dimensions
 * - scale(x, y) - Set scale (y optional)
 * - anchor(x, y) - Set anchor point
 * - etc.
 * 
 * All numeric properties support interpolation with easing.
 * Color properties use RGB interpolation.
 * Transform properties use matrix interpolation.
 */
abstract VisualTransitionProperties(VisualTransition) from VisualTransition {

    /**
     * Target X position for the transition.
     */
    public var x(get, set):Float;
    function get_x():Float return this.xTarget;
    function set_x(x:Float):Float {
        if (this.xTween == null || x != this.xEnd) {
            this.anyPropertyChanged = true;
            this.xChanged = true;
        }
        this.xTarget = x;
        return x;
    }

    /**
     * Target Y position for the transition.
     */
    public var y(get, set):Float;
    function get_y():Float return this.yTarget;
    function set_y(y:Float):Float {
        if (this.yTween == null || y != this.yEnd) {
            this.anyPropertyChanged = true;
            this.yChanged = true;
        }
        this.yTarget = y;
        return y;
    }

    /**
     * Set both X and Y position at once.
     * 
     * @param x Target X position
     * @param y Target Y position
     */
    public function pos(x:Float, y:Float):Void {
        inline set_x(x);
        inline set_y(y);
    }

    /**
     * Target depth value for the transition.
     * Controls the Z-order/layering of the visual.
     */
    public var depth(get, set):Float;
    function get_depth():Float return this.depthTarget;
    function set_depth(depth:Float):Float {
        if (this.depthTween == null || depth != this.depthEnd) {
            this.anyPropertyChanged = true;
            this.depthChanged = true;
        }
        this.depthTarget = depth;
        return depth;
    }

    /**
     * Target X scale factor for the transition.
     */
    public var scaleX(get, set):Float;
    function get_scaleX():Float return this.scaleXTarget;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleXTween == null || scaleX != this.scaleXEnd) {
            this.anyPropertyChanged = true;
            this.scaleXChanged = true;
        }
        this.scaleXTarget = scaleX;
        return scaleX;
    }

    /**
     * Target Y scale factor for the transition.
     */
    public var scaleY(get, set):Float;
    function get_scaleY():Float return this.scaleYTarget;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleYTween == null || scaleY != this.scaleYEnd) {
            this.anyPropertyChanged = true;
            this.scaleYChanged = true;
        }
        this.scaleYTarget = scaleY;
        return scaleY;
    }

    /**
     * Set both X and Y scale factors at once.
     * 
     * @param scaleX Target X scale factor
     * @param scaleY Target Y scale factor (defaults to scaleX if -1)
     */
    public function scale(scaleX:Float, scaleY:Float = -1):Void {
        inline set_scaleX(scaleX);
        inline set_scaleY(scaleY != -1 ? scaleY : scaleX);
    }

    /**
     * Target X translation for the transition.
     * This is additional transform translation, separate from position.
     */
    public var translateX(get, set):Float;
    function get_translateX():Float return this.translateXTarget;
    function set_translateX(translateX:Float):Float {
        if (this.translateXTween == null || translateX != this.translateXEnd) {
            this.anyPropertyChanged = true;
            this.translateXChanged = true;
        }
        this.translateXTarget = translateX;
        return translateX;
    }

    /**
     * Target Y translation for the transition.
     * This is additional transform translation, separate from position.
     */
    public var translateY(get, set):Float;
    function get_translateY():Float return this.translateYTarget;
    function set_translateY(translateY:Float):Float {
        if (this.translateYTween == null || translateY != this.translateYEnd) {
            this.anyPropertyChanged = true;
            this.translateYChanged = true;
        }
        this.translateYTarget = translateY;
        return translateY;
    }

    /**
     * Set both X and Y translation values at once.
     * 
     * @param translateX Target X translation
     * @param translateY Target Y translation (defaults to translateX if -1)
     */
    public function translate(translateX:Float, translateY:Float = -1):Void {
        inline set_translateX(translateX);
        inline set_translateY(translateY != -1 ? translateY : translateX);
    }

    /**
     * Target X skew angle in degrees for the transition.
     */
    public var skewX(get, set):Float;
    function get_skewX():Float return this.skewXTarget;
    function set_skewX(skewX:Float):Float {
        if (this.skewXTween == null || skewX != this.skewXEnd) {
            this.anyPropertyChanged = true;
            this.skewXChanged = true;
        }
        this.skewXTarget = skewX;
        return skewX;
    }

    /**
     * Target Y skew angle in degrees for the transition.
     */
    public var skewY(get, set):Float;
    function get_skewY():Float return this.skewYTarget;
    function set_skewY(skewY:Float):Float {
        if (this.skewYTween == null || skewY != this.skewYEnd) {
            this.anyPropertyChanged = true;
            this.skewYChanged = true;
        }
        this.skewYTarget = skewY;
        return skewY;
    }

    /**
     * Set both X and Y skew angles at once.
     * 
     * @param skewX Target X skew angle in degrees
     * @param skewY Target Y skew angle in degrees
     */
    public function skew(skewX:Float, skewY:Float):Void {
        inline set_skewX(skewX);
        inline set_skewY(skewY);
    }

    /**
     * Target X anchor point for the transition.
     * Range: 0.0 (left) to 1.0 (right).
     */
    public var anchorX(get, set):Float;
    function get_anchorX():Float return this.anchorXTarget;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorXTween == null || anchorX != this.anchorXEnd) {
            this.anyPropertyChanged = true;
            this.anchorXChanged = true;
        }
        this.anchorXTarget = anchorX;
        return anchorX;
    }

    /**
     * Target Y anchor point for the transition.
     * Range: 0.0 (top) to 1.0 (bottom).
     */
    public var anchorY(get, set):Float;
    function get_anchorY():Float return this.anchorYTarget;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorYTween == null || anchorY != this.anchorYEnd) {
            this.anyPropertyChanged = true;
            this.anchorYChanged = true;
        }
        this.anchorYTarget = anchorY;
        return anchorY;
    }

    /**
     * Set both X and Y anchor points at once.
     * 
     * @param anchorX Target X anchor point (0.0-1.0)
     * @param anchorY Target Y anchor point (0.0-1.0)
     */
    public function anchor(anchorX:Float, anchorY:Float):Void {
        inline set_anchorX(anchorX);
        inline set_anchorY(anchorY);
    }

    /**
     * Target rotation in degrees.
     * Automatically uses shortest path interpolation.
     */
    public var rotation(get, set):Float;
    function get_rotation():Float return this.rotationTarget;
    function set_rotation(rotation:Float):Float {
        if (this.rotationTween == null || rotation != this.rotationEnd) {
            this.anyPropertyChanged = true;
            this.rotationChanged = true;
        }
        this.rotationTarget = rotation;
        return rotation;
    }

    /**
     * Target width for the transition.
     */
    public var width(get, set):Float;
    function get_width():Float return this.widthTarget;
    function set_width(width:Float):Float {
        if (this.widthTween == null || width != this.widthEnd) {
            this.anyPropertyChanged = true;
            this.widthChanged = true;
        }
        this.widthTarget = width;
        return width;
    }

    /**
     * Target height for the transition.
     */
    public var height(get, set):Float;
    function get_height():Float return this.heightTarget;
    function set_height(height:Float):Float {
        if (this.heightTween == null || height != this.heightEnd) {
            this.anyPropertyChanged = true;
            this.heightChanged = true;
        }
        this.heightTarget = height;
        return height;
    }

    /**
     * Set both width and height at once.
     * 
     * @param width Target width
     * @param height Target height
     */
    public function size(width:Float, height:Float):Void {
        inline set_width(width);
        inline set_height(height);
    }

    /**
     * Target color for the transition.
     * Uses RGB interpolation during animation.
     */
    public var color(get, set):Color;
    function get_color():Color return this.colorTarget;
    function set_color(color:Color):Color {
        if (this.colorTween == null || color != this.colorEnd) {
            this.anyPropertyChanged = true;
            this.colorChanged = true;
        }
        this.colorTarget = color;
        return color;
    }

    /**
     * Target alpha (opacity) value.
     * Range: 0.0 (transparent) to 1.0 (opaque).
     */
    public var alpha(get, set):Float;
    function get_alpha():Float return this.alphaTarget;
    function set_alpha(alpha:Float):Float {
        if (this.alphaTween == null || alpha != this.alphaEnd) {
            this.anyPropertyChanged = true;
            this.alphaChanged = true;
        }
        this.alphaTarget = alpha;
        return alpha;
    }

    /**
     * Target transform matrix for the transition.
     * Uses matrix interpolation during animation.
     */
    public var transform(get, set):Transform;
    function get_transform():Transform return this.transformTarget;
    function set_transform(transform:Transform):Transform {
        this.anyPropertyChanged = true;
        this.transformChanged = true;
        this.transformAssigned = true;
        this.transformAssignedInstance = transform;
        this.transformTarget = transform;
        return transform;
    }

    #if plugin_ui
    /**
     * Horizontal offset position for UI views (UI plugin only).
     * Sets the target offsetX value for transition animation.
     */
    @:plugin('ui')
    public var offsetX(get, set):Float;
    function get_offsetX():Float return this.offsetXTarget;
    function set_offsetX(offsetX:Float):Float {
        if (this.offsetXTween == null || offsetX != this.offsetXEnd) {
            this.anyPropertyChanged = true;
            this.offsetXChanged = true;
        }
        this.offsetXTarget = offsetX;
        return offsetX;
    }

    /**
     * Vertical offset position for UI views (UI plugin only).
     * Sets the target offsetY value for transition animation.
     */
    @:plugin('ui')
    public var offsetY(get, set):Float;
    function get_offsetY():Float return this.offsetYTarget;
    function set_offsetY(offsetY:Float):Float {
        if (this.offsetYTween == null || offsetY != this.offsetYEnd) {
            this.anyPropertyChanged = true;
            this.offsetYChanged = true;
        }
        this.offsetYTarget = offsetY;
        return offsetY;
    }

    @:plugin('ui')
    public function offset(offsetX:Float, offsetY:Float):Void {
        inline set_offsetX(offsetX);
        inline set_offsetY(offsetY);
    }

    /**
     * View width dimension for UI views (UI plugin only).
     * Sets the target viewWidth value for transition animation.
     */
    @:plugin('ui')
    public var viewWidth(get, set):Float;
    function get_viewWidth():Float return this.viewWidthTarget;
    function set_viewWidth(viewWidth:Float):Float {
        if (this.viewWidthTween == null || viewWidth != this.viewWidthEnd) {
            this.anyPropertyChanged = true;
            this.viewWidthChanged = true;
        }
        this.viewWidthTarget = viewWidth;
        return viewWidth;
    }

    /**
     * View height dimension for UI views (UI plugin only).
     * Sets the target viewHeight value for transition animation.
     */
    @:plugin('ui')
    public var viewHeight(get, set):Float;
    function get_viewHeight():Float return this.viewHeightTarget;
    function set_viewHeight(viewHeight:Float):Float {
        if (this.viewHeightTween == null || viewHeight != this.viewHeightEnd) {
            this.anyPropertyChanged = true;
            this.viewHeightChanged = true;
        }
        this.viewHeightTarget = viewHeight;
        return viewHeight;
    }

    @:plugin('ui')
    public function viewSize(viewWidth:Float, viewHeight:Float):Void {
        inline set_viewWidth(viewWidth);
        inline set_viewHeight(viewHeight);
    }
    #end

}
