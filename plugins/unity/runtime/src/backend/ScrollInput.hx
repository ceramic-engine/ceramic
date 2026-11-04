package backend;

import ceramic.MouseScrollConverter;
import ceramic.ScrollUnit;

#if !no_backend_docs
/**
 * Mouse scroll from Unity's Input System, one OS event at a time.
 *
 * `Mouse.scroll` sums the events of a frame, which loses what each event
 * says about the device (a notched wheel gives whole values, a precise
 * device fractional ones on macOS). So the backend listens to
 * `InputSystem.onEvent` and reads the scroll of each mouse state event,
 * then `backend.Screen` emits one `mouseScroll` per event once per frame
 * (`ceramic.MouseScrollConverter` gives the unit and the deltas, with the
 * rules of clay), and the legacy `mouseWheel` once per frame.
 *
 * The raw values do not depend on the project: `InputSettings.scrollDeltaBehavior`
 * is set to `KeepPlatformSpecificInputRange` (the values of the platform,
 * Unity 6000.0.9 and later), and `disableRedundantEventsMerging` to true (by
 * default the Input System merges the consecutive state events of a mouse
 * received in one update, summing their scroll). Units, Input System 1.14:
 *
 * - macOS: the values of the system's scroll events, about 1 per notch of a
 *   classic wheel (whole values, possibly more than 1 with acceleration),
 *   fractional for precise devices: clay's macOS rule (whole values are
 *   lines, fractional ones are pixels once multiplied by 10, a precise device
 *   seen less than 0.5 s ago keeps the events in pixels). To calibrate on the
 *   owner's devices (docs/UNITY.md of the GPUI port).
 * - Windows: 120 per notch (`WHEEL_DELTA`), less for high resolution wheels
 *   and precision touchpads: lines, `raw / 120`, like SDL.
 * - Linux and others: about 1 per notch: lines.
 *
 * The y of the Input System is positive away from the user (like SDL), so
 * `mouseScroll`'s `deltaY` is the opposite of the raw y.
 */
#end
class ScrollInput {

    #if !no_backend_docs
    /**
     * Converts the raw values of each event (unit, sign, scale).
     */
    #end
    public var converter(default, null):MouseScrollConverter = null;

    #if !no_backend_docs
    /**
     * Called for every scroll event emitted, with its raw values and what
     * was emitted (calibration and tests). The time is the Input System's
     * event time in seconds.
     */
    #end
    public var onScrollEvent:(rawX:Float, rawY:Float, time:Float, deltaX:Float, deltaY:Float, unit:ScrollUnit)->Void = null;

    #if !no_backend_docs
    /**
     * Raw values of the events received since the last `flush()`: x, y, time
     * for each event.
     */
    #end
    var pending:Array<Float> = [];

    var bound:Bool = false;

    #if !no_backend_docs
    /**
     * The C# delegate added to `InputSystem.onEvent` (kept to remove it).
     */
    #end
    var listener:Dynamic = null;

    var wheelRemainderX:Float = 0;

    var wheelRemainderY:Float = 0;

    public function new() {}

