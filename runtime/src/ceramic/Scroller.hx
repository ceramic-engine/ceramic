package ceramic;

import ceramic.ScrollDirection;
import ceramic.ScrollerStatus;
import ceramic.Shortcuts.*;

@:keep
class Scroller extends Visual {

    static var _point:Point = new Point(0, 0);

/// Events

    @event function dragStart();

    @event function dragEnd();

    @event function wheelStart();

    @event function wheelEnd();

    @event function click(info:TouchInfo);

    @event function scrollerPointerDown(info:TouchInfo);

    @event function scrollerPointerUp(info:TouchInfo);

/// Public properties

    public var content(default,null):Visual = null;

    public var scrollbar(default, set):Visual = null;
    function set_scrollbar(scrollbar:Visual):Visual {
        if (this.scrollbar == scrollbar) return scrollbar;
        if (this.scrollbar != null) {
            this.scrollbar.destroy();
        }
        this.scrollbar = scrollbar;
        if (this.scrollbar != null) {
            add(this.scrollbar);
            this.scrollbar.depth = 2;
            bindScrollbar(this.scrollbar);
        }
        return this.scrollbar;
    }

    public var direction = VERTICAL;

    public var allowPointerOutside:Bool = true;

    public var scrollTransform(default,null):Transform = new Transform();

    public var scrollEnabled(default,set):Bool = true;

    public var dragEnabled:Bool = true;

    /**
     * If set to a value above zero, scrollX and scrollY will be rounded when scroller is idle.
     *
     * ```haxe
     * roundScrollWhenIddle = 0; // No rounding (default)
     * roundScrollWhenIddle = 1; // Pixel perfect rounding
     * roundScrollWhenIddle = 2; // Half-pixel rounding
     * ```
     */
    @editable
    public var roundScrollWhenIddle(default,set):Int = 1;
    function set_roundScrollWhenIddle(roundScrollWhenIddle:Int):Int {
        if (this.roundScrollWhenIddle == roundScrollWhenIddle) return roundScrollWhenIddle;
        this.roundScrollWhenIddle = roundScrollWhenIddle;
        if (status == IDLE) {
            inline roundScrollIfNeeded();
        }
        return roundScrollWhenIddle;
    }

    public var status(default,set):ScrollerStatus = IDLE;

    function set_status(status:ScrollerStatus):ScrollerStatus {
        if (status == this.status) return status;
        var prevStatus = this.status;
        this.status = status;
        if (status == DRAGGING) {
            emitDragStart();
        }
        else if (prevStatus == DRAGGING) {
            emitDragEnd();
        }
        else if (status == IDLE) {
            inline roundScrollIfNeeded();
        }
        return status;
    }

/// Global tuning

    public static var threshold = 4.0;

/// Fine tuning

    /**
     * When set to `true`, vertical mouse wheel event
     * will also work on horizontal scroller.
     */
    public var verticalToHorizontalWheel = false;

    public var deceleration = 300.0;

    public var wheelDeceleration = 1600.0;

    public var wheelFactor = 1.0;

    public var wheelMomentum = false;

    public var wheelEndDelay = 0.25;

    public var overScrollResistance = 5.0;

    public var maxClickMomentum = 100.0;

    public var bounceMomentumFactor = 0.00075;

    public var bounceMinDuration = 0.08;

    public var bounceDurationFactor = 0.00004;

    public var bounceNoMomentumDuration = 0.1;

    public var dragFactor = 1.0;

    public var touchableStrictHierarchy = true;

/// Internal

    var prevPointerX:Float = -999999;

    var prevPointerY:Float = -999999;

/// Lifecycle

    public function new(?content:Visual) {

        super();

        if (content == null) {
            content = new Visual();
        }
        this.content = content;
        content.anchor(0, 0);
        content.pos(0, 0);
        content.transform = scrollTransform;
        content.depth = 1;
        add(content);

        scrollTransform.onChange(this, updateScrollbar);

        // Just to ensure nothing behind the scroller
        // will catch pointerDown event
        onPointerDown(this, function(_) {});

        // Start tracking events to handle scroll
        startTracking();

    }

