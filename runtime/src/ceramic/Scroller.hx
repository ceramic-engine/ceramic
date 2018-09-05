package ceramic;

import ceramic.ScrollDirection;
import ceramic.ScrollerStatus;
import ceramic.Shortcuts.*;

import motion.Actuate;

@:keep
class Scroller extends Visual {

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

    public var direction = VERTICAL;

    public var scrollTransform(default,null):Transform = new Transform();

    public var scrollEnabled(default,set):Bool = true;

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
        return status;
    }

/// Global tuning

    public static var threshold = 4.0;

/// Fine tuning

    public var deceleration = 300.0;

    public var wheelDeceleration = 1600.0;

    public var wheelFactor = 1.0;

    public var wheelMomentum = #if mac true #else false #end;

    public var wheelEndDelay = 0.25;

    public var overScrollResistance = 5.0;

    public var maxClickMomentum = 100.0;

    public var bounceMomentumFactor = 0.00075;

    public var bounceMinDuration = 0.08;

    public var bounceDurationFactor = 0.00004;

    public var bounceNoMomentumDuration = 0.1;

    public var dragFactor = 1.0;

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
        add(content);

        // Just to ensure nothing behind the scroller
        // will catch pointerDown event
        onPointerDown(this, function(_) {});

        // Start tracking events to handle scroll
        startTracking();

    } //new

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

    } //scrollEnabled

/// Overrides

    override function set_width(width:Float):Float {

        super.set_width(width);

        if (direction == VERTICAL) {
            content.width = width;
        }

        return width;

    } //set_width

    override function set_height(height:Float):Float {

        super.set_height(height);

        if (direction == HORIZONTAL) {
            content.height = height;
        }

        return height;

    } //set_height

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

    } //scrollToBounds

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

    public var velocity(default,null):Velocity = null;
    
    public var momentum(default,null):Float = 0;

    var overScrollRelease:Bool = false;

    var fromWheel:Bool = false;

    var lastWheelEventTime:Float = -1;

    var canClick:Bool = false;

    var tweenX:Tween = null;

    var tweenY:Tween = null;

    var animating:Bool = false;

    var snapping:Bool = false;

/// Toggle tracking

    function startTracking():Void {

        app.onUpdate(this, update);

        screen.onMultiTouchPointerDown(this, pointerDown);

        screen.onFocus(this, screenFocus);

        screen.onMouseWheel(this, mouseWheel);

    } //startTracking

    function stopTracking():Void {

        app.offUpdate(update);

        screen.offMultiTouchPointerDown(pointerDown);

        screen.offFocus(screenFocus);

        screen.offMouseWheel(mouseWheel);

    } //stopTracking

