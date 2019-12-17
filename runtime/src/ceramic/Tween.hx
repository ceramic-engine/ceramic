package ceramic;

using ceramic.Extensions;

@:allow(ceramic.App)
class Tween extends Entity {

/// Events

    @event function update(value:Float, time:Float);

    @event function complete();

/// Properties

    var owner:Entity;

    var easing:Easing;

    var duration:Float;

    var remaining:Float;

    var fromValue:Float;

    var toValue:Float;

    var computedEasing:Void->Void;

    var customEasing:Float->Float = null;

/// Lifecycle

    private function new(#if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, easing:Easing, duration:Float, fromValue:Float, toValue:Float #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        this.owner = owner;
        this.easing = easing;
        this.duration = duration;
        this.fromValue = fromValue;
        this.toValue = toValue;

        init();

    } //new

    function init() {

        if (duration <= 0.0) {
            App.app.onceImmediate(immediateComplete);
            return;
        }

        computeEasing(easing);
        computedEasing = _computedEasingFunction;
        customEasing = _computedCustomEasing;
        _computedEasingFunction = null;
        _computedCustomEasing = null;

        _tweens.push(this);
        
        remaining = duration;

        App.app.onceImmediate(immediateStart);

    } //init

    inline function updateFromTick(delta:Float):Void {
        
        if (owner != null && owner.destroyed) {
            destroy();
        }
        else {
            remaining -= delta;
            if (remaining <= 0) {
                emitUpdate(toValue, duration);
                emitComplete();
                destroy();
            }
            else {
                var elapsed = (duration - remaining);
                TweenEasingFunction.k = elapsed / duration;
                var k = TweenEasingFunction.k;
                TweenEasingFunction.customEasing = customEasing;
                computedEasing();
                TweenEasingFunction.customEasing = null;
                emitUpdate(fromValue + (toValue - fromValue) * TweenEasingFunction.k, elapsed);
            }
        }

    } //updateFromTick

    function immediateComplete() {

        emitUpdate(toValue, 0);
        emitComplete();
        destroy();

    } //immediateComplete

    function immediateStart() {

        emitUpdate(fromValue, 0);

    } //immediateStar

    override function destroy() {

        easing = null;
        owner = null;
        computedEasing = null;
        customEasing = null;

        _tweens.remove(this);

        super.destroy();

    } //destroy

/// Static helpers

    static var _tweens:Array<Tween> = [];
    static var _iteratedTweens:Array<Tween> = [];