    #if !no_backend_docs
    /**
     * Sets the scroll delta behavior and listens to the Input System events
     * (once, from the first frame).
     */
    #end
    public function bind():Void {

        if (bound) return;
        bound = true;

        final os = ceramic.App.app.backend.info.operatingSystem();
        converter = new MouseScrollConverter(os == 'mac', os == 'windows' ? 120.0 : 1.0);

        // The raw range of the platform, and no merging of consecutive mouse
        // events (the Input System merges the state events of a mouse within
        // one update, summing their scroll, which would lose the value of
        // each event). A temporary settings object (no settings asset in the
        // project) is changed in place; an asset is copied first so that the
        // project's file is never modified.
        untyped __cs__('
            var settings = UnityEngine.InputSystem.InputSystem.settings;
            if (settings != null && (settings.scrollDeltaBehavior != UnityEngine.InputSystem.InputSettings.ScrollDeltaBehavior.KeepPlatformSpecificInputRange || !settings.disableRedundantEventsMerging)) {
                var copied = false;
                if (settings.hideFlags != UnityEngine.HideFlags.HideAndDontSave) {
                    settings = UnityEngine.Object.Instantiate(settings);
                    settings.hideFlags = UnityEngine.HideFlags.HideAndDontSave;
                    copied = true;
                }
                settings.scrollDeltaBehavior = UnityEngine.InputSystem.InputSettings.ScrollDeltaBehavior.KeepPlatformSpecificInputRange;
                settings.disableRedundantEventsMerging = true;
                if (copied) {
                    UnityEngine.InputSystem.InputSystem.settings = settings;
                }
            }
        ');

        listener = untyped __cs__('(System.Action<UnityEngine.InputSystem.LowLevel.InputEventPtr, UnityEngine.InputSystem.InputDevice>)((ev, device) => {
            var mouse = device as UnityEngine.InputSystem.Mouse;
            if (mouse == null) return;
            // Editor updates carry the events the game does not get (game
            // view without the focus), as Mouse.scroll did not either
            if (UnityEngine.InputSystem.LowLevel.InputState.currentUpdateType == UnityEngine.InputSystem.LowLevel.InputUpdateType.Editor) return;
            if (!ev.IsA<UnityEngine.InputSystem.LowLevel.StateEvent>() && !ev.IsA<UnityEngine.InputSystem.LowLevel.DeltaStateEvent>()) return;
            UnityEngine.Vector2 value;
            if (!UnityEngine.InputSystem.InputControlExtensions.ReadValueFromEvent<UnityEngine.Vector2>(mouse.scroll, ev, out value)) return;
            if (value.x == 0f && value.y == 0f) return;
            this.handleRawScroll(value.x, value.y, ev.time);
        })');
        untyped __cs__('UnityEngine.InputSystem.InputSystem.onEvent += (System.Action<UnityEngine.InputSystem.LowLevel.InputEventPtr, UnityEngine.InputSystem.InputDevice>){0}', listener);

        // Without a domain reload between two play sessions of the editor,
        // the listener of a previous app must not stay
        untyped __cs__('UnityEngine.Application.quitting += () => this.unbind()');

    }

    #if !no_backend_docs
    /**
     * Stops listening to the Input System events.
     */
    #end
    @:keep public function unbind():Void {

        if (listener != null) {
            untyped __cs__('UnityEngine.InputSystem.InputSystem.onEvent -= (System.Action<UnityEngine.InputSystem.LowLevel.InputEventPtr, UnityEngine.InputSystem.InputDevice>){0}', listener);
            listener = null;
        }
        pending.resize(0);

    }

    @:keep function handleRawScroll(x:Float, y:Float, time:Float):Void {

        pending.push(x);
        pending.push(y);
        pending.push(time);

    }

    #if !no_backend_docs
    /**
     * Emits the scroll events received since the previous call: one
     * `mouseScroll` per event, then one `mouseWheel` for the frame (the sum
     * of the frame in notches, whole values only, as before: the fraction
     * is kept for the next frames, in both directions alike).
     * @param screen The screen emitting the events
     */
    #end
    @:allow(backend.Screen)
    function flush(screen:Screen):Void {

        if (pending.length == 0) return;

        final events = pending;
        pending = [];

        var sumX:Float = 0;
        var sumY:Float = 0;
        var i = 0;
        while (i < events.length) {
            final rawX = events[i];
            final rawY = events[i + 1];
            final time = events[i + 2];
            i += 3;

            converter.convert(rawX, rawY, time);
            @:privateAccess screen.emitMouseScroll(converter.deltaX, converter.deltaY, converter.unit);
            if (onScrollEvent != null) {
                onScrollEvent(rawX, rawY, time, converter.deltaX, converter.deltaY, converter.unit);
            }

            sumX += rawX / converter.unitsPerLine;
            sumY += rawY / converter.unitsPerLine;
        }

        // Legacy mouseWheel: Unity's sign, notches
        if ((sumX > 0 && wheelRemainderX < 0) || (sumX < 0 && wheelRemainderX > 0)) wheelRemainderX = 0;
        if ((sumY > 0 && wheelRemainderY < 0) || (sumY < 0 && wheelRemainderY > 0)) wheelRemainderY = 0;
        final totalX = wheelRemainderX + sumX;
        final totalY = wheelRemainderY + sumY;
        final wheelX = totalX < 0 ? Math.fceil(totalX) : Math.ffloor(totalX);
        final wheelY = totalY < 0 ? Math.fceil(totalY) : Math.ffloor(totalY);
        wheelRemainderX = totalX - wheelX;
        wheelRemainderY = totalY - wheelY;
        if (wheelX != 0 || wheelY != 0) {
            @:privateAccess screen.emitMouseWheel(wheelX, wheelY);
        }

    }

}
