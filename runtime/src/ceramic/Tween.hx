package ceramic;

class Tween extends Entity {

/// Static helpers

    public static function start(?owner:Entity, ?id:Int, ?easing:TweenEasing, duration:Float, fromValue:Float, toValue:Float, update:Float->Float->Void):Tween {

        var instance = new Tween(owner, id, easing, duration, fromValue, toValue);
        
        instance.onUpdate(update);

        return instance;

    } //start

/// Events

    @event function update(value:Float, time:Float);

    @event function complete();

/// Properties

    var actuator:motion.actuators.GenericActuator<UpdateFloat>;

    var target:UpdateFloat;

    var startTime:Float;

/// Lifecycle

    private function new(?owner:Entity, ?id:Int, easing:TweenEasing, duration:Float, fromValue:Float, toValue:Float) {

        var actuateEasing = switch (easing) {

            case LINEAR: motion.easing.Linear.easeNone;

            case BACK_EASE_IN: motion.easing.Back.easeIn;
            case BACK_EASE_IN_OUT: motion.easing.Back.easeInOut;
            case BACK_EASE_OUT: motion.easing.Back.easeOut;

            case QUAD_EASE_IN: motion.easing.Quad.easeIn;
            case QUAD_EASE_IN_OUT: motion.easing.Quad.easeInOut;
            case QUAD_EASE_OUT: motion.easing.Quad.easeOut;

            case BOUNCE_EASE_IN: motion.easing.Bounce.easeIn;
            case BOUNCE_EASE_IN_OUT: motion.easing.Bounce.easeInOut;
            case BOUNCE_EASE_OUT: motion.easing.Bounce.easeOut;

            case CUBIC_EASE_IN: motion.easing.Cubic.easeIn;
            case CUBIC_EASE_IN_OUT: motion.easing.Cubic.easeInOut;
            case CUBIC_EASE_OUT: motion.easing.Cubic.easeOut;

            case ELASTIC_EASE_IN: motion.easing.Elastic.easeIn;
            case ELASTIC_EASE_IN_OUT: motion.easing.Elastic.easeInOut;
            case ELASTIC_EASE_OUT: motion.easing.Elastic.easeOut;

            case EXPO_EASE_IN: motion.easing.Expo.easeIn;
            case EXPO_EASE_IN_OUT: motion.easing.Expo.easeInOut;
            case EXPO_EASE_OUT: motion.easing.Expo.easeOut;

            case QUART_EASE_IN: motion.easing.Quart.easeIn;
            case QUART_EASE_IN_OUT: motion.easing.Quart.easeInOut;
            case QUART_EASE_OUT: motion.easing.Quart.easeOut;

            case QUINT_EASE_IN: motion.easing.Quint.easeIn;
            case QUINT_EASE_IN_OUT: motion.easing.Quint.easeInOut;
            case QUINT_EASE_OUT: motion.easing.Quint.easeOut;

            case SINE_EASE_IN: motion.easing.Sine.easeIn;
            case SINE_EASE_IN_OUT: motion.easing.Sine.easeInOut;
            case SINE_EASE_OUT: motion.easing.Sine.easeOut;

        }

#if js
        // Somehow, Actuate doesn't handle durations the same way
        // depending on the platform??
        var actuateDuration = duration;
#else
        var actuateDuration = duration * 1000;
#end
        
        startTime = Timer.now;
        target = new UpdateFloat(fromValue);
        actuator = motion.Actuate.tween(target, actuateDuration, { value: toValue }, false);

        actuator.onComplete(function() {
            if (destroyed) return;
            emitComplete();
            destroy();
        });

        actuator.onUpdate(function() {
            if (destroyed) return;
            var time = Timer.now - startTime;
            var value = target.value;
            emitUpdate(value, time);
        });

        actuator.ease(actuateEasing);

    } //new

    function destroy() {

        if (target != null) {
            motion.Actuate.stop(target);
            actuator = null;
            target = null;
        }

    } //destroy

} //Tween

@:allow(ceramic.Tween)
private class UpdateFloat {

    public var value:Float = 0;

    public function new(value:Float) {

        this.value = value;

    } //new
    
} //UpdateFloat