    public static function start(#if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, ?easing:Easing, duration:Float, fromValue:Float, toValue:Float, handleValueTime:Float->Float->Void #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Tween {

        var instance = new Tween(owner, easing == null ? Easing.QUAD_EASE_IN_OUT : easing, duration, fromValue, toValue #if ceramic_debug_entity_allocs , pos #end);
        
        instance.onUpdate(owner, handleValueTime);

        return instance;

    } //start

    static function tick(delta:Float):Void {

        // Iterate over tweens to update them.
        // We use a dedicated array for iteration to allow
        // active particles array to be updated while iterating
        var len = _tweens.length;
        for (i in 0...len) {
            var tween = _tweens.unsafeGet(i);
            _iteratedTweens[i] = tween;
        }
        for (i in 0...len) {
            var tween = _iteratedTweens.unsafeGet(i);
            _iteratedTweens.unsafeSet(i, null);
            tween.updateFromTick(delta);
        }

    } //tick

    static var _computedEasingFunction:Void->Void = null;
    static var _computedCustomEasing:Float->Float = null;

    inline static function computeEasing(easing:Easing):Void {

        switch (easing) {

            case NONE:
                _computedEasingFunction = TweenEasingFunction.none;

            case LINEAR:
                _computedEasingFunction = TweenEasingFunction.linear;

            case BACK_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.backEaseIn;
            case BACK_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.backEaseInOut;
            case BACK_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.backEaseOut;

            case QUAD_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.quadEaseIn;
            case QUAD_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.quadEaseInOut;
            case QUAD_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.quadEaseOut;

            case CUBIC_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.cubicEaseIn;
            case CUBIC_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.cubicEaseInOut;
            case CUBIC_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.cubicEaseOut;

            case QUART_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.quartEaseIn;
            case QUART_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.quartEaseInOut;
            case QUART_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.quartEaseOut;

            case QUINT_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.quintEaseIn;
            case QUINT_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.quintEaseInOut;
            case QUINT_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.quintEaseOut;

            case BOUNCE_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.bounceEaseIn;
            case BOUNCE_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.bounceEaseInOut;
            case BOUNCE_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.bounceEaseOut;

            case ELASTIC_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.elasticEaseIn;
            case ELASTIC_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.elasticEaseInOut;
            case ELASTIC_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.elasticEaseOut;

            case EXPO_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.expoEaseIn;
            case EXPO_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.expoEaseInOut;
            case EXPO_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.expoEaseOut;

            case SINE_EASE_IN:
                _computedEasingFunction = TweenEasingFunction.sineEaseIn;
            case SINE_EASE_IN_OUT:
                _computedEasingFunction = TweenEasingFunction.sineEaseInOut;
            case SINE_EASE_OUT:
                _computedEasingFunction = TweenEasingFunction.sineEaseOut;

            case BEZIER(x1, y1, x2, y2):
                _computedEasingFunction = TweenEasingFunction.custom;
                _computedCustomEasing = BezierEasing.get(x1, y1, x2, y2).ease;

            case CUSTOM(easing):
                _computedEasingFunction = TweenEasingFunction.custom;
                _computedCustomEasing = easing;

        }

    } //computeEasing

    public static function ease(easing:Easing, value:Float):Float {

        TweenEasingFunction.k = value;
        
        switch (easing) {

            case NONE:
                TweenEasingFunction.none();

            case LINEAR:
                TweenEasingFunction.linear();

            case BACK_EASE_IN:
                TweenEasingFunction.backEaseIn();
            case BACK_EASE_IN_OUT:
                TweenEasingFunction.backEaseInOut();
            case BACK_EASE_OUT:
                TweenEasingFunction.backEaseOut();

            case QUAD_EASE_IN:
                TweenEasingFunction.quadEaseIn();
            case QUAD_EASE_IN_OUT:
                TweenEasingFunction.quadEaseInOut();
            case QUAD_EASE_OUT:
                TweenEasingFunction.quadEaseOut();

            case CUBIC_EASE_IN:
                TweenEasingFunction.cubicEaseIn();
            case CUBIC_EASE_IN_OUT:
                TweenEasingFunction.cubicEaseInOut();
            case CUBIC_EASE_OUT:
                TweenEasingFunction.cubicEaseOut();

            case QUART_EASE_IN:
                TweenEasingFunction.quartEaseIn();
            case QUART_EASE_IN_OUT:
                TweenEasingFunction.quartEaseInOut();
            case QUART_EASE_OUT:
                TweenEasingFunction.quartEaseOut();

            case QUINT_EASE_IN:
                TweenEasingFunction.quintEaseIn();
            case QUINT_EASE_IN_OUT:
                TweenEasingFunction.quintEaseInOut();
            case QUINT_EASE_OUT:
                TweenEasingFunction.quintEaseOut();

            case BOUNCE_EASE_IN:
                TweenEasingFunction.bounceEaseIn();
            case BOUNCE_EASE_IN_OUT:
                TweenEasingFunction.bounceEaseInOut();
            case BOUNCE_EASE_OUT:
                TweenEasingFunction.bounceEaseOut();

            case ELASTIC_EASE_IN:
                TweenEasingFunction.elasticEaseIn();
            case ELASTIC_EASE_IN_OUT:
                TweenEasingFunction.elasticEaseInOut();
            case ELASTIC_EASE_OUT:
                TweenEasingFunction.elasticEaseOut();

            case EXPO_EASE_IN:
                TweenEasingFunction.expoEaseIn();
            case EXPO_EASE_IN_OUT:
                TweenEasingFunction.expoEaseInOut();
            case EXPO_EASE_OUT:
                TweenEasingFunction.expoEaseOut();

            case SINE_EASE_IN:
                TweenEasingFunction.sineEaseIn();
            case SINE_EASE_IN_OUT:
                TweenEasingFunction.sineEaseInOut();
            case SINE_EASE_OUT:
                TweenEasingFunction.sineEaseOut();

            case BEZIER(x1, y1, x2, y2):
                TweenEasingFunction.customEasing = BezierEasing.get(x1, y1, x2, y2).ease;
                TweenEasingFunction.custom();
                TweenEasingFunction.customEasing = null;

            case CUSTOM(easing):
                TweenEasingFunction.customEasing = easing;
                TweenEasingFunction.custom();
                TweenEasingFunction.customEasing = null;

        }

        return TweenEasingFunction.k;

    } //ease

    /** Get a tween easing function as a plain Float->Float function. */
    public static function easingFunction(easing:Easing):Float->Float {

        computeEasing(easing);
        var computedEasing = _computedEasingFunction;
        var customEasing = _computedCustomEasing;

        return function(value:Float):Float {
            TweenEasingFunction.k = value;
            TweenEasingFunction.customEasing = customEasing;
            computedEasing();
            TweenEasingFunction.customEasing = null;
            return TweenEasingFunction.k;
        };

    } //easingFunction

} //Tween

@:allow(ceramic.Tween)
private class TweenEasingFunction {

