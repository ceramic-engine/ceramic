package ceramic;

/** A particle item.
    You should not instanciate this yourself as
    it is managed by a `Particles` emitter object. */
@:allow(ceramic.ParticleEmitter)
class ParticleItem {

    public var visual:Visual = null;

    public var visualScaleActive:Bool = true;
    public var visualColorActive:Bool = true;
    public var visualPositionActive:Bool = true;
    public var visualRotationActive:Bool = true;
    public var visualAlphaActive:Bool = true;

    public var active:Bool = false;

    public var lifespan:Float = 0;
    public var age:Float = 0;

    /** The time relative to app when this particule was emitted */
    public var time:Float = 0;

    /** Convenience: hold a random value between 0 and 1 for each particle */
    public var random:Float = 0;

    /** In case implementation needs to keep a status for each particle, this property can be used for that */
    public var status:Int = 0;

    public var colorRangeActive:Bool = true;
    public var colorRangeStart:Color = Color.WHITE;
    public var colorRangeEnd:Color = Color.WHITE;
    @:isVar public var color(get,set):Color;
    inline function get_color():Color {
        var color:Color = Color.WHITE;
        if (visualColorActive && visual != null) {
            if (visual.asQuad != null) {
                color = visual.asQuad.color;
            }
            else if (visual.asMesh != null) {
                color = visual.asMesh.color;
            }
        }
        else {
            color = this.color;
        }
        return color;
    }
    inline function set_color(color:Color):Color {
        if (visualColorActive && visual != null) {
            if (visual.asQuad != null) {
                visual.asQuad.color = color;
            }
            else if (visual.asMesh != null) {
                visual.asMesh.color = color;
            }
        }
        return this.color = color;
    }

    public var accelerationRangeActive:Bool = true;
    public var accelerationRangeStartX:Float = 0;
    public var accelerationRangeStartY:Float = 0;
    public var accelerationRangeEndX:Float = 0;
    public var accelerationRangeEndY:Float = 0;
    public var accelerationX:Float = 0;
    public var accelerationY:Float = 0;

    public var dragRangeActive:Bool = true;
    public var dragRangeStartX:Float = 0;
    public var dragRangeStartY:Float = 0;
    public var dragRangeEndX:Float = 0;
    public var dragRangeEndY:Float = 0;
    public var dragX:Float = 0;
    public var dragY:Float = 0;

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

    public var angularDrag:Float = 0;

    public var scaleRangeActive:Bool = true;
    public var scaleRangeStartX:Float = 1;
    public var scaleRangeStartY:Float = 1;
    public var scaleRangeEndX:Float = 1;
    public var scaleRangeEndY:Float = 1;
    @:isVar public var scaleX(get,set):Float;
    inline function get_scaleX():Float {
        return visualScaleActive && visual != null ? visual.scaleX : this.scaleX;
    }
    inline function set_scaleX(scaleX:Float):Float {
        if (visualScaleActive && visual != null) {
            visual.scaleX = scaleX;
        }
        return this.scaleX = scaleX;
    }
    @:isVar public var scaleY(get,set):Float;
    inline function get_scaleY():Float {
        return visualScaleActive && visual != null ? visual.scaleY : this.scaleY;
    }
    inline function set_scaleY(scaleY:Float):Float {
        if (visualScaleActive && visual != null) {
            visual.scaleY = scaleY;
        }
        return this.scaleY = scaleY;
    }
    inline public function scale(scaleX:Float, scaleY:Float):Void {
        this.scaleX = scaleX;
        this.scaleY = scaleY;
    }

    @:isVar public var x(get,set):Float;
    inline function get_x():Float {
        return visualPositionActive && visual != null ? visual.x : this.x;
    }
    inline function set_x(x:Float):Float {
        if (visualPositionActive && visual != null) {
            visual.x = x;
        }
        return this.x = x;
    }
    @:isVar public var y(get,set):Float;
    inline function get_y():Float {
        return visualPositionActive && visual != null ? visual.y : this.y;
    }
    inline function set_y(y:Float):Float {
        if (visualPositionActive && visual != null) {
            visual.y = y;
        }
        return this.y = y;
    }
    inline public function pos(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
    }

    @:isVar public var angle(get,set):Float = 0;
    inline function get_angle():Float {
        return visualRotationActive && visual != null ? visual.rotation : this.angle;
    }
    inline function set_angle(angle:Float):Float {
        if (visualRotationActive && visual != null) {
            visual.rotation = angle;
        }
        return this.angle = angle;
    }

    public var alphaRangeActive:Bool = true;
    public var alphaRangeStart:Float = 1;
    public var alphaRangeEnd:Float = 1;
    @:isVar public var alpha(get,set):Float;
    inline function get_alpha():Float {
        return visualAlphaActive && visual != null ? visual.alpha : this.alpha;
    }
    inline function set_alpha(alpha:Float):Float {
        if (visualAlphaActive && visual != null) {
            visual.alpha = alpha;
        }
        return this.alpha = alpha;
    }

    private function new() {}

    inline public function reset():Void {

        age = 0;
        lifespan = 0;
        status = 0;
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

        dragRangeActive = true;
        dragRangeStartX = 0;
        dragRangeStartY = 0;
        dragRangeEndX = 0;
        dragRangeEndY = 0;
        dragX = 0;
        dragY = 0;

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

        angularDrag = 0;

        scaleRangeActive = true;
        scaleRangeStartX = 1;
        scaleRangeStartY = 1;
        scaleRangeEndX = 1;
        scaleRangeEndY = 1;

        pos(0, 0);
        scale(1, 1);
        alpha = 1;
        angle = 0;

    }

}