    function set_scrollEnabled(scrollEnabled:Bool):Bool {

        if (this.scrollEnabled == scrollEnabled) return scrollEnabled;

        this.scrollEnabled = scrollEnabled;
        status = IDLE;

        if (scrollEnabled) {
            startTracking();
        } else {
            stopTracking();
        }

        return scrollEnabled;

    }

/// Overrides

    override function set_width(width:Float):Float {

        super.set_width(width);

        if (direction == VERTICAL) {
            content.width = width;
        }

        return width;

    }

    override function set_height(height:Float):Float {

        super.set_height(height);

        if (direction == HORIZONTAL) {
            content.height = height;
        }

        return height;

    }

    override function interceptPointerDown(hittingVisual:Visual, x:Float, y:Float, touchIndex:Int, buttonId:Int):Bool {

        if (!allowPointerOutside && !hits(x, y)) {
            return true;
        }

        return false;

    }

    override function interceptPointerOver(hittingVisual:Visual, x:Float, y:Float):Bool {

        var doesHit = hits(x, y);
        pointerOnScrollerChild = doesHit && !Std.isOfType(hittingVisual, Scroller);

        if (!allowPointerOutside && !doesHit) {
            return true;
        }

        return false;

    }

/// Public API

    public function scrollToBounds():Void {

       if (direction == VERTICAL) {
           if (content.height - height < scrollY) {
               scrollY = content.height - height;
           }
           else if (scrollY < 0) {
               scrollY = 0;
           }
       }
       else {
           if (content.width - width < scrollX) {
               scrollX = content.width - width;
           }
           else if (scrollX < 0) {
               scrollX = 0;
           }
       }

    }

    public function isContentPositionInBounds(x:Float, y:Float):Bool {

        if (x < scrollX)
            return false;
        if (x >= scrollX + width)
            return false;

        if (y < scrollY)
            return false;
        if (y >= scrollY + height)
            return false;

        return true;

    }

    public function ensureContentPositionIsInBounds(x:Float, y:Float):Void {

        var targetScrollX = scrollX;
        var targetScrollY = scrollY;

        // Compute target scrollX
        if (x < targetScrollX) {
            targetScrollX = x;
        }
        else if (x >= targetScrollX + width) {
            targetScrollX = x - width;
        }

        // Check bounds
        var maxScrollX = content.width - width;
        if (targetScrollX > maxScrollX) {
            targetScrollX = maxScrollX;
        }
        if (targetScrollX < 0) {
            targetScrollX = 0;
        }

        // Compute target scrollY
        if (y < targetScrollY) {
            targetScrollY = y;
        }
        else if (y >= targetScrollY + height) {
            targetScrollY = y - height;
        }

        // Check bounds
        var maxScrollY = content.height - height;
        if (targetScrollY > maxScrollY) {
            targetScrollY = maxScrollY;
        }
        if (targetScrollY < 0) {
            targetScrollY = 0;
        }

        // Apply scroll
        scrollX = targetScrollX;
        scrollY = targetScrollY;

    }

    public var scrollX(get,set):Float;
    inline function get_scrollX():Float {
        return -scrollTransform.tx;
    }
    inline function set_scrollX(scrollX:Float):Float {
        if (scrollTransform.tx == -scrollX) return scrollX;
        scrollTransform.tx = -scrollX;
        scrollTransform.changedDirty = true;
        return scrollX;
    }

    public var scrollY(get,set):Float;
    inline function get_scrollY():Float {
        return -scrollTransform.ty;
    }
    inline function set_scrollY(scrollY:Float):Float {
        if (scrollTransform.ty == -scrollY) return scrollY;
        scrollTransform.ty = -scrollY;
        scrollTransform.changedDirty = true;
        return scrollY;
    }

/// State

