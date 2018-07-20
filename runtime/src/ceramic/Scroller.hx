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

    public var overScrollDeceleration = 100.0;

    public var wheelDeceleration = 1600.0;

    public var wheelFactor = 1.0;

    public var wheelMomentum = #if mac true #else false #end;

    public var wheelEndDelay = 0.25;

    public var overScrollResistance = 5.0;

    public var bounceMaxMomentum = 50.0;

    public var bounceMinMomentum = 20.0;

    public var bounceMin = 100.0;

    public var bounceOverScrollMin = 1000.0;

    public var bounceAcceleration = 1000.0;

    public var bounceOverScrollAcceleration = 2000.0;

    public var maxClickMomentum = 100.0;

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

/// Internal

    var position:Float = 0;

    var contentStart:Float = 0;

    var pointerStart:Float = 0;

    var touchIndex:Int = -1;

    var velocity:Velocity = null;
    
    var momentum:Float = 0;

    var bounce:Float = 0;

    var overScrollRelease:Bool = false;

    var overScrolling:Bool = false;

    var fromWheel:Bool = false;

    var lastWheelEventTime:Float = -1;

    var canClick:Bool = false;

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
        bounce = 0;
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

        if (hits) {
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
        }

    } //pointerDown

    function pointerUp(info:TouchInfo):Void {

        if (info.touchIndex == touchIndex) {
            // Can click?
            if (status != TOUCHING || screen.focusedVisual != this) {
                canClick = false;
            }

            // End of drag
            status = SCROLLING;
            screen.offMultiTouchPointerUp(pointerUp);

            // Get momentum from velocity
            // and stop computing velocity
            momentum = velocity.get();
            velocity = null;
            touchIndex = -1;

            // Set bounce value
            bounce = 0;
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

    inline function isOverScrollingTop() {

        return scrollTransform.ty > 0;

    } //isOverScrollingTop

    inline function isOverScrollingBottom() {

        return scrollTransform.ty < height - content.height;

    } //isOverScrollingBottom

    inline function isOverScrollingLeft() {

        return scrollTransform.tx > 0;

    } //isOverScrollingLeft

    inline function isOverScrollingRight() {

        return scrollTransform.tx < width - content.width;

    } //isOverScrollingRight

/// Update loop

    function update(delta:Float):Void {

        var pointerX:Float = screen.pointerX;
        var pointerY:Float = screen.pointerY;

        if (touchIndex != -1) {
            var pointer = screen.touches.get(touchIndex);
            if (pointer != null) {
                pointerX = pointer.x;
                pointerY = pointer.y;
            }
        }

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
                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerY - pointerStart);
                }
                else {

                    if (Math.abs(pointerX - pointerStart) >= threshold) {
                        status = DRAGGING;
                        pointerStart = pointerX;
                        scrollTransform.tx = contentStart + pointerX - pointerStart;
                        scrollTransform.changedDirty = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerX - pointerStart);
                }
            
            case DRAGGING:
                if (direction == VERTICAL) {
                    scrollTransform.ty = contentStart + pointerY - pointerStart;

                    if (isOverScrollingTop()) {
                        scrollTransform.ty = scrollTransform.ty / overScrollResistance;
                    }
                    else {
                        var minY = height - content.height;
                        if (scrollTransform.ty < minY) {
                            scrollTransform.ty = minY + (scrollTransform.ty - minY) / overScrollResistance;
                        }
                    }

                    scrollTransform.changedDirty = true;
                    velocity.add(pointerY - pointerStart);
                }
                else {
                    scrollTransform.tx = contentStart + pointerX - pointerStart;

                    if (isOverScrollingLeft()) {
                        scrollTransform.tx = scrollTransform.tx / overScrollResistance;
                    }
                    else {
                        var minX = width - content.width;
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

                    if (isOverScrollingTop() || isOverScrollingBottom()) {

                        // Overscroll
                        overScrolling = true;

                        if (momentum > 0) {
                            momentum = Math.max(bounce == 0 ? bounceMinMomentum : 0, Math.min(momentum, bounceMaxMomentum));
                        } else if (momentum < 0) {
                            momentum = Math.min(bounce == 0 ? -bounceMinMomentum : 0, Math.max(momentum, -bounceMaxMomentum));
                        }
                        if (bounce != 0) {
                            subtract = Math.round(overScrollDeceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        }
                        
                        var add = Math.round(bounceAcceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        if (isOverScrollingTop()) {
                            // Overscroll bottom
                            if (bounce == 0) {
                                if (overScrollRelease) {
                                    bounce = -scrollTransform.ty * 7.5;
                                } else {
                                    bounce = -bounceMin;
                                }
                            }
                            bounce -= add * delta;
                            scrollTransform.ty = Math.max(0, scrollTransform.ty + bounce * delta);
                            scrollTransform.changedDirty = true;
                        }
                        else if (isOverScrollingBottom()) {
                            // Overscroll top
                            if (bounce == 0) {
                                if (overScrollRelease) {
                                    bounce = (height - content.height - scrollTransform.ty) * 7.5;
                                } else {
                                    bounce = bounceMin;
                                }
                            }
                            bounce += add * delta;
                            scrollTransform.ty = Math.min(height - content.height, scrollTransform.ty + bounce * delta);
                            scrollTransform.changedDirty = true;
                        }
                    }
                    else {
                        // Regular scroll
                        overScrolling = false;
                        if (fromWheel) {
                            subtract = Math.round(wheelDeceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        } else {
                            subtract = Math.round(deceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                        }
                    }

                    if (!overScrolling || Math.abs(momentum * delta) > screen.nativeHeight * screen.nativeDensity * 0.25) {
                        scrollTransform.ty += momentum * delta;
                        scrollTransform.changedDirty = true;
                    }
                    else {
                        momentum = 0;
                    }
                }
                else {
                    if (isOverScrollingLeft() || isOverScrollingRight()) {

                        // Overscroll
                        overScrolling = true;

                        if (momentum > 0) {
                            momentum = Math.max(bounce == 0 ? bounceMinMomentum : 0, Math.min(momentum, bounceMaxMomentum));
                        } else if (momentum < 0) {
                            momentum = Math.min(bounce == 0 ? -bounceMinMomentum : 0, Math.max(momentum, -bounceMaxMomentum));
                        }
                        if (bounce != 0) {
                            subtract = Math.round(overScrollDeceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        }
                        
                        var add = Math.round(bounceAcceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        if (isOverScrollingLeft()) {
                            // Overscroll bottom
                            if (bounce == 0) {
                                if (overScrollRelease) {
                                    bounce = -scrollTransform.tx * 7.5;
                                } else {
                                    bounce = -bounceMin;
                                }
                            }
                            bounce -= add * delta;
                            scrollTransform.tx = Math.max(0, scrollTransform.tx + bounce * delta);
                            scrollTransform.changedDirty = true;
                        }
                        else if (isOverScrollingRight()) {
                            // Overscroll top
                            if (bounce == 0) {
                                if (overScrollRelease) {
                                    bounce = (width - content.width - scrollTransform.tx) * 7.5;
                                } else {
                                    bounce = bounceMin;
                                }
                            }
                            bounce += add * delta;
                            scrollTransform.tx = Math.min(width - content.width, scrollTransform.tx + bounce * delta);
                            scrollTransform.changedDirty = true;
                        }
                    }
                    else {
                        // Regular scroll
                        overScrolling = false;
                        if (fromWheel) {
                            subtract = Math.round(wheelDeceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        } else {
                            subtract = Math.round(deceleration * screen.width / (screen.nativeWidth * screen.nativeDensity));
                        }
                    }

                    if (!overScrolling || Math.abs(momentum * delta) > screen.nativeWidth * screen.nativeDensity * 0.25) {
                        scrollTransform.tx += momentum * delta;
                        scrollTransform.changedDirty = true;
                    }
                    else {
                        momentum = 0;
                    }
                }

                if (momentum > 0) {
                    momentum = Math.max(0, momentum - subtract * delta);
                }
                else if (momentum < 0) {
                    momentum = Math.min(0, momentum + subtract * delta);
                }
                else if (momentum == 0) {
                    if (!overScrolling) {
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

    } //stop

/// Smooth scroll

    public function scrollTo(scrollX:Float, scrollY:Float):Void {

        stop();

        this.scrollX = scrollX;
        this.scrollY = scrollY;

    } //smoothScrollTo

    public function smoothScrollTo(scrollX:Float, scrollY:Float, duration:Float = 0.25, ?easing:TweenEasing):Void {

        stop();

        if (easing == null) easing = QUAD_EASE_IN_OUT;

        if (scrollX != this.scrollX) {
            tween(0, easing, duration, this.scrollX, scrollX, function(scrollX, _) {
                this.scrollX = scrollX;
            });
        }

        if (scrollY != this.scrollY) {
            tween(1, easing, duration, this.scrollY, scrollY, function(scrollY, _) {
                this.scrollY = scrollY;
            });
        }

    } //smoothScrollTo

} //Scroller