    /** Using `k` as static variable allows us to call easing function dynamically
        without needing boxing of float type on c++ target when it is passed as arg.
        (boxing of primitive types on c++ creates trash object references that give pressure to GC.
        When we can, we try to avoid it.) */
    public static var k:Float = 0;

    public static var customEasing:Float->Float = null;

/// Custom

    public static function custom():Void {
        k = customEasing(k);
    }

/// None

    public static function none():Void {
        k = (k >= 1) ? 1 : 0;
    }

/// Linear

    public static function linear():Void {
        // k = k
    }

/// Back

    public static function backEaseIn():Void {
        k = k * k * ((1.70158 + 1) * k - 1.70158);
    }

    public static function backEaseInOut():Void {
        var s:Float = 1.70158;
		if ((k *= 2) < 1) k = 0.5 * (k * k * (((s *= (1.525)) + 1) * k - s));
		else k = 0.5 * ((k -= 2) * k * (((s *= (1.525)) + 1) * k + s) + 2);
    }

    public static function backEaseOut():Void {
		k = ((k = k - 1) * k * ((1.70158 + 1) * k + 1.70158) + 1);
    }

/// Quad

    public static function quadEaseIn():Void {
        k = k * k;
    }

    public static function quadEaseInOut():Void {
		if ((k *= 2) < 1) {
			k = 1 / 2 * k * k;
		}
		else k = -1 / 2 * ((k - 1) * (k - 3) - 1);
    }

    public static function quadEaseOut():Void {
		k = -k * (k - 2);
    }

/// Cubic

    public static function cubicEaseIn():Void {
        k = k * k * k;
    }

    public static function cubicEaseInOut():Void {
		k = ((k /= 1 / 2) < 1) ? 0.5 * k * k * k : 0.5 * ((k -= 2) * k * k + 2);
    }

    public static function cubicEaseOut():Void {
		k = --k * k * k + 1;
    }

/// Quart

    public static function quartEaseIn():Void {
        k = k * k * k * k;
    }

    public static function quartEaseInOut():Void {
		if ((k *= 2) < 1) k = 0.5 * k * k * k * k;
		else k = -0.5 * ((k -= 2) * k * k * k - 2);
    }

    public static function quartEaseOut():Void {
		k = -(--k * k * k * k - 1);
    }

/// Quint

    public static function quintEaseIn():Void {
        k = k * k * k * k * k;
    }

    public static function quintEaseInOut():Void {
		if ((k *= 2) < 1) k = 0.5 * k * k * k * k * k;
		else k = 0.5 * ((k -= 2) * k * k * k * k + 2);
    }

    public static function quintEaseOut():Void {
		k = --k * k * k * k * k + 1;
    }

/// Bounce