    var position:Float = 0;

    var contentStart:Float = 0;

    var pointerStart:Float = 0;

    var touchIndex:Int = -1;

    public var scrollVelocity(default,null):Velocity = null;

    public var momentum(default,null):Float = 0;

    var overScrollRelease:Bool = false;

    var fromWheel:Bool = false;

    var lastWheelEventTime:Float = -1;

    var canClick:Bool = false;

    var tweenX:Tween = null;

    var tweenY:Tween = null;

    var animating:Bool = false;

    var snapping:Bool = false;

    var pointerOnScroller:Bool = false;

    var pointerOnScrollerChild:Bool = false;

/// Toggle tracking

    function startTracking():Void {

        app.onUpdate(this, update);

        onPointerOver(this, pointerOver);
        onPointerOut(this, pointerOut);

        screen.onMultiTouchPointerDown(this, pointerDown);

        screen.onFocus(this, screenFocus);

        screen.onMouseWheel(this, mouseWheel);

    }

    function stopTracking():Void {

        app.offUpdate(update);

        offPointerOver(pointerOver);
        offPointerOut(pointerOut);

        screen.offMultiTouchPointerDown(pointerDown);

        screen.offFocus(screenFocus);

        screen.offMouseWheel(mouseWheel);

    }

/// Event handling

    function pointerOver(info:TouchInfo) {

        pointerOnScroller = true;

    }

    function pointerOut(info:TouchInfo) {

        pointerOnScroller = false;

    }

    function mouseWheel(x:Float, y:Float):Void {

        if (status == TOUCHING || status == DRAGGING || (!pointerOnScroller && !pointerOnScrollerChild)) {
            // Did already put a finger on this scroller
            return;
        }

        if (!hits(screen.pointerX, screen.pointerY)) {
            // Ignore wheel event if mouse is not above the visual
            return;
        }

        if (direction == VERTICAL) {
            if (isOverScrollingTop() || isOverScrollingBottom()) return;
        } else {
            if (isOverScrollingLeft() || isOverScrollingRight()) return;
        }

        x *= wheelFactor #if mac * -1.0 #end;
        y *= wheelFactor;

        status = SCROLLING;
        fromWheel = true;
        if (lastWheelEventTime == -1) {
            lastWheelEventTime = Timer.now;
            emitWheelStart();
        } else {
            lastWheelEventTime = Timer.now;
        }
        if (direction == VERTICAL) {
            if ((momentum < 0 && y > 0) || (momentum > 0 && y < 0)) {
                momentum = 0;
            }
            scrollTransform.ty -= y;
            if (isOverScrollingTop()) {
                scrollTransform.ty = 0;
            }
            else if (isOverScrollingBottom()) {
                scrollTransform.ty = height - content.height;
            }
            if (wheelMomentum && scrollTransform.ty < 0 && scrollTransform.ty > height - content.height) {
                momentum -= y * 60;
            }
        }
        else {
            if (verticalToHorizontalWheel && x == 0) {
                if ((momentum < 0 && y > 0) || (momentum > 0 && y < 0)) {
                    momentum = 0;
                }
                scrollTransform.tx -= y;
                if (isOverScrollingLeft()) {
                    scrollTransform.tx = 0;
                }
                else if (isOverScrollingRight()) {
                    scrollTransform.tx = width - content.width;
                }
                if (wheelMomentum && scrollTransform.tx <= 0 && scrollTransform.tx >= width - content.width) {
                    momentum -= y * 60;
                }
            } else {
                if ((momentum < 0 && x > 0) || (momentum > 0 && x < 0)) {
                    momentum = 0;
                }
                scrollTransform.tx -= x;
                if (isOverScrollingLeft()) {
                    scrollTransform.tx = 0;
                }
                else if (isOverScrollingRight()) {
                    scrollTransform.tx = width - content.width;
                }
                if (wheelMomentum && scrollTransform.tx <= 0 && scrollTransform.tx >= width - content.width) {
                    momentum -= x * 60;
                }
            }
        }
        scrollTransform.changedDirty = true;

    }

