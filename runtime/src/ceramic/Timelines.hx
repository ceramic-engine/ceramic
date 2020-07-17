package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;

using ceramic.Extensions;

/**
 * App-level timeline related events.
 * You'll only need to track these events if you want to add new types of timeline tracks & keyframes
 * that can be created from raw data in `Fragment` instances.
 */
class Timelines extends Entity {

    /**
     * Used to expand how timeline tracks are created from raw data (from `Fragment` instances).
     * Respond to this event by assigning a value to the `result` argument.
     * @param type Type of the field being modified by the track
     * @param options Can be used to configure timeline track creation
     * @param result The object that will hold the resulting track.
     */
    @event public function createTrack(type:String, options:Dynamic<Dynamic>, result:Value<TimelineTrack<TimelineKeyframe>>);

    /**
     * Used to expand how timeline tracks are bound to objects.
     * @param type Type of the field being modified by the track
     * @param options Can be used to configure timeline track binding
     * @param track The track on which we bind the entity
     * @param entity The entity to bind to this track
     * @param field The entity field that should be updated by this track
     */
    @event public function bindTrack(type:String, options:Dynamic<Dynamic>, track:TimelineTrack<TimelineKeyframe>, entity:Entity, field:String);

    /**
     * Used to expand how timeline keyframes are created from raw data (from `Fragment` instances).
     * Respond to this event by assigning a value to the `result` argument.
     * @param type Type of the field being modified by the keyframe
     * @param options Can be used to configure timeline keyframe creation
     * @param value Value of the keyframe
     * @param time Time (in seconds) of the keyframe
     * @param easing Easing of the keyframe
     * @param existing Existing keyframe instance at the same position/time. Can be reused to prevent new allocation of keyframe instance
     * @param result The object that will hold the resulting keyframe.
     */
    @event public function createKeyframe(type:String, options:Dynamic<Dynamic>, value:Dynamic, time:Float, easing:Easing, existing:Null<TimelineKeyframe>, result:Value<TimelineKeyframe>);

    public function new() {

        super();

        onCreateTrack(this, handleCreateTrack);
        onBindTrack(this, handleBindTrack);
        onCreateKeyframe(this, handleCreateKeyframe);

    }

    function handleCreateTrack(type:String, options:Dynamic<Dynamic>, result:Value<TimelineTrack<TimelineKeyframe>>) {

        // Track already created?
        if (result.value != null)
            return;

        if (options != null && options.degrees == true) {
            result.value = cast new TimelineDegreesTrack();
        }
        else if (type == 'Float') {
            result.value = cast new TimelineFloatTrack();
        }
        else if (type == 'ceramic.Color') {
            result.value = cast new TimelineColorTrack();
        }
        else if (type == 'Bool') {
            result.value = cast new TimelineBoolTrack();
        }
        else if (type == 'Array<Float>') {
            result.value = cast new TimelineFloatArrayTrack();
        }

    }

    function handleBindTrack(type:String, options:Dynamic<Dynamic>, track:TimelineTrack<TimelineKeyframe>, entity:Entity, field:String) {

        if (Std.is(track, TimelineFloatTrack)) {
            var floatTrack:TimelineFloatTrack = cast track;
            floatTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.is(track, TimelineDegreesTrack)) {
            var degreesTrack:TimelineDegreesTrack = cast track;
            degreesTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.is(track, TimelineColorTrack)) {
            var colorTrack:TimelineColorTrack = cast track;
            colorTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.is(track, TimelineBoolTrack)) {
            var boolTrack:TimelineBoolTrack = cast track;
            boolTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.is(track, TimelineFloatArrayTrack)) {
            var copyArray:Bool = (options != null && options.copyArray == true);
            var floatArrayTrack:TimelineFloatArrayTrack = cast track;
            floatArrayTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                var array:Array<Float> = null;
                if (copyArray) {
                    array = [];
                }
                else {
                    array = entity.getProperty(field);
                    if (array == null) {
                        array = [];
                    }
                }
                var value = track.value;
                var valueLen = value.length;
                if (array.length != valueLen) {
                    array.setArrayLength(valueLen);
                }
                for (i in 0...valueLen) {
                    var val = value.unsafeGet(i);
                    array.unsafeSet(i, val);
                }
                entity.setProperty(field, array);
            });
        }

    }

    function handleCreateKeyframe(type:String, options:Dynamic<Dynamic>, value:Dynamic, time:Float, easing:Easing, existing:Null<TimelineKeyframe>, result:Value<TimelineKeyframe>) {

        // Keyframe already created?
        if (result.value != null)
            return;

        if (type == 'Float') {
            if (existing != null && Std.is(existing, TimelineFloatKeyframe)) {
                var floatKeyframe:TimelineFloatKeyframe = cast existing;
                floatKeyframe.value = value;
                floatKeyframe.time = time;
                floatKeyframe.easing = easing;
                result.value = floatKeyframe;
            }
            else {
                result.value = new TimelineFloatKeyframe(value, time, easing);
            }
        }
        else if (type == 'ceramic.Color') {
            if (existing != null && Std.is(existing, TimelineColorKeyframe)) {
                var colorKeyframe:TimelineColorKeyframe = cast existing;
                colorKeyframe.value = value;
                colorKeyframe.time = time;
                colorKeyframe.easing = easing;
                result.value = colorKeyframe;
            }
            else {
                result.value = new TimelineColorKeyframe(value, time, easing);
            }
        }
        else if (type == 'Bool') {
            if (existing != null && Std.is(existing, TimelineBoolKeyframe)) {
                var boolKeyframe:TimelineBoolKeyframe = cast existing;
                boolKeyframe.value = value;
                boolKeyframe.time = time;
                boolKeyframe.easing = easing;
                result.value = boolKeyframe;
            }
            else {
                result.value = new TimelineBoolKeyframe(value, time, easing);
            }
        }
        else if (type == 'Array<Float>') {
            if (existing != null && Std.is(existing, TimelineFloatArrayKeyframe)) {
                var floatArrayKeyframe:TimelineFloatArrayKeyframe = cast existing;
                var floatArrayValue:Array<Float> = cast value;
                floatArrayKeyframe.value = [].concat(floatArrayValue);
                floatArrayKeyframe.time = time;
                floatArrayKeyframe.easing = easing;
                result.value = floatArrayKeyframe;
            }
            else {
                result.value = new TimelineFloatArrayKeyframe(value, time, easing);
            }
        }

    }

}