    public static function bounceEaseIn():Void {
        k = _bounceEaseIn(k, 0, 1, 1);
    }

    public static function bounceEaseInOut():Void {
		if (k < .5) {
			k = _bounceEaseIn(k * 2, 0, 1, 1) * 0.5;
		} else {
			k = _bounceEaseOut(k * 2 - 1, 0, 1, 1) * 0.5 + 1 * 0.5; 
		}
    }

    public static function bounceEaseOut():Void {
		k = _bounceEaseOut(k, 0, 1, 1);
    }

    inline static function _bounceEaseIn(t:Float, b:Float, c:Float, d:Float):Float {
        return c - _bounceEaseOut(d-t, 0, c, d) + b;
    }

    inline static function _bounceEaseOut(t:Float, b:Float, c:Float, d:Float):Float {
        var result:Float;
		if ((t/=d) < (1/2.75)) {
			result = c * (7.5625 * t * t) + b;
		}
        else if (t < (2/2.75)) {
			result = c * (7.5625 * (t -= (1.5 / 2.75)) * t + 0.75) + b;
		}
        else if (t < (2.5/2.75)) {
			result = c * (7.5625 * (t -= (2.25 / 2.75)) * t + 0.9375) + b;
		}
        else {
			result = c * (7.5625 * (t -= (2.625 / 2.75)) * t + 0.984375) + b;
		}
        return result;
    }

/// Elastic

    public static function elasticEaseIn():Void {
		if (k == 0) return;
        if (k == 1) return;
        var a:Float = 0.1;
        var p:Float = 0.4;
		var s:Float;
		if (a < 1) {
            a = 1;
            s = p / 4;
        }
		else {
            s = p / (2 * Math.PI) * Math.asin (1 / a);
        }
		k = -(a * Math.exp(6.931471805599453 * (k -= 1)) * Math.sin( (k - s) * (2 * Math.PI) / p ));
    }

    public static function elasticEaseInOut():Void {
		if (k == 0) return;
		if ((k *= 2) == 2) {
            k = 1;
			return;
		}
		
		var p:Float = (0.3 * 1.5);
		var s:Float = p / 4;
		
		if (k < 1) {
			k = -0.5 * (Math.exp(6.931471805599453 * (k -= 1)) * Math.sin((k - s) * (2 * Math.PI) / p));
		}
		else k = Math.exp(-6.931471805599453 * (k -= 1)) * Math.sin((k - s) * (2 * Math.PI) / p) * 0.5 + 1;
    }

    public static function elasticEaseOut():Void {
		if (k == 0) return;
        if (k == 1) return;
        var a:Float = 0.1;
        var p:Float = 0.4;
		var s:Float;
		if (a < 1) {
            a = 1;
            s = p / 4;
        }
		else {
            s = p / (2 * Math.PI) * Math.asin (1 / a);
        }
		k = (a * Math.exp(-6.931471805599453 * k) * Math.sin((k - s) * (2 * Math.PI) / p ) + 1);
    }

/// Expo

    public static function expoEaseIn():Void {
        k = (k == 0 ? 0 : Math.exp(6.931471805599453 * (k - 1)));
    }

    public static function expoEaseInOut():Void {
		if (k == 0) return;
		if (k == 1) return;
		if ((k /= 1 / 2.0) < 1.0) {
			k = 0.5 * Math.exp(6.931471805599453 * (k - 1));
		}
		else k = 0.5 * (2 - Math.exp(-6.931471805599453 * --k));
    }

    public static function expoEaseOut():Void {
		k = (k == 1 ? 1 : (1 - Math.exp(-6.931471805599453 * k)));
    }

/// Sine

    public static function sineEaseIn():Void {
        k = 1 - Math.cos(k * (Math.PI / 2));
    }

    public static function sineEaseInOut():Void {
		k = -(Math.cos(Math.PI * k) - 1) / 2;
    }

    public static function sineEaseOut():Void {
		k = Math.sin(k * (Math.PI / 2));
    }

} //TweenEasingFunction