    function pointerDown(info:TouchInfo):Void {

        if (!computedTouchable) {
            // Not touchable, do nothing
            return;
        }

        if (!dragEnabled) {
            // Dragging disabled
            return;
        }

        if (status == TOUCHING || status == DRAGGING) {
            // Did already put a finger on this scroller
            return;
        }

        // Does this touch intersect with our scroller?
        var hits = this.hits(info.x, info.y);
        var firstDownListener = hits && touchableStrictHierarchy ? @:privateAccess screen.matchFirstDownListener(info.x, info.y) : null;

        if (hits && (!touchableStrictHierarchy || (firstDownListener != null && (firstDownListener == this || this.contains(firstDownListener, true))))) {
            // If it was bouncing, snapping..., it is not anymore
            animating = false;
            snapping = false;

            // Stop any tween
            if (tweenX != null) tweenX.destroy();
            if (tweenY != null) tweenY.destroy();

            // Are we stopping some previous scroll?
            if (status == SCROLLING && Math.abs(momentum) > maxClickMomentum) {
                // Get focus
                screen.focusedVisual = this;
                canClick = false;
            }
            else {
                canClick = true;
            }

            // Yes, then let's start touching
            prevPointerX = -999999;
            prevPointerY = -999999;
            status = TOUCHING;
            touchIndex = info.touchIndex;
            if (direction == VERTICAL) {
                contentStart = scrollTransform.ty;
                pointerStart = info.y;
            } else {
                contentStart = scrollTransform.tx;
                pointerStart = info.x;
            }

            // Start computing scrollVelocity
            scrollVelocity = new Velocity();
            scrollVelocity.add(0);

            // Catch `pointer up` event
            screen.onMultiTouchPointerUp(this, pointerUp);

            emitScrollerPointerDown(info);
        }

    }

    function pointerUp(info:TouchInfo):Void {

        if (info.touchIndex == touchIndex) {
            // Can click?
            if (status != TOUCHING || screen.focusedVisual != this) {
                canClick = false;
            }

            // Get momentum from scrollVelocity
            // and stop computing scrollVelocity
            momentum = scrollVelocity.get();
            scrollVelocity = null;
            touchIndex = -1;

            // End of drag
            status = SCROLLING;
            screen.offMultiTouchPointerUp(pointerUp);

            if (direction == VERTICAL) {
                if (isOverScrollingTop() || isOverScrollingBottom()) {
                    overScrollRelease = true;
                }
                else {
                    overScrollRelease = false;
                }
            }
            else {
                if (isOverScrollingLeft() || isOverScrollingRight()) {
                    overScrollRelease = true;
                }
                else {
                    overScrollRelease = false;
                }
            }

            if (canClick) {
                canClick = false;
                emitClick(info);
            }

            emitScrollerPointerUp(info);
        }

    }

    function screenFocus(focusedVisual:Visual):Void {

        // Should something above this scroller keep us idle?
        if (focusedVisual != null && focusedVisual != this && status == TOUCHING) {

            if (!contains(focusedVisual)) {
                // The focused visual is not inside the scroller,
                // thus we should cancel any started scrolling.
                status = IDLE;
                screen.offMultiTouchPointerUp(pointerUp);
            }

        }

    }

/// Helpers

    inline public function isOverScrollingTop() {

        return scrollTransform.ty > 0;

    }

    inline public function isOverScrollingBottom() {

        return scrollTransform.ty < height - content.height;

    }

    inline public function isOverScrollingLeft() {

        return scrollTransform.tx > 0;

    }

    inline public function isOverScrollingRight() {

        return scrollTransform.tx < width - content.width;

    }

/// Round scroll

