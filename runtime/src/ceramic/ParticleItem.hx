package ceramic;

/** A particle item.
    You should not instanciate this yourself as
    it is managed by a `Particles` emitter object. */
@:allow(ceramic.Particles)
class ParticleItem {

    public var visual:Visual = null;

    public var active:Bool = false;

    public var lifespan:Float = 0;
    public var age:Float = 0;
    public var time:Float = 0;
    public var random:Float = 0;

    public var colorRangeActive:Bool = true;
    public var colorRangeStart:Color = Color.WHITE;
    public var colorRangeEnd:Color = Color.WHITE;
    public var color(get,set):Color;
    inline function get_color():Color {
        var color:Color = Color.WHITE;
        if (visual.asQuad != null) {
            color = visual.asQuad.color;
        }
        else if (visual.asMesh != null) {
            color = visual.asMesh.color;
        }
        return color;
    }
    inline function set_color(color:Color):Color {
        if (visual.asQuad != null) {
            visual.asQuad.color = color;
        }
        else if (visual.asMesh != null) {
            visual.asMesh.color = color;
        }
        return color;
    }

    public var accelerationRangeActive:Bool = true;
    public var accelerationRangeStartX:Float = 0;
    public var accelerationRangeStartY:Float = 0;
    public var accelerationRangeEndX:Float = 0;
    public var accelerationRangeEndY:Float = 0;
    public var accelerationX:Float = 0;
    public var accelerationY:Float = 0;

    public var decelerationRangeActive:Bool = true;
    public var decelerationRangeStartX:Float = 0;
    public var decelerationRangeStartY:Float = 0;
    public var decelerationRangeEndX:Float = 0;
    public var decelerationRangeEndY:Float = 0;
    public var decelerationX:Float = 0;
    public var decelerationY:Float = 0;

    public var velocityRangeActive:Bool = true;
    public var velocityRangeStartX:Float = 0;
    public var velocityRangeStartY:Float = 0;
    public var velocityRangeEndX:Float = 0;
    public var velocityRangeEndY:Float = 0;
    public var velocityX:Float = 0;
    public var velocityY:Float = 0;

    public var angularVelocityRangeActive:Bool = true;
    public var angularVelocityRangeStart:Float = 0;
    public var angularVelocityRangeEnd:Float = 0;
    public var angularVelocity:Float = 0;

    public var angularAccelerationRangeActive:Bool = true;
    public var angularAccelerationRangeStart:Float = 0;
    public var angularAccelerationRangeEnd:Float = 0;
    public var angularAcceleration:Float = 0;

    public var angularDeceleration:Float = 0;

    public var scaleRangeActive:Bool = true;
    public var scaleRangeStartX:Float = 1;
    public var scaleRangeStartY:Float = 1;
    public var scaleRangeEndX:Float = 1;
    public var scaleRangeEndY:Float = 1;
    public var scaleX(get,set):Float;
    inline function get_scaleX():Float {
        return visual.scaleX;
    }
    inline function set_scaleX(scaleX:Float):Float {
        visual.scaleX = scaleX;
        return scaleX;
    }
    public var scaleY(get,set):Float;
    inline function get_scaleY():Float {
        return visual.scaleY;
    }
    inline function set_scaleY(scaleY:Float):Float {
        visual.scaleY = scaleY;
        return scaleY;
    }
    inline public function scale(scaleX:Float, scaleY:Float):Void {
        visual.scale(scaleX, scaleY);
    }

    public var x(get,set):Float;
    inline function get_x():Float {
        return visual.x;
    }
    inline function set_x(x:Float):Float {
        visual.x = x;
        return x;
    }
    public var y(get,set):Float;
    inline function get_y():Float {
        return visual.y;
    }
    inline function set_y(y:Float):Float {
        visual.y = y;
        return y;
    }
    inline public function pos(x:Float, y:Float):Void {
        visual.pos(x, y);
    }

    public var angle(get,set):Float;
    inline function get_angle():Float {
        return visual.rotation;
    }
    inline function set_angle(angle:Float):Float {
        visual.rotation = angle;
        return angle;
    }

    public var alphaRangeActive:Bool = true;
    public var alphaRangeStart:Float = 1;
    public var alphaRangeEnd:Float = 1;
    public var alpha(get,set):Float;
    inline function get_alpha():Float {
        return visual.alpha;
    }
    inline function set_alpha(alpha:Float):Float {
        visual.alpha = alpha;
        return alpha;
    }

    private function new() {}

    inline public function reset():Void {

        age = 0;
        lifespan = 0;
        time = Timer.now;

        colorRangeActive = true;
        colorRangeStart = Color.WHITE;
        colorRangeEnd = Color.WHITE;
        color = Color.WHITE;

        accelerationRangeActive = true;
        accelerationRangeStartX = 0;
        accelerationRangeStartY = 0;
        accelerationRangeEndX = 0;
        accelerationRangeEndY = 0;
        accelerationX = 0;
        accelerationY = 0;

        decelerationRangeActive = true;
        decelerationRangeStartX = 0;
        decelerationRangeStartY = 0;
        decelerationRangeEndX = 0;
        decelerationRangeEndY = 0;
        decelerationX = 0;
        decelerationY = 0;

        velocityRangeActive = true;
        velocityRangeStartX = 0;
        velocityRangeStartY = 0;
        velocityRangeEndX = 0;
        velocityRangeEndY = 0;
        velocityX = 0;
        velocityY = 0;

        angularVelocityRangeActive = true;
        angularVelocityRangeStart = 0;
        angularVelocityRangeEnd = 0;
        angularVelocity = 0;

        angularAccelerationRangeActive = true;
        angularAccelerationRangeStart = 0;
        angularAccelerationRangeEnd = 0;
        angularAcceleration = 0;

        angularDeceleration = 0;

        scaleRangeActive = true;
        scaleRangeStartX = 1;
        scaleRangeStartY = 1;
        scaleRangeEndX = 1;
        scaleRangeEndY = 1;

        pos(0, 0);
        scale(1, 1);
        alpha = 1;
        angle = 0;

    } //reset

} //ParticleItem
