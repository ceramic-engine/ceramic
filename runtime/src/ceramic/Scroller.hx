package ceramic;

import ceramic.ScrollDirection;
import ceramic.ScrollerStatus;
import ceramic.Shortcuts.*;

@:keep
class Scroller extends Quad {

/// Public properties

    public var content(default,null):Quad = new Quad();

    public var direction = VERTICAL;

    public var scrollTransform(default,null):Transform = new Transform();

    public var scrollEnabled(default,set):Bool = true;

    public var status:ScrollerStatus = IDLE;

/// Fine tuning

    public var deceleration = 100.0;

    public var overScrollDeceleration = 100.0;

    public var overScrollResistance = 5.0;

    public var bounceMaxMomentum = 50.0;

    public var bounceMinMomentum = 20.0;

    public var bounceMin = 100.0;

    public var bounceOverScrollMin = 1000.0;

    public var bounceAcceleration = 1000.0;

    public var bounceOverScrollAcceleration = 2000.0;

/// Lifecycle

    public function new() {

        super();

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

    function startTracking():Void {

        app.onUpdate(this, update);

        screen.onMultiTouchPointerDown(this, pointerDown);

        screen.onFocus(this, screenFocus);

    } //startTracking

    function stopTracking():Void {

        app.offUpdate(update);

        screen.offMultiTouchPointerDown(pointerDown);

        screen.offFocus(screenFocus);

    } //stopTracking

    function pointerDown(info:TouchInfo):Void {

        if (status == TOUCHING || status == DRAGGING) {
            // Did already put a finger on this scroller
            return;
        }

        // Does this touch intersect with our scroller?
        var hits = this.hits(info.x, info.y);

        if (hits) {
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
                if (scrollTransform.ty > 0 || scrollTransform.ty < height - content.height) {
                    overScrollRelease = true;
                }
                else {
                    overScrollRelease = false;
                }
            }
            else {
                if (scrollTransform.tx > 0 || scrollTransform.tx < width - content.width) {
                    overScrollRelease = true;
                }
                else {
                    overScrollRelease = false;
                }
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

    function update(delta:Float):Void {

        var pointerX:Float = screen.pointerX;
        var pointerY:Float = screen.pointerY;

        if (touchIndex != -1) {
            var pointer = screen.touches.get(touchIndex);
            pointerX = pointer.x;
            pointerY = pointer.y;
        }

        switch (status) {

            case IDLE:
                // Nothing to do

            case TOUCHING:

                if (direction == VERTICAL) {

                    var threshold = Math.round(5 * screen.height / (screen.nativeHeight * screen.nativeDensity));

                    if (Math.abs(pointerY - pointerStart) >= threshold) {
                        status = DRAGGING;
                        pointerStart = pointerY;
                        scrollTransform.ty = contentStart + pointerY - pointerStart;
                        scrollTransform.changed = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerY - pointerStart);
                }
                else {

                    var threshold = Math.round(4 * screen.width / (screen.nativeWidth * screen.nativeDensity));

                    if (Math.abs(pointerX - pointerStart) >= threshold) {
                        status = DRAGGING;
                        pointerStart = pointerX;
                        scrollTransform.tx = contentStart + pointerX - pointerStart;
                        scrollTransform.changed = true;

                        // Get focus
                        screen.focusedVisual = this;
                    }

                    velocity.add(pointerX - pointerStart);
                }
            
            case DRAGGING:
                if (direction == VERTICAL) {
                    scrollTransform.ty = contentStart + pointerY - pointerStart;

                    if (scrollTransform.ty > 0) {
                        scrollTransform.ty = scrollTransform.ty / overScrollResistance;
                    }
                    else {
                        var minY = height - content.height;
                        if (scrollTransform.ty < minY) {
                            scrollTransform.ty = minY + (scrollTransform.ty - minY) / overScrollResistance;
                        }
                    }

                    scrollTransform.changed = true;
                    velocity.add(pointerY - pointerStart);
                }
                else {
                    scrollTransform.tx = contentStart + pointerX - pointerStart;

                    if (scrollTransform.tx > 0) {
                        scrollTransform.tx = scrollTransform.tx / overScrollResistance;
                    }
                    else {
                        var minX = width - content.width;
                        if (scrollTransform.tx < minX) {
                            scrollTransform.tx = minX + (scrollTransform.tx - minX) / overScrollResistance;
                        }
                    }

                    scrollTransform.changed = true;
                    velocity.add(pointerX - pointerStart);
                }
            
            case SCROLLING:
                var subtract = 0.0;

                if (direction == VERTICAL) {
                    if (scrollTransform.ty > 0 || scrollTransform.ty < height - content.height) {

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
                        if (scrollTransform.ty > 0) {
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
                            scrollTransform.changed = true;
                        }
                        else if (scrollTransform.ty < height - content.height) {
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
                            scrollTransform.changed = true;
                        }
                    }
                    else {
                        // Regular scroll
                        overScrolling = false;
                        subtract = Math.round(deceleration * screen.height / (screen.nativeHeight * screen.nativeDensity));
                    }

                    if (!overScrolling || Math.abs(momentum * delta) > screen.nativeHeight * screen.nativeDensity * 0.25) {
                        scrollTransform.ty += momentum * delta;
                        scrollTransform.changed = true;
                    }
                    else {
                        momentum = 0;
                    }
                }
                else {
                    if (scrollTransform.tx > 0 || scrollTransform.tx < width - content.width) {

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
                        if (scrollTransform.tx > 0) {
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
                            scrollTransform.changed = true;
                        }
                        else if (scrollTransform.tx < width - content.width) {
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
                            scrollTransform.changed = true;
                        }
                    }
                    else {
                        // Regular scroll
                        overScrolling = false;
                        subtract = Math.round(deceleration * screen.width / (screen.nativeHeight * screen.nativeDensity));
                    }

                    if (!overScrolling || Math.abs(momentum * delta) > screen.nativeWidth * screen.nativeDensity * 0.25) {
                        scrollTransform.tx += momentum * delta;
                        scrollTransform.changed = true;
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

    } //update

} //Scroller