/// Event handling

    function mouseWheel(x:Float, y:Float):Void {

        if (status == TOUCHING || status == DRAGGING) {
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
            if (x == 0) {
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

    } //mouseWheel

    function pointerDown(info:TouchInfo):Void {

        if (!computedTouchable) {
            // Not touchable, do nothing
            return;
        }

        if (status == TOUCHING || status == DRAGGING) {
            // Did already put a finger on this scroller
            return;
        }

        // Does this touch intersect with our scroller?
        var hits = this.hits(info.x, info.y);
        var firstDownListener = hits ? matchFirstDownListener(info.x, info.y) : null;

        if (hits && (firstDownListener == this || this.contains(firstDownListener, true))) {
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
            status = TOUCHING;
            touchIndex = info.touchIndex;
            if (direction == VERTICAL) {
                contentStart = scrollTransform.ty;
                pointerStart = info.y;
            } else {
                contentStart = scrollTransform.tx;
                pointerStart = info.x;
            }

            // Start computing velocity
            velocity = new Velocity();
            velocity.add(0);

            // Catch `pointer up` event
            screen.onMultiTouchPointerUp(this, pointerUp);
            
            emitScrollerPointerDown(info);
        }

    } //pointerDown

    function matchFirstDownListener(x:Float, y:Float):Visual {

        app.computeHierarchy();

        var visuals = app.visuals;
        var i = visuals.length - 1;
        while (i >= 0) {

            var visual = visuals[i];
            if (visual == this || (visual.computedTouchable && visual.listensPointerDown() && visual.hits(x, y))) {
                return visual;
            }

            i--;
        }

        return null;

    } //matchFirstDownListener

    function pointerUp(info:TouchInfo):Void {

        if (info.touchIndex == touchIndex) {
            // Can click?
            if (status != TOUCHING || screen.focusedVisual != this) {
                canClick = false;
            }

            // Get momentum from velocity
            // and stop computing velocity
            momentum = velocity.get();
            velocity = null;
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

    } //pointerUp

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

    } //screenFocus

/// Helpers

    inline public function isOverScrollingTop() {

        return scrollTransform.ty > 0;

    } //isOverScrollingTop

    inline public function isOverScrollingBottom() {

        return scrollTransform.ty < height - content.height;

    } //isOverScrollingBottom

    inline public function isOverScrollingLeft() {

        return scrollTransform.tx > 0;

    } //isOverScrollingLeft

    inline public function isOverScrollingRight() {

        return scrollTransform.tx < width - content.width;

    } //isOverScrollingRight

/// Update loop

    function update(delta:Float):Void {

        var realPointerX:Float = screen.pointerX;
        var realPointerY:Float = screen.pointerY;

        if (touchIndex != -1) {
            var pointer = screen.touches.get(touchIndex);
            if (pointer != null) {
                realPointerX = pointer.x;
                realPointerY = pointer.y;
            }
        }

        var pointerX = realPointerX;
        var pointerY = realPointerY;

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
                            velocity.reset();
                            var maxY = Math.max(contentStart, 0);
                            pointerStart = contentStart + pointerY - (maxY + (scrollTransform.ty - maxY) * overScrollResistance);
                            scrollTransform.ty = maxY + ((contentStart + pointerY - pointerStart) - maxY) / overScrollResistance;
                        }
                        else if (isOverScrollingRight()) {
                            velocity.reset();
                            var minY = Math.min(contentStart, height - content.height);
                            pointerStart = contentStart + pointerY - (minY + (scrollTransform.ty - minY) * overScrollResistance);
                            scrollTransform.ty = minY + ((contentStart + pointerY - pointerStart) - minY) / overScrollResistance;
                        }

                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerY - pointerStart);
                }
                else {

                    if (Math.abs(pointerX - pointerStart) >= threshold) {
                        status = DRAGGING;
                        fromWheel = false;
                        pointerStart = pointerX;
                        scrollTransform.tx = contentStart + pointerX - pointerStart;

                        if (isOverScrollingLeft()) {
                            velocity.reset();
                            var maxX = Math.max(contentStart, 0);
                            pointerStart = contentStart + pointerX - (maxX + (scrollTransform.tx - maxX) * overScrollResistance);
                            scrollTransform.tx = maxX + ((contentStart + pointerX - pointerStart) - maxX) / overScrollResistance;
                        }
                        else if (isOverScrollingRight()) {
                            velocity.reset();
                            var minX = Math.min(contentStart, width - content.width);
                            pointerStart = contentStart + pointerX - (minX + (scrollTransform.tx - minX) * overScrollResistance);
                            scrollTransform.tx = minX + ((contentStart + pointerX - pointerStart) - minX) / overScrollResistance;
                        }

                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerX - pointerStart);
                }
            
            case DRAGGING:
                if (direction == VERTICAL) {
                    pointerX = pointerStart + (realPointerY - pointerStart) * dragFactor;
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
                    velocity.add(pointerY - pointerStart);
                }
                else {
                    pointerX = pointerStart + (realPointerX - pointerStart) * dragFactor;
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
                    velocity.add(pointerX - pointerStart);
                }
            
            case SCROLLING:
                var subtract = 0.0;

                if (direction == VERTICAL) {

                    if (animating || snapping) {
                        // Nothing to do
                    }
                    else if (isOverScrollingTop() || isOverScrollingBottom()) {
                        // bounce
                        bounce();
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
                        bounce();
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

        if (lastWheelEventTime != -1) {
            if (Timer.now - lastWheelEventTime > wheelEndDelay) {
                lastWheelEventTime = -1;
                emitWheelEnd();
            }
        }

    } //update

/// Helpers

    public function stop():Void {

        status = IDLE;

        stopTweens();

    } //stop

    inline public function stopTweens():Void {

        if (tweenX != null) tweenX.destroy();
        if (tweenY != null) tweenY.destroy();

    } //stop

/// Smooth scroll

    public function scrollTo(scrollX:Float, scrollY:Float):Void {

        stop();

        this.scrollX = scrollX;
        this.scrollY = scrollY;

    } //smoothScrollTo

    public function smoothScrollTo(scrollX:Float, scrollY:Float, duration:Float = 0.15, ?easing:TweenEasing):Void {

        momentum = 0;
        animating = true;
        status = SCROLLING;
        stopTweens();

        if (easing == null) easing = QUAD_EASE_IN_OUT;

        if (scrollX != this.scrollX) {
            var tweenX = tween(0, easing, duration, this.scrollX, scrollX, function(scrollX, _) {
                this.scrollX = scrollX;
            });
            this.tweenX = tweenX;
            tweenX.onceComplete(this, function() {
                animating = false;
                status = IDLE;
            });
            tweenX.onDestroy(this, function() {
                if (this.tweenX == tweenX) {
                    this.tweenX = null;
                }
            });
        }

        if (scrollY != this.scrollY) {
            var tweenY = tween(1, easing, duration, this.scrollY, scrollY, function(scrollY, _) {
                this.scrollY = scrollY;
            });
            this.tweenY = tweenY;
            tweenY.onceComplete(this, function() {
                animating = false;
                status = IDLE;
            });
            tweenY.onDestroy(this, function() {
                if (this.tweenY == tweenY) {
                    this.tweenY = null;
                }
            });
        }

    } //smoothScrollTo

    public function snapTo(scrollX:Float, scrollY:Float, duration:Float = 0.15, ?easing:TweenEasing):Void {

        momentum = 0;
        snapping = true;
        status = SCROLLING;
        stopTweens();

        if (duration > 0) {
            smoothScrollTo(scrollX, scrollY, duration, easing);
        } else {
            scrollTo(scrollY, scrollY);
        }

    } //snapTo

    public function bounce():Void {

        var momentum = this.momentum;
        this.momentum = 0;

        animating = true;
        status = SCROLLING;
        stopTweens();

        if (direction == VERTICAL) {
            if (tweenY != null) tweenY.destroy();
            if (!overScrollRelease && (momentum > 0 || momentum < 0)) {
                var easing:TweenEasing = LINEAR;
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

                var tweenY = tween(0, easing, duration, 0, 1, function(t, _) {

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
                tweenY.onDestroy(this, function() {
                    if (this.tweenY == tweenY) {
                        this.tweenY = null;
                    }
                });

            }
            else {
                // No momentum
                var duration = bounceNoMomentumDuration;
                var easing:TweenEasing = QUAD_EASE_OUT;
                var fromY = scrollY;
                var toY:Float;
                if (Math.abs(scrollY - content.height + height) < Math.abs(scrollY)) {
                    toY = content.height - height;
                }
                else {
                    toY = 0;
                }
                var tweenY = tween(0, easing, duration * 2, fromY, toY, function(ty, _) {
                    scrollY = ty;
                });
                this.tweenY = tweenY;
                tweenY.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenY.onDestroy(this, function() {
                    if (this.tweenY == tweenY) {
                        this.tweenY = null;
                    }
                });
            }
        }
        else {
            if (tweenX != null) tweenX.destroy();
            if (!overScrollRelease && (momentum > 0 || momentum < 0)) {
                var easing:TweenEasing = LINEAR;
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

                var tweenX = tween(0, easing, duration, 0, 1, function(t, _) {

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
                tweenX.onDestroy(this, function() {
                    if (this.tweenX == tweenX) {
                        this.tweenX = null;
                    }
                });

            }
            else {
                // No momentum
                var duration = bounceNoMomentumDuration;
                var easing:TweenEasing = QUAD_EASE_OUT;
                var fromX = scrollX;
                var toX:Float;
                if (Math.abs(scrollX - content.width + width) < Math.abs(scrollX)) {
                    toX = content.width - width;
                }
                else {
                    toX = 0;
                }
                var tweenX = tween(0, easing, duration * 2, fromX, toX, function(tx, _) {
                    scrollX = tx;
                });
                this.tweenX = tweenX;
                tweenX.onceComplete(this, function() {
                    animating = false;
                    status = IDLE;
                });
                tweenX.onDestroy(this, function() {
                    if (this.tweenX == tweenX) {
                        this.tweenX = null;
                    }
                });
            }
        }

    } //bounce

} //Scroller
