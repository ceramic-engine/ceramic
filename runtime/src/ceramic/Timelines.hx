package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;

using ceramic.Extensions;

/**
 * Central system for creating and binding timeline tracks and keyframes.
 * 
 * The Timelines class serves as a factory and binding system for the timeline
 * animation framework. It handles:
 * - Creating appropriate track types based on field types
 * - Creating keyframes with proper typing
 * - Binding tracks to entity properties for automatic updates
 * - Extensibility through events for custom track/keyframe types
 * 
 * This system is primarily used by the Fragment system when loading
 * timeline data from .fragment files, but can also be extended to support
 * custom animation types.
 * 
 * Built-in support includes:
 * - Float tracks (numeric properties)
 * - Color tracks (Color properties)
 * - Boolean tracks (Bool properties)
 * - Float array tracks (Array<Float> properties)
 * - Degrees tracks (rotation with shortest-path interpolation)
 * 
 * To add custom track types:
 * 1. Listen to the `createTrack` event
 * 2. Check the type parameter
 * 3. Create and assign your custom track to result.value
 * 
 * Example extension:
 * ```haxe
 * app.timelines.onCreateTrack(this, (type, options, result) -> {
 *     if (type == "MyCustomType") {
 *         result.value = new MyCustomTrack();
 *     }
 * });
 * ```
 * 
 * @see Timeline
 * @see TimelineTrack
 * @see Fragment
 */
class Timelines extends Entity {

    /**
     * Event for creating timeline tracks from field type information.
     * 
     * Listen to this event to add support for custom track types.
     * The system will check all listeners until one sets result.value.
     * 
     * @param type The field type as a string (e.g., "Float", "Bool", "MyCustomType")
     * @param options Optional configuration from track data (e.g., {degrees: true})
     * @param result Assign the created track to result.value
     */
    @event public function createTrack(type:String, options:Dynamic<Dynamic>, result:Value<TimelineTrack<TimelineKeyframe>>);

    /**
     * Event for binding timeline tracks to entity properties.
     * 
     * Listen to this event to customize how track values are applied
     * to entity properties. Default implementation uses reflection
     * via entity.setProperty().
     * 
     * @param type The field type as a string
     * @param options Optional configuration (e.g., {copyArray: true})
     * @param track The track to bind
     * @param entity The entity whose property will be animated
     * @param field The property name to animate
     */
    @event public function bindTrack(type:String, options:Dynamic<Dynamic>, track:TimelineTrack<TimelineKeyframe>, entity:Entity, field:String);

    /**
     * Event for creating timeline keyframes from data.
     * 
     * Listen to this event to add support for custom keyframe types.
     * The system will check all listeners until one sets result.value.
     * 
     * Tip: Reuse the `existing` keyframe when possible to reduce allocations.
     * 
     * @param type The field type as a string
     * @param options Optional configuration
     * @param value The keyframe value (type depends on field type)
     * @param index The frame index (time position)
     * @param easing The easing function for interpolation
     * @param existing Existing keyframe at this index (can be reused)
     * @param result Assign the created/updated keyframe to result.value
     */
    @event public function createKeyframe(type:String, options:Dynamic<Dynamic>, value:Dynamic, index:Int, easing:Easing, existing:Null<TimelineKeyframe>, result:Value<TimelineKeyframe>);

    /**
     * Create a new Timelines system instance.
     * Automatically registers default handlers for built-in track types.
     */
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

        if (Std.isOfType(track, TimelineFloatTrack)) {
            var floatTrack:TimelineFloatTrack = cast track;
            floatTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.isOfType(track, TimelineDegreesTrack)) {
            var degreesTrack:TimelineDegreesTrack = cast track;
            degreesTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.isOfType(track, TimelineColorTrack)) {
            var colorTrack:TimelineColorTrack = cast track;
            colorTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.isOfType(track, TimelineBoolTrack)) {
            var boolTrack:TimelineBoolTrack = cast track;
            boolTrack.onChange(entity, track -> {
                // TODO optimize / avoid using reflection on visual properties etc...
                entity.setProperty(field, track.value);
            });
        }
        else if (Std.isOfType(track, TimelineFloatArrayTrack)) {
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

    function handleCreateKeyframe(type:String, options:Dynamic<Dynamic>, value:Dynamic, index:Int, easing:Easing, existing:Null<TimelineKeyframe>, result:Value<TimelineKeyframe>) {

        // Keyframe already created?
        if (result.value != null)
            return;

        if (type == 'Float') {
            if (existing != null && Std.isOfType(existing, TimelineFloatKeyframe)) {
                var floatKeyframe:TimelineFloatKeyframe = cast existing;
                floatKeyframe.value = value;
                floatKeyframe.index = index;
                floatKeyframe.easing = easing;
                result.value = floatKeyframe;
            }
            else {
                result.value = new TimelineFloatKeyframe(value, index, easing);
            }
        }
        else if (type == 'ceramic.Color') {
            if (existing != null && Std.isOfType(existing, TimelineColorKeyframe)) {
                var colorKeyframe:TimelineColorKeyframe = cast existing;
                colorKeyframe.value = value;
                colorKeyframe.index = index;
                colorKeyframe.easing = easing;
                result.value = colorKeyframe;
            }
            else {
                result.value = new TimelineColorKeyframe(value, index, easing);
            }
        }
        else if (type == 'Bool') {
            if (existing != null && Std.isOfType(existing, TimelineBoolKeyframe)) {
                var boolKeyframe:TimelineBoolKeyframe = cast existing;
                boolKeyframe.value = value;
                boolKeyframe.index = index;
                boolKeyframe.easing = easing;
                result.value = boolKeyframe;
            }
            else {
                result.value = new TimelineBoolKeyframe(value, index, easing);
            }
        }
        else if (type == 'Array<Float>') {
            if (existing != null && Std.isOfType(existing, TimelineFloatArrayKeyframe)) {
                var floatArrayKeyframe:TimelineFloatArrayKeyframe = cast existing;
                var floatArrayValue:Array<Float> = cast value;
                floatArrayKeyframe.value = [].concat(floatArrayValue);
                floatArrayKeyframe.index = index;
                floatArrayKeyframe.easing = easing;
                result.value = floatArrayKeyframe;
            }
            else {
                result.value = new TimelineFloatArrayKeyframe(value, index, easing);
            }
        }

    }

}