    function roundScrollIfNeeded():Void {

        if (roundScrollWhenIddle > 0) {
            if (roundScrollWhenIddle == 1) {
                scrollX = Math.round(scrollX);
                scrollY = Math.round(scrollY);
            }
            else {
                scrollX = Math.round(scrollX * roundScrollWhenIddle) / roundScrollWhenIddle;
                scrollY = Math.round(scrollY * roundScrollWhenIddle) / roundScrollWhenIddle;
            }
        }

    }

/// Update loop

    function update(delta:Float):Void {

        if (delta == 0) return;

        var pointerX:Float = screen.pointerX;
        var pointerY:Float = screen.pointerY;

        if (touchIndex != -1) {
            var pointer = screen.touches.get(touchIndex);
            if (pointer != null) {
                pointerX = pointer.x;
                pointerY = pointer.y;
            }
        }

        #if ceramic_scroller_tweak_delta
        // Scroll is expected to work fine on 60 FPS
        // If FPS is lower (higher delta), compute more frames with shorter deltas
        var optimalDelta = 1.0 / 60;
        if (delta >= optimalDelta * 1.5) {
            if (prevPointerX != -999999 && prevPointerY != -999999) {
                scrollUpdate((pointerX + prevPointerX) * 0.5, (pointerY + prevPointerY) * 0.5, delta * 0.5, delta * 0.5);
            }
            else {
                scrollUpdate(pointerX, pointerY, delta * 0.5, delta * 0.5);
            }
            scrollUpdate(pointerX, pointerY, delta * 0.5);
        }
        else {
        #end
            scrollUpdate(pointerX, pointerY, delta);
        #if ceramic_scroller_tweak_delta
        }
        #end

        if (lastWheelEventTime != -1) {
            if (Timer.now - lastWheelEventTime > wheelEndDelay) {
                lastWheelEventTime = -1;
                emitWheelEnd();
            }
        }

        switch (status) {
            case TOUCHING | DRAGGING:
                prevPointerX = pointerX;
                prevPointerY = pointerY;
            default:
                prevPointerX = -999999;
                prevPointerY = -999999;
        }

        updateScrollbar();

        if (status == IDLE) {
            roundScrollIfNeeded();
        }

    }

    function updateScrollbar():Void {

        if (scrollbar != null) {
            if (direction == VERTICAL) {
                scrollbar.x = width - scrollbar.width * (1 - scrollbar.anchorX);
                if (content.height > 0) {
                    scrollbar.height = Math.min(height, height * height / content.height);
                    scrollbar.y = height * scrollY / content.height;
                }
                else {
                    scrollbar.height = 0;
                    scrollbar.y = 0;
                }
            }
            else {
                scrollbar.y = height - scrollbar.height * (1 - scrollbar.anchorY);
                if (content.width > 0) {
                    scrollbar.width = Math.min(width, width * width / content.width);
                    scrollbar.x = width * scrollX / content.width;
                }
                else {
                    scrollbar.width = 0;
                    scrollbar.x = 0;
                }
            }
        }

    }

    var scrollbarDownX:Float = -1;

    var scrollbarDownY:Float = -1;

    var scrollbarStartX:Float = -1;

    var scrollbarStartY:Float = -1;

    function bindScrollbar(scrollbar:Visual):Void {

        scrollbarDownX = -1;
        scrollbarDownY = -1;

        scrollbar.onPointerDown(this, handleScrollbarDown);
        scrollbar.onPointerUp(this, handleScrollbarUp);

    }

    function handleScrollbarDown(info:TouchInfo) {

        if (scrollEnabled) {

            scrollbarStartX = scrollbar.x;
            scrollbarStartY = scrollbar.y;

            screenToVisual(info.x, info.y, _point);
            scrollbarDownX = _point.x;
            scrollbarDownY = _point.y;

            screen.offPointerMove(handleScrollbarMove);
            screen.onPointerMove(scrollbar, handleScrollbarMove);
        }

    }

    function handleScrollbarUp(info:TouchInfo) {

        screen.offPointerMove(handleScrollbarMove);

    }

    function handleScrollbarMove(info:TouchInfo) {

        screenToVisual(info.x, info.y, _point);
        var diffX = _point.x - scrollbarDownX;
        var diffY = _point.y - scrollbarDownY;

        if (direction == VERTICAL) {
            scrollY = ((scrollbarStartY + diffY) * content.height) / height;
        }
        else {
            scrollX = ((scrollbarStartX + diffX) * content.width) / width;
        }

        scrollToBounds();

    }

    function scrollUpdate(pointerX:Float, pointerY:Float, delta:Float, minusDelta:Float = 0):Void {

        switch (status) {

            case IDLE:
                // Nothing to do

            case TOUCHING:

                if (direction == VERTICAL) {

                    if (Math.abs(pointerY - pointerStart) >= threshold) {
                        status = DRAGGING;
                        fromWheel = false;
                        pointerStart = pointerY;
                        scrollTransform.ty = contentStart + pointerY - pointerStart;

                        if (isOverScrollingLeft()) {
                            scrollVelocity.reset();
                            var maxY = Math.max(contentStart, 0);
                            pointerStart = contentStart + pointerY - (maxY + (scrollTransform.ty - maxY) * overScrollResistance);
                            scrollTransform.ty = maxY + ((contentStart + pointerY - pointerStart) - maxY) / overScrollResistance;
                        }
                        else if (isOverScrollingRight()) {
                            scrollVelocity.reset();
                            var minY = Math.min(contentStart, height - content.height);
                            pointerStart = contentStart + pointerY - (minY + (scrollTransform.ty - minY) * overScrollResistance);
                            scrollTransform.ty = minY + ((contentStart + pointerY - pointerStart) - minY) / overScrollResistance;
                        }

                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    scrollVelocity.add(pointerY - pointerStart, minusDelta);
                }
                else {

                    if (Math.abs(pointerX - pointerStart) >= threshold) {
                        status = DRAGGING;
                        fromWheel = false;
                        pointerStart = pointerX;
                        scrollTransform.tx = contentStart + pointerX - pointerStart;

                        if (isOverScrollingLeft()) {
                            scrollVelocity.reset();
                            var maxX = Math.max(contentStart, 0);
                            pointerStart = contentStart + pointerX - (maxX + (scrollTransform.tx - maxX) * overScrollResistance);
                            scrollTransform.tx = maxX + ((contentStart + pointerX - pointerStart) - maxX) / overScrollResistance;
                        }
                        else if (isOverScrollingRight()) {
                            scrollVelocity.reset();
                            var minX = Math.min(contentStart, width - content.width);
                            pointerStart = contentStart + pointerX - (minX + (scrollTransform.tx - minX) * overScrollResistance);
                            scrollTransform.tx = minX + ((contentStart + pointerX - pointerStart) - minX) / overScrollResistance;
                        }

                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    scrollVelocity.add(pointerX - pointerStart, minusDelta);
                }

            case DRAGGING:
                if (direction == VERTICAL) {
                    pointerX = pointerStart + (pointerY - pointerStart) * dragFactor;
                    scrollTransform.ty = contentStart + pointerY - pointerStart;

                    var maxY = Math.max(contentStart, 0);
                    if (scrollTransform.ty > maxY) {
                        scrollTransform.ty = maxY + (scrollTransform.ty - maxY) / overScrollResistance;
                    }
                    else {
                        var minY = Math.min(contentStart, height - content.height);
                        if (scrollTransform.ty < minY) {
                            scrollTransform.ty = minY + (scrollTransform.ty - minY) / overScrollResistance;
                        }
                    }

                    scrollTransform.changedDirty = true;
                    scrollVelocity.add(pointerY - pointerStart, minusDelta);
                }
                else {
                    pointerX = pointerStart + (pointerX - pointerStart) * dragFactor;
                    scrollTransform.tx = contentStart + pointerX - pointerStart;

                    var maxX = Math.max(contentStart, 0);
                    if (scrollTransform.tx > maxX) {
                        scrollTransform.tx = maxX + (scrollTransform.tx - maxX) / overScrollResistance;
                    }
                    else {
                        var minX = Math.min(contentStart, width - content.width);
                        if (scrollTransform.tx < minX) {
                            scrollTransform.tx = minX + (scrollTransform.tx - minX) / overScrollResistance;
                        }
                    }

                    scrollTransform.changedDirty = true;
                    scrollVelocity.add(pointerX - pointerStart, minusDelta);
                }

            case SCROLLING:
                var subtract = 0.0;

                if (direction == VERTICAL) {

                    if (animating || snapping) {
                        // Nothing to do
                    }
                    else if (isOverScrollingTop() || isOverScrollingBottom()) {
                        // bounce
                        bounceScroll();
                    }
                    else {
                        // Regular scroll
                        if (fromWheel) {
                            subtract = Math.round(wheelDeceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        } else {
                            subtract = Math.round(deceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        }

                        scrollTransform.ty += momentum * delta;
                        scrollTransform.changedDirty = true;
                    }
                }
                else {
                    if (animating || snapping) {
                        // Nothing to do
                    }
                    else if (isOverScrollingLeft() || isOverScrollingRight()) {
                        // bounce
                        bounceScroll();
                    }
                    else {
                        // Regular scroll
                        if (fromWheel) {
                            subtract = Math.round(wheelDeceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        } else {
                            subtract = Math.round(deceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        }

                        scrollTransform.tx += momentum * delta;
                        scrollTransform.changedDirty = true;
                    }
                }

                if (momentum > 0) {
                    momentum = Math.max(0, momentum - subtract * delta);
                }
                else if (momentum < 0) {
                    momentum = Math.min(0, momentum + subtract * delta);
                }
                else if (momentum == 0) {
                    if (!animating) {
                        status = IDLE;
                    }
                }

        }

    }

/// Helpers

    override public function stop():Void {

        super.stop();

        status = IDLE;
        animating = false;

        stopTweens();

    }

    inline public function stopTweens():Void {

        if (tweenX != null) tweenX.destroy();
        if (tweenY != null) tweenY.destroy();

    }

/// Smooth scroll

    public function scrollTo(scrollX:Float, scrollY:Float):Void {

        stop();

        this.scrollX = scrollX;
        this.scrollY = scrollY;

    }

    public function smoothScrollTo(scrollX:Float, scrollY:Float, duration:Float = 0.15, ?easing:Easing):Void {

        stopTweens();

        momentum = 0;
        status = SCROLLING;

        if (easing == null) easing = QUAD_EASE_IN_OUT;

        if (scrollX != this.scrollX) {
            animating = true;

            var tweenX = tween(easing, duration, this.scrollX, scrollX, function(scrollX, _) {
                this.scrollX = scrollX;
            });
            this.tweenX = tweenX;
            tweenX.onceComplete(this, function() {
                animating = false;
                status = IDLE;
            });
            tweenX.onDestroy(this, function(_) {
                if (this.tweenX == tweenX) {
                    this.tweenX = null;
                }
            });
        }

        if (scrollY != this.scrollY) {
            animating = true;

            var tweenY = tween(easing, duration, this.scrollY, scrollY, function(scrollY, _) {
                this.scrollY = scrollY;
            });
            this.tweenY = tweenY;
            tweenY.onceComplete(this, function() {
                animating = false;
                status = IDLE;
            });
            tweenY.onDestroy(this, function(_) {
                if (this.tweenY == tweenY) {
                    this.tweenY = null;
                }
            });
        }

    }

    public function snapTo(scrollX:Float, scrollY:Float, duration:Float = 0.15, ?easing:Easing):Void {

        momentum = 0;
        snapping = true;
        stopTweens();

        status = SCROLLING;

        if (duration > 0) {
            smoothScrollTo(scrollX, scrollY, duration, easing);
        } else {
            scrollTo(scrollY, scrollY);
        }

    }

    public function bounceScroll():Void {

        var momentum = this.momentum;
        this.momentum = 0;

        stopTweens();
        status = SCROLLING;

        if (direction == VERTICAL) {
            if (tweenY != null) tweenY.destroy();
            if (!overScrollRelease && (momentum > 0 || momentum < 0)) {
                var easing:Easing = LINEAR;
                var toY:Float;
                if (Math.abs(scrollY - content.height + height) < Math.abs(scrollY)) {
                    toY = content.height - height;
                }
                else {
                    toY = 0;
                }
                var fromY = scrollY - toY;
                var byY = scrollY + momentum * bounceMomentumFactor - toY;
                var duration = bounceMinDuration + Math.abs(momentum) * bounceDurationFactor;

                animating = true;
                var tweenY = tween(easing, duration, 0, 1, function(t, _) {

                    var value:Float;

                    if (t <= 0.5) {
                        value = (fromY * 2 * (1 - t * 2) + byY * (t * 2)) / 2;
                    } else {
                        value = (byY * (1 - (t - 0.5) * 2)) / 2;
                    }

                    scrollY = toY + value;

                });

                this.tweenY = tweenY;
                tweenY.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenY.onDestroy(this, function(_) {
                    if (this.tweenY == tweenY) {
                        this.tweenY = null;
                    }
                });

            }
            else {
                // No momentum
                var duration = bounceNoMomentumDuration;
                var easing:Easing = QUAD_EASE_OUT;
                var fromY = scrollY;
                var toY:Float;
                if (Math.abs(scrollY - content.height + height) < Math.abs(scrollY)) {
                    toY = content.height - height;
                }
                else {
                    toY = 0;
                }
                animating = true;
                var tweenY = tween(easing, duration * 2, fromY, toY, function(ty, _) {
                    scrollY = ty;
                });
                this.tweenY = tweenY;
                tweenY.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenY.onDestroy(this, function(_) {
                    if (this.tweenY == tweenY) {
                        this.tweenY = null;
                    }
                });
            }
        }
        else {
            if (tweenX != null) tweenX.destroy();
            if (!overScrollRelease && (momentum > 0 || momentum < 0)) {
                var easing:Easing = LINEAR;
                var toX:Float;
                if (Math.abs(scrollX - content.width + width) < Math.abs(scrollX)) {
                    toX = content.width - width;
                }
                else {
                    toX = 0;
                }
                var fromX = scrollX - toX;
                var byX = scrollX + momentum * bounceMomentumFactor - toX;
                var duration = bounceMinDuration + Math.abs(momentum) * bounceDurationFactor;

                var tweenX = tween(easing, duration, 0, 1, function(t, _) {

                    var value:Float;

                    if (t <= 0.5) {
                        value = (fromX * 2 * (1 - t * 2) + byX * (t * 2)) / 2;
                    } else {
                        value = (byX * (1 - (t - 0.5) * 2)) / 2;
                    }

                    scrollX = toX + value;

                });

                this.tweenX = tweenX;
                tweenX.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenX.onDestroy(this, function(_) {
                    if (this.tweenX == tweenX) {
                        this.tweenX = null;
                    }
                });

            }
            else {
                // No momentum
                var duration = bounceNoMomentumDuration;
                var easing:Easing = QUAD_EASE_OUT;
                var fromX = scrollX;
                var toX:Float;
                if (Math.abs(scrollX - content.width + width) < Math.abs(scrollX)) {
                    toX = content.width - width;
                }
                else {
                    toX = 0;
                }
                var tweenX = tween(easing, duration * 2, fromX, toX, function(tx, _) {
                    scrollX = tx;
                });
                this.tweenX = tweenX;
                tweenX.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenX.onDestroy(this, function(_) {
                    if (this.tweenX == tweenX) {
                        this.tweenX = null;
                    }
                });
            }
        }

    }

} //Scroller